import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/features/main/main_controller.dart';
import 'package:epic_app/features/home/home_tab.dart';
import 'package:epic_app/features/home/guru_home_tab.dart';
import 'package:epic_app/features/ranking/ranking_screen.dart';
import 'package:epic_app/features/galeri/galeri_tab.dart';
import 'package:epic_app/features/karakter_toko/karakter_tab.dart';
import 'package:epic_app/features/profile/profile_screen.dart';
import 'package:epic_app/shared/controllers/session_controller.dart' as epic_session;
import 'package:epic_app/features/kelas/guru_dashboard_screen.dart';
import 'package:epic_app/features/murid/guru_murid_tab.dart';
import 'package:epic_app/features/auth/guru_pending_screen.dart';
import 'package:epic_app/features/auth/guru_rejected_screen.dart';

/// Shell utama aplikasi EPIC.
/// Menggunakan PageView untuk transisi pemindahan halaman yang mulus.
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final MainController ctrl = Get.put(MainController());
    final session = Get.find<epic_session.SessionController>();

    return Scaffold(
      extendBody: true, // Memungkinkan konten discroll di bawah bar navigasi kaca melayang
      body: Obx(() {
        final isGuru = session.isGuru;
        final isGuruPending = session.isGuruPending;
        final isGuruRejected = session.isGuruRejected;

        if (isGuruPending) {
          return const GuruPendingScreen();
        }

        if (isGuruRejected) {
          return const GuruRejectedScreen();
        }

        return PageView(
          controller: ctrl.pageController,
          physics: const NeverScrollableScrollPhysics(), // Nonaktifkan geser agar tidak bentrok dengan slider horizontal
          children: isGuru
              ? [
                  const GuruHomeTab(),          // 0 - Home Guru (Ringkasan)
                  GuruDashboardScreen(),        // 1 - Kelas (Manajemen Kelas)
                  const GuruMuridTab(),         // 2 - Murid
                  const ProfileScreen(),        // 3 - Profil
                ]
              : const [
                  HomeTab(),                    // 0 - Beranda
                  RankingScreen(),              // 1 - Peringkat
                  GaleriTab(),                  // 2 - Galeri
                  KarakterTab(),                // 3 - Avatar
                  ProfileScreen(),              // 4 - Profil
                ],
        );
      }),
      bottomNavigationBar: Obx(() => (session.isGuruPending || session.isGuruRejected)
          ? const SizedBox.shrink()
          : _buildBottomNav(ctrl, context, session)),
    );
  }

  Widget _buildBottomNav(
    MainController ctrl,
    BuildContext context,
    epic_session.SessionController session,
  ) {
    return Obx(() {
      final isGuru = session.isGuru;
      final bottomPadding = MediaQuery.of(context).padding.bottom;

      return Container(
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: bottomPadding > 0 ? bottomPadding : 12,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.55),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: isGuru
                      ? [
                          _buildNavItem(ctrl, 0, Icons.home_rounded, Icons.home_outlined, 'Home'),
                          _buildNavItem(ctrl, 1, Icons.class_rounded, Icons.class_outlined, 'Kelas'),
                          _buildNavItem(ctrl, 2, Icons.people_rounded, Icons.people_outline_rounded, 'Murid'),
                          _buildNavItem(ctrl, 3, Icons.person_rounded, Icons.person_outline_rounded, 'Profil'),
                        ]
                      : [
                          _buildNavItem(ctrl, 0, Icons.home_rounded, Icons.home_outlined, 'Home'),
                          _buildNavItem(ctrl, 1, Icons.emoji_events_rounded, Icons.emoji_events_outlined, 'Ranking'),
                          _buildNavItem(ctrl, 2, Icons.photo_library_rounded, Icons.photo_library_outlined, 'Galeri'),
                          _buildNavItem(ctrl, 3, Icons.face_retouching_natural_rounded, Icons.face_rounded, 'Avatar'),
                          _buildNavItem(ctrl, 4, Icons.person_rounded, Icons.person_outline_rounded, 'Profil'),
                        ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildNavItem(
    MainController ctrl,
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
  ) {
    return Obx(() {
      final isActive = ctrl.currentIndex.value == index;
      return GestureDetector(
        onTap: () => ctrl.changeTab(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isActive ? 18 : 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 300),
                scale: isActive ? 1.06 : 0.95,
                curve: Curves.easeOutBack,
                child: Icon(
                  isActive ? activeIcon : inactiveIcon,
                  color: isActive ? AppColors.primary : AppColors.inactive,
                  size: 24,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'FredokaOne',
                  fontSize: isActive ? 10.5 : 9.5,
                  color: isActive ? AppColors.primary : AppColors.inactive,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: isActive ? 1.0 : 0.0,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
