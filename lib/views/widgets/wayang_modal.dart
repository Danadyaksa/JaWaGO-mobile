import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../utils/geo_helper.dart';

class WayangModal extends StatelessWidget {
  final Map spawn; // or spawn model
  final List<double>? userLoc;
  final bool isCaught;
  final VoidCallback onClose;
  final Function(Map) onRoute;
  final Function(Map) onCatch;

  const WayangModal({
    super.key,
    required this.spawn,
    this.userLoc,
    required this.isCaught,
    required this.onClose,
    required this.onRoute,
    required this.onCatch,
  });

  @override
  Widget build(BuildContext context) {
    final pokedex = spawn['pokedex'] ?? spawn;
    final String name = (pokedex['name'] ?? 'Unknown') as String;
    final String type = (pokedex['type'] ?? 'Default') as String;
    final String description = (pokedex['description'] ?? '') as String;
    final String imageUrl = (pokedex['image_url'] ?? '') as String;
    final String education = (pokedex['education'] ?? '') as String;
    final String rarity = (pokedex['rarity'] ?? 'Common') as String;
    final int xpReward = (pokedex['xp_reward'] is num)
        ? (pokedex['xp_reward'] as num).toInt()
        : int.tryParse(pokedex['xp_reward']?.toString() ?? '') ?? 100;

    // Element Gradients
    final typeColors = {
      'Angin': [const Color(0xFF2DD4BF), const Color(0xFF059669)],
      'Api': [const Color(0xFFF97316), const Color(0xFFDC2626)],
      'Bumi': [const Color(0xFFB45309), const Color(0xFFCA8A04)],
      'Air': [const Color(0xFF3B82F6), const Color(0xFF06B6D4)],
      'Petir': [const Color(0xFFFACC15), const Color(0xFFF59E0B)],
      'Cahaya': [const Color(0xFFFEF08A), const Color(0xFFFDBA74)],
      'Bulan': [const Color(0xFF6366F1), const Color(0xFF9333EA)],
      'Spirit': [const Color(0xFF8B5CF6), const Color(0xFFC084FC)],
      'Default': [const Color(0xFF94A3B8), const Color(0xFF475569)],
    };
    final activeGradient = typeColors[type] ?? typeColors['Default']!;

    // Rarity Background Colors
    final rarityColors = {
      'Common': const Color(0xFF64748B),
      'Rare': const Color(0xFF2563EB),
      'Legendary': const Color(0xFF7C3AED),
    };
    final rarityBg = rarityColors[rarity] ?? const Color(0xFF64748B);

    // Calc distance & ETA
    String distanceInfo = "???";
    String etaInfo = "???";
    if (userLoc != null && !isCaught) {
      double lat = (spawn['lat'] as num).toDouble();
      double lng = (spawn['lng'] as num).toDouble();
      double dist = GeoHelper.calculateDistance(userLoc![0], userLoc![1], lat, lng);
      distanceInfo = dist > 1000
          ? "${(dist / 1000).toStringAsFixed(1)} km"
          : "${dist.floor()} m";
      etaInfo = GeoHelper.calculateETA(dist);
    }

    String? caughtDate;
    if (isCaught && spawn['caught_at'] != null) {
      DateTime dt = DateTime.parse(spawn['caught_at'] as String);
      caughtDate = "${dt.day} ${[
        '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ][dt.month]} ${dt.year}";
    }

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: 360,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Banner Gradient
              Container(
                height: 190,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: activeGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Texture overlay
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.1,
                        child: Image.network(
                          'https://www.transparenttextures.com/patterns/cubes.png',
                          repeat: ImageRepeat.repeat,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        ),
                      ),
                    ),

                    // Close Button
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: onClose,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.x,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),

                    // Rarity Badge
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: rarityBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                          boxShadow: rarity == 'Legendary'
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFA855F7).withOpacity(0.6),
                                    blurRadius: 10,
                                  )
                                ]
                              : null,
                        ),
                        child: Text(
                          rarity.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),

                    // Image (Silhouette if wild/uncaught)
                    Center(
                      child: Container(
                        width: 140,
                        height: 140,
                        alignment: Alignment.center,
                        child: Image.asset(
                          'assets/wayang/${name}.png',
                          fit: BoxFit.contain,
                          // Silhouette effect for uncaught
                          color: !isCaught ? Colors.black.withOpacity(0.75) : null,
                          colorBlendMode: !isCaught ? BlendMode.srcIn : null,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback to loaded imageUrl
                            return Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                              color: !isCaught ? Colors.black.withOpacity(0.75) : null,
                              colorBlendMode: !isCaught ? BlendMode.srcIn : null,
                              errorBuilder: (_, __, ___) => const Icon(
                                LucideIcons.image,
                                color: Colors.white30,
                                size: 50,
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Bottom info overlays (caught date or distance)
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: isCaught
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: Text(
                                '✅ DITANGKAP: ${caughtDate ?? "Baru saja"}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : (userLoc != null
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(LucideIcons.mapPin, color: Colors.white, size: 10),
                                          const SizedBox(width: 4),
                                          Text(
                                            distanceInfo,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(LucideIcons.clock, color: Colors.white, size: 10),
                                          const SizedBox(width: 4),
                                          Text(
                                            etaInfo,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox()),
                    ),
                  ],
                ),
              ),

              // Detail Section
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Name & Type row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (!isCaught)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      const Text(
                                        '✨ Reward: ',
                                        style: TextStyle(
                                          color: Color(0xFFD97706),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '+$xpReward XP',
                                          style: const TextStyle(
                                            color: Color(0xFFB45309),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 9,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: activeGradient),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: activeGradient.first.withOpacity(0.3),
                                blurRadius: 6,
                              )
                            ],
                          ),
                          child: Text(
                            type.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 8),

                    // Description text
                    Container(
                      padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: Color(0xFFCBD5E1),
                            width: 4.0,
                          ),
                        ),
                      ),
                      child: Text(
                        '"$description"',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Philosophy box (unlocked if caught, locked otherwise)
                    Container(
                      height: 130,
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB), // amber-50
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFEF3C7)), // amber-100
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: const [
                              Icon(LucideIcons.lightbulb, color: Color(0xFFD97706), size: 16),
                              SizedBox(width: 6),
                              Text(
                                'FILOSOFI BUDAYA',
                                style: TextStyle(
                                  color: Color(0xFF78350F),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: isCaught
                                ? SingleChildScrollView(
                                    child: Text(
                                      education,
                                      style: const TextStyle(
                                        color: Color(0xFF78350F),
                                        fontSize: 11,
                                        height: 1.4,
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(
                                          LucideIcons.lock,
                                          color: Color(0xFFB45309),
                                          size: 20,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Tangkap untuk membuka rahasia!',
                                          style: TextStyle(
                                            color: Color(0xFFB45309),
                                            fontSize: 10,
                                            fontStyle: FontStyle.italic,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),

                    // Capture / Navigate actions (shown if wild/uncaught)
                    if (!isCaught) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => onRoute(spawn),
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(LucideIcons.navigation, color: Color(0xFF64748B), size: 14),
                                    SizedBox(width: 6),
                                    Text(
                                      'Rute',
                                      style: TextStyle(
                                        color: Color(0xFF475569),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => onCatch(spawn),
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: activeGradient),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: activeGradient.first.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(LucideIcons.sparkles, color: Colors.white, size: 14),
                                    SizedBox(width: 6),
                                    Text(
                                      'Tangkap!',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
