import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../controllers/inventory_controller.dart';
import 'widgets/wayang_modal.dart';
import 'widgets/landmark_modal.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final InventoryController _controller = InventoryController();
  String _activeTab = 'wayang'; // 'wayang' or 'landmark'

  Map<String, dynamic>? _selectedWayang;
  Map<String, dynamic>? _selectedLandmark;

  // Delegates for Controller State Variables (to keep Build method unchanged)
  List<dynamic> get _myPokemons => _controller.myPokemons;
  List<dynamic> get _myLandmarks => _controller.myLandmarks;
  bool get _loading => _controller.loading;

  String get _wayangSortBy => _controller.wayangSortBy;
  set _wayangSortBy(String val) => _controller.wayangSortBy = val;

  String get _wayangSortOrder => _controller.wayangSortOrder;
  set _wayangSortOrder(String val) => _controller.wayangSortOrder = val;

  String get _landmarkSortOrder => _controller.landmarkSortOrder;
  set _landmarkSortOrder(String val) => _controller.landmarkSortOrder = val;

  List<dynamic> get _sortedWayangs => _controller.sortedWayangs;
  List<dynamic> get _sortedLandmarks => _controller.sortedLandmarks;

  @override
  void initState() {
    super.initState();
    _fetchStorage();
  }

  Future<void> _fetchStorage() async {
    try {
      await _controller.fetchStorage();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil data inventori: $e')),
        );
      }
    }
  }

  String _formatDate(String isoString, {bool short = false}) {
    try {
      DateTime dt = DateTime.parse(isoString);
      List<String> months = [
        '',
        short ? 'Jan' : 'Januari',
        short ? 'Feb' : 'Februari',
        short ? 'Mar' : 'Maret',
        short ? 'Apr' : 'April',
        short ? 'Mei' : 'Mei',
        short ? 'Jun' : 'Juni',
        short ? 'Jul' : 'Juli',
        short ? 'Agt' : 'Agustus',
        short ? 'Sep' : 'September',
        short ? 'Okt' : 'Oktober',
        short ? 'Nov' : 'November',
        short ? 'Des' : 'Desember'
      ];
      return "${dt.day} ${months[dt.month]} ${dt.year}";
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // bg-slate-100
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Inventory',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.x, color: Color(0xFF64748B)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab Toggle Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              children: [
                // Tabs
                Container(
                  padding: const EdgeInsets.all(4.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9), // slate-100
                    borderRadius: BorderRadius.circular(14.0),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeTab = 'wayang'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _activeTab == 'wayang' ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10.0),
                              boxShadow: _activeTab == 'wayang'
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Wayang (${_myPokemons.length})',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _activeTab == 'wayang'
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeTab = 'landmark'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _activeTab == 'landmark' ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10.0),
                              boxShadow: _activeTab == 'landmark'
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Landmarks (${_myLandmarks.length})',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _activeTab == 'landmark'
                                    ? const Color(0xFF1D4ED8) // blue-700
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Sorting Filters
                SizedBox(
                  height: 32,
                  child: _activeTab == 'wayang'
                      ? Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _wayangSortBy,
                                  icon: const Icon(LucideIcons.chevronDown, size: 12),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF475569),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'date', child: Text('Tanggal')),
                                    DropdownMenuItem(value: 'rarity', child: Text('Kelangkaan')),
                                    DropdownMenuItem(value: 'name', child: Text('Nama (A-Z)')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _wayangSortBy = val;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _wayangSortOrder = _wayangSortOrder == 'asc' ? 'desc' : 'asc';
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              child: Text(
                                _wayangSortOrder == 'asc' ? 'Naik' : 'Turun',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _landmarkSortOrder = _landmarkSortOrder == 'asc' ? 'desc' : 'asc';
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 0),
                                ),
                                child: Text(
                                  'Urutkan: ${_landmarkSortOrder == 'asc' ? 'Terlama' : 'Terbaru'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),

          // Items Content
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text(
                          'Membuka tas...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      // List View
                      _activeTab == 'wayang'
                          ? _buildWayangList()
                          : _buildLandmarkList(),

                      // Floating dialog overlays
                      if (_selectedWayang != null)
                        Container(
                          color: Colors.black.withOpacity(0.6),
                          child: WayangModal(
                            spawn: _selectedWayang!,
                            isCaught: true,
                            onClose: () => setState(() => _selectedWayang = null),
                            onRoute: (_) {},
                            onCatch: (_) {},
                          ),
                        ),

                      if (_selectedLandmark != null)
                        Container(
                          color: Colors.black.withOpacity(0.6),
                          child: LandmarkModal(
                            landmark: _selectedLandmark!,
                            isVisited: true,
                            onClose: () => setState(() => _selectedLandmark = null),
                            onRoute: (_) {},
                            onCollect: (_) {},
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWayangList() {
    final list = _sortedWayangs;
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada wayang yang ditangkap.',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final pokedex = item['pokedex'] ?? {};
        final String name = (pokedex['name'] ?? 'Unknown') as String;
        final String type = (pokedex['type'] ?? 'Default') as String;
        final String rarity = (pokedex['rarity'] ?? 'Common') as String;
        final String imageUrl = (pokedex['image_url'] ?? '') as String;

        final bool isLegend = rarity == 'Legendary';
        final bool isRare = rarity == 'Rare';

        final borderColor = isLegend
            ? const Color(0xFFD8B4FE) // border-purple-300
            : (isRare ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0));
        final bgColor = isLegend
            ? const Color(0xFFF3E8FF) // bg-purple-50
            : (isRare ? const Color(0xFFEFF6FF) : Colors.white);

        final rarityTagBg = isLegend
            ? const Color(0xFF8B5CF6)
            : (isRare ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8));

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedWayang = item;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: Row(
              children: [
                // Image Box
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Image.asset(
                            'assets/wayang/$name.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Image.network(
                                imageUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  LucideIcons.image,
                                  color: Color(0xFFCBD5E1),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: rarityTagBg,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                            ),
                          ),
                          child: Text(
                            rarity,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          type,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ditangkap: ${_formatDate(item['caught_at'] as String, short: true)}',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  LucideIcons.chevronRight,
                  color: Color(0xFFCBD5E1),
                  size: 16,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLandmarkList() {
    final list = _sortedLandmarks;
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'Belum pernah check-in kemana-mana.',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final lm = item['landmarks'] ?? {};
        final String name = (lm['name'] ?? 'Unknown') as String;
        final String desc = (lm['description'] ?? '') as String;
        final String imageUrl = (lm['image_url'] ?? '') as String;

        String assetName = '';
        if (imageUrl.contains('/landmarks/')) {
          assetName = imageUrl.split('/landmarks/').last;
        }

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedLandmark = Map<String, dynamic>.from(lm);
              _selectedLandmark!['visited_at'] = item['visited_at'];
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFDBEAFE), width: 1.5), // border-blue-100
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: Row(
              children: [
                // Image Box
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFF1F5F9),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: assetName.isNotEmpty
                      ? Image.asset(
                          'assets/landmarks/$assetName',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                LucideIcons.image,
                                color: Color(0xFFCBD5E1),
                              ),
                            );
                          },
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            LucideIcons.image,
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                ),
                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Color(0xFF1E3A8A), // blue-900
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.checkCircle2,
                            color: Color(0xFF10B981),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(item['visited_at'] as String),
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  LucideIcons.chevronRight,
                  color: Color(0xFFCBD5E1),
                  size: 16,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
