class PokedexModel {
  final int id;
  final String name;
  final String type;
  final String description;
  final String imageUrl;
  final String education;
  final String rarity;
  final int xpReward;

  PokedexModel({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.imageUrl,
    required this.education,
    required this.rarity,
    required this.xpReward,
  });

  factory PokedexModel.fromJson(Map<String, dynamic> json) {
    return PokedexModel(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      type: (json['type'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      imageUrl: (json['image_url'] ?? '') as String,
      education: (json['education'] ?? '') as String,
      rarity: (json['rarity'] ?? 'Common') as String,
      xpReward: (json['xp_reward'] ?? 100) as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'description': description,
      'image_url': imageUrl,
      'education': education,
      'rarity': rarity,
      'xp_reward': xpReward,
    };
  }
}

class SpawnModel {
  final int id;
  final int pokedexId;
  final double lat;
  final double lng;
  final String? createdAt;
  final PokedexModel pokedex;

  SpawnModel({
    required this.id,
    required this.pokedexId,
    required this.lat,
    required this.lng,
    this.createdAt,
    required this.pokedex,
  });

  factory SpawnModel.fromJson(Map<String, dynamic> json) {
    return SpawnModel(
      id: json['id'] as int,
      pokedexId: (json['pokedex_id'] ?? 0) as int,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      createdAt: json['created_at'] as String?,
      pokedex: PokedexModel.fromJson(json['pokedex'] ?? {}),
    );
  }
}

class UserStorageModel {
  final int id;
  final String caughtAt;
  final PokedexModel pokedex;

  UserStorageModel({
    required this.id,
    required this.caughtAt,
    required this.pokedex,
  });

  factory UserStorageModel.fromJson(Map<String, dynamic> json) {
    return UserStorageModel(
      id: json['id'] as int,
      caughtAt: (json['caught_at'] ?? '') as String,
      pokedex: PokedexModel.fromJson(json['pokedex'] ?? json['pokedex_id'] ?? {}),
    );
  }
}
