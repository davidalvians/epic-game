import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/data/models/drawing_template_model.dart';
import 'package:epic_app/data/repositories/template_repository.dart';
import 'package:epic_app/core/utils/helpers.dart';

/// Bottom sheet untuk memilih kerangka/template gambar sebelum menggambar.
/// Template diambil dari Firestore (dikelola admin via Admin Panel).
class TemplateSelectorSheet extends StatefulWidget {
  final String kategori;
  final int level;
  final String? currentTemplateId;
  final void Function(DrawingTemplateModel?) onSelected;

  const TemplateSelectorSheet({
    super.key,
    required this.kategori,
    required this.level,
    required this.onSelected,
    this.currentTemplateId,
  });

  @override
  State<TemplateSelectorSheet> createState() => _TemplateSelectorSheetState();
}

class _TemplateSelectorSheetState extends State<TemplateSelectorSheet> {
  final _repo = TemplateRepository();
  List<DrawingTemplateModel> _templates = [];
  bool _isLoading = true;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.currentTemplateId;
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final templates = await _repo.getTemplates(
      kategori: widget.kategori,
      level: widget.level,
    );

    if (mounted) {
      setState(() {
        _templates = templates;
        _isLoading = false;
      });
    }
  }

  Color get _kategoriColor {
    switch (widget.kategori) {
      case 'batik': return const Color(0xFF8B5CF6);
      case 'anyaman': return const Color(0xFF10B981);
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _kategoriColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    Helpers.getKategoriEmoji(widget.kategori),
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pilih Kerangka Gambar',
                        style: TextStyle(
                          fontFamily: 'FredokaOne',
                          fontSize: 18,
                          color: _kategoriColor,
                        ),
                      ),
                      Text(
                        '${Helpers.getKategoriLabel(widget.kategori)} • ${Helpers.getLevelLabel(widget.kategori, widget.level)}',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Content
          Flexible(
            child: _isLoading
                ? _buildLoading()
                : _templates.isEmpty
                    ? _buildEmpty()
                    : _buildTemplateGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Memuat kerangka gambar...',
              style: TextStyle(fontFamily: 'Nunito', color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFEDD5), width: 2),
              ),
              child: const Text('🖼️', style: TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Kerangka Belum Tersedia',
              style: TextStyle(
                fontFamily: 'FredokaOne',
                fontSize: 18,
                color: Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Admin belum menambahkan kerangka gambar untuk level ini.\nKamu tetap bisa menggambar di kertas kosong!',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Get.back();
                widget.onSelected(null);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kategoriColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Mulai dengan Kertas Kosong',
                style: TextStyle(
                  fontFamily: 'FredokaOne',
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateGrid() {
    final totalCount = _templates.length + 1;

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.9,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          final isSelected = _selectedId == null;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedId = null);
              Future.delayed(const Duration(milliseconds: 200), () {
                Get.back();
                widget.onSelected(null);
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isSelected ? _kategoriColor.withValues(alpha: 0.05) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? _kategoriColor : const Color(0xFFE2E8F0),
                  width: isSelected ? 2.5 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? _kategoriColor.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: isSelected ? 12 : 6,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: const Color(0xFFFAFAFA)),
                          Center(
                            child: Icon(
                              Icons.crop_free_rounded,
                              color: isSelected ? _kategoriColor : const Color(0xFF94A3B8),
                              size: 40,
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              top: 8, right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: _kategoriColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      'Kertas Kosong',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? _kategoriColor : const Color(0xFF334155),
                      ),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final template = _templates[index - 1];
        final isSelected = _selectedId == template.id;
        return _TemplateCard(
          template: template,
          isSelected: isSelected,
          kategoriColor: _kategoriColor,
          onTap: () {
            setState(() => _selectedId = template.id);
            Future.delayed(const Duration(milliseconds: 200), () {
              Get.back();
              widget.onSelected(template);
            });
          },
        );
      },
    );
  }
}

// ── Card template individual ───────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  final DrawingTemplateModel template;
  final bool isSelected;
  final Color kategoriColor;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    required this.isSelected,
    required this.kategoriColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? kategoriColor.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? kategoriColor : const Color(0xFFE2E8F0),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? kategoriColor.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Thumbnail preview
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background kertas
                    Container(color: const Color(0xFFFAFAFA)),
                    // Gambar template
                    if (template.thumbnailUrl.isNotEmpty)
                      Image.network(
                        template.thumbnailUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            'assets/images/asetcontoh.png',
                            fit: BoxFit.contain,
                          );
                        },
                      )
                    else
                      const Center(
                        child: Icon(Icons.image_outlined, color: Color(0xFFCBD5E1), size: 40),
                      ),
                    // Selected badge
                    if (isSelected)
                      Positioned(
                        top: 8, right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: kategoriColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Nama template
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                template.nama,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? kategoriColor : const Color(0xFF334155),
                ),
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
