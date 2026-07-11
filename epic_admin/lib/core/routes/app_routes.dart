import 'package:epic_admin/features/ai_monitoring/ai_monitoring_screen.dart';
import 'package:epic_admin/features/dashboard/dashboard_screen.dart';
import 'package:epic_admin/features/kelas/kelas_list_screen.dart';
import 'package:epic_admin/features/kelas/kelas_detail_screen.dart';
import 'package:epic_admin/features/konten/instrument_form_screen.dart';
import 'package:epic_admin/features/konten/onboarding_form_screen.dart';
import 'package:epic_admin/features/konten/konten_screen.dart';
import 'package:epic_admin/features/konten/misi_form_screen.dart';
import 'package:epic_admin/features/konten/template_edit_screen.dart';
import 'package:epic_admin/features/konten/template_upload_screen.dart';
import 'package:epic_admin/features/laporan/laporan_screen.dart';
import 'package:epic_admin/features/settings/settings_screen.dart';
import 'package:epic_admin/features/users/users_screen.dart';
import 'package:epic_admin/features/users/murid_detail_screen.dart';
import 'package:epic_admin/features/users/guru_detail_screen.dart';
import 'package:epic_admin/features/verifikasi/verifikasi_list_screen.dart';
import 'package:epic_admin/features/verifikasi/verifikasi_detail_screen.dart';
import 'package:epic_admin/shared/layout/admin_layout.dart';
import 'package:epic_admin/core/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:epic_admin/features/auth/admin_login_screen.dart';

/// Notifier yang memicu GoRouter refresh saat auth state berubah.
class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        AppRoutes.clearCache();
      } else if (AppRoutes._cachedUid != user.uid) {
        AppRoutes.clearCache();
      }
      notifyListeners();
    });
  }
}

class AppRoutes {
  static final _authService = AuthService();
  static final _authNotifier = _AuthStateNotifier();

  // Cache status admin untuk menghindari pembacaan Firestore berkali-kali saat navigasi tab
  static String? _cachedUid;
  static bool? _cachedIsAdmin;

  static void clearCache() {
    _cachedUid = null;
    _cachedIsAdmin = null;
    if (kDebugMode) debugPrint('[AppRoutes] 🧹 Cache admin direset');
  }

  static final router = GoRouter(
    initialLocation: '/login',
    // Refresh router otomatis setiap kali auth state berubah (login/logout)
    refreshListenable: _authNotifier,

    /// Guard utama: dipanggil setiap navigasi dan saat auth state berubah.
    ///
    /// Logika perlindungan:
    /// 1. Belum login → wajib ke /login
    /// 2. Sudah login + di /login → redirect ke dashboard /
    /// 3. Sudah login + bukan admin → logout paksa + redirect ke /login
    redirect: (context, state) async {
      final user = FirebaseAuth.instance.currentUser;
      final isOnLoginPage = state.matchedLocation == '/login';

      // Belum login → paksa ke /login
      if (user == null) {
        clearCache();
        if (isOnLoginPage) return null;
        if (kDebugMode) debugPrint('[AppRoutes] 🔒 Belum login → redirect ke /login');
        return '/login';
      }

      // Validasi role admin dengan cache
      bool isAdmin = false;
      if (_cachedUid == user.uid && _cachedIsAdmin != null) {
        isAdmin = _cachedIsAdmin!;
        if (kDebugMode) {
          debugPrint('[AppRoutes] ⚡ Menggunakan cached admin role: $isAdmin untuk UID: ${user.uid}');
        }
      } else {
        // Validasi ke Firestore
        isAdmin = await _authService.validateAdminRole(user.uid);
        _cachedUid = user.uid;
        _cachedIsAdmin = isAdmin;
        if (kDebugMode) {
          debugPrint('[AppRoutes] 💾 Menyimpan admin role: $isAdmin untuk UID: ${user.uid} ke cache');
        }
      }

      if (!isAdmin) {
        // Sudah login tapi bukan admin → logout paksa
        if (kDebugMode) debugPrint('[AppRoutes] ❌ Bukan admin, logout → /login');
        clearCache();
        await _authService.signOut();
        return '/login';
      }

      // Sudah login sebagai admin tapi masih di /login → ke dashboard
      if (isOnLoginPage) {
        if (kDebugMode) debugPrint('[AppRoutes] ✅ Admin terverifikasi → redirect ke /');
        return '/';
      }

      // Akses diizinkan
      return null;
    },

    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AdminLayout(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => const UsersScreen(),
            routes: [
              GoRoute(
                path: 'murid/:id',
                builder: (context, state) => MuridDetailScreen(id: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'guru/:id',
                builder: (context, state) => GuruDetailScreen(id: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/verifikasi',
            builder: (context, state) => const VerifikasiListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => VerifikasiDetailScreen(id: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/kelas',
            builder: (context, state) => const KelasListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => KelasDetailScreen(id: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/ai-monitoring',
            builder: (context, state) => const AiMonitoringScreen(),
          ),
          GoRoute(
            path: '/konten',
            builder: (context, state) {
              final tabStr = state.uri.queryParameters['tab'];
              final initialTab = tabStr != null ? int.tryParse(tabStr) ?? 0 : 0;
              return KontenScreen(initialTab: initialTab);
            },
            routes: [
              GoRoute(
                path: 'instrumen/:id',
                builder: (context, state) => InstrumentFormScreen(id: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'onboarding/:id',
                builder: (context, state) => OnboardingFormScreen(id: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'template/edit/:id',
                builder: (context, state) => TemplateEditScreen(id: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'template/upload',
                builder: (context, state) => const TemplateUploadScreen(),
              ),
              GoRoute(
                path: 'misi/tambah',
                builder: (context, state) => const MisiFormScreen(),
              ),
              GoRoute(
                path: 'misi/edit/:id',
                builder: (context, state) => MisiFormScreen(id: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/laporan',
            builder: (context, state) => const LaporanScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
}
