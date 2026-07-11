import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/utils/helpers.dart';
import 'package:epic_app/data/models/artwork_model.dart';
import 'package:epic_app/data/repositories/artwork_repository.dart';
import 'package:epic_app/data/repositories/kelas_repository.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';

/// Layar detail karya — tampilkan gambar penuh, info skor, dan opsi download/hapus
class ArtworkDetailScreen extends StatefulWidget {
  final ArtworkModel artwork;

  const ArtworkDetailScreen({super.key, required this.artwork});

  @override
  State<ArtworkDetailScreen> createState() => _ArtworkDetailScreenState();
}

class _ArtworkDetailScreenState extends State<ArtworkDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late ConfettiController _confettiController;
  bool _isDownloading = false;
  bool _isDeleting = false;

  final _artworkRepo = ArtworkRepository();

  @override
  void initState() {
    super.initState();
    // Debug log - hapus setelah confirmed OK
    debugPrint('=== ARTWORK DEBUG ===');
    debugPrint('imageUrl: ${widget.artwork.imageUrl}');
    debugPrint('kategori: ${widget.artwork.kategori}');
    debugPrint('skorAI: ${(widget.artwork.skorAI ?? 0)}');
    debugPrint('====================');
    
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();

    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    if (_gradeLabel == 'S') {
      Future.delayed(const Duration(milliseconds: 500), () {
        _confettiController.play();
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Color get _kategoriColor {
    switch (widget.artwork.kategori) {
      case 'batik': return const Color(0xFF8B5CF6);
      case 'anyaman': return const Color(0xFF10B981);
      default: return AppColors.primary;
    }
  }

  String get _gradeLabel {
    return widget.artwork.actualGrade;
  }

  // ─── Download ke galeri HP ────────────────────────────────────────────────

  Future<void> _downloadToGallery() async {
    if (_isDownloading) return;

    // Cek dan minta izin jika diperlukan
    final hasAccess = await Gal.hasAccess(toAlbum: true);
    if (!hasAccess) {
      final granted = await Gal.requestAccess(toAlbum: true);
      if (!granted) {
        if (mounted) {
          Get.snackbar(
            'Izin Diperlukan',
            'Izin penyimpanan diperlukan untuk mengunduh gambar.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: const Color(0xFFFEF2F2),
            colorText: const Color(0xFFDC2626),
            icon: const Icon(Icons.warning_rounded, color: Color(0xFFDC2626)),
          );
        }
        return;
      }
    }

    setState(() => _isDownloading = true);

    try {
      // Download gambar dari URL
      final response = await http.get(Uri.parse(widget.artwork.imageUrl));
      if (response.statusCode != 200) throw Exception('Gagal mengunduh gambar');

      final Uint8List imageBytes = response.bodyBytes;

      // Simpan ke galeri menggunakan Gal
      await Gal.putImageBytes(
        imageBytes,
        album: 'EPIC App',
        name: 'EPIC_${widget.artwork.idKarya}',
      );

      if (mounted) {
        Get.snackbar(
          'Berhasil Diunduh! 🎉',
          'Gambar tersimpan di galeri foto HP kamu!',
          snackPosition: SnackPosition.TOP,
          backgroundColor: const Color(0xFFECFDF5),
          colorText: const Color(0xFF059669),
          icon: const Icon(Icons.download_done_rounded, color: Color(0xFF059669)),
        );
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar(
          'Gagal Mengunduh',
          'Periksa koneksi internet dan coba lagi.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: const Color(0xFFFEF2F2),
          colorText: const Color(0xFFDC2626),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  // ─── Hapus karya ─────────────────────────────────────────────────────────

  Future<void> _deleteArtwork() async {
    final session = Get.find<SessionController>();
    final isGuru = session.isGuru;

    // Proteksi Kelas Terarsip: Cek status kelas terlebih dahulu jika ada kelas terlink
    if (widget.artwork.kelasId != null) {
      try {
        final kelasRepo = KelasRepository();
        final kelas = await kelasRepo.getKelasDetail(widget.artwork.kelasId!);
        if (kelas != null && kelas.status == 'arsip') {
          Get.snackbar(
            'Kelas Terarsip 📁',
            'Karya ini telah terkunci di kelas terarsip dan tidak dapat dihapus.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: const Color(0xFFFEF2F2),
            colorText: const Color(0xFFDC2626),
            icon: const Icon(Icons.lock_rounded, color: Color(0xFFDC2626)),
            duration: const Duration(seconds: 4),
          );
          return;
        }
      } catch (e) {
        debugPrint('⚠️ Gagal memeriksa status arsip kelas: $e');
      }
    }

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(isGuru ? 'Hapus Karya Permanen?' : 'Hapus Karya?',
            style: const TextStyle(fontFamily: 'FredokaOne', fontSize: 18)),
        content: Text(
          isGuru
              ? 'Karya ini akan dihapus secara permanen dari server dan kelas selamanya. Tindakan ini tidak bisa dibatalkan.'
              : (widget.artwork.kelasId != null
                  ? 'Karya ini akan dihapus dari galerimu. (Namun karena sudah dikumpulkan ke kelas, gurumu masih dapat melihatnya).'
                  : 'Karya ini akan dihapus permanen dari galeri. Tindakan ini tidak bisa dibatalkan.'),
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Batal',
                style: TextStyle(color: Colors.grey, fontFamily: 'Nunito')),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Hapus',
                style: TextStyle(fontFamily: 'FredokaOne')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    Get.dialog(
      const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      barrierDismissible: false,
    );

    try {
      await _artworkRepo.deleteArtwork(widget.artwork, isGuru: isGuru);
      Get.back(); // Tutup loading
      Get.back(result: true); // Kembali ke galeri dengan sinyal refresh
      Get.snackbar(
        'Dihapus',
        isGuru ? 'Karya berhasil dihapus secara permanen.' : 'Karya berhasil dihapus dari galeri.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFFECFDF5),
        colorText: const Color(0xFF059669),
      );
    } catch (e) {
      Get.back(); // Tutup loading
      if (mounted) {
        setState(() => _isDeleting = false);
        Get.snackbar(
          'Gagal Menghapus',
          'Terjadi kesalahan. Coba lagi.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: const Color(0xFFFEF2F2),
          colorText: const Color(0xFFDC2626),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final artwork = widget.artwork;
    final waktuMenit = artwork.waktuPengerjaan ~/ 60;
    final waktuDetik = artwork.waktuPengerjaan % 60;
    final waktuStr =
        '${waktuMenit.toString().padLeft(2, '0')}:${waktuDetik.toString().padLeft(2, '0')}';
    final displayFeedback = artwork.feedback.isNotEmpty 
        ? artwork.feedback 
        : (artwork.detailPenilaian['feedback']?.toString() ?? '');

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          children: [
            Column(
              children: [
                // ── Header dengan SafeArea ──
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        // Tombol back
                        IconButton(
                          onPressed: () => Get.back(),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black38,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const Spacer(),
                        // Download icon button
                        IconButton(
                          onPressed: _isDownloading ? null : _downloadToGallery,
                          icon: _isDownloading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.download_rounded, color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black38,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Hapus icon button
                        IconButton(
                          onPressed: _isDeleting ? null : _deleteArtwork,
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF6B6B)),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black38,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Gambar (mengisi sisa ruang) ──
                Expanded(
                  child: Center(
                    child: artwork.imageUrl.isEmpty
                        ? const Icon(Icons.image_not_supported_rounded, color: Colors.white38, size: 80)
                        : CachedNetworkImage(
                            imageUrl: artwork.imageUrl,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.broken_image_rounded, color: Colors.white38, size: 80,
                            ),
                          ),
                  ),
                ),

                // ── Info Panel Bawah ──
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Judul + Grade badge
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      artwork.judulKarya.isNotEmpty
                                          ? artwork.judulKarya
                                          : 'Karya ${Helpers.getKategoriLabel(artwork.kategori)}',
                                      style: const TextStyle(
                                          fontFamily: 'FredokaOne', fontSize: 18, color: Colors.white),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${Helpers.getKategoriLabel(artwork.kategori)} • Level ${artwork.level} • ${DateFormat('dd MMM yyyy').format(artwork.createdAt)}',
                                      style: const TextStyle(
                                          fontFamily: 'Nunito',
                                          fontSize: 11,
                                          color: Colors.white60,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Grade badge besar
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: artwork.status == 'pending' ? Colors.orange : _kategoriColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                        color: (artwork.status == 'pending' ? Colors.orange : _kategoriColor).withValues(alpha: 0.5), blurRadius: 12)
                                  ],
                                ),
                                child: Center(
                                  child: artwork.status == 'pending'
                                      ? const Icon(Icons.access_time_filled, color: Colors.white, size: 28)
                                      : Text(
                                          _gradeLabel,
                                          style: const TextStyle(
                                              fontFamily: 'FredokaOne', fontSize: 22, color: Colors.white),
                                        ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Stats chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                if (artwork.status != 'pending') ...[
                                  _InfoChip(
                                    icon: Icons.analytics_rounded,
                                    label: 'Skor ${(artwork.skorAI ?? 0)}',
                                    color: _kategoriColor,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                _InfoChip(
                                  icon: Icons.timer_rounded,
                                  label: waktuStr,
                                  color: const Color(0xFF3B82F6),
                                ),
                                if (artwork.status != 'pending') ...[
                                  const SizedBox(width: 8),
                                  _InfoChip(
                                    icon: Icons.stars_rounded,
                                    label: '+${artwork.poinDapat} Poin',
                                    color: const Color(0xFFFF9900),
                                  ),
                                ],
                                if (artwork.nyawaDigunakan > 0) ...[
                                  const SizedBox(width: 8),
                                  _InfoChip(
                                    icon: Icons.favorite_rounded,
                                    label: '${artwork.nyawaDigunakan}x',
                                    color: const Color(0xFFEF4444),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Komentar AI
                          if (artwork.status == 'pending') ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, color: Colors.orange, size: 24),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Penilaian tertunda karena limit token AI habis. Karya akan dinilai otomatis nanti saat limit tersedia.',
                                      style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: Colors.white, height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (displayFeedback.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.smart_toy_rounded, color: Colors.white60, size: 14),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Komentar Juri AI',
                                        style: TextStyle(
                                          fontFamily: 'FredokaOne',
                                          fontSize: 11,
                                          color: _kategoriColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    displayFeedback,
                                    style: const TextStyle(
                                        fontFamily: 'Nunito', fontSize: 13, color: Colors.white, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 14),

                          // Tombol Download besar
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isDownloading ? null : _downloadToGallery,
                              icon: _isDownloading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.download_rounded),
                              label: Text(
                                _isDownloading ? 'Mengunduh...' : 'Unduh ke Galeri HP',
                                style: const TextStyle(fontFamily: 'FredokaOne', fontSize: 15),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _kategoriColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Confetti di atas semua
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.red,
                  Colors.yellow,
                  Colors.green,
                  Colors.blue,
                  Colors.orange,
                  Colors.purple,
                ],
                numberOfParticles: 30,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'FredokaOne',
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
