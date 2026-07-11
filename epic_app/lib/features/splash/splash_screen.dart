import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_strings.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:epic_app/core/constants/app_assets.dart';
import 'package:epic_app/core/routes/app_routes.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  final SessionController _sessionController = Get.find<SessionController>();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _animationController.forward();

    // Tunggu 2.5 detik lalu navigasi
    Future.delayed(const Duration(milliseconds: 2500), _navigateToNext);
  }

  void _navigateToNext() async {
    // ROOT-FIX-1: Tunggu SessionController selesai loading.
    // Timeout dinaikkan ke 12 detik (safety timeout di SessionController = 10 detik).
    // Sebelumnya 5 detik — terlalu pendek jika Firestore server lambat merespons.
    int waited = 0;
    while (_sessionController.isLoading.value && waited < 120) {
      await Future.delayed(const Duration(milliseconds: 100));
      waited++;
    }

    if (_sessionController.isLoggedIn) {
      if (_sessionController.isProfileComplete) {
        Get.offAllNamed(Routes.home);
      } else {
        // Profil belum lengkap — ke profile setup
        Get.offAllNamed(Routes.profileSetup);
      }
    } else {
      // ROOT-FIX (Safety Net): Cek Firebase Auth secara langsung.
      // Jika Firebase Auth masih punya token tapi Firestore gagal dimuat,
      // arahkan ke auth screen (BUKAN onboarding) sehingga:
      // 1. User tidak melihat layar "selamat datang" (onboarding) lagi
      // 2. User bisa tap "Masuk" untuk retry — silent sign-in akan mencoba
      //    otomatis tanpa menampilkan Google account picker
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        debugPrint('⚠️ Splash: Firebase Auth masih ada user tapi Firestore gagal. Arahkan ke auth screen (bukan onboarding).');
        Get.offAllNamed(Routes.auth);
      } else {
        Get.offAllNamed(Routes.onboarding);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: Stack(
        children: [
          // Background batik bisa diletakkan di sini (opsional)
          
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      AppAssets.epicLogo,
                      width: 200,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  AppStrings.tagline,
                  style: AppFonts.heading4(color: AppColors.secondary),
                ),
              ],
            ),
          ),
          
          // Progress bar di bawah
          Positioned(
            bottom: 40,
            left: 50,
            right: 50,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                minHeight: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
