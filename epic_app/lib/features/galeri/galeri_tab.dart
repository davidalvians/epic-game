import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/features/galeri/galeri_controller.dart';
import 'package:epic_app/features/galeri/artwork_detail_screen.dart';
import 'package:epic_app/data/models/artwork_model.dart';
import 'package:intl/intl.dart';

class GaleriTab extends StatelessWidget {
  const GaleriTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(GaleriController());
    final filters = ['Semua', 'Keris', 'Batik', 'Anyaman'];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F0),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Galeri Karya',
                    style: TextStyle(
                      fontFamily: 'FredokaOne',
                      fontSize: 28,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Koleksi hasil karya terbaikmu!',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            // ── Filter Chips ────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              physics: const BouncingScrollPhysics(),
              child: Obx(() => Row(
                children: filters.map((filter) {
                  final isSelected = controller.selectedFilter.value == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        filter,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) controller.setFilter(filter);
                      },
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              )),
            ),
            
            const SizedBox(height: 16),

            // ── Konten ─────────────────────────────────────────────
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                if (controller.errorMessage.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Color(0xFFCBD5E1)),
                        const SizedBox(height: 16),
                        Text(
                          controller.errorMessage.value,
                          style: const TextStyle(
                            fontFamily: 'FredokaOne',
                            fontSize: 16,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: controller.loadArtworks,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  );
                }

                final items = controller.filteredArtworks;
                if (items.isEmpty) {
                  return _buildEmptyState();
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.6,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return _buildArtworkCard(context, items[index]);
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Color _kategoriColor(String kategori) {
    switch (kategori) {
      case 'batik': return const Color(0xFF8B5CF6);
      case 'anyaman': return const Color(0xFF10B981);
      default: return AppColors.primary;
    }
  }

  Widget _buildArtworkCard(BuildContext context, ArtworkModel artwork) {
    return GestureDetector(
      onTap: () async {
        final deleted = await Get.to<bool>(
          () => ArtworkDetailScreen(artwork: artwork),
          transition: Transition.fadeIn,
        );
        if (deleted == true) {
          // Refresh galeri setelah karya dihapus
          Get.find<GaleriController>().loadArtworks();
        }
      },
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1E5D9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: artwork.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: const Color(0xFFF8FAFC),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2, 
                          color: AppColors.primary
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: const Color(0xFFF8FAFC),
                      child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                    ),
                  ),
                  // Overlay gradient
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Poin Badge
                  if (artwork.status != 'pending')
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Row(
                        children: [
                          const Icon(Icons.stars_rounded, color: Color(0xFFFFD700), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '+${artwork.poinDapat ?? 0}',
                            style: const TextStyle(
                              fontFamily: 'FredokaOne',
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Grade Badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: artwork.status == 'pending' ? Colors.orange : _kategoriColor(artwork.kategori),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (artwork.status == 'pending') ...[
                             const Icon(Icons.access_time_filled, color: Colors.white, size: 14),
                             const SizedBox(width: 4),
                             const Text(
                               'Pending',
                               style: TextStyle(fontFamily: 'FredokaOne', color: Colors.white, fontSize: 12),
                             ),
                          ] else 
                             Text(
                               artwork.actualGrade,
                               style: const TextStyle(
                                 fontFamily: 'FredokaOne',
                                 color: Colors.white,
                                 fontSize: 14,
                               ),
                             ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  artwork.judulKarya.isNotEmpty ? artwork.judulKarya : 'Karya ${artwork.kategori.capitalizeFirst}',
                  style: const TextStyle(
                    fontFamily: 'FredokaOne',
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Level ${artwork.level}',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      DateFormat('dd MMM').format(artwork.createdAt),
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFEDD5), width: 2),
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                size: 64,
                color: Color(0xFFFF9900),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Galeri Masih Kosong',
              style: TextStyle(
                fontFamily: 'FredokaOne',
                fontSize: 22,
                color: Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Ayo selesaikan game menggambar dan simpan karyamu di sini!',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

