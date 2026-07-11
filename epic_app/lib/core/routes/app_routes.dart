// Definisi semua named route dan konfigurasi halaman GetX
import 'package:get/get.dart';
import 'package:epic_app/core/middleware/auth_middleware.dart';
import 'package:epic_app/features/splash/splash_screen.dart';
import 'package:epic_app/features/onboarding/onboarding_screen.dart';
import 'package:epic_app/features/auth/auth_screen.dart';
import 'package:epic_app/features/auth/profile_setup_screen.dart';
import 'package:epic_app/features/kelas/kelas_screen.dart';
import 'package:epic_app/features/main/main_screen.dart';
import 'package:epic_app/features/auth/guru_pending_screen.dart';
import 'package:epic_app/features/auth/guru_rejected_screen.dart';
import 'package:epic_app/features/auth/suspended_screen.dart';

/// Nama-nama route untuk navigasi GetX.
class Routes {
  Routes._();

  static const String splash       = '/splash';
  static const String onboarding   = '/onboarding';
  static const String auth         = '/auth';
  static const String profileSetup = '/auth/profile-setup';
  static const String guruPending  = '/auth/guru-pending';
  static const String guruRejected = '/auth/guru-rejected';
  static const String suspended    = '/auth/suspended';
  static const String home         = '/home';
  static const String kelas        = '/kelas';
}

/// Daftar semua halaman GetX dengan transisi.
class AppRoutes {
  AppRoutes._();

  static final List<GetPage> pages = [
    GetPage(
      name: Routes.splash,
      page: () => const SplashScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.onboarding,
      page: () => const OnboardingScreen(),
      transition: Transition.rightToLeft,
    ),
    // Auth — layar login utama (Google)
    GetPage(
      name: Routes.auth,
      page: () => const AuthScreen(),
      transition: Transition.rightToLeft,
    ),
    // Profile setup (onboarding profil setelah Google Sign-In)
    GetPage(
      name: Routes.profileSetup,
      page: () => const ProfileSetupScreen(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: Routes.guruPending,
      page: () => const GuruPendingScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.guruRejected,
      page: () => const GuruRejectedScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.suspended,
      page: () => const SuspendedScreen(),
      transition: Transition.fadeIn,
    ),
    // Shell utama — dilindungi AuthMiddleware
    GetPage(
      name: Routes.home,
      page: () => const MainScreen(),
      transition: Transition.fadeIn,
      middlewares: [AuthMiddleware()],
    ),
    // Kelas — dilindungi AuthMiddleware
    GetPage(
      name: Routes.kelas,
      page: () => const KelasScreen(),
      transition: Transition.rightToLeft,
      middlewares: [AuthMiddleware()],
    ),
  ];
}
