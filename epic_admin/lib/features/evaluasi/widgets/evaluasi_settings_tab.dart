import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class EvaluasiSettingsTab extends StatelessWidget {
  final String selectedCategory;
  final int selectedLevel;
  final bool isLoadingConfig;
  final String status;
  final bool enableTts;
  final TextEditingController feelingPromptCtrl;
  final List<TextEditingController> questionControllers;
  final List<dynamic> emotionOptionDrafts;

  // Callbacks
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<int> onLevelSelected;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<bool> onTtsChanged;
  final VoidCallback onAddQuestion;
  final ValueChanged<int> onRemoveQuestion;
  final VoidCallback onAddEmotion;
  final ValueChanged<int> onRemoveEmotion;

  const EvaluasiSettingsTab({
    super.key,
    required this.selectedCategory,
    required this.selectedLevel,
    required this.isLoadingConfig,
    required this.status,
    required this.enableTts,
    required this.feelingPromptCtrl,
    required this.questionControllers,
    required this.emotionOptionDrafts,
    required this.onCategorySelected,
    required this.onLevelSelected,
    required this.onStatusChanged,
    required this.onTtsChanged,
    required this.onAddQuestion,
    required this.onRemoveQuestion,
    required this.onAddEmotion,
    required this.onRemoveEmotion,
  });

  final List<Map<String, dynamic>> _categories = const [
    {'id': 'keris', 'name': 'Keris', 'icon': Icons.military_tech_rounded},
    {'id': 'batik', 'name': 'Batik', 'icon': Icons.palette_rounded},
    {'id': 'anyaman', 'name': 'Anyaman', 'icon': Icons.grid_4x4_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 1000) {
          // Desktop: split kiri-kanan, masing2 bisa scroll sendiri
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kolom Kiri: fixed width, bisa scroll
              SizedBox(
                width: 300,
                child: _buildLeftPanel(context),
              ).animate().fade(duration: 400.ms).slideX(begin: -0.05, end: 0),
              const SizedBox(width: 20),
              // Kolom Kanan: flexible, bisa scroll
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: isLoadingConfig
                      ? const Center(child: CircularProgressIndicator())
                      : _buildRightPanel(context)
                          .animate()
                          .fade(duration: 500.ms)
                          .slideX(begin: 0.03, end: 0),
                ),
              ),
            ],
          );
        }

        // Mobile: kolom tunggal, full scroll
        return SingleChildScrollView(
          child: Column(
            children: [
              _buildLeftPanel(context).animate().fade(duration: 400.ms),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: isLoadingConfig
                    ? const Center(child: CircularProgressIndicator())
                    : _buildRightPanel(context)
                        .animate()
                        .fade(duration: 500.ms),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── KOLOM KIRI: PANEL KONTROL (scroll independen) ───────────────────────────
  Widget _buildLeftPanel(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFF8FAFC),
              AdminColors.primary.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: AdminColors.primary.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            )
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Panel
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AdminColors.primary,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AdminColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: const Icon(Icons.dashboard_customize_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Panel Modul',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Kategori Materi - SATU BARIS, tidak wrap ke bawah
            const Text('KATEGORI MATERI',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Row(
              children: _categories.map((cat) {
                final isSelected = selectedCategory == cat['id'];
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: cat['id'] == _categories.last['id'] ? 0 : 6),
                    child: GestureDetector(
                      onTap: () {
                        if (selectedCategory != cat['id']) {
                          onCategorySelected(cat['id'] as String);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color:
                              isSelected ? AdminColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AdminColors.primary
                                : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                      color: AdminColors.primary
                                          .withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2))
                                ]
                              : [],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat['icon'] as IconData,
                                size: 18,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF64748B)),
                            const SizedBox(height: 4),
                            Text(
                              cat['name'] as String,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF475569),
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: 11,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 16),

            // Level - SATU BARIS
            const Text('TINGKAT KESULITAN',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Row(
              children: [1, 2, 3, 4].map((lvl) {
                final isSelected = selectedLevel == lvl;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: lvl == 4 ? 0 : 6),
                    child: GestureDetector(
                      onTap: () {
                        if (selectedLevel != lvl) onLevelSelected(lvl);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFF59E0B)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                      color: const Color(0xFFF59E0B)
                                          .withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2))
                                ]
                              : [],
                        ),
                        child: Text(
                          'LVL $lvl',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF475569),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 16),

            // Kebijakan
            const Text('KEBIJAKAN EVALUASI',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 1.2)),
            const SizedBox(height: 12),
            _buildModernRadioOption('mandatory', 'Wajib Diisi',
                Icons.gpp_good_rounded, const Color(0xFFEF4444)),
            const SizedBox(height: 8),
            _buildModernRadioOption('optional', 'Opsional', Icons.rule_rounded,
                const Color(0xFFF59E0B)),
            const SizedBox(height: 8),
            _buildModernRadioOption('disabled', 'Nonaktif',
                Icons.do_not_disturb_alt_rounded, const Color(0xFF94A3B8)),

            const SizedBox(height: 20),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 16),

            // TTS Toggle
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Text-to-Speech 🔊',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                                fontSize: 13)),
                        SizedBox(height: 2),
                        Text('Soal dibacakan otomatis',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Switch(
                    value: enableTts,
                    activeThumbColor: Colors.white,
                    activeTrackColor: const Color(0xFF10B981),
                    onChanged: onTtsChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8), // Bottom padding agar tidak terpotong
          ],
        ),
      ),
    );
  }

  Widget _buildModernRadioOption(
      String value, String label, IconData icon, Color accentColor) {
    final isSelected = status == value;
    return InkWell(
      onTap: () => onStatusChanged(value),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color:
              isSelected ? accentColor.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? accentColor.withValues(alpha: 0.4)
                : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: isSelected ? accentColor : const Color(0xFF94A3B8)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? accentColor : const Color(0xFF475569),
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: accentColor, size: 16)
                  .animate()
                  .scale(duration: 200.ms, curve: Curves.elasticOut),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required Widget action,
  }) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              copy,
              const SizedBox(height: 12),
              action,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: copy),
            const SizedBox(width: 16),
            action,
          ],
        );
      },
    );
  }

  // ─── KOLOM KANAN: KANVAS SOAL & EMOTIKON (scroll independen) ─────────────────
  Widget _buildRightPanel(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        children: [
          // Card Soal
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width < 600 ? 18 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  title: 'Soal Evaluasi',
                  subtitle:
                      'Rancang pertanyaan untuk menguji kemampuan logika siswa.',
                  action: ElevatedButton.icon(
                    onPressed: onAddQuestion,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Tambah Soal',
                        style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Daftar Soal
                if (questionControllers.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.draw_rounded,
                            size: 40, color: const Color(0xFFCBD5E1)),
                        const SizedBox(height: 12),
                        const Text('Area Soal Kosong',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        const Text('Klik Tambah Soal untuk mulai.',
                            style: TextStyle(color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ).animate().fade()
                else
                  Column(
                    children: questionControllers.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final ctrl = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Nomor soal panel - lebar tetap, tinggi mengikuti konten
                              Container(
                                width: 44,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(14),
                                    bottomLeft: Radius.circular(14),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${idx + 1}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF475569),
                                        fontSize: 15),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: ctrl,
                                  maxLines: null,
                                  minLines: 2,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF1E293B)),
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Tulis kalimat pertanyaan penalaran ramah anak...',
                                    hintStyle: TextStyle(
                                        color: Color(0xFF94A3B8), fontSize: 13),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 16),
                                  ),
                                ),
                              ),
                              // Tombol hapus
                              InkWell(
                                onTap: () => onRemoveQuestion(idx),
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(14),
                                  bottomRight: Radius.circular(14),
                                ),
                                child: Container(
                                  width: 40,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.close_rounded,
                                      color: Color(0xFFCBD5E1), size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                          .animate()
                          .fade(duration: 300.ms)
                          .slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
                    }).toList(),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Card Emotikon
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width < 600 ? 18 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  title: 'Penilaian Perasaan (Pop-up Akhir)',
                  subtitle:
                      'Pertanyaan emosi yang tampil setelah siswa selesai.',
                  action: TextButton.icon(
                    onPressed: onAddEmotion,
                    icon:
                        const Icon(Icons.add_circle_outline_rounded, size: 16),
                    label: const Text('Tambah Emoji',
                        style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF10B981)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('KALIMAT PERTANYAAN EMOSI',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 1.2)),
                const SizedBox(height: 8),
                TextField(
                  controller: feelingPromptCtrl,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                  decoration: InputDecoration(
                    hintText:
                        'Contoh: Bagaimana perasaanmu selama membuat karya ini tadi?',
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('PILIHAN EMOTIKON',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 1.2)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: emotionOptionDrafts.asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    return Container(
                      width: 160,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: emotionOptionDrafts.length > 1
                                    ? () => onRemoveEmotion(index)
                                    : null,
                                child: Icon(Icons.close_rounded,
                                    size: 14,
                                    color: emotionOptionDrafts.length > 1
                                        ? Colors.redAccent
                                        : Colors.transparent),
                              )
                            ],
                          ),
                          TextField(
                            controller: option.iconController,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 32),
                            decoration: const InputDecoration(
                                border: InputBorder.none, hintText: '😀'),
                          ),
                          const Divider(height: 8),
                          TextField(
                            controller: option.labelController,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155)),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Label...',
                              hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ],
                      ),
                    ).animate().scale(
                        delay: (index * 80).ms,
                        duration: 250.ms,
                        curve: Curves.easeOutBack);
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(height: 16), // Bottom padding
        ],
      ),
    );
  }
}
