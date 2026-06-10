import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../utils/geo_helper.dart';

class LandmarkModal extends StatelessWidget {
  final Map landmark;
  final List<double>? userLoc;
  final bool isVisited;
  final VoidCallback onClose;
  final Function(Map) onRoute;
  final Function(Map) onCollect;

  const LandmarkModal({
    super.key,
    required this.landmark,
    this.userLoc,
    required this.isVisited,
    required this.onClose,
    required this.onRoute,
    required this.onCollect,
  });

  @override
  Widget build(BuildContext context) {
    final String name = (landmark['name'] ?? 'Unknown Landmark') as String;
    final String description = (landmark['description'] ?? '') as String;
    final String imageUrl = (landmark['image_url'] ?? '') as String;
    final String philosophy = (landmark['philosophy'] ?? '') as String;
    final int xpReward = (landmark['xp_reward'] is num)
        ? (landmark['xp_reward'] as num).toInt()
        : int.tryParse(landmark['xp_reward']?.toString() ?? '') ?? 500;

    // Active Gradient for Landmarks
    const activeGradient = [Color(0xFF2563EB), Color(0xFF4338CA)];

    String distanceInfo = "???";
    String etaInfo = "???";
    if (userLoc != null && !isVisited) {
      double lat = (landmark['lat'] as num).toDouble();
      double lng = (landmark['lng'] as num).toDouble();
      double dist = GeoHelper.calculateDistance(userLoc![0], userLoc![1], lat, lng);
      distanceInfo = dist > 1000
          ? "${(dist / 1000).toStringAsFixed(1)} km"
          : "${dist.floor()} m";
      etaInfo = GeoHelper.calculateETA(dist);
    }

    String? visitedDate;
    if (isVisited && landmark['visited_at'] != null) {
      DateTime dt = DateTime.parse(landmark['visited_at'] as String);
      visitedDate = "${dt.day} ${[
        '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ][dt.month]} ${dt.year}";
    }

    String assetName = '';
    if (imageUrl.contains('/landmarks/')) {
      assetName = imageUrl.split('/landmarks/').last;
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
              Container(
                height: 190,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: activeGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColorFiltered(
                        colorFilter: !isVisited
                            ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                            : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                        child: assetName.isNotEmpty
                            ? Image.asset(
                                'assets/landmarks/$assetName',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const SizedBox(),
                                  );
                                },
                              )
                            : Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox(),
                              ),
                      ),
                    ),

                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withOpacity(0.6),
                              Colors.transparent,
                              Colors.black.withOpacity(0.6),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),

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

                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: const Text(
                          'LANDMARK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: isVisited
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: Text(
                                '✅ SUDAH DIKUNJUNGI ${visitedDate != null ? ": $visitedDate" : ""}',
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
                                        color: Colors.black.withOpacity(0.4),
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
                                        color: Colors.black.withOpacity(0.4),
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
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (!isVisited)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      const Text(
                                        '✨ Reward: ',
                                        style: TextStyle(
                                          color: Color(0xFF2563EB),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDBEAFE),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '+$xpReward XP',
                                          style: const TextStyle(
                                            color: Color(0xFF1E40AF),
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
                            gradient: const LinearGradient(colors: activeGradient),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'SEJARAH',
                            style: TextStyle(
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

                    Container(
                      padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: Color(0xFF93C5FD),
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

                    // Philosophy & History Box
                    Container(
                      height: 130,
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: const [
                              Icon(LucideIcons.landmark, color: Color(0xFF2563EB), size: 16),
                              SizedBox(width: 6),
                              Text(
                                'FILOSOFI & SEJARAH',
                                style: TextStyle(
                                  color: Color(0xFF1E3A8A),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: isVisited
                                ? SingleChildScrollView(
                                    child: Text(
                                      philosophy,
                                      style: const TextStyle(
                                        color: Color(0xFF1E3A8A),
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
                                          color: Color(0xFF1D4ED8),
                                          size: 20,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Check-in untuk membuka sejarah!',
                                          style: TextStyle(
                                            color: Color(0xFF1D4ED8),
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

                    // Route / Check-in buttons (shown if unvisited & user location exists)
                    if (userLoc != null && !isVisited) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => onRoute(landmark),
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
                              onTap: () => onCollect(landmark),
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: activeGradient),
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
                                    Icon(LucideIcons.flag, color: Colors.white, size: 14),
                                    SizedBox(width: 6),
                                    Text(
                                      'Check-in',
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
