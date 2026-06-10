import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_model.dart';
import '../utils/geo_helper.dart';

class MapScreenController {
  final SupabaseClient _client = Supabase.instance.client;

  // Controller State Variables
  ProfileModel? profile;
  List<dynamic> spawns = [];
  List<dynamic> landmarks = [];
  List<int> visitedLandmarks = [];
  int wayangCount = 0;
  int landmarkCount = 0;

  // Route state
  List<LatLng> routeCoordinates = [];
  List<dynamic> routes = [];
  int activeRouteIdx = 0;
  bool routeLoading = false;

  User? get currentUser => _client.auth.currentUser;

  Future<void> fetchProfile() async {
    final user = currentUser;
    if (user == null) return;

    final data = await _client
        .from('profiles')
        .select('*')
        .eq('id', user.id)
        .single();

    final wCount = await _client
        .from('user_storage')
        .select('id')
        .eq('user_id', user.id);

    final lCount = await _client
        .from('user_landmarks')
        .select('id')
        .eq('user_id', user.id);

    final visitData = await _client
        .from('user_landmarks')
        .select('landmark_id')
        .eq('user_id', user.id);

    profile = ProfileModel.fromJson(data);
    wayangCount = wCount.length;
    landmarkCount = lCount.length;
    visitedLandmarks = (visitData as List<dynamic>)
        .map((v) => v['landmark_id'] as int)
        .toList();
  }

  Future<void> fetchLandmarks() async {
    final data = await _client.from('landmarks').select('*');
    landmarks = data as List<dynamic>;
  }

  Future<void> fetchSpawns() async {
    final data = await _client.from('view_active_spawns').select('*');
    spawns = (data as List<dynamic>).map((item) {
      return {
        ...item,
        'pokedex': {
          'id': item['pokedex_id'],
          'name': item['name'],
          'type': item['type'],
          'description': item['description'],
          'image_url': item['image_url'],
          'education': item['education'],
          'rarity': item['rarity'],
          'xp_reward': item['xp_reward']
        }
      };
    }).toList();
  }

  Future<void> saveName(String newName) async {
    final user = currentUser;
    if (user == null) return;

    await _client
        .from('profiles')
        .update({'display_name': newName})
        .eq('id', user.id);
  }

  /// Handles catching a wayang.
  /// Returns a Map detailing status and message, e.g.
  /// {'success': true, 'message': 'MANTAP! Arjuna ketangkep...'}
  /// or returns a level integer if the catch caused a Level Up, e.g. {'success': true, 'levelUp': 2, 'message': '...'}
  Future<Map<String, dynamic>> handleCatch(Map spawn, LatLng currentPosition) async {
    final user = currentUser;
    if (user == null) return {'success': false, 'message': 'Sesi masuk tidak ditemukan. Silakan masuk kembali.'};

    final double lat = (spawn['lat'] as num).toDouble();
    final double lng = (spawn['lng'] as num).toDouble();
    final double dist = GeoHelper.calculateDistance(
        currentPosition.latitude, currentPosition.longitude, lat, lng);
    const double maxRadius = 30;

    final isAdmin = profile?.role == 'admin';
    if (!isAdmin && dist > maxRadius) {
      return {
        'success': false,
        'message': 'Jarak terlalu jauh (${dist.floor()}m). Silakan mendekat hingga kurang dari ${maxRadius.floor()}m.'
      };
    }

    await _client.from('user_storage').insert({
      'user_id': user.id,
      'pokedex_id': spawn['pokedex_id'],
    });

    await _client.from('active_spawns').delete().eq('id', spawn['id']);

    final pokedex = spawn['pokedex'] ?? spawn;
    final int xpGained = (pokedex['xp_reward'] is num)
        ? (pokedex['xp_reward'] as num).toInt()
        : int.tryParse(pokedex['xp_reward']?.toString() ?? '') ?? 100;

    final int? newLevel = await _addExperience(xpGained);

    final String name = spawn['name'] ?? 'Wayang';
    final String successMessage = isAdmin
        ? 'Mode Admin Aktif: Berhasil menangkap $name dari jarak ${dist.floor()}m.'
        : 'Berhasil menangkap $name (jarak: ${dist.floor()}m).';

    return {
      'success': true,
      'message': successMessage,
      'levelUp': newLevel,
    };
  }

  /// Handles checking in a landmark.
  Future<Map<String, dynamic>> handleCollectLandmark(Map landmark, LatLng currentPosition) async {
    final user = currentUser;
    if (user == null) return {'success': false, 'message': 'Sesi masuk tidak ditemukan. Silakan masuk kembali.'};

    final double lat = (landmark['lat'] as num).toDouble();
    final double lng = (landmark['lng'] as num).toDouble();
    final double dist = GeoHelper.calculateDistance(
        currentPosition.latitude, currentPosition.longitude, lat, lng);
    const double maxRadius = 50;

    final isAdmin = profile?.role == 'admin';
    if (!isAdmin && dist > maxRadius) {
      return {
        'success': false,
        'message': 'Jarak terlalu jauh (${dist.floor()}m). Silakan mendekat hingga kurang dari ${maxRadius.floor()}m.'
      };
    }

    await _client.from('user_landmarks').insert({
      'user_id': user.id,
      'landmark_id': landmark['id'],
    });

    final int xpGained = (landmark['xp_reward'] is num)
        ? (landmark['xp_reward'] as num).toInt()
        : int.tryParse(landmark['xp_reward']?.toString() ?? '') ?? 500;

    final int? newLevel = await _addExperience(xpGained);

    final String name = landmark['name'] ?? 'Landmark';
    final String successMessage = isAdmin
        ? 'Mode Admin Aktif: Berhasil check-in di $name dari jarak ${dist.floor()}m.'
        : 'Berhasil melakukan check-in di $name (jarak: ${dist.floor()}m).';

    return {
      'success': true,
      'message': successMessage,
      'levelUp': newLevel,
    };
  }

  /// Adds XP to user profile and handles level up logic.
  /// Returns new level if a level up occurred, else null.
  Future<int?> _addExperience(int xpGained) async {
    final user = currentUser;
    if (user == null || profile == null) return null;

    int newXp = profile!.currentXp + xpGained;
    int currentLevel = profile!.level;
    int nextLevelXp = profile!.nextLevelXp;
    int? levelUpTo;

    while (newXp >= nextLevelXp) {
      newXp -= nextLevelXp;
      currentLevel += 1;
      nextLevelXp = (nextLevelXp * 1.5).round();
      levelUpTo = currentLevel;
    }

    await _client.from('profiles').update({
      'current_xp': newXp,
      'level': currentLevel,
      'next_level_xp': nextLevelXp,
    }).eq('id', user.id);

    await fetchProfile();

    return levelUpTo;
  }

  /// Fetches route from OSRM driving router
  Future<void> fetchRoute(LatLng start, LatLng target) async {
    routeLoading = true;

    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${target.longitude},${target.latitude}?overview=full&geometries=geojson&alternatives=true';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['routes'] != null && data['routes'].length > 0) {
          final rawRoutes = data['routes'] as List<dynamic>;

          final List<dynamic> uniqueRoutes = [];
          for (var r in rawRoutes) {
            bool exists = uniqueRoutes.any((ur) =>
                ((ur['distance'] as num) - (r['distance'] as num)).abs() < 50);
            if (!exists) {
              uniqueRoutes.add(r);
            }
          }

          routes = uniqueRoutes;
          activeRouteIdx = 0;
          routeCoordinates = _parseCoordinates(
              uniqueRoutes[activeRouteIdx]['geometry']['coordinates']);
        }
      }
    } catch (e) {
      debugPrint("Error fetching route: $e");
    } finally {
      routeLoading = false;
    }
  }

  List<LatLng> _parseCoordinates(List<dynamic> coords) {
    return coords.map((c) {
      final list = c as List<dynamic>;
      return LatLng(list[1].toDouble(), list[0].toDouble());
    }).toList();
  }

  void selectRoute(int idx) {
    if (idx < 0 || idx >= routes.length) return;
    activeRouteIdx = idx;
    routeCoordinates = _parseCoordinates(
        routes[activeRouteIdx]['geometry']['coordinates']);
  }

  void clearRoute() {
    routeCoordinates = [];
    routes = [];
    activeRouteIdx = 0;
  }
}
