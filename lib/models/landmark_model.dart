class LandmarkModel {
  final int id;
  final String name;
  final String imageUrl;
  final String description;
  final String philosophy;
  final double lat;
  final double lng;
  final int xpReward;

  LandmarkModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.description,
    required this.philosophy,
    required this.lat,
    required this.lng,
    required this.xpReward,
  });

  factory LandmarkModel.fromJson(Map<String, dynamic> json) {
    return LandmarkModel(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      imageUrl: (json['image_url'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      philosophy: (json['philosophy'] ?? '') as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      xpReward: (json['xp_reward'] ?? 500) as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image_url': imageUrl,
      'description': description,
      'philosophy': philosophy,
      'lat': lat,
      'lng': lng,
      'xp_reward': xpReward,
    };
  }
}

class UserLandmarkModel {
  final int id;
  final String visitedAt;
  final LandmarkModel landmark;

  UserLandmarkModel({
    required this.id,
    required this.visitedAt,
    required this.landmark,
  });

  factory UserLandmarkModel.fromJson(Map<String, dynamic> json) {
    return UserLandmarkModel(
      id: json['id'] as int,
      visitedAt: (json['visited_at'] ?? '') as String,
      landmark: LandmarkModel.fromJson(json['landmarks'] ?? {}),
    );
  }
}
