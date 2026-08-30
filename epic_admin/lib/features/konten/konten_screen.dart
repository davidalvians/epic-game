import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class KontenScreen extends StatefulWidget {
  final int initialTab;
  const KontenScreen({super.key, this.initialTab = 0});

  @override
  State<KontenScreen> createState() => _KontenScreenState();
}

class _KontenScreenState extends State<KontenScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedTemplateFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: AdminColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom Premium Header (Title & Subtitle) - Out of AppBar to prevent cutting off text
            Padding(
              padding: EdgeInsets.only(
                left: isMobile ? 16 : 32,
                right: isMobile ? 16 : 32,
                top: isMobile ? 16 : 32,
                bottom: isMobile ? 12 : 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manajemen Konten',
                    style: (isMobile
                            ? Theme.of(context).textTheme.headlineMedium
                            : Theme.of(context).textTheme.headlineLarge)
                        ?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Kelola instrumen penilaian AI, gambar template mewarnai, dan misi harian murid.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.normal),
                  ),
                ],
              ),
            ),

            // TabBar Container - Styled pill-shape tabs
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 8),
              child: SizedBox(
                width: isMobile ? double.infinity : 680,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: isMobile,
                    tabAlignment: isMobile ? TabAlignment.start : TabAlignment.fill,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: const Color(0xFF64748B),
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    splashFactory: NoSplash.splashFactory,
                    indicatorPadding: EdgeInsets.zero,
                    indicator: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    tabs: const [
                      Tab(text: 'INSTRUMEN AI'),
                      Tab(text: 'PANDUAN ONBOARDING'),
                      Tab(text: 'TEMPLATE GAMBAR'),
                      Tab(text: 'MISI HARIAN'),
                    ],
                  ),
                ),
              ),
            ),

            // Main Content Area
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildInstrumenTab(context, isMobile),
                  _buildOnboardingTab(context, isMobile),
                  _buildTemplateTab(context, isMobile),
                  _buildMisiHarianTab(context, isMobile),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstrumenTab(BuildContext context, bool isMobile) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('app_config')
          .doc('game_settings')
          .collection('instruments')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AdminColors.primary)));
        }
        final docs = snapshot.data?.docs ?? [];
        final Map<String, Map<String, dynamic>> instrumentsMap = {};
        for (final doc in docs) {
          instrumentsMap[doc.id] = doc.data() as Map<String, dynamic>;
        }

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 14 : 32),
          children: [
            Row(
              children: const [
                Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'KRITERIA & BOBOT PROMPT PENILAIAN AI BERDASARKAN KATEGORI & LEVEL',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5, fontSize: 11),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms),
            SizedBox(height: isMobile ? 16 : 24),
            _buildCategorySection(context, 'Keris', Icons.architecture_rounded, const Color(0xFF8B5CF6), instrumentsMap, isMobile),
            SizedBox(height: isMobile ? 16 : 32),
            _buildCategorySection(context, 'Batik', Icons.brush_rounded, const Color(0xFFF97316), instrumentsMap, isMobile),
            SizedBox(height: isMobile ? 16 : 32),
            _buildCategorySection(context, 'Anyaman', Icons.grid_on_rounded, const Color(0xFF10B981), instrumentsMap, isMobile),
          ],
        );
      }
    );
  }

  Widget _buildCategorySection(BuildContext context, String category, IconData icon, Color color, Map<String, Map<String, dynamic>> instrumentsMap, bool isMobile) {
    final String catKey = category.toLowerCase();
    final instL1 = instrumentsMap['${catKey}_1'] ?? {};
    final instL2 = instrumentsMap['${catKey}_2'] ?? {};
    final instL3 = instrumentsMap['${catKey}_3'] ?? {};
    final instL4 = instrumentsMap['${catKey}_4'] ?? {};

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 18 : 24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Text(
                category,
                style: TextStyle(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), fontSize: isMobile ? 17 : 20),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              return isWide
                  ? Row(
                      children: [
                        Expanded(child: _buildInstrumentCard(context, '$category Level 1', instL1, '${catKey}_1', color)),
                        const SizedBox(width: 20),
                        Expanded(child: _buildInstrumentCard(context, '$category Level 2', instL2, '${catKey}_2', color)),
                        const SizedBox(width: 20),
                        Expanded(child: _buildInstrumentCard(context, '$category Level 3', instL3, '${catKey}_3', color)),
                        const SizedBox(width: 20),
                        Expanded(child: _buildInstrumentCard(context, '$category Level 4', instL4, '${catKey}_4', color)),
                      ],
                    )
                  : Column(
                      children: [
                        _buildInstrumentCard(context, '$category Level 1', instL1, '${catKey}_1', color),
                        const SizedBox(height: 14),
                        _buildInstrumentCard(context, '$category Level 2', instL2, '${catKey}_2', color),
                        const SizedBox(height: 14),
                        _buildInstrumentCard(context, '$category Level 3', instL3, '${catKey}_3', color),
                        const SizedBox(height: 14),
                        _buildInstrumentCard(context, '$category Level 4', instL4, '${catKey}_4', color),
                      ],
                    );
            },
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.03, end: 0, curve: Curves.easeOutQuad);
  }

  Widget _buildInstrumentCard(BuildContext context, String title, Map<String, dynamic> data, String id, Color color) {
    final model = data['modelAI'] ?? 'gemini-2.5-flash-lite';
    final List<dynamic>? criteria = data['criteria'] as List<dynamic>?;
    String weight = '';
    if (criteria != null && criteria.isNotEmpty) {
      weight = criteria.map((c) => c['weight']?.toString() ?? '0').join('/');
    } else {
      final b1 = data['bobot1'] ?? 40;
      final b2 = data['bobot2'] ?? 30;
      final b3 = data['bobot3'] ?? 30;
      weight = '$b1/$b2/$b3';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.smart_toy_rounded, model),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.balance_rounded, 'Bobot: $weight %'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/konten/instrumen/$id'),
              icon: const Icon(Icons.edit_note_rounded, size: 16),
              label: const Text('Edit Instrumen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2563EB),
                elevation: 0,
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateTab(BuildContext context, bool isMobile) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('drawing_templates').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AdminColors.primary)));
        }
        final docs = snapshot.data?.docs ?? [];
        final filteredTemplates = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final String category = data['kategori'] ?? '';
          if (_selectedTemplateFilter == 'Semua') return true;
          return category.toLowerCase() == _selectedTemplateFilter.toLowerCase();
        }).toList();

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 14 : 32),
          children: [
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildFilterChip('Semua', _selectedTemplateFilter == 'Semua'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Keris', _selectedTemplateFilter == 'Keris'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Batik', _selectedTemplateFilter == 'Batik'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Anyaman', _selectedTemplateFilter == 'Anyaman'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/konten/template/upload'),
                    icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                    label: const Text('Upload Template Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms)
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildFilterChip('Semua', _selectedTemplateFilter == 'Semua'),
                      const SizedBox(width: 10),
                      _buildFilterChip('Keris', _selectedTemplateFilter == 'Keris'),
                      const SizedBox(width: 10),
                      _buildFilterChip('Batik', _selectedTemplateFilter == 'Batik'),
                      const SizedBox(width: 10),
                      _buildFilterChip('Anyaman', _selectedTemplateFilter == 'Anyaman'),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/konten/template/upload'),
                    icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                    label: const Text('Upload Template Baru', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms),
            SizedBox(height: isMobile ? 16 : 32),
            
            filteredTemplates.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(64.0),
                      child: Column(
                        children: const [
                          Icon(Icons.image_not_supported_rounded, size: 64, color: Color(0xFF94A3B8)),
                          SizedBox(height: 16),
                          Text('Tidak Ada Template', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: isMobile ? 180 : 260,
                      mainAxisSpacing: isMobile ? 14 : 24,
                      crossAxisSpacing: isMobile ? 14 : 24,
                      childAspectRatio: isMobile ? 0.65 : 0.68,
                    ),
                    itemCount: filteredTemplates.length,
                    itemBuilder: (context, index) {
                      final doc = filteredTemplates[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final String id = doc.id;
                      final String title = data['nama'] ?? 'Tanpa Nama';
                      final String outlineUrl = data['outlineUrl'] ?? '';
                      final bool isActive = data['isActive'] ?? false;
                      final String kategori = data['kategori'] ?? '-';
                      final int level = data['level'] is int ? data['level'] as int : (int.tryParse(data['level']?.toString() ?? '0') ?? 0);
                      final String deskripsi = data['deskripsi'] ?? '';

                      return _buildTemplateCard(context, id, title, outlineUrl, isActive, kategori, level, deskripsi)
                          .animate()
                          .fadeIn(delay: (index * 50).ms, duration: 350.ms);
                    },
                  ),
          ],
        );
      }
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTemplateFilter = label;
        });
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateCard(BuildContext context, String docId, String title, String outlineUrl, bool isActive, String kategori, int level, String deskripsi) {
    Gradient categoryGradient;
    Color categoryColor;
    if (title.toLowerCase().contains('keris') || kategori.toLowerCase() == 'keris') {
      categoryGradient = const LinearGradient(colors: [Color(0xFFC084FC), Color(0xFF8B5CF6)]);
      categoryColor = const Color(0xFF8B5CF6);
    } else if (title.toLowerCase().contains('batik') || kategori.toLowerCase() == 'batik') {
      categoryGradient = const LinearGradient(colors: [Color(0xFFFDBA74), Color(0xFFF97316)]);
      categoryColor = const Color(0xFFF97316);
    } else {
      categoryGradient = const LinearGradient(colors: [Color(0xFF6EE7B7), Color(0xFF059669)]);
      categoryColor = const Color(0xFF059669);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                // Background gambar template - klik untuk buka pratinjau
                GestureDetector(
                  onTap: () => _showTemplatePreviewDialog(
                    context,
                    docId: docId,
                    title: title,
                    outlineUrl: outlineUrl,
                    isActive: isActive,
                    kategori: kategori,
                    level: level,
                    deskripsi: deskripsi,
                    categoryColor: categoryColor,
                    categoryGradient: categoryGradient,
                  ),
                  child: Container(
                    color: const Color(0xFFF8FAFC),
                    width: double.infinity,
                    child: outlineUrl.isNotEmpty
                        ? Image.network(
                            outlineUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(Icons.broken_image_rounded, size: 48, color: Color(0xFF94A3B8)),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.image_outlined, size: 48, color: Color(0xFF94A3B8)),
                          ),
                  ),
                ),
                // Label kategori
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: categoryGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      kategori.isNotEmpty ? kategori : (title.split(' ').isNotEmpty ? title.split(' ')[0] : ''),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (level > 0)
                  Text(
                    'Level $level',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isActive ? 'Aktif' : 'Nonaktif',
                        style: TextStyle(
                          color: isActive ? const Color(0xFF065F46) : const Color(0xFF64748B),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 20,
                      width: 36,
                      child: Switch(
                        value: isActive,
                        onChanged: (val) async {
                          try {
                            await FirebaseFirestore.instance
                                .collection('drawing_templates')
                                .doc(docId)
                                .update({'isActive': val});
                          } catch (e) {
                            debugPrint('Error updating active state: $e');
                          }
                        },
                        activeColor: const Color(0xFF2563EB),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showTemplatePreviewDialog(
                          context,
                          docId: docId,
                          title: title,
                          outlineUrl: outlineUrl,
                          isActive: isActive,
                          kategori: kategori,
                          level: level,
                          deskripsi: deskripsi,
                          categoryColor: categoryColor,
                          categoryGradient: categoryGradient,
                        ),
                        icon: const Icon(Icons.visibility_rounded, size: 12),
                        label: const Text('Pratinjau', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => context.go('/konten/template/edit/$docId'),
                        icon: const Icon(Icons.edit_rounded, size: 12),
                        label: const Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Modal pratinjau template gambar — menampilkan gambar besar dengan detail lengkap
  void _showTemplatePreviewDialog(
    BuildContext context, {
    required String docId,
    required String title,
    required String outlineUrl,
    required bool isActive,
    required String kategori,
    required int level,
    required String deskripsi,
    required Color categoryColor,
    required Gradient categoryGradient,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 620),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 60,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                // ── Kiri: Pratinjau Gambar ──────────────────────────────────
                Expanded(
                  flex: 5,
                  child: Container(
                    color: const Color(0xFFF0F4F8),
                    child: Stack(
                      children: [
                        // Gambar template dengan padding
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: outlineUrl.isNotEmpty
                                ? Image.network(
                                    outlineUrl,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (ctx, child, progress) {
                                      if (progress == null) return child;
                                      return Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircularProgressIndicator(
                                              value: progress.expectedTotalBytes != null
                                                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                                  : null,
                                              color: categoryColor,
                                              strokeWidth: 2,
                                            ),
                                            const SizedBox(height: 12),
                                            const Text(
                                              'Memuat gambar...',
                                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) => Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.image_not_supported_rounded, size: 72, color: categoryColor.withValues(alpha: 0.25)),
                                          const SizedBox(height: 16),
                                          const Text(
                                            'Gambar tidak dapat dimuat',
                                            style: TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Pastikan CORS Firebase Storage\nsudah dikonfigurasi untuk web',
                                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 16),
                                          SelectableText(
                                            outlineUrl.length > 60 ? '${outlineUrl.substring(0, 60)}...' : outlineUrl,
                                            style: const TextStyle(
                                              color: Color(0xFFCBD5E1),
                                              fontSize: 9,
                                              fontFamily: 'monospace',
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.image_not_supported_rounded, size: 72, color: categoryColor.withValues(alpha: 0.25)),
                                        const SizedBox(height: 12),
                                        const Text('Belum ada gambar', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                        // Label kategori di pojok kiri atas
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: categoryGradient,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: categoryColor.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              kategori.isNotEmpty ? kategori.toUpperCase() : 'TEMPLATE',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                            ),
                          ),
                        ),
                        // Tombol tutup
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Material(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => Navigator.of(ctx).pop(),
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.close_rounded, size: 20, color: Color(0xFF475569)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Kanan: Detail Template ──────────────────────────────────
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header detail
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pratinjau Template',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: categoryColor, letterSpacing: 0.5),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    title,
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // Info cards
                        _buildPreviewInfoTile(
                          icon: Icons.category_rounded,
                          label: 'Kategori',
                          value: kategori.isNotEmpty ? kategori : '-',
                          color: categoryColor,
                        ),
                        const SizedBox(height: 12),
                        _buildPreviewInfoTile(
                          icon: Icons.bar_chart_rounded,
                          label: 'Level',
                          value: level > 0 ? 'Level $level' : '-',
                          color: categoryColor,
                        ),
                        const SizedBox(height: 12),
                        _buildPreviewInfoTile(
                          icon: Icons.toggle_on_rounded,
                          label: 'Status',
                          value: isActive ? 'Aktif' : 'Nonaktif',
                          color: isActive ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                          valueColor: isActive ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                        ),
                        if (deskripsi.isNotEmpty) ...[  
                          const SizedBox(height: 12),
                          _buildPreviewInfoTile(
                            icon: Icons.description_rounded,
                            label: 'Deskripsi',
                            value: deskripsi,
                            color: categoryColor,
                          ),
                        ],

                        const Spacer(),
                        const Divider(color: Color(0xFFE2E8F0)),
                        const SizedBox(height: 16),

                        // Action buttons
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              context.go('/konten/template/edit/$docId');
                            },
                            icon: const Icon(Icons.edit_rounded, size: 16),
                            label: const Text('Edit Template', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: categoryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF64748B),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreviewInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8), letterSpacing: 0.3),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? const Color(0xFF0F172A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMisiHarianTab(BuildContext context, bool isMobile) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('misi_templates').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AdminColors.primary)));
        }
        final docs = snapshot.data?.docs ?? [];

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 32, vertical: isMobile ? 16 : 24),
          children: [
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Template Misi Harian',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 16),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '(3 misi aktif per hari akan di-render acak pada dashboard murid)',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/konten/misi/tambah'),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Tambah Misi Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms)
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Template Misi Harian',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 16),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '(3 misi aktif per hari akan di-render acak pada dashboard mobile murid)',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/konten/misi/tambah'),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Tambah Misi Baru', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms),
            SizedBox(height: isMobile ? 16 : 24),
            
            docs.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(Icons.assignment_late_rounded, size: 48, color: Color(0xFF94A3B8)),
                          SizedBox(height: 16),
                          Text(
                            'Belum ada misi harian yang ditambahkan',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: List.generate(docs.length, (index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final String id = doc.id;
                      final String title = data['judul'] ?? 'Misi Tanpa Judul';
                      final int target = data['target'] is int ? data['target'] as int : 1;
                      final int reward = data['poinReward'] is int ? data['poinReward'] as int : 0;
                      final String type = data['tipe'] ?? 'unknown';
                      final bool isActive = data['isActive'] ?? false;

                      return _buildMissionCard(context, id, title, '$target', '$reward', type, isActive, index, isMobile);
                    }),
                  ),
          ],
        );
      }
    );
  }

  Widget _buildMissionCard(BuildContext context, String docId, String title, String target, String reward, String type, bool isActive, int index, bool isMobile) {
    if (isMobile) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.015),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.emoji_events_rounded, color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isActive ? 'Aktif' : 'Nonaktif',
                    style: TextStyle(
                      color: isActive ? const Color(0xFF065F46) : const Color(0xFF64748B),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildMissionTag(Icons.radar_rounded, 'Target: $target'),
                _buildMissionTag(Icons.monetization_on_rounded, '+$reward Poin', textColor: const Color(0xFFB45309), bgColor: const Color(0xFFFEF3C7)),
                _buildMissionTag(Icons.category_rounded, type),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/konten/misi/edit/$docId'),
                    icon: const Icon(Icons.edit_rounded, size: 13),
                    label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      try {
                        await FirebaseFirestore.instance
                            .collection('misi_templates')
                            .doc(docId)
                            .update({'isActive': !isActive});
                      } catch (e) {
                        debugPrint('Error toggling mission status: $e');
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isActive ? AdminColors.error : const Color(0xFF10B981),
                      side: BorderSide(color: isActive ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      isActive ? 'Nonaktifkan' : 'Aktifkan',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showDeleteMissionDialog(context, docId, title),
                  icon: const Icon(Icons.delete_outline_rounded, color: AdminColors.error, size: 18),
                  tooltip: 'Hapus Misi',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFFEF2F2),
                    padding: const EdgeInsets.all(8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFFEE2E8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(delay: (index * 40).ms, duration: 300.ms).slideY(begin: 0.03, end: 0, curve: Curves.easeOutQuad);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon decoration
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.emoji_events_rounded, color: Color(0xFF2563EB), size: 28),
          ),
          const SizedBox(width: 24),
          
          // Body Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildMissionTag(Icons.radar_rounded, 'Target: $target Kali'),
                    _buildMissionTag(Icons.monetization_on_rounded, '+$reward Poin', textColor: const Color(0xFFB45309), bgColor: const Color(0xFFFEF3C7)),
                    _buildMissionTag(Icons.category_rounded, 'Tipe: $type'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isActive ? 'Aktif' : 'Nonaktif',
                        style: TextStyle(
                          color: isActive ? const Color(0xFF065F46) : const Color(0xFF64748B),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          
          // Action Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.go('/konten/misi/edit/$docId'),
                icon: const Icon(Icons.edit_rounded, size: 14),
                label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  fixedSize: const Size(100, 40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () async {
                  try {
                    await FirebaseFirestore.instance
                        .collection('misi_templates')
                        .doc(docId)
                        .update({'isActive': !isActive});
                  } catch (e) {
                    debugPrint('Error toggling mission status: $e');
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminColors.error,
                  side: const BorderSide(color: Color(0xFFFECACA)),
                  fixedSize: const Size(120, 40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                 child: Text(
                  isActive ? 'Nonaktifkan' : 'Aktifkan',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _showDeleteMissionDialog(context, docId, title),
                icon: const Icon(Icons.delete_outline_rounded, color: AdminColors.error),
                tooltip: 'Hapus Misi',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFFEF2F2),
                  padding: const EdgeInsets.all(8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFFEE2E2)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 60).ms, duration: 350.ms).slideY(begin: 0.03, end: 0, curve: Curves.easeOutQuad);
  }

  Widget _buildMissionTag(IconData icon, String text, {Color? textColor, Color? bgColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor ?? const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor ?? const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor ?? const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteMissionDialog(BuildContext context, String docId, String title) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Hapus Misi Harian?',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus misi "$title"? Tindakan ini tidak dapat dibatalkan.',
            style: const TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.5),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await FirebaseFirestore.instance
                      .collection('misi_templates')
                      .doc(docId)
                      .delete();
                  
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: const [
                          Icon(Icons.delete_forever, color: Colors.white, size: 18),
                          SizedBox(width: 10),
                          Expanded(child: Text('Misi harian berhasil dihapus.')),
                        ],
                      ),
                      backgroundColor: AdminColors.error,
                      behavior: SnackBarBehavior.floating,
                      width: 420,
                    ),
                  );
                } catch (e) {
                  debugPrint('Error deleting mission: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Ya, Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOnboardingTab(BuildContext context, bool isMobile) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('app_config')
          .doc('game_settings')
          .collection('onboardings')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AdminColors.primary)));
        }
        final docs = snapshot.data?.docs ?? [];
        final Map<String, Map<String, dynamic>> onboardingsMap = {};
        for (final doc in docs) {
          onboardingsMap[doc.id] = doc.data() as Map<String, dynamic>;
        }

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 14 : 32),
          children: [
            Row(
              children: const [
                Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'KONFIGURASI PANDUAN BUDAYA & MATEMATIKA ONBOARDING TAMPILAN KLIEN',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5, fontSize: 11),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms),
            SizedBox(height: isMobile ? 16 : 24),
            _buildOnboardingCategorySection(context, 'Keris', Icons.architecture_rounded, const Color(0xFF8B5CF6), onboardingsMap, isMobile),
            SizedBox(height: isMobile ? 16 : 32),
            _buildOnboardingCategorySection(context, 'Batik', Icons.brush_rounded, const Color(0xFFF97316), onboardingsMap, isMobile),
            SizedBox(height: isMobile ? 16 : 32),
            _buildOnboardingCategorySection(context, 'Anyaman', Icons.grid_on_rounded, const Color(0xFF10B981), onboardingsMap, isMobile),
          ],
        );
      }
    );
  }

  Widget _buildOnboardingCategorySection(BuildContext context, String category, IconData icon, Color color, Map<String, Map<String, dynamic>> onboardingsMap, bool isMobile) {
    final String catKey = category.toLowerCase();
    final instL1 = onboardingsMap['${catKey}_1'] ?? {};
    final instL2 = onboardingsMap['${catKey}_2'] ?? {};
    final instL3 = onboardingsMap['${catKey}_3'] ?? {};
    final instL4 = onboardingsMap['${catKey}_4'] ?? {};

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 18 : 24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Text(
                category,
                style: TextStyle(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), fontSize: isMobile ? 17 : 20),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              return isWide
                  ? Row(
                      children: [
                        Expanded(child: _buildOnboardingCard(context, '$category Level 1', instL1, '${catKey}_1', color)),
                        const SizedBox(width: 20),
                        Expanded(child: _buildOnboardingCard(context, '$category Level 2', instL2, '${catKey}_2', color)),
                        const SizedBox(width: 20),
                        Expanded(child: _buildOnboardingCard(context, '$category Level 3', instL3, '${catKey}_3', color)),
                        const SizedBox(width: 20),
                        Expanded(child: _buildOnboardingCard(context, '$category Level 4', instL4, '${catKey}_4', color)),
                      ],
                    )
                  : Column(
                      children: [
                        _buildOnboardingCard(context, '$category Level 1', instL1, '${catKey}_1', color),
                        const SizedBox(height: 14),
                        _buildOnboardingCard(context, '$category Level 2', instL2, '${catKey}_2', color),
                        const SizedBox(height: 14),
                        _buildOnboardingCard(context, '$category Level 3', instL3, '${catKey}_3', color),
                        const SizedBox(height: 14),
                        _buildOnboardingCard(context, '$category Level 4', instL4, '${catKey}_4', color),
                      ],
                    );
            },
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.03, end: 0, curve: Curves.easeOutQuad);
  }

  Widget _buildOnboardingCard(BuildContext context, String title, Map<String, dynamic> data, String id, Color color) {
    final budayaSnippet = data['konteksBudaya']?.toString() ?? 'Teks budaya belum dikonfigurasi (menggunakan default).';
    final matSnippet = data['materiMatematika']?.toString() ?? 'Materi matematika belum dikonfigurasi (menggunakan default).';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.account_balance_rounded, budayaSnippet),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.calculate_rounded, matSnippet),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/konten/onboarding/$id'),
              icon: const Icon(Icons.edit_note_rounded, size: 16),
              label: const Text('Edit Panduan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2563EB),
                elevation: 0,
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter untuk background checkerboard (kotak-kotak abu abu putih)
/// Digunakan sebagai background pratinjau template agar gambar PNG transparan terlihat jelas
class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double squareSize = 16;
    final Paint lightPaint = Paint()..color = const Color(0xFFFFFFFF);
    final Paint darkPaint = Paint()..color = const Color(0xFFE5E9F0);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), lightPaint);

    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        final bool isDark = ((x / squareSize).floor() + (y / squareSize).floor()) % 2 == 1;
        if (isDark) {
          canvas.drawRect(
            Rect.fromLTWH(x, y, squareSize, squareSize),
            darkPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
