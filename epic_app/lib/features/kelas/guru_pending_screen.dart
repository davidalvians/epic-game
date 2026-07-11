import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:epic_app/core/routes/app_routes.dart';

class GuruPendingScreen extends StatelessWidget {
  const GuruPendingScreen({super.key});

  void _logout() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    Get.offAllNamed(Routes.auth);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.hourglass_top_rounded,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Akun Anda Sedang Diverifikasi',
                style: AppFonts.heading2(color: AppColors.primary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Halo Bapak/Ibu Guru!\nTerima kasih telah mendaftar di EPIC. Saat ini tim Admin kami sedang meninjau permohonan Anda. Proses ini biasanya memakan waktu maksimal 1x24 jam.\n\nHarap kembali lagi nanti untuk menggunakan fitur khusus Guru.',
                style: AppFonts.bodyText(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Keluar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
