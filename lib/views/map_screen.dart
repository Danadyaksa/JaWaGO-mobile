import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../controllers/auth_controller.dart';
import '../controllers/map_controller.dart';
import '../models/profile_model.dart';
import '../services/location_service.dart';
import '../utils/geo_helper.dart';
import 'inventory_screen.dart';
import 'widgets/wayang_modal.dart';
import 'widgets/landmark_modal.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapScreenController _controller = MapScreenController();
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();

  // State Data delegated to MapScreenController
  ProfileModel? get _profile => _controller.profile;
  set _profile(ProfileModel? val) => _controller.profile = val;

  List<dynamic> get _spawns => _controller.spawns;

  List<dynamic> get _landmarks => _controller.landmarks;

  List<int> get _visitedLandmarks => _controller.visitedLandmarks;

  int get _wayangCount => _controller.wayangCount;

  int get _landmarkCount => _controller.landmarkCount;

  // Route state delegated to MapScreenController
  List<LatLng> get _routeCoordinates => _controller.routeCoordinates;

  List<dynamic> get _routes => _controller.routes;

  int get _activeRouteIdx => _controller.activeRouteIdx;

  // Local state variables (UI state / handlers)
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _spawnsTimer;
  LatLng? _routeTarget;

  // Search & Filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _searchCategory = "all"; // 'all', 'wayang', 'landmark'
  String _searchElement = "all"; // 'all', 'Angin', 'Api', 'Bumi', 'Cahaya', 'Petir', 'Bulan', 'Spirit'
  bool _isSearchActive = false;

  // Overlays
  bool _showMenu = false;
  bool _showProfile = false;
  bool _showAbout = false;
  bool _showTips = false;
  bool _isEditingName = false;
  final TextEditingController _nameController = TextEditingController();

  int? _levelUpModal;

  // Detail Dialogs
  Map? _selectedPokemon;
  Map? _selectedLandmark;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _spawnsTimer?.cancel();
    _searchController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    final user = _controller.currentUser;
    if (user == null) {
      // Re-route to login if no active user session
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return;
    }

    await _fetchProfile();
    await _fetchLandmarks();
    await _fetchSpawns();

    // Start listening to user location
    _startLocationTracking();

    // Timer to pull spawns every 10 seconds (Matches NextJS)
    _spawnsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchSpawns();
    });
  }

  Future<void> _fetchProfile() async {
    try {
      await _controller.fetchProfile();
      if (mounted) {
        setState(() {
          _nameController.text = _profile?.displayName ?? 'Trainer';
        });
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    }
  }

  Future<void> _fetchLandmarks() async {
    try {
      await _controller.fetchLandmarks();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint("Error fetching landmarks: $e");
    }
  }

  Future<void> _fetchSpawns() async {
    try {
      await _controller.fetchSpawns();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint("Error fetching spawns: $e");
    }
  }

  void _startLocationTracking() async {
    final pos = await _locationService.getCurrentLocation();
    if (pos != null) {
      setState(() {
        _currentPosition = pos;
      });
      _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
    }

    _positionSubscription = _locationService.getLocationStream().listen((pos) {
      if (mounted) {
        setState(() {
          _currentPosition = pos;
        });
        // Recalculate route if target exists
        if (_routeTarget != null) {
          _fetchRoute(LatLng(pos.latitude, pos.longitude), _routeTarget!);
        }
      }
    });
  }

  // Fetch Route from OSRM delegated to controller
  Future<void> _fetchRoute(LatLng start, LatLng target) async {
    try {
      await _controller.fetchRoute(start, target);
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint("Error fetching route: $e");
    }
  }

  Future<void> _handleCatch(Map spawn) async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPS belum ke-detect!')),
      );
      return;
    }

    try {
      final res = await _controller.handleCatch(
        spawn,
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      );

      if (mounted) {
        if (res['success'] == true) {
          final double lat = (spawn['lat'] as num).toDouble();
          final double lng = (spawn['lng'] as num).toDouble();
          final double dist = GeoHelper.calculateDistance(
              _currentPosition!.latitude, _currentPosition!.longitude, lat, lng);
          const double maxRadius = 30;
          final isAdmin = _profile?.role == 'admin';

          if (isAdmin && dist > maxRadius) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: Colors.redAccent,
                content: Text('🔥 CHEAT MODE ACTIVE! Wayang berhasil ditangkap dari jauh!'),
              ),
            );
          } else {
            final xpReward = (spawn['pokedex']?['xp_reward'] ?? 100) as int;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gotcha! ${spawn['name']} tertangkap. +$xpReward XP')),
            );
          }

          if (res['levelUp'] != null) {
            setState(() {
              _levelUpModal = res['levelUp'] as int;
            });
          }

          setState(() {
            _selectedPokemon = null;
            _routeTarget = null;
            _controller.clearRoute();
          });

          // trigger server API to spawn another wayang if needed
          try {
            await http.get(Uri.parse('https://romzwsitdrsfbcbflhqc.supabase.co/functions/v1/spawn'));
          } catch (_) {}

          await _fetchSpawns();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Gagal menyimpan wayang.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan wayang: $e')),
        );
      }
    }
  }

  Future<void> _handleCollectLandmark(Map lm) async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPS belum ke-detect!')),
      );
      return;
    }

    try {
      final res = await _controller.handleCollectLandmark(
        lm,
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      );

      if (mounted) {
        if (res['success'] == true) {
          final double lat = (lm['lat'] as num).toDouble();
          final double lng = (lm['lng'] as num).toDouble();
          final double dist = GeoHelper.calculateDistance(
              _currentPosition!.latitude, _currentPosition!.longitude, lat, lng);
          const double maxRadius = 50;
          final isAdmin = _profile?.role == 'admin';

          if (isAdmin && dist > maxRadius) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: Colors.redAccent,
                content: Text('🔥 CHEAT MODE ACTIVE! Check-in landmark dari jauh berhasil!'),
              ),
            );
          } else {
            final xpReward = (lm['xp_reward'] ?? 500) as int;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Check-in Sukses! +$xpReward XP')),
            );
          }

          if (res['levelUp'] != null) {
            setState(() {
              _levelUpModal = res['levelUp'] as int;
            });
          }

          setState(() {
            _selectedLandmark = null;
            _routeTarget = null;
            _controller.clearRoute();
          });

          await _fetchProfile();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Gagal check-in.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal check-in atau udah pernah.')),
        );
      }
    }
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    try {
      await _controller.saveName(name);
      setState(() {
        if (_profile != null) {
          _profile = _profile!.copyWith(displayName: name);
        }
        _isEditingName = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan nama: $e')),
      );
    }
  }

  Future<void> _handleLogout() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Yakin mau logout dari game?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthController().logout();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  // Filtered Search Results
  List<dynamic> get _searchResults {
    if (_searchQuery.isEmpty && _searchCategory == 'all' && _searchElement == 'all') {
      return [];
    }

    List<dynamic> results = [];

    // Filter Wayang Spawns
    if (_searchCategory == 'all' || _searchCategory == 'wayang') {
      final matchedSpawns = _spawns.where((s) {
        final nameMatch = (s['name'] as String)
            .toLowerCase()
            .contains(_searchQuery.toLowerCase());
        final typeMatch = _searchElement == 'all' || s['type'] == _searchElement;
        return nameMatch && typeMatch;
      }).toList();

      results.addAll(matchedSpawns.map((s) => {...s, 'category': 'wayang'}));
    }

    // Filter Landmarks
    if ((_searchCategory == 'all' || _searchCategory == 'landmark') &&
        _searchElement == 'all') {
      final matchedLandmarks = _landmarks.where((l) {
        return (l['name'] as String)
            .toLowerCase()
            .contains(_searchQuery.toLowerCase());
      }).toList();

      results.addAll(matchedLandmarks.map((l) => {...l, 'category': 'landmark'}));
    }

    return results.take(10).toList();
  }

  // Nearest 5 Radar items
  List<dynamic> get _nearestRadarSpawns {
    if (_currentPosition == null || _spawns.isEmpty) return [];

    List<dynamic> mapped = _spawns.map((s) {
      final double lat = (s['lat'] as num).toDouble();
      final double lng = (s['lng'] as num).toDouble();
      final double dist = GeoHelper.calculateDistance(
          _currentPosition!.latitude, _currentPosition!.longitude, lat, lng);
      return {...s, 'distance': dist};
    }).toList();

    mapped.sort((a, b) => (a['distance'] as num).compareTo(b['distance'] as num));
    return mapped.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;


    return Scaffold(
      body: Stack(
        children: [
          // 1. Interactive Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(-7.7829, 110.3670), // Center of Jogja
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.jawago_mobile',
              ),

              // Player Range Ring
              if (_currentPosition != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      radius: 50, // 50 meters
                      useRadiusInMeter: true,
                      color: const Color(0xFF22C55E).withOpacity(0.1),
                      borderColor: const Color(0xFF22C55E),
                      borderStrokeWidth: 1.0,
                    ),
                  ],
                ),

              // Routing Polylines
              if (_routeCoordinates.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routeCoordinates,
                      color: const Color(0xFF3B82F6), // blue-500
                      strokeWidth: 6.0,
                    ),
                  ],
                ),

              // Markers
              MarkerLayer(
                markers: [
                  // User Marker
                  if (_currentPosition != null)
                    Marker(
                      point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      width: 32,
                      height: 32,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Wayang Spawns Markers
                  ..._spawns.map((s) {
                    final lat = (s['lat'] as num).toDouble();
                    final lng = (s['lng'] as num).toDouble();
                    return Marker(
                      point: LatLng(lat, lng),
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          debugPrint("Wayang marker tapped: ${s['name']}");
                          setState(() {
                            _selectedPokemon = s;
                            _selectedLandmark = null;
                            _isSearchActive = false;
                          });
                        },
                        child: Image.asset(
                          'assets/wayang-marker.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Image.network(
                            'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/poke-ball.png',
                          ),
                        ),
                      ),
                    );
                  }),

                  // Landmarks Markers
                  ..._landmarks.map((l) {
                    final lat = (l['lat'] as num).toDouble();
                    final lng = (l['lng'] as num).toDouble();
                    final isVisited = _visitedLandmarks.contains(l['id']);
                    return Marker(
                      point: LatLng(lat, lng),
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          debugPrint("Landmark marker tapped: ${l['name']}");
                          setState(() {
                            _selectedLandmark = l;
                            _selectedPokemon = null;
                            _isSearchActive = false;
                          });
                        },
                        child: isVisited
                            ? Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981), // emerald-500
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  '✓',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : Image.asset(
                                'assets/landmark-marker.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  LucideIcons.landmark,
                                  color: Colors.amber,
                                  size: 30,
                                ),
                              ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // 2. Floating Search Bar Overlay
          if (!_showMenu)
            Positioned(
              top: 48,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.4)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.search, color: Color(0xFF94A3B8), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Cari Wayang / Landmark...',
                              border: InputBorder.none,
                              isDense: true,
                              hintStyle: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                                _isSearchActive = true;
                              });
                            },
                            onTap: () {
                              setState(() {
                                _isSearchActive = true;
                              });
                            },
                          ),
                        ),
                        Container(width: 1, height: 20, color: const Color(0xFFE2E8F0)),
                        const SizedBox(width: 4),

                        // Category Dropdown
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _searchCategory,
                            icon: const Icon(LucideIcons.chevronDown, size: 10),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF475569),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('Semua')),
                              DropdownMenuItem(value: 'wayang', child: Text('Wayang')),
                              DropdownMenuItem(value: 'landmark', child: Text('Landmark')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _searchCategory = val;
                                  if (val == 'landmark') _searchElement = 'all';
                                  _isSearchActive = true;
                                });
                              }
                            },
                          ),
                        ),

                        // Element Dropdown (only visible if category is wayang/all)
                        if (_searchCategory != 'landmark') ...[
                          const SizedBox(width: 4),
                          Container(width: 1, height: 20, color: const Color(0xFFE2E8F0)),
                          const SizedBox(width: 4),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _searchElement,
                              icon: const Icon(LucideIcons.chevronDown, size: 10),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF475569),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'all', child: Text('Elemen')),
                                DropdownMenuItem(value: 'Angin', child: Text('Angin')),
                                DropdownMenuItem(value: 'Api', child: Text('Api')),
                                DropdownMenuItem(value: 'Bumi', child: Text('Bumi')),
                                DropdownMenuItem(value: 'Cahaya', child: Text('Cahaya')),
                                DropdownMenuItem(value: 'Petir', child: Text('Petir')),
                                DropdownMenuItem(value: 'Bulan', child: Text('Bulan')),
                                DropdownMenuItem(value: 'Spirit', child: Text('Spirit')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _searchElement = val;
                                    _isSearchActive = true;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Search Results panel
                  if (_isSearchActive && (_searchQuery.isNotEmpty || _searchElement != 'all'))
                    Container(
                      margin: const EdgeInsets.only(top: 8.0),
                      width: double.infinity,
                      constraints: BoxConstraints(maxHeight: size.height * 0.45),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header Results Panel
                          Container(
                            color: const Color(0xFFF8FAFC),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'HASIL (${_searchResults.length})',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => _isSearchActive = false),
                                  child: const Text(
                                    'Tutup',
                                    style: TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),

                          // Results Items List
                          Flexible(
                            child: _searchResults.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text(
                                      'Tidak ditemukan.',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    padding: EdgeInsets.zero,
                                    itemCount: _searchResults.length,
                                    itemBuilder: (context, idx) {
                                      final item = _searchResults[idx];
                                      final bool isWayang = item['category'] == 'wayang';

                                      String distText = "";
                                      String etaText = "";
                                      if (_currentPosition != null) {
                                        double d = GeoHelper.calculateDistance(
                                            _currentPosition!.latitude,
                                            _currentPosition!.longitude,
                                            (item['lat'] as num).toDouble(),
                                            (item['lng'] as num).toDouble());
                                        distText = d > 1000
                                            ? "${(d / 1000).toStringAsFixed(1)} km"
                                            : "${d.floor()} m";
                                        etaText = GeoHelper.calculateETA(d);
                                      }

                                      return InkWell(
                                        onTap: () {
                                          setState(() {
                                            if (isWayang) {
                                              _selectedPokemon = item;
                                            } else {
                                              _selectedLandmark = item;
                                            }
                                            _isSearchActive = false;
                                          });
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: isWayang
                                                      ? const Color(0xFFFEF3C7)
                                                      : const Color(0xFFDBEAFE),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  isWayang
                                                      ? LucideIcons.sparkles
                                                      : LucideIcons.landmark,
                                                  color: isWayang
                                                      ? const Color(0xFFD97706)
                                                      : const Color(0xFF2563EB),
                                                  size: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item['name'] ?? '',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                        color: Color(0xFF334155),
                                                      ),
                                                    ),
                                                    Text(
                                                      (item['category'] as String)
                                                          .toUpperCase(),
                                                      style: const TextStyle(
                                                        fontSize: 8,
                                                        color: Color(0xFF94A3B8),
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (_currentPosition != null)
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      distText,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF475569),
                                                      ),
                                                    ),
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                          LucideIcons.car,
                                                          size: 10,
                                                          color: Color(0xFF94A3B8),
                                                        ),
                                                        const SizedBox(width: 2),
                                                        Text(
                                                          etaText,
                                                          style: const TextStyle(
                                                            fontSize: 8,
                                                            color: Color(0xFF94A3B8),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          // 3. Navigation routing HUD display
          if (_routeTarget != null && _routes.isNotEmpty)
            Positioned(
              top: 110,
              right: 16,
              child: Container(
                width: 240,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header navigation details
                    Container(
                      color: const Color(0xFF2563EB), // blue-600
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'NAVIGASI AKTIF',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Pilih Jalur',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _routeTarget = null;
                                _controller.clearRoute();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.x,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Navigation paths list
                    Container(
                      color: const Color(0xFFF8FAFC),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: _routes.length,
                        itemBuilder: (context, idx) {
                          final r = _routes[idx];
                          final bool isActive = idx == _activeRouteIdx;
                          final durationMins = ((r['duration'] as num) / 60).ceil();
                          final distKm = ((r['distance'] as num) / 1000).toStringAsFixed(1);
                          final arrDt = DateTime.now().add(Duration(seconds: (r['duration'] as num).toInt()));
                          final arrivalTime = "${arrDt.hour.toString().padLeft(2, '0')}:${arrDt.minute.toString().padLeft(2, '0')}";

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _controller.selectRoute(idx);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                border: const Border(
                                  bottom: BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                color: isActive ? const Color(0xFFEFF6FF) : Colors.white,
                              ),
                              child: Row(
                                children: [
                                  if (isActive)
                                    Container(
                                      width: 4,
                                      height: 24,
                                      color: const Color(0xFF2563EB),
                                      margin: const EdgeInsets.only(right: 8),
                                    ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          idx == 0
                                              ? 'Rute Tercepat ($durationMins mnt)'
                                              : 'Alternatif $idx ($durationMins mnt)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: isActive
                                                ? const Color(0xFF1E40AF)
                                                : const Color(0xFF475569),
                                          ),
                                        ),
                                        Text(
                                          '$distKm km • Tiba pukul $arrivalTime',
                                          style: const TextStyle(
                                            fontSize: 9,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (idx == 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Best',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 7,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 4. BOTTOM TRAINER HUD
          if (!_showMenu)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16, top: 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.black.withOpacity(0.2),
                      Colors.transparent,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Trainer Profile Bubble (Left)
                    GestureDetector(
                      onTap: () => setState(() => _showProfile = true),
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(left: 32),
                            padding: const EdgeInsets.only(left: 40, right: 16, top: 4, bottom: 4),
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                              ),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _profile?.displayName.toUpperCase() ?? 'TRAINER',
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  'Lv. ${_profile?.level ?? 1}',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                )
                              ],
                            ),
                            child: ClipOval(
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                                child: const Icon(LucideIcons.user, color: Colors.white, size: 32),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Menu Trigger Button (Center)
                    GestureDetector(
                      onTap: () => setState(() => _showMenu = !_showMenu),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFEA580C)], // from-amber-500 to-orange-600
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/logo.png',
                            width: 32,
                            height: 32,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    // Radar sheet trigger (Right)
                    GestureDetector(
                      onTap: _openRadarSheet,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                            )
                          ],
                        ),
                        child: const Icon(
                          LucideIcons.radio,
                          color: Color(0xFF2563EB), // blue-600
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 5. FULL-SCREEN GLOW MENU OVERLAY (Center button clicked)
          if (_showMenu)
            GestureDetector(
              onTap: () => setState(() => _showMenu = false),
              child: Container(
                color: const Color(0xFF0F172A).withOpacity(0.92), // slate-900/90
                width: size.width,
                height: size.height,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Grid Menu Options
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 2,
                      mainAxisSpacing: 32,
                      crossAxisSpacing: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 56),
                      children: [
                        // Menu Koleksi
                        _buildMenuOption(
                          label: 'KOLEKSI',
                          icon: LucideIcons.backpack,
                          colors: [const Color(0xFFFBBF24), const Color(0xFFF97316)],
                          onTap: () {
                            setState(() => _showMenu = false);
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const InventoryScreen()),
                            ).then((_) {
                              _fetchProfile(); // reload profile stats on return
                            });
                          },
                        ),
                        // Menu Profil
                        _buildMenuOption(
                          label: 'PROFIL',
                          icon: LucideIcons.user,
                          colors: [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
                          onTap: () {
                            setState(() {
                              _showMenu = false;
                              _showProfile = true;
                            });
                          },
                        ),
                        // Menu Tentang
                        _buildMenuOption(
                          label: 'TENTANG',
                          icon: LucideIcons.info,
                          colors: [const Color(0xFF60A5FA), const Color(0xFF2563EB)],
                          onTap: () {
                            setState(() {
                              _showMenu = false;
                              _showAbout = true;
                            });
                          },
                        ),
                        // Menu Tips
                        _buildMenuOption(
                          label: 'TIPS',
                          icon: LucideIcons.lightbulb,
                          colors: [const Color(0xFF34D399), const Color(0xFF059669)],
                          onTap: () {
                            setState(() {
                              _showMenu = false;
                              _showTips = true;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),

                    // Close menu button
                    GestureDetector(
                      onTap: () => setState(() => _showMenu = false),
                      child: Container(
                        width: 60,
                        height: 60,
                        margin: const EdgeInsets.only(bottom: 28),
                        decoration: BoxDecoration(
                          color: const Color(0xFF475569), // slate-600
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: const Icon(LucideIcons.x, color: Colors.white, size: 28),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 6. PROFIL MODAL OVERLAY
          if (_showProfile && _profile != null)
            _buildProfileDialog(),

          // 7. TENTANG MODAL OVERLAY
          if (_showAbout)
            _buildAboutDialog(),

          // 8. TIPS MODAL OVERLAY
          if (_showTips)
            _buildTipsDialog(),

          // 9. WILD WAYANG MODAL OVERLAY
          if (_selectedPokemon != null)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: WayangModal(
                spawn: _selectedPokemon!,
                userLoc: _currentPosition != null
                    ? [_currentPosition!.latitude, _currentPosition!.longitude]
                    : null,
                isCaught: false,
                onClose: () => setState(() => _selectedPokemon = null),
                onRoute: (spawn) {
                  double targetLat = (spawn['lat'] as num).toDouble();
                  double targetLng = (spawn['lng'] as num).toDouble();
                  setState(() {
                    _routeTarget = LatLng(targetLat, targetLng);
                    _selectedPokemon = null;
                  });
                  if (_currentPosition != null) {
                    _fetchRoute(LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                        _routeTarget!);
                  }
                },
                onCatch: _handleCatch,
              ),
            ),

          // 10. LANDMARK MODAL OVERLAY
          if (_selectedLandmark != null)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: LandmarkModal(
                landmark: _selectedLandmark!,
                userLoc: _currentPosition != null
                    ? [_currentPosition!.latitude, _currentPosition!.longitude]
                    : null,
                isVisited: _visitedLandmarks.contains(_selectedLandmark!['id']),
                onClose: () => setState(() => _selectedLandmark = null),
                onRoute: (lm) {
                  double targetLat = (lm['lat'] as num).toDouble();
                  double targetLng = (lm['lng'] as num).toDouble();
                  setState(() {
                    _routeTarget = LatLng(targetLat, targetLng);
                    _selectedLandmark = null;
                  });
                  if (_currentPosition != null) {
                    _fetchRoute(LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                        _routeTarget!);
                  }
                },
                onCollect: _handleCollectLandmark,
              ),
            ),

          // 11. LEVEL UP CELEBRATION OVERLAY
          if (_levelUpModal != null)
            _buildLevelUpDialog(),
        ],
      ),
    );
  }

  // Radar Bottom Sheet modal
  void _openRadarSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final nearList = _nearestRadarSpawns;

            Widget radarBody;
            if (_currentPosition == null) {
              radarBody = Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text(
                      'Melacak Lokasi...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              );
            } else if (nearList.isEmpty) {
              radarBody = Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(LucideIcons.leaf, color: Color(0xFFCBD5E1), size: 36),
                    SizedBox(height: 8),
                    Text(
                      'Sepi amat, ga ada wayang.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              );
            } else {
              radarBody = ListView.builder(
                itemCount: nearList.length,
                itemBuilder: (context, idx) {
                  final s = nearList[idx];
                  final double dist = s['distance'] as double;
                  final distDisplay = dist > 1000
                      ? "${(dist / 1000).toStringAsFixed(1)} km"
                      : "${dist.floor()} m";

                  final lat = (s['lat'] as num).toDouble();
                  final lng = (s['lng'] as num).toDouble();
                  final address = GeoHelper.getMockAddress(lat, lng);
                  final eta = GeoHelper.calculateETA(dist);
                  final String name = s['name'] ?? '';
                  final String type = s['type'] ?? '';

                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() {
                        _selectedPokemon = s;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 4,
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Image.asset(
                              'assets/wayang/$name.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                LucideIcons.image,
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Icon(LucideIcons.mapPin,
                                        color: Color(0xFF94A3B8), size: 10),
                                    const SizedBox(width: 2),
                                    Expanded(
                                      child: Text(
                                        address,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    type.toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF475569),
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                distDisplay,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(LucideIcons.clock,
                                        color: Color(0xFF166534), size: 10),
                                    const SizedBox(width: 2),
                                    Text(
                                      eta,
                                      style: const TextStyle(
                                        color: Color(0xFF166534),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }

            return Container(
              padding: const EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.55,
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Radar Terdekat',
                    style: TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: radarBody,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Helper Widget for Overlay Grid Menu options
  Widget _buildMenuOption({
    required String label,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  // 6. Profile Dialog UI
  Widget _buildProfileDialog() {
    double progress = (_profile!.currentXp / _profile!.nextLevelXp).clamp(0.0, 1.0);

    return Container(
      color: Colors.black.withOpacity(0.8),
      alignment: Alignment.center,
      child: Container(
        width: 320,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: const Border(
            top: BorderSide(color: Color(0xFF6366F1), width: 4.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 24,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _showProfile = false),
                  child: const Icon(LucideIcons.x, color: Color(0xFF94A3B8), size: 20),
                )
              ],
            ),

            // Profile Avatar
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFEEF2F6), width: 4),
              ),
              child: const Icon(LucideIcons.user, color: Color(0xFF6366F1), size: 40),
            ),
            const SizedBox(height: 12),

            // Editable Display Name
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _isEditingName
                    ? Row(
                        children: [
                          Container(
                            width: 140,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: TextField(
                              controller: _nameController,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.only(bottom: 12),
                              ),
                              onSubmitted: (_) => _saveName(),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: _saveName,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.check, color: Colors.white, size: 14),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => setState(() => _isEditingName = false),
                            child: const Icon(LucideIcons.x, color: Color(0xFF94A3B8), size: 16),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Text(
                            _profile!.displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => setState(() => _isEditingName = true),
                            child: const Icon(
                              LucideIcons.pencil,
                              color: Color(0xFFCBD5E1),
                              size: 14,
                            ),
                          ),
                        ],
                      )
              ],
            ),
            const SizedBox(height: 4),

            // Role Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _profile!.role.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF6366F1),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Level Stats
            const Text(
              'LEVEL SAAT INI',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            Text(
              '${_profile!.level}',
              style: const TextStyle(
                fontSize: 48,
                color: Color(0xFF6366F1),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),

            // XP Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: const Color(0xFFEEF2F6),
                color: const Color(0xFF6366F1),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_profile!.currentXp} XP',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_profile!.nextLevelXp} XP',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Counts Grid
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEEF2F6)),
                    ),
                    child: Column(
                      children: [
                        const Icon(LucideIcons.sparkles, color: Colors.amber, size: 20),
                        const SizedBox(height: 4),
                        const Text(
                          'WAYANG',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$_wayangCount',
                          style: const TextStyle(color: Color(0xFF475569), fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEEF2F6)),
                    ),
                    child: Column(
                      children: [
                        const Icon(LucideIcons.landmark, color: Colors.blue, size: 20),
                        const SizedBox(height: 4),
                        const Text(
                          'LANDMARK',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$_landmarkCount',
                          style: const TextStyle(color: Color(0xFF475569), fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Logout Button
            OutlinedButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(LucideIcons.logOut, size: 14, color: Colors.redAccent),
              label: const Text(
                'Logout',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 7. About Dialog UI
  Widget _buildAboutDialog() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      alignment: Alignment.center,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: const Border(
            top: BorderSide(color: Color(0xFF2563EB), width: 4.0),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _showAbout = false),
                  child: const Icon(LucideIcons.x, color: Color(0xFF94A3B8), size: 20),
                )
              ],
            ),
            const Icon(LucideIcons.info, color: Color(0xFF2563EB), size: 48),
            const SizedBox(height: 12),
            const Text(
              'JAWA GO',
              style: TextStyle(fontSize: 18, color: Color(0xFF1E293B), fontWeight: FontWeight.w900),
            ),
            const Text(
              'v1.0.0',
              style: TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Jelajahi keindahan budaya Yogyakarta dengan cara baru!\n\nTemukan wayang tersembunyi dan kunjungi landmark bersejarah.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  // 8. Tips Dialog UI
  Widget _buildTipsDialog() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      alignment: Alignment.center,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: const Border(
            top: BorderSide(color: Color(0xFF10B981), width: 4.0),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _showTips = false),
                  child: const Icon(LucideIcons.x, color: Color(0xFF94A3B8), size: 20),
                )
              ],
            ),
            const Icon(LucideIcons.lightbulb, color: Color(0xFF10B981), size: 48),
            const SizedBox(height: 12),
            const Text(
              'Tips Bermain',
              style: TextStyle(fontSize: 18, color: Color(0xFF1E293B), fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD1FAE5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTipsItem('1', 'Nyalakan GPS untuk melihat wayang.'),
                  const SizedBox(height: 10),
                  _buildTipsItem('2', 'Mendekatlah < 30m untuk menangkap.'),
                  const SizedBox(height: 10),
                  _buildTipsItem('3', 'Cari Landmark untuk XP besar!'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => setState(() => _showTips = false),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 44),
                elevation: 0,
              ),
              child: const Text('Siap, Mengerti!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsItem(String num, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$num. ',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF047857), fontSize: 12),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFF065F46), fontSize: 12),
          ),
        )
      ],
    );
  }

  // 11. Level Up Overlay Dialog
  Widget _buildLevelUpDialog() {
    return Container(
      color: Colors.black.withOpacity(0.9),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.trophy, color: Colors.amber, size: 80),
          const SizedBox(height: 16),
          const Text(
            'LEVEL UP!',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.amber,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kamu sekarang Level $_levelUpModal',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 48),
          GestureDetector(
            onTap: () => setState(() => _levelUpModal = null),
            child: Container(
              width: 200,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.6),
                    blurRadius: 20,
                  )
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                'MANTAP!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
