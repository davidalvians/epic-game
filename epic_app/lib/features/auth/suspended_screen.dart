import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class SuspendedScreen extends StatefulWidget {
  const SuspendedScreen({super.key});

  @override
  State<SuspendedScreen> createState() => _SuspendedScreenState();
}

class _SuspendedScreenState extends State<SuspendedScreen> with SingleTickerProviderStateMixin {
  final _session = Get.find<SessionController>();
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _session.user;
    final String name = user?.namaPanggilan ?? 'Pengguna';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.light,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                
                // Animated Glowing Lock Icon
                Center(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.lock_person_rounded,
                          size: 52,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                Text(
                  'Akses Akun Ditangguhkan',
                  style: AppFonts.heading2(color: AppColors.dark),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 20),
                
                Text(
                  'Halo, $name.\nAkun Anda telah ditangguhkan oleh Administrator karena melanggar pedoman komunitas atau aktivitas yang mencurigakan.',
                  style: AppFonts.bodyText(color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 24),
                
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.gavel_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Status Akun: Suspended',
                            style: AppFonts.bodyText(color: AppColors.primary, weight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Anda tidak dapat masuk ke dashboard atau menggunakan fitur aplikasi EPIC selama masa penangguhan ini aktif.',
                        style: AppFonts.caption(color: Colors.red.shade800),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 48),
                
                ElevatedButton.icon(
                  onPressed: () => _launchEmail(
                    'ecoculturalpattern@gmail.com',
                    'Banding Penangguhan Akun EPIC - $name',
                    body: 'Halo Admin EPIC,\n\nSaya ingin menanyakan perihal penangguhan akun saya:\nNama Lengkap: ${user?.namaLengkap ?? "-"}\nEmail: ${user?.email ?? "-"}\n\n[Tuliskan penjelasan Anda di sini]\n',
                  ),
                  icon: const Icon(Icons.support_agent_rounded),
                  label: const Text('Hubungi Dukungan / Banding'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                OutlinedButton.icon(
                  onPressed: () => _session.logout(),
                  icon: const Icon(Icons.logout_rounded, color: Colors.red),
                  label: const Text('Keluar Akun', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        ),
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
            title: const Text('Hubungi Dukungan'),
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
