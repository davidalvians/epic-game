// Middleware untuk melindungi route yang memerlukan autentikasi
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/routes/app_routes.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';

/// Middleware yang memastikan user sudah login DAN profil lengkap
/// sebelum mengakses halaman tertentu.
class AuthMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    // Cek apakah SessionController sudah ada
    try {
      final session = Get.find<SessionController>();

      // Jika masih loading (app baru dibuka), tunggu sebentar
      if (session.isLoading.value) return null;

      // Jika belum login, redirect ke onboarding
      if (!session.isLoggedIn) {
        return const RouteSettings(name: Routes.onboarding);
      }

      // Cek apakah akun ditangguhkan (suspended)
      if (session.user != null && (session.user!.status == 'suspended' || !session.user!.isActive)) {
        return const RouteSettings(name: Routes.suspended);
      }

      // Jika sudah login tapi profil belum lengkap, redirect ke profile setup
      if (!session.isProfileComplete) {
        return const RouteSettings(name: Routes.profileSetup);
      }

      // Khusus Guru: cek status verifikasi
      if (session.user != null && session.user!.isGuru) {
        if (session.user!.isGuruPending) {
          return const RouteSettings(name: Routes.guruPending);
        }
        if (session.user!.isGuruRejected) {
          return const RouteSettings(name: Routes.guruRejected);
        }
      }
    } catch (_) {
      // SessionController belum ada = belum login
      return const RouteSettings(name: Routes.onboarding);
    }

    // Sudah login dan profil lengkap, izinkan akses
    return null;
  }
}
