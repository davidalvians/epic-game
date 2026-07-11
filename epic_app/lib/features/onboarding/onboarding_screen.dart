import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:epic_app/core/constants/app_strings.dart';
import 'package:epic_app/core/constants/app_sizes.dart';
import 'package:epic_app/core/constants/app_assets.dart';
import 'package:epic_app/features/onboarding/onboarding_controller.dart';
import 'package:epic_app/shared/widgets/epic_button.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(OnboardingController());

    return Scaffold(
      body: Obx(() {
        final currentPage = controller.currentPage.value;
        return Stack(
          children: [
            // 1. Latar Belakang Gradient Dinamis
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _getBackgroundColors(currentPage),
                ),
              ),
            ),

            // 2. Dekorasi Geometris Abstrak (Glassmorphism / Lingkaran)
            Positioned(
              top: -50,
              right: -50,
              child: _buildDecorativeCircle(200, Colors.white.withValues(alpha: 0.1)),
            ),
            Positioned(
              bottom: 100,
              left: -80,
              child: _buildDecorativeCircle(250, Colors.white.withValues(alpha: 0.15)),
            ),

            // 3. Konten Utama
            SafeArea(
              child: Column(
                children: [
                  // Header (Lewati)
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16.0, top: 16.0),
                      child: InkWell(
                        onTap: controller.skip,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppStrings.skip,
                                style: AppFonts.bodyText(
                                  color: Colors.white,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // PageView Konten
                  Expanded(
                    child: PageView(
                      controller: controller.pageController,
                      onPageChanged: controller.onPageChanged,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildPage(
                          image: AppAssets.onboard1,
                          title: AppStrings.onboard1Title,
                          subtitle: AppStrings.onboard1Sub,
                        ),
                        _buildPage(
                          image: AppAssets.onboard2,
                          title: AppStrings.onboard2Title,
                          subtitle: AppStrings.onboard2Sub,
                        ),
                        _buildPage(
                          image: AppAssets.onboard3,
                          title: AppStrings.onboard3Title,
                          subtitle: AppStrings.onboard3Sub,
                        ),
                      ],
                    ),
                  ),

                  // Footer (Dot indicator + Button)
                  Padding(
                    padding: const EdgeInsets.all(AppSizes.paddingXL),
                    child: Column(
                      children: [
                        // Indicators
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            3,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 10,
                              width: currentPage == index ? 30 : 10,
                              decoration: BoxDecoration(
                                color: currentPage == index
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSizes.paddingXXL),

                        // Tombol Lanjut/Mulai
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: EpicButton(
                            key: ValueKey<bool>(controller.isLastPage.value),
                            text: controller.isLastPage.value
                                ? AppStrings.start
                                : AppStrings.next,
                            onPressed: controller.nextPage,
                            color: Colors.white,
                            textColor: AppColors.primary,
                            width: double.infinity,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  /// Menghasilkan palet warna gradient berdasarkan halaman aktif
  List<Color> _getBackgroundColors(int pageIndex) {
    switch (pageIndex) {
      case 0:
        return [const Color(0xFF6A11CB), const Color(0xFF2575FC)]; // Ungu - Biru
      case 1:
        return [const Color(0xFFFF8008), const Color(0xFFFFC837)]; // Oranye Hangat
      case 2:
        return [const Color(0xFF11998E), const Color(0xFF38EF7D)]; // Hijau Teal
      default:
        return [AppColors.primary, AppColors.secondary];
    }
  }

  /// Membuat lingkaran dekoratif berukuran custom
  Widget _buildDecorativeCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  /// Membangun isi dari satu slide Onboarding
  Widget _buildPage({
    String? image,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.paddingXL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Gambar / Animasi
          Expanded(
            flex: 6,
            child: Center(
              child: Image.asset(
                image ?? AppAssets.onboard1,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.image,
                  size: 150,
                  color: Colors.white54,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.paddingXL),
          
          // Teks Judul dan Subjudul
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppFonts.heading2(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSizes.paddingM),
                  Text(
                    subtitle,
                    style: AppFonts.bodyText(color: Colors.white.withValues(alpha: 0.9)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
