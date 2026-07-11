import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:epic_app/core/utils/epic_snackbar.dart';
import 'package:epic_app/data/models/kelas_model.dart';
import 'package:epic_app/features/kelas/kelas_detail_guru_screen.dart';

class KelasSuccessScreen extends StatefulWidget {
  final KelasModel kelas;

  const KelasSuccessScreen({super.key, required this.kelas});

  @override
  State<KelasSuccessScreen> createState() => _KelasSuccessScreenState();
}

class _KelasSuccessScreenState extends State<KelasSuccessScreen> {
  final GlobalKey _qrKey = GlobalKey();
  bool _isSaving = false;

  Future<void> _saveQRToGallery() async {
    if (_isSaving) return;

    // Cek dan minta izin penyimpanan
    final hasAccess = await Gal.hasAccess(toAlbum: true);
    if (!hasAccess) {
      final granted = await Gal.requestAccess(toAlbum: true);
      if (!granted) {
        EpicSnackbar.error(
          'Izin Diperlukan',
          'Izin penyimpanan diperlukan untuk menyimpan QR Code.',
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      // Jeda singkat agar frame selesai dirender
      await Future.delayed(const Duration(milliseconds: 150));

      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Gagal memproses QR Code card');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Gagal mengonversi QR Code ke data bytes');

      final pngBytes = byteData.buffer.asUint8List();

      await Gal.putImageBytes(
        pngBytes,
        album: 'EPIC App',
        name: 'EPIC_QR_${widget.kelas.kodeKelas}',
      );

      EpicSnackbar.success(
        'Berhasil Disimpan 📸',
        'QR Code berhasil disimpan ke galeri foto Anda.',
      );
    } catch (e) {
      debugPrint('Error saving QR: $e');
      EpicSnackbar.error(
        'Gagal Menyimpan',
        'Terjadi kesalahan saat menyimpan gambar ke galeri.',
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final qrData = widget.kelas.qrData.isNotEmpty 
        ? widget.kelas.qrData 
        : jsonEncode({
            'type': 'epic_kelas',
            'code': widget.kelas.kodeKelas,
          });

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon Success
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF22C55E),
                    size: 56,
                  ),
                ),
                const SizedBox(height: 16),
                
                Text(
                  'Kelas Berhasil Dibuat!',
                  style: AppFonts.heading2(color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.kelas.namaKelas} — ${widget.kelas.namaSekolah}',
                  style: AppFonts.bodyText(weight: FontWeight.w700, color: const Color(0xFFEA580C)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                Text(
                  'Bagikan kode atau QR ini\nkepada murid-muridmu:',
                  style: AppFonts.bodySmall(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // QR Code Card (Wrapped in RepaintBoundary for capture)
                RepaintBoundary(
                  key: _qrKey,
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF7A00).withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                          ),
                          child: QrImageView(
                            data: qrData,
                            version: QrVersions.auto,
                            size: 180.0,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: AppColors.dark,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: AppColors.dark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'KODE MANUAL',
                          style: AppFonts.caption(color: Colors.grey.shade400).copyWith(letterSpacing: 1),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.kelas.kodeKelas,
                          style: const TextStyle(
                            fontFamily: 'FredokaOne',
                            fontSize: 28,
                            letterSpacing: 3,
                            color: Color(0xFFEA580C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // Button Actions
                _buildActionButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        // 📤 Bagikan Kode
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.kelas.kodeKelas));
              EpicSnackbar.success(
                'Tersalin! 📤',
                'Kode kelas ${widget.kelas.kodeKelas} disalin ke clipboard.',
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.share_rounded),
            label: const Text(
              'Bagikan Kode',
              style: TextStyle(fontFamily: 'FredokaOne', fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 📸 Simpan QR ke Galeri (Nyata)
        SizedBox(
          width: double.infinity,
          height: 52,
          child: TextButton.icon(
            onPressed: _isSaving ? null : _saveQRToGallery,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: _isSaving 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.textSecondary),
                  )
                : const Icon(Icons.download_rounded),
            label: Text(
              _isSaving ? 'Menyimpan...' : 'Simpan QR ke Galeri',
              style: const TextStyle(fontFamily: 'FredokaOne', fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 👁️ Lihat Detail Kelas (Gradient Main Button)
        SizedBox(
          width: double.infinity,
          height: 56,
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
              onPressed: () {
                // Hapus layar sukses dan buka detail kelas
                Get.off(() => KelasDetailGuruScreen(kelas: widget.kelas));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.visibility_rounded, color: Colors.white),
              label: const Text(
                'Lihat Detail Kelas',
                style: TextStyle(fontFamily: 'FredokaOne', fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
