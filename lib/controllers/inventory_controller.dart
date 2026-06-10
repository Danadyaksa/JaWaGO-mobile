import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryController {
  final SupabaseClient _client = Supabase.instance.client;

  List<dynamic> myPokemons = [];
  List<dynamic> myLandmarks = [];
  bool loading = true;

  String wayangSortBy = 'date';
  String wayangSortOrder = 'desc';
  String landmarkSortOrder = 'desc';

  Future<void> fetchStorage() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final wayangData = await _client
        .from('user_storage')
        .select('id, caught_at, pokedex(id, name, type, image_url, description, education, rarity, xp_reward)')
        .eq('user_id', user.id);

    final lmData = await _client
        .from('user_landmarks')
        .select('id, visited_at, landmarks(id, name, image_url, description, philosophy, lat, lng, xp_reward)')
        .eq('user_id', user.id);

    myPokemons = wayangData as List<dynamic>;
    myLandmarks = lmData as List<dynamic>;
    loading = false;
  }

  int _rarityValue(String rarity) {
    switch (rarity) {
      case 'Legendary':
        return 3;
      case 'Rare':
        return 2;
      default:
        return 1;
    }
  }

  List<dynamic> get sortedWayangs {
    List<dynamic> sorted = List.from(myPokemons);
    sorted.sort((a, b) {
      final aDex = a['pokedex'] ?? {};
      final bDex = b['pokedex'] ?? {};
      int comparison = 0;

      if (wayangSortBy == 'date') {
        final aDate = DateTime.parse(a['caught_at'] as String);
        final bDate = DateTime.parse(b['caught_at'] as String);
        comparison = aDate.compareTo(bDate);
      } else if (wayangSortBy == 'rarity') {
        comparison = _rarityValue(aDex['rarity'] ?? 'Common')
            .compareTo(_rarityValue(bDex['rarity'] ?? 'Common'));
      } else if (wayangSortBy == 'name') {
        final aName = (aDex['name'] ?? '') as String;
        final bName = (bDex['name'] ?? '') as String;
        comparison = aName.toLowerCase().compareTo(bName.toLowerCase());
      }

      return wayangSortOrder == 'asc' ? comparison : -comparison;
    });
    return sorted;
  }

  List<dynamic> get sortedLandmarks {
    List<dynamic> sorted = List.from(myLandmarks);
    sorted.sort((a, b) {
      final aDate = DateTime.parse(a['visited_at'] as String);
      final bDate = DateTime.parse(b['visited_at'] as String);
      int comparison = aDate.compareTo(bDate);
      return landmarkSortOrder == 'asc' ? comparison : -comparison;
    });
    return sorted;
  }
}
