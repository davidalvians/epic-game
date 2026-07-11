import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'package:epic_app/core/routes/app_routes.dart';

class GuruRejectedScreen extends StatefulWidget {
  const GuruRejectedScreen({super.key});

  @override
  State<GuruRejectedScreen> createState() => _GuruRejectedScreenState();
}

class _GuruRejectedScreenState extends State<GuruRejectedScreen> {
  String _alasanPenolakan = 'Memuat alasan penolakan...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlasanPenolakan();
  }

  Future<void> _loadAlasanPenolakan() async {
    try {
      final session = Get.find<SessionController>();
      final uid = session.user?.uid;
      if (uid == null) return;

      // Cari dokumen verifikasi terbaru untuk user ini
      final snapshot = await FirebaseFirestore.instance
          .collection('guru_verifikasi')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final catatan = data['catatanAdmin']?.toString();
        if (catatan != null && catatan.isNotEmpty && catatan != 'null') {
          setState(() => _alasanPenolakan = catatan);
        } else {
          setState(() => _alasanPenolakan =
              'Dokumen bukti mengajar tidak memenuhi syarat. Silakan upload ulang dengan dokumen yang valid.');
        }
      } else {
        setState(() => _alasanPenolakan =
            'Dokumen bukti mengajar tidak memenuhi syarat. Silakan upload ulang dengan dokumen yang valid.');
      }
    } catch (e) {
      setState(() => _alasanPenolakan =
          'Dokumen bukti mengajar tidak memenuhi syarat. Silakan upload ulang dengan dokumen yang valid.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionController>();

    return Scaffold(
      backgroundColor: AppColors.light,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ikon Error
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 60,
                  color: Colors.red,
                ),
              ),
              
              const SizedBox(height: 32),
              
              Text(
                'Verifikasi Ditolak',
                style: AppFonts.heading2(color: AppColors.dark),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'Maaf, bukti mengajar yang kamu kirimkan tidak dapat diverifikasi oleh tim kami.',
                style: AppFonts.bodyText(color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // Kartu Alasan Penolakan — dari Firestore
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          'Alasan Penolakan',
                          style: AppFonts.heading3(color: Colors.red.shade900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.red,
                              ),
                            ),
                          )
                        : Text(
                            '"$_alasanPenolakan"',
                            style: AppFonts.bodyText(
                                color: Colors.red.shade800,
                                weight: FontWeight.w500),
                            textAlign: TextAlign.justify,
                          ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '— Admin EPIC',
                        style: AppFonts.caption(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              ElevatedButton.icon(
                onPressed: () {
                  Get.offAllNamed(Routes.profileSetup); 
                },
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Upload Bukti Baru'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              
              const SizedBox(height: 16),
              
              TextButton.icon(
                onPressed: () => session.logout(),
                icon: const Icon(Icons.logout_rounded, color: Colors.grey),
                label: const Text('Keluar Akun', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
