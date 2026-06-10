class ProfileModel {
  final String id;
  final String displayName;
  final int level;
  final int currentXp;
  final int nextLevelXp;
  final String role;

  ProfileModel({
    required this.id,
    required this.displayName,
    required this.level,
    required this.currentXp,
    required this.nextLevelXp,
    required this.role,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      displayName: (json['display_name'] ?? 'Trainer') as String,
      level: (json['level'] ?? 1) as int,
      currentXp: (json['current_xp'] ?? 0) as int,
      nextLevelXp: (json['next_level_xp'] ?? 100) as int,
      role: (json['role'] ?? 'player') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'level': level,
      'current_xp': currentXp,
      'next_level_xp': nextLevelXp,
      'role': role,
    };
  }

  ProfileModel copyWith({
    String? id,
    String? displayName,
    int? level,
    int? currentXp,
    int? nextLevelXp,
    String? role,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      level: level ?? this.level,
      currentXp: currentXp ?? this.currentXp,
      nextLevelXp: nextLevelXp ?? this.nextLevelXp,
      role: role ?? this.role,
    );
  }
}
