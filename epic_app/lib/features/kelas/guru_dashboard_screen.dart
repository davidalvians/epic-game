import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:epic_app/data/models/artwork_model.dart';
import 'package:epic_app/data/repositories/artwork_repository.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:epic_app/core/utils/epic_snackbar.dart';
import 'package:epic_app/data/models/kelas_model.dart';
import 'package:epic_app/features/kelas/kelas_controller.dart';
import 'package:epic_app/features/kelas/kelas_detail_guru_screen.dart';
import 'package:epic_app/features/kelas/buat_kelas_screen.dart';

class GuruDashboardScreen extends StatelessWidget {
  GuruDashboardScreen({super.key});

  final RxString selectedFilter = 'aktif'.obs;

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(KelasController());

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F0),
      appBar: AppBar(
        title: Text(
          'Kelas Saya',
          style: AppFonts.heading2(color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF7A00), Color(0xFFFF5100)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF7A00).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Get.to(() => const BuatKelasScreen()),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Buat Kelas',
                          style: TextStyle(
                            fontFamily: 'FredokaOne',
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.kelasList.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final activeClasses = controller.kelasList.where((k) => k.isActive).toList();
        final inactiveClasses = controller.kelasList.where((k) => k.status == 'nonaktif').toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Filter Kapsul/Chip ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Filter: ',
                    style: AppFonts.bodyText(weight: FontWeight.w700, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Aktif',
                    isSelected: selectedFilter.value == 'aktif',
                    count: activeClasses.length,
                    onTap: () => selectedFilter.value = 'aktif',
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Nonaktif',
                    isSelected: selectedFilter.value == 'nonaktif',
                    count: inactiveClasses.length,
                    onTap: () => selectedFilter.value = 'nonaktif',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // --- List Kelas ---
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: controller.loadKelas,
                child: selectedFilter.value == 'aktif'
                    ? _buildActiveSection(context, activeClasses)
                    : _buildInactiveSection(context, inactiveClasses, controller),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required int count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'FredokaOne',
                fontSize: 13,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            if (isSelected) const SizedBox(width: 4),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                size: 14,
                color: Colors.white,
              ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSection(BuildContext context, List<KelasModel> classes) {
    if (classes.isEmpty) {
      return _buildEmptyState(
        icon: Icons.school_rounded,
        title: 'Belum Ada Kelas Aktif',
        description: 'Ayo buat ruang kelas untuk murid-muridmu dan mulai belajar bersama!',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      itemCount: classes.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 4),
            child: Text(
              '── KELAS AKTIF (${classes.length}) ──',
              style: const TextStyle(
                fontFamily: 'FredokaOne',
                fontSize: 12,
                color: Color(0xFF64748B),
                letterSpacing: 1.2,
              ),
            ),
          );
        }
        final kelas = classes[index - 1];
        return _buildActiveKelasCard(context, kelas);
      },
    );
  }

  Widget _buildInactiveSection(BuildContext context, List<KelasModel> classes, KelasController controller) {
    if (classes.isEmpty) {
      return _buildEmptyState(
        icon: Icons.power_off_rounded,
        title: 'Tidak Ada Kelas Nonaktif',
        description: 'Kelas yang telah selesai semester/ajaran dan Anda nonaktifkan akan tersimpan aman di sini.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      itemCount: classes.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 4),
            child: Text(
              '── KELAS NONAKTIF (${classes.length}) ──',
              style: const TextStyle(
                fontFamily: 'FredokaOne',
                fontSize: 12,
                color: Color(0xFF64748B),
                letterSpacing: 1.2,
              ),
            ),
          );
        }
        final kelas = classes[index - 1];
        return _buildInactiveKelasCard(context, kelas, controller);
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Icon(icon, size: 64, color: AppColors.inactive),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: AppFonts.heading3(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: AppFonts.bodyText(color: const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveKelasCard(BuildContext context, KelasModel kelas) {
    return StreamBuilder<List<ArtworkModel>>(
      stream: ArtworkRepository().watchArtworksByKelas(kelas.kelasId),
      builder: (context, snapshot) {
        double avgNilai = 0.0;
        int totalKarya = 0;
        if (snapshot.hasData) {
          final filteredArtworks = snapshot.data!;
          totalKarya = filteredArtworks.length;
          if (filteredArtworks.isNotEmpty) {
            avgNilai = filteredArtworks.fold<int>(0, (sum, a) => sum + (a.skorAI ?? 0)) / totalKarya;
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Get.to(() => KelasDetailGuruScreen(kelas: kelas)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Status Indicator
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFF22C55E), // Green
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              kelas.namaKelas,
                              style: const TextStyle(
                                fontFamily: 'FredokaOne',
                                fontSize: 18,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: kelas.kodeKelas));
                              EpicSnackbar.success('Tersalin', 'Kode kelas disalin ke clipboard');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFFEDD5)),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    kelas.kodeKelas,
                                    style: const TextStyle(
                                      fontFamily: 'FredokaOne',
                                      fontSize: 12,
                                      color: Color(0xFFEA580C),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.copy_rounded, size: 13, color: Color(0xFFEA580C)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.people_alt_rounded, size: 16, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Text(
                            '${kelas.jumlahMurid} murid',
                            style: AppFonts.bodySmall(color: AppColors.textSecondary, weight: FontWeight.w600),
                          ),
                          const SizedBox(width: 12),
                          Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFFCBD5E1), shape: BoxShape.circle)),
                          const SizedBox(width: 12),
                          Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'Avg: ${avgNilai.toStringAsFixed(1)}',
                            style: AppFonts.bodySmall(color: AppColors.textSecondary, weight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• $totalKarya karya',
                            style: AppFonts.bodySmall(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: Color(0xFFF1F5F9)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Dibuat: ${_formatDate(kelas.createdAt)}',
                            style: AppFonts.caption(color: const Color(0xFF94A3B8)),
                          ),
                          const Row(
                            children: [
                              Text(
                                'Lihat',
                                style: TextStyle(
                                  fontFamily: 'FredokaOne',
                                  fontSize: 13,
                                  color: AppColors.primary,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primary),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInactiveKelasCard(BuildContext context, KelasModel kelas, KelasController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Inactive Dot
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF64748B), // Grey status dot
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${kelas.namaKelas} (Nonaktif)',
                    style: TextStyle(
                      fontFamily: 'FredokaOne',
                      fontSize: 18,
                      color: Colors.grey.shade600,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    kelas.kodeKelas,
                    style: TextStyle(
                      fontFamily: 'FredokaOne',
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.people_alt_rounded, size: 16, color: Colors.grey.shade400),
                const SizedBox(width: 6),
                Text(
                  '${kelas.jumlahMurid} murid',
                  style: AppFonts.bodySmall(color: Colors.grey.shade500, weight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFFE2E8F0), shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Text(
                  kelas.nonaktifkanAt != null
                      ? 'Dinonaktifkan: ${_formatDate(kelas.nonaktifkanAt!)}'
                      : 'Nonaktif',
                  style: AppFonts.caption(color: Colors.grey.shade500),
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => controller.toggleStatusKelas(kelas.kelasId, true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.restore_rounded, size: 16),
                    label: const Text(
                      'Aktifkan Kembali',
                      style: TextStyle(fontFamily: 'FredokaOne', fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmDelete(context, controller, kelas),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEF2F2),
                      foregroundColor: const Color(0xFFEF4444),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.delete_forever_rounded, size: 16),
                    label: const Text(
                      'Hapus',
                      style: TextStyle(fontFamily: 'FredokaOne', fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, KelasController controller, KelasModel kelas) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Hapus Kelas Permanen?',
          style: AppFonts.heading3(color: const Color(0xFFEF4444)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah Anda yakin ingin menghapus kelas "${kelas.namaKelas}" secara permanen?',
              style: AppFonts.bodyText(weight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Semua data kelas dan hubungan murid dengan kelas ini akan hilang selamanya dan tidak dapat dikembalikan.',
              style: AppFonts.bodySmall(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Batal',
              style: TextStyle(fontFamily: 'FredokaOne', color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.deleteKelasPermanen(kelas.kelasId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Hapus Permanen',
              style: TextStyle(fontFamily: 'FredokaOne'),
            ),
          ),
        ],
      ),
    );
  }
}
