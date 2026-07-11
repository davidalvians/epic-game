import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:epic_app/core/utils/epic_snackbar.dart';
import 'package:epic_app/data/models/artwork_model.dart';
import 'package:epic_app/data/models/user_model.dart';
import 'package:epic_app/data/repositories/artwork_repository.dart';
import 'package:epic_app/data/repositories/kelas_repository.dart';
import 'package:epic_app/data/repositories/user_repository.dart';
import 'package:epic_app/features/kelas/kelas_controller.dart';
import 'package:epic_app/features/kelas/kelas_detail_guru_screen.dart';
import 'package:epic_app/features/galeri/artwork_detail_screen.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'package:epic_app/shared/widgets/user_avatar_widget.dart';

class GuruHomeTab extends StatelessWidget {
  const GuruHomeTab({super.key});

  String _getDynamicGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) {
      return 'Selamat Pagi 🌅';
    } else if (hour >= 11 && hour < 15) {
      return 'Selamat Siang ☀️';
    } else if (hour >= 15 && hour < 18) {
      return 'Selamat Sore 🌇';
    } else {
      return 'Selamat Malam 🌙';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionCtrl = Get.find<SessionController>();
    final kelasCtrl = Get.put(KelasController());
    final user = sessionCtrl.user;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF9),
      body: Stack(
        children: [
          // ─── Mesh Gradient Ambient Blobs ───
          Positioned(
            top: -120,
            right: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFE5D9).withValues(alpha: 0.5),
              ),
            ),
          ),
          Positioned(
            top: 280,
            left: -150,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFD7BA).withValues(alpha: 0.4),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFEC89A).withValues(alpha: 0.35),
              ),
            ),
          ),
          // Blur filter overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(color: Colors.transparent),
            ),
          ),

          // Main contents
          SafeArea(
            child: RefreshIndicator(
              onRefresh: kelasCtrl.loadKelas,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                // ─── Header ───
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getDynamicGreeting(),
                            style: AppFonts.bodySmall(color: Colors.grey[700], weight: FontWeight.w600).copyWith(
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Bpk/Ibu ${user?.namaPanggilan ?? "Guru"}',
                            style: AppFonts.heading2().copyWith(
                              fontSize: 25,
                              fontFamily: 'FredokaOne',
                              color: AppColors.dark,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.school_rounded, size: 13, color: AppColors.primary),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  user?.sekolah ?? 'Sekolah tidak diketahui',
                                  style: AppFonts.caption(color: Colors.grey[700]).copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Double ring avatar with neon shadow glow
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFFFF6B35), Color(0xFFFFB700)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: UserAvatarWidget(
                          avatarUrl: user?.avatarUrl,
                          name: user?.namaLengkap ?? '',
                          radius: 28,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // ─── Ringkasan (Grid 2x2) ───
                Text(
                  'Ringkasan',
                  style: AppFonts.heading3(),
                ),
                const SizedBox(height: 16),
                Obx(() {
                  final activeClasses = kelasCtrl.kelasList.where((k) => k.isActive).toList();
                  final totalMurid = activeClasses.fold<int>(0, (acc, k) => acc + k.jumlahMurid);
                  final activeClassIds = activeClasses.map((k) => k.kelasId).toList();

                  Widget buildGrid({required double avgNilai, required int karyaHariIni}) {
                    return GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.2,
                      children: [
                        _buildSummaryCard(
                          icon: Icons.school_rounded,
                          title: 'Kelas Aktif',
                          value: activeClasses.length.toString(),
                          color: const Color(0xFFFF5A36),
                          gradientColors: const [Color(0xFFFF5A36), Color(0xFFFF855A)],
                        ),
                        _buildSummaryCard(
                          icon: Icons.people_alt_rounded,
                          title: 'Total Murid',
                          value: totalMurid.toString(),
                          color: const Color(0xFF02B386),
                          gradientColors: const [Color(0xFF02B386), Color(0xFF2EC4B6)],
                        ),
                        _buildSummaryCard(
                          icon: Icons.star_rounded,
                          title: 'Rata² Nilai',
                          value: avgNilai.toStringAsFixed(1),
                          color: const Color(0xFFE09000),
                          gradientColors: const [Color(0xFFE09000), Color(0xFFFFB700)],
                        ),
                        _buildSummaryCard(
                          icon: Icons.palette_rounded,
                          title: 'Karya Hari Ini',
                          value: karyaHariIni.toString(),
                          color: const Color(0xFF3B40F6),
                          gradientColors: const [Color(0xFF3B40F6), Color(0xFF6366F1)],
                        ),
                      ],
                    );
                  }

                  if (activeClassIds.isEmpty) {
                    return buildGrid(avgNilai: 0.0, karyaHariIni: 0);
                  }

                  return StreamBuilder<List<ArtworkModel>>(
                    stream: ArtworkRepository().watchArtworksByKelasList(activeClassIds),
                    builder: (context, snapshot) {
                      double avgNilai = 0.0;
                      int worksTodayCount = 0;

                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        final artworks = snapshot.data!;
                        
                        if (artworks.isNotEmpty) {
                          final totalScores = artworks.fold<int>(0, (acc, a) => acc + (a.skorAI ?? 0));
                          avgNilai = totalScores / artworks.length;

                          final now = DateTime.now();
                          worksTodayCount = artworks.where((a) {
                            return a.createdAt.year == now.year &&
                                a.createdAt.month == now.month &&
                                a.createdAt.day == now.day;
                          }).length;
                        }
                      }

                      return buildGrid(avgNilai: avgNilai, karyaHariIni: worksTodayCount);
                    },
                  );
                }),

                const SizedBox(height: 32),

                // ─── Daftar Kelas Saya ───
                Text(
                  'Kelas Saya',
                  style: AppFonts.heading3(),
                ),
                const SizedBox(height: 16),
                Obx(() {
                  if (kelasCtrl.isLoading.value && kelasCtrl.kelasList.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final activeClasses = kelasCtrl.kelasList.where((k) => k.isActive).toList();

                  if (activeClasses.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Belum Ada Kelas Aktif',
                            style: AppFonts.bodyText(weight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Buka menu Kelas untuk membuatnya.',
                            style: AppFonts.caption(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: activeClasses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final kelas = activeClasses[index];
                      final themeIndex = index % 3;
                      final Color accentColor = themeIndex == 0
                          ? AppColors.primary
                          : themeIndex == 1
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF10B981);

                      return StreamBuilder<List<ArtworkModel>>(
                        stream: ArtworkRepository().watchArtworksByKelas(kelas.kelasId),
                        builder: (context, snapshot) {
                          double avgNilai = 0.0;
                          int totalKarya = 0;
                          if (snapshot.hasData) {
                            final filteredArtworks = snapshot.data!;
                            totalKarya = filteredArtworks.length;
                            if (filteredArtworks.isNotEmpty) {
                              avgNilai = filteredArtworks.fold<int>(0, (acc, a) => acc + (a.skorAI ?? 0)) / totalKarya;
                            }
                          }

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Get.to(() => KelasDetailGuruScreen(kelas: kelas)),
                                borderRadius: BorderRadius.circular(24),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [accentColor, accentColor.withValues(alpha: 0.75)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: accentColor.withValues(alpha: 0.3),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(Icons.class_rounded, color: Colors.white, size: 24),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  kelas.namaKelas,
                                                  style: AppFonts.bodyText(weight: FontWeight.bold).copyWith(
                                                    fontSize: 17,
                                                    color: AppColors.dark,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: accentColor.withValues(alpha: 0.08),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        'KODE: ${kelas.kodeKelas}',
                                                        style: AppFonts.caption(color: accentColor).copyWith(
                                                          fontWeight: FontWeight.w900,
                                                          fontSize: 10,
                                                          letterSpacing: 0.3,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    GestureDetector(
                                                      onTap: () {
                                                        Clipboard.setData(ClipboardData(text: kelas.kodeKelas));
                                                        EpicSnackbar.success('Tersalin', 'Kode kelas disalin ke clipboard');
                                                      },
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: Colors.grey.shade100,
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(color: Colors.grey.shade200),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons.copy_rounded, size: 10, color: Colors.grey.shade600),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              'Salin',
                                                              style: AppFonts.caption(color: Colors.grey.shade600).copyWith(
                                                                fontSize: 9,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            )
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '${kelas.jumlahMurid}',
                                                style: AppFonts.heading2().copyWith(
                                                  color: accentColor,
                                                  fontSize: 26,
                                                  fontFamily: 'FredokaOne',
                                                ),
                                              ),
                                              Text(
                                                'Murid',
                                                style: AppFonts.caption(color: Colors.grey[500]).copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24, color: Color(0xFFF1F5F9), thickness: 1.2),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFFBEB),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: const Color(0xFFFDE68A), width: 1),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.star_rounded, size: 16, color: Color(0xFFD97706)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Rerata: ${avgNilai.toStringAsFixed(1)}',
                                                  style: AppFonts.bodySmall(color: const Color(0xFFB45309), weight: FontWeight.w800),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: accentColor.withValues(alpha: 0.06),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: accentColor.withValues(alpha: 0.15), width: 1),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.palette_rounded, size: 16, color: accentColor),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$totalKarya Karya',
                                                  style: AppFonts.bodySmall(color: accentColor, weight: FontWeight.w800),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                }),

                const SizedBox(height: 32),

                // ─── Karya Terbaru (Real Data) ───
                Obx(() {
                  final activeClasses = kelasCtrl.kelasList.where((k) => k.isActive).toList();
                  if (activeClasses.isEmpty) return const SizedBox.shrink();
                  final activeClassIds = activeClasses.map((k) => k.kelasId).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Karya Terbaru', style: AppFonts.heading3()),
                          TextButton(
                            onPressed: () => _showAllKaryaBottomSheet(context, activeClassIds),
                            child: const Text(
                              'Lihat Semua',
                              style: TextStyle(
                                fontFamily: 'FredokaOne',
                                color: AppColors.primary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _RealKaryaTerbaru(kelasIds: activeClassIds),
                      const SizedBox(height: 32),
                    ],
                  );
                }),

                // ─── Top Murid (Real Data) ───
                Obx(() {
                  final activeClasses = kelasCtrl.kelasList.where((k) => k.isActive).toList();
                  if (activeClasses.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Top Murid', style: AppFonts.heading3()),
                      const SizedBox(height: 16),
                      _RealTopMurid(kelasIds: activeClasses.map((k) => k.kelasId).toList()),
                      const SizedBox(height: 40),
                    ],
                  );
                }),

                // ─── Kelas Terarsip (Collapsible Folder) ───
                Obx(() {
                  final archivedClasses = kelasCtrl.kelasList.where((k) => k.status == 'arsip').toList();
                  if (archivedClasses.isEmpty) return const SizedBox.shrink();

                  return Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Row(
                        children: [
                          const Icon(Icons.archive_outlined, color: Colors.grey, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Kelas Terarsip (${archivedClasses.length})',
                            style: AppFonts.heading3().copyWith(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                      children: [
                        const SizedBox(height: 12),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: archivedClasses.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final kelas = archivedClasses[index];
                            return StreamBuilder<List<ArtworkModel>>(
                              stream: ArtworkRepository().watchArtworksByKelas(kelas.kelasId),
                              builder: (context, snapshot) {
                                double avgNilai = 0.0;
                                int totalKarya = 0;
                                if (snapshot.hasData) {
                                  final filteredArtworks = snapshot.data!;
                                  totalKarya = filteredArtworks.length;
                                  if (filteredArtworks.isNotEmpty) {
                                    avgNilai = filteredArtworks.fold<int>(0, (acc, a) => acc + (a.skorAI ?? 0)) / totalKarya;
                                  }
                                }

                                return InkWell(
                                  onTap: () => Get.to(() => KelasDetailGuruScreen(kelas: kelas)),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.folder_zip_rounded, color: Colors.grey),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                kelas.namaKelas,
                                                style: AppFonts.bodyText(weight: FontWeight.bold).copyWith(color: Colors.grey[700]),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Tahun Ajaran: ${kelas.tahunAjaran}',
                                                style: AppFonts.caption(color: Colors.grey[500]),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '${kelas.jumlahMurid} Murid',
                                              style: AppFonts.bodySmall(color: Colors.grey[700], weight: FontWeight.w700),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                                                const SizedBox(width: 2),
                                                Text(
                                                  avgNilai.toStringAsFixed(1),
                                                  style: AppFonts.caption(color: Colors.grey[600]).copyWith(fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    ],
  ),
);
}

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required List<Color> gradientColors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          // Background decorative circle shape
          Positioned(
            right: -25,
            bottom: -25,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                value,
                style: AppFonts.heading1().copyWith(
                  color: Colors.white,
                  fontSize: 26,
                  fontFamily: 'FredokaOne',
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      offset: const Offset(0, 1.5),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 1),
              Text(
                title,
                style: AppFonts.caption(color: Colors.white.withValues(alpha: 0.85)).copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAllKaryaBottomSheet(BuildContext context, List<String> kelasIds) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '🎨 Seluruh Karya Terbaru',
                    style: AppFonts.heading3(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Menampilkan semua karya dari murid-murid di kelas Anda.',
                    style: AppFonts.caption(color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<List<ArtworkModel>>(
                      stream: ArtworkRepository().watchArtworksByKelasList(kelasIds),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(
                            child: Text('Belum ada karya seni.', style: AppFonts.caption(color: Colors.grey)),
                          );
                        }
                        final artworks = snapshot.data!;
                        return ListView.builder(
                          controller: scrollController,
                          physics: const BouncingScrollPhysics(),
                          itemCount: artworks.length,
                          itemBuilder: (context, index) {
                            return _KaryaCard(art: artworks[index]);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

}

// ─── Widget: Karya Terbaru dari Firestore ─────────────────────────────────────
class _RealKaryaTerbaru extends StatelessWidget {
  final List<String> kelasIds;
  const _RealKaryaTerbaru({required this.kelasIds});

  @override
  Widget build(BuildContext context) {
    if (kelasIds.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<List<ArtworkModel>>(
      stream: ArtworkRepository().watchArtworksByKelasList(kelasIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'Belum ada karya yang dikirim.',
                style: AppFonts.caption(color: Colors.grey[500]),
              ),
            ),
          );
        }

        final filtered = snapshot.data!;

        // Ambil 5 karya terbaru untuk horizontal scroll
        final latest = filtered.take(5).toList();

        return SizedBox(
          height: 175,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: latest.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final art = latest[index];
              return _KaryaCardHorizontal(art: art);
            },
          ),
        );
      },
    );
  }
}

class _KaryaCard extends StatelessWidget {
  final ArtworkModel art;
  const _KaryaCard({required this.art});

  Color _gradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'S':
        return const Color(0xFFD97706); // Amber Gold
      case 'A':
      case 'A+':
      case 'A-':
        return const Color(0xFF10B981); // Emerald Green
      case 'B':
      case 'B+':
      case 'B-':
        return const Color(0xFF3B82F6); // Blue
      case 'C':
      case 'C+':
      case 'C-':
        return const Color(0xFFF59E0B); // Orange
      case 'D':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFF64748B); // Slate Grey
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  @override
  Widget build(BuildContext context) {
    final String actualGrade = art.actualGrade;

    return GestureDetector(
      onTap: () => Get.to(() => ArtworkDetailScreen(artwork: art)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Colors.grey.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            // Thumbnail with subtle shadow and border
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: art.imageUrl.isNotEmpty
                    ? Image.network(
                        art.imageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 60,
                          height: 60,
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(Icons.image_rounded, color: Colors.grey),
                        ),
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        color: const Color(0xFFF1F5F9),
                        child: const Icon(Icons.palette_rounded, color: AppColors.primary),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    art.judulKarya.isNotEmpty ? art.judulKarya : 'Karya Seni',
                    style: AppFonts.bodyText(weight: FontWeight.bold).copyWith(
                      fontSize: 15,
                      color: AppColors.dark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<UserModel?>(
                    future: UserRepository().getUser(art.uid),
                    builder: (context, userSnap) {
                      String studentName = 'Memuat nama...';
                      if (userSnap.hasData && userSnap.data != null) {
                        final userModel = userSnap.data!;
                        studentName = userModel.namaLengkap.trim().isNotEmpty
                            ? userModel.namaLengkap.trim()
                            : (userModel.namaPanggilan.trim().isNotEmpty
                                ? userModel.namaPanggilan.trim()
                                : 'Murid');
                      }

                      // Dapatkan nama kelas berdasarkan kelasId
                      final kelasCtrl = Get.find<KelasController>();
                      final classObj = kelasCtrl.kelasList.firstWhereOrNull((k) => k.kelasId == art.kelasId);
                      final className = classObj?.namaKelas ?? 'Kelas -';

                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$studentName • $className',
                              style: AppFonts.caption(color: Colors.grey.shade600).copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (art.deletedByMurid == true) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: const Text(
                                'Dihapus',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          art.kategori.capitalizeFirst ?? art.kategori,
                          style: AppFonts.caption(color: AppColors.primary).copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(art.createdAt),
                        style: AppFonts.caption(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Grade Badge with glow shadow
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _gradeColor(actualGrade),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _gradeColor(actualGrade).withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  actualGrade,
                  style: const TextStyle(
                    fontFamily: 'FredokaOne',
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RealTopMurid extends StatelessWidget {
  final List<String> kelasIds;
  const _RealTopMurid({required this.kelasIds});

  @override
  Widget build(BuildContext context) {
    if (kelasIds.isEmpty) return const SizedBox.shrink();

    final kelasRepo = KelasRepository();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: kelasRepo.watchLeaderboardKelas(kelasIds.first),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final members = snapshot.data ?? [];
        if (members.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Text(
                'Belum ada murid dengan poin di kelas ini.',
                style: AppFonts.caption(color: Colors.grey[500]),
              ),
            ),
          );
        }

        final top = members.take(3).toList();
        final total = top.length;

        final Map<String, dynamic>? rank1 = total >= 1 ? top[0] : null;
        final Map<String, dynamic>? rank2 = total >= 2 ? top[1] : null;
        final Map<String, dynamic>? rank3 = total >= 3 ? top[2] : null;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (total >= 2)
                  _buildPodiumStep(
                    context: context,
                    member: rank2,
                    rank: 2,
                    height: 100,
                    gradientColors: const [Color(0xFF94A3B8), Color(0xFF475569)],
                    metalColor: const Color(0xFFCBD5E1),
                    avatarRadius: 20,
                    trophyEmoji: '🥈',
                  )
                else
                  const Expanded(child: SizedBox.shrink()),

                const SizedBox(width: 8),

                if (total >= 1)
                  _buildPodiumStep(
                    context: context,
                    member: rank1,
                    rank: 1,
                    height: 135,
                    gradientColors: const [Color(0xFFFBBF24), Color(0xFFD97706)],
                    metalColor: const Color(0xFFF59E0B),
                    avatarRadius: 26,
                    trophyEmoji: '👑',
                  )
                else
                  const Expanded(child: SizedBox.shrink()),

                const SizedBox(width: 8),

                if (total >= 3)
                  _buildPodiumStep(
                    context: context,
                    member: rank3,
                    rank: 3,
                    height: 85,
                    gradientColors: const [Color(0xFFFB923C), Color(0xFFC2410C)],
                    metalColor: const Color(0xFFFDBA74),
                    avatarRadius: 18,
                    trophyEmoji: '🥉',
                  )
                else
                  const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPodiumStep({
    required BuildContext context,
    required Map<String, dynamic>? member,
    required int rank,
    required double height,
    required List<Color> gradientColors,
    required Color metalColor,
    required double avatarRadius,
    required String trophyEmoji,
  }) {
    if (member == null) {
      return const Expanded(child: SizedBox.shrink());
    }

    final nama = member['namaPanggilan']?.toString().isNotEmpty == true
        ? member['namaPanggilan']
        : member['namaLengkap'] ?? 'Murid';
    final poin = member['poin'] ?? 0;
    final avatarUrl = member['avatarUrl']?.toString() ?? '';
    final studentUid = member['uid'] ?? '';

    final kelasCtrl = Get.find<KelasController>();
    final activeClasses = kelasCtrl.kelasList.where((k) => k.isActive).toList();
    final joinedClass = activeClasses.firstWhereOrNull((k) => k.muridIds.contains(studentUid));
    final className = joinedClass?.namaKelas ?? 'Kelas -';

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            trophyEmoji,
            style: TextStyle(fontSize: rank == 1 ? 26 : 20),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: metalColor,
                width: rank == 1 ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: metalColor.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: UserAvatarWidget(
              avatarUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
              radius: avatarRadius,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            nama,
            style: AppFonts.bodySmall(weight: FontWeight.bold).copyWith(
              fontSize: rank == 1 ? 12 : 10,
              color: AppColors.dark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            className,
            style: AppFonts.caption(color: Colors.grey.shade500).copyWith(
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: gradientColors.first.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, -3),
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '#$rank',
                  style: TextStyle(
                    fontFamily: 'FredokaOne',
                    fontSize: rank == 1 ? 22 : 16,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        offset: const Offset(0, 2),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.stars_rounded,
                        size: 10,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '$poin',
                        style: AppFonts.bodyText(weight: FontWeight.bold).copyWith(
                          color: Colors.white,
                          fontSize: 9,
                          fontFamily: 'FredokaOne',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KaryaCardHorizontal extends StatelessWidget {
  final ArtworkModel art;
  const _KaryaCardHorizontal({required this.art});

  Color _gradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'S':
        return const Color(0xFFD97706); // Amber Gold
      case 'A':
      case 'A+':
      case 'A-':
        return const Color(0xFF10B981); // Emerald Green
      case 'B':
      case 'B+':
      case 'B-':
        return const Color(0xFF3B82F6); // Blue
      case 'C':
      case 'C+':
      case 'C-':
        return const Color(0xFFF59E0B); // Orange
      case 'D':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFF64748B); // Slate Grey
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}j';
    return '${diff.inDays}h';
  }

  @override
  Widget build(BuildContext context) {
    final String actualGrade = art.actualGrade;
    final kelasCtrl = Get.find<KelasController>();
    final classObj = kelasCtrl.kelasList.firstWhereOrNull((k) => k.kelasId == art.kelasId);
    final className = classObj?.namaKelas ?? 'Kelas -';

    return GestureDetector(
      onTap: () => Get.to(() => ArtworkDetailScreen(artwork: art)),
      child: Container(
        width: 140,
        height: 165,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image cover section
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                  child: art.imageUrl.isNotEmpty
                      ? Image.network(
                          art.imageUrl,
                          width: double.infinity,
                          height: 85,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: double.infinity,
                            height: 85,
                            color: const Color(0xFFF1F5F9),
                            child: const Icon(Icons.image_rounded, color: Colors.grey, size: 20),
                          ),
                        )
                      : Container(
                          width: double.infinity,
                          height: 85,
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(Icons.palette_rounded, color: AppColors.primary, size: 24),
                        ),
                ),
                // Glowing Grade Badge
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _gradeColor(actualGrade),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _gradeColor(actualGrade).withValues(alpha: 0.45),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                    child: Center(
                      child: Text(
                        actualGrade,
                        style: const TextStyle(
                          fontFamily: 'FredokaOne',
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                // Category Tag overlay
                Positioned(
                  bottom: 6,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      art.kategori.capitalizeFirst ?? art.kategori,
                      style: AppFonts.caption(color: Colors.white).copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          art.judulKarya.isNotEmpty ? art.judulKarya : 'Karya Seni',
                          style: AppFonts.bodyText(weight: FontWeight.bold).copyWith(
                            fontSize: 12,
                            color: AppColors.dark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        FutureBuilder<UserModel?>(
                          future: UserRepository().getUser(art.uid),
                          builder: (context, userSnap) {
                            String studentName = 'Memuat...';
                            if (userSnap.hasData && userSnap.data != null) {
                              final userModel = userSnap.data!;
                              studentName = userModel.namaLengkap.trim().isNotEmpty
                                  ? userModel.namaLengkap.trim()
                                  : (userModel.namaPanggilan.trim().isNotEmpty
                                      ? userModel.namaPanggilan.trim()
                                      : 'Murid');
                            }

                            return Text(
                              studentName,
                              style: AppFonts.caption(color: Colors.grey.shade700).copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ],
                    ),
                    Text(
                      '$className • ${_formatTime(art.createdAt)}',
                      style: AppFonts.caption(color: Colors.grey.shade500).copyWith(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
