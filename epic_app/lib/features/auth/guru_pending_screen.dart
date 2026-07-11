import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class GuruPendingScreen extends StatefulWidget {
  const GuruPendingScreen({super.key});

  @override
  State<GuruPendingScreen> createState() => _GuruPendingScreenState();
}

class _GuruPendingScreenState extends State<GuruPendingScreen> with SingleTickerProviderStateMixin {
  final _session = Get.find<SessionController>();
  bool _isRefreshing = false;
  late AnimationController _animController;
  StreamSubscription? _userSub;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Listener realtime untuk mendeteksi persetujuan dari Admin secara otomatis
    _userSub = _session.currentUser.listen((user) {
      if (user != null && mounted) {
        if (user.isGuruVerified) {
          Get.offAllNamed('/home');
        } else if (user.isGuruRejected) {
          Get.offAllNamed('/auth/guru-rejected');
        }
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _userSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    setState(() => _isRefreshing = true);
    try {
      await _session.refreshUser();
      // AuthMiddleware akan otomatis redirect jika status berubah
      if (_session.user?.isGuruVerified == true) {
        Get.offAllNamed('/home');
      } else if (_session.user?.isGuruRejected == true) {
        Get.offAllNamed('/auth/guru-rejected');
      } else {
        Get.snackbar(
          'Informasi', 
          'Status verifikasi masih dalam proses.',
          backgroundColor: Colors.blue.shade100,
          colorText: Colors.blue.shade900,
        );
      }
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _session.user;
    if (user == null) return const Scaffold();

    final dateFormatted = DateFormat('dd MMMM yyyy').format(user.createdAt);

    return Scaffold(
      backgroundColor: AppColors.light,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              
              // Animasi Loading (hourglass)
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: RotationTransition(
                      turns: _animController,
                      child: const Icon(
                        Icons.hourglass_empty_rounded,
                        size: 40,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              Text(
                'Akun Guru Sedang Diverifikasi',
                style: AppFonts.heading2(color: AppColors.dark),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'Halo, ${user.namaPanggilan}!\nBukti mengajarmu sudah kami terima dan sedang diproses oleh tim EPIC.',
                style: AppFonts.bodyText(color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // Kartu Detail Pengajuan
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.assignment_rounded, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Detail Pengajuan',
                          style: AppFonts.heading3(color: AppColors.dark),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildDetailRow('Nama', user.namaLengkap),
                    _buildDetailRow('Sekolah', user.sekolah),
                    _buildDetailRow('Dikirim', dateFormatted),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text('Status', style: AppFonts.bodySmall(color: Colors.grey[600])),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.hourglass_top_rounded, size: 16, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text('Menunggu Verifikasi', 
                                style: AppFonts.bodySmall(color: Colors.amber.shade800, weight: FontWeight.bold)
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Estimasi proses: 1x24 jam',
                            style: AppFonts.caption(color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              Text(
                'Kamu akan mendapat notifikasi email setelah akun disetujui.',
                style: AppFonts.caption(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              ElevatedButton.icon(
                onPressed: _isRefreshing ? null : _refreshStatus,
                icon: _isRefreshing 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.refresh_rounded),
                label: Text(_isRefreshing ? 'Memperbarui...' : 'Refresh Status'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              
              const SizedBox(height: 12),
              
              OutlinedButton.icon(
                onPressed: () => _launchEmail(
                  'ecoculturalpattern@gmail.com',
                  'Bantuan Verifikasi Akun Guru EPIC',
                ),
                icon: const Icon(Icons.email_outlined),
                label: const Text('Hubungi Admin'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              
              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('atau', style: TextStyle(color: Colors.grey)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),
              
              TextButton.icon(
                onPressed: () => _session.logout(),
                icon: const Icon(Icons.logout_rounded, color: Colors.red),
                label: const Text('Keluar Akun', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: AppFonts.bodySmall(color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value, style: AppFonts.bodyText(color: AppColors.dark, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail(String email, String subject, {String? body}) async {
    String? encodeQueryParameters(Map<String, String> params) {
      return params.entries
          .map((MapEntry<String, String> e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
    }

    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: encodeQueryParameters(<String, String>{
        'subject': subject,
        if (body != null) 'body': body,
      }),
    );

    try {
      final launched = await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw Exception('launchUrl returned false');
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Hubungi Admin'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tidak dapat membuka aplikasi email secara otomatis.'),
                const SizedBox(height: 12),
                const Text('Silakan hubungi kami secara manual ke alamat email berikut:'),
                const SizedBox(height: 8),
                SelectableText(
                  email,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }
}
