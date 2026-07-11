import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/utils/epic_snackbar.dart';
import 'package:epic_app/data/models/artwork_model.dart';
import 'package:epic_app/data/repositories/artwork_repository.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:epic_app/features/kelas/kelas_controller.dart';
import 'package:epic_app/features/kelas/gabung_kelas_screen.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'package:epic_app/data/models/kelas_model.dart';

/// Layar daftar kelas ("Kelas Saya") sisi murid.
/// Sesuai PRD §3.13 & sistem-kelas&fitur-guru.md Bagian 11.
class KelasScreen extends StatelessWidget {
  const KelasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(KelasController());
    final session = Get.find<SessionController>();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F0), // Krem premium hangat
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            _buildHeader(context),

            // ── Tombol Tambah/Gabung Kelas Baru ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: _buildGabungBaruCard(),
            ),

            // ── Daftar Kelas Yang Diikuti ──
            Expanded(
              child: Obx(() {
                if (ctrl.isLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                final joinedClasses = ctrl.kelasList.where((k) => k.status == 'aktif').toList();

                if (joinedClasses.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: ctrl.loadKelas,
                  color: AppColors.primary,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: joinedClasses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final kelas = joinedClasses[index];
                      return _buildKelasCard(context, kelas, ctrl, session);
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 22),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kelas Saya', style: AppFonts.heading3(color: AppColors.textPrimary)),
                Text('Daftar ruang kelas yang kamu ikuti', style: AppFonts.caption(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildGabungBaruCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF7A00), Color(0xFFFF5100)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7A00).withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => Get.to(() => const GabungKelasScreen(fromKelasScreen: true)),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.group_add_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gabung Kelas Baru',
                      style: TextStyle(
                        fontFamily: 'FredokaOne',
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Scan QR Code atau masukkan kode dari Gurumu',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.class_outlined, color: AppColors.primary, size: 44),
            ),
            const SizedBox(height: 24),
            Text(
              'Belum Ada Kelas',
              style: AppFonts.heading3(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Kamu belum bergabung ke kelas manapun.\nGabung sekarang untuk mulai belajar bersama!',
              style: AppFonts.bodySmall(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              width: 220,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFFFF6B35)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => Get.to(() => const GabungKelasScreen(fromKelasScreen: true)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  label: const Text(
                    'Gabung Kelas Pertama',
                    style: TextStyle(
                      fontFamily: 'FredokaOne',
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKelasCard(BuildContext context, KelasModel kelas, KelasController ctrl, SessionController session) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.class_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kelas.namaKelas,
                      style: AppFonts.bodyText(
                        color: AppColors.textPrimary,
                        weight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Guru: ${kelas.guruNama}',
                      style: AppFonts.caption(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // Badge & Active Status (Toggling)
              Obx(() {
                final isActive = session.activeKelasId.value == kelas.kelasId;
                return GestureDetector(
                  onTap: () async {
                    if (isActive) {
                      // Matikan (Nonaktifkan)
                      await session.setActiveKelasId('');
                      EpicSnackbar.info('Mode Bebas', 'Kelas dinonaktifkan. Karyamu tidak akan dikirim ke laporan kelas (mode bermain bebas).');
                    } else {
                      // Set Aktif
                      await session.setActiveKelasId(kelas.kelasId);
                      EpicSnackbar.success('Kelas Aktif', 'Karya berikutnya akan dikirim ke "${kelas.namaKelas}"');
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      isActive ? '🟢 Aktif (Ketuk utk Matikan)' : 'Set Aktif',
                      style: TextStyle(
                        fontFamily: 'FredokaOne',
                        fontSize: 10,
                        color: isActive ? const Color(0xFF15803D) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),

          const SizedBox(height: 14),

          // Info Sekolah
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.business_rounded, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    kelas.namaSekolah,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Stats & Keluar Row (Bug 4)
          StreamBuilder<List<ArtworkModel>>(
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

              return Row(
                children: [
                  _buildKelasStatChip(
                    Icons.people_rounded,
                    '${kelas.muridIds.length} murid',
                    const Color(0xFF3B82F6),
                  ),
                  const SizedBox(width: 8),
                  _buildKelasStatChip(
                    Icons.star_rounded,
                    'Avg: ${avgNilai.toStringAsFixed(1)}',
                    const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 8),
                  _buildKelasStatChip(
                    Icons.palette_rounded,
                    '$totalKarya karya',
                    const Color(0xFF10B981),
                  ),
                  const Spacer(),
                  // Actions: Keluar Kelas
                  GestureDetector(
                    onTap: () => _confirmLeave(context, kelas, ctrl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFEE2E2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.exit_to_app_rounded, size: 12, color: Color(0xFFEF4444)),
                          SizedBox(width: 4),
                          Text(
                            'Keluar',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKelasStatChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLeave(BuildContext context, KelasModel kelas, KelasController ctrl) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Keluar Kelas?',
            style: AppFonts.heading3(color: const Color(0xFFEF4444)),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'Yakin ingin keluar dari "${kelas.namaKelas}"? Kamu bisa bergabung kembali kapan saja menggunakan kode kelas.',
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 14),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actionsPadding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
              child: const Text('Batal', style: TextStyle(fontFamily: 'FredokaOne', fontSize: 13)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ctrl.leaveKelas(kelas);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
              child: const Text('Ya, Keluar', style: TextStyle(fontFamily: 'FredokaOne', fontSize: 13)),
            ),
          ],
        );
      },
    );
  }
}
