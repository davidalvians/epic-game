import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:epic_app/data/models/user_model.dart';
import 'package:epic_app/data/models/artwork_model.dart';
import 'package:epic_app/data/repositories/user_repository.dart';
import 'package:epic_app/data/repositories/artwork_repository.dart';
import 'package:epic_app/features/galeri/artwork_detail_screen.dart';

class ProfilMuridScreen extends StatelessWidget {
  final String muridUid;
  final String? kelasId;
  final String? kelasName;
  final String? sekolah;

  const ProfilMuridScreen({
    super.key,
    required this.muridUid,
    this.kelasId,
    this.kelasName,
    this.sekolah,
  });

  @override
  Widget build(BuildContext context) {
    final userRepo = UserRepository();
    final artworkRepo = ArtworkRepository();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Profil Murid',
          style: AppFonts.heading3(color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<UserModel?>(
        stream: userRepo.watchUser(muridUid),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final user = userSnap.data;
          final nama = user?.namaPanggilan.isNotEmpty == true
              ? user!.namaPanggilan
              : (user?.namaLengkap.isNotEmpty == true ? user!.namaLengkap : 'Murid');
          final username = user?.username ?? '';
          final avatarUrl = user?.avatarUrl ?? '';
          final poin = user?.poin ?? 0;
          final currentKelas = kelasName ?? user?.kelas ?? '';
          final currentSekolah = sekolah ?? user?.sekolah ?? '';

          return StreamBuilder<List<ArtworkModel>>(
            stream: kelasId != null
                ? artworkRepo.watchArtworksByKelas(kelasId!)
                : artworkRepo.watchArtworksByMurids([muridUid]),
            builder: (context, artSnap) {
              // Jika ada kelasId, saring karya murid di kelas ini saja.
              // Jika tidak, tampilkan semua karya murid tersebut.
              final artworks = (artSnap.data ?? [])
                  .where((a) => a.uid == muridUid)
                  .toList();
              final totalKarya = artworks.length;

              final avgNilai = totalKarya > 0
                  ? artworks.fold<int>(0, (sum, a) => sum + (a.skorAI ?? 0)) / totalKarya
                  : 0.0;

              // Calculate class-specific points if viewing inside a class, otherwise show global points
              final classPoints = kelasId != null
                  ? artworks.fold<int>(0, (sum, a) => sum + (a.poinDapat ?? 0))
                  : poin;

              // Calculate favorite grade (mode)
              final Map<String, int> gradeCounts = {};
              for (final art in artworks) {
                gradeCounts[art.actualGrade] = (gradeCounts[art.actualGrade] ?? 0) + 1;
              }
              String favoriteGrade = '-';
              int maxCount = 0;
              gradeCounts.forEach((grade, count) {
                if (count > maxCount) {
                  maxCount = count;
                  favoriteGrade = grade;
                }
              });

              // Calculate category levels completed
              final kerisLevel = artworks.where((a) => a.kategori == 'keris').fold<int>(0, (maxL, a) => a.level > maxL ? a.level : maxL);
              final batikLevel = artworks.where((a) => a.kategori == 'batik').fold<int>(0, (maxL, a) => a.level > maxL ? a.level : maxL);
              final anyamanLevel = artworks.where((a) => a.kategori == 'anyaman').fold<int>(0, (maxL, a) => a.level > maxL ? a.level : maxL);

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- PROFILE HEADER CARD ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: const Color(0xFFFFF7ED),
                            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl.isEmpty
                                ? Text(
                                    nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      fontFamily: 'FredokaOne',
                                      color: AppColors.primary,
                                      fontSize: 32,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nama,
                                  style: AppFonts.heading2(color: AppColors.textPrimary),
                                ),
                                Text(
                                  '@$username',
                                  style: AppFonts.bodyText(color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Kelas $currentKelas • $currentSekolah',
                                  style: AppFonts.caption(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- STATS GRID (2x2) ---
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 2.0,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      children: [
                        _buildStatCard('Total Poin', '$classPoints', AppColors.primary),
                        _buildStatCard('Karya Disubmit', '$totalKarya', const Color(0xFF3B82F6)),
                        _buildStatCard('Rata-rata Nilai', avgNilai.toStringAsFixed(1), const Color(0xFFF59E0B)),
                        _buildStatCard('Grade Terbanyak', favoriteGrade, const Color(0xFF10B981)),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // --- CATEGORY PROGRESS ---
                    const Text(
                      '📊 Progress per Kategori',
                      style: TextStyle(
                        fontFamily: 'FredokaOne',
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCategoryProgressRow('Keris', kerisLevel),
                    _buildCategoryProgressRow('Batik', batikLevel),
                    _buildCategoryProgressRow('Anyaman', anyamanLevel),
                    const SizedBox(height: 28),

                    // --- LATEST ARTWORKS ---
                    const Text(
                      '🎨 Karya Terbaru',
                      style: TextStyle(
                        fontFamily: 'FredokaOne',
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    artworks.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                'Belum ada karya yang disubmit.',
                                style: AppFonts.bodySmall(color: Colors.grey),
                              ),
                            ),
                          )
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.85,
                            ),
                            itemCount: artworks.length,
                            itemBuilder: (context, idx) {
                              final art = artworks[idx];
                              return _buildKaryaGridCard(context, art);
                            },
                          ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'FredokaOne',
              fontSize: 20,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppFonts.caption(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryProgressRow(String category, int levelCompleted) {
    double progress = levelCompleted / 4.0; // Level 4 completion is max
    if (progress > 1.0) progress = 1.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category,
                style: AppFonts.bodySmall(weight: FontWeight.w700),
              ),
              Text(
                levelCompleted > 0 ? 'L$levelCompleted Selesai' : 'Belum Dimulai',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: levelCompleted > 0 ? AppColors.primary : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE2E8F0),
              color: AppColors.primary,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKaryaGridCard(BuildContext context, ArtworkModel art) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: art.imageUrl.isNotEmpty
                      ? Image.network(
                          art.imageUrl,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        art.judulKarya.isNotEmpty ? art.judulKarya : 'Karya Seni',
                        style: const TextStyle(
                          fontFamily: 'FredokaOne',
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        art.kategori.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: art.kategori.toLowerCase() == 'batik'
                              ? const Color(0xFF8B5CF6)
                              : art.kategori.toLowerCase() == 'anyaman'
                                  ? const Color(0xFF10B981)
                                  : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Tapping Overlay
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Get.to(() => ArtworkDetailScreen(artwork: art));
                  },
                ),
              ),
            ),
            // Grade Badge Top Right
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Text(
                  art.actualGrade,
                  style: const TextStyle(
                    fontFamily: 'FredokaOne',
                    color: Colors.white,
                    fontSize: 11,
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
