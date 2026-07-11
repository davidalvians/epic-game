// Progress bar XP animasi
import 'package:flutter/material.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_sizes.dart';

/// Progress bar untuk menampilkan XP.
/// Memiliki animasi transisi saat nilai berubah.
class XpBarWidget extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final Color backgroundColor;
  final Color fillColor;
  final double height;

  const XpBarWidget({
    super.key,
    required this.progress,
    this.backgroundColor = AppColors.border,
    this.fillColor = AppColors.primary,
    this.height = AppSizes.xpBarHeight,
  });

  @override
  Widget build(BuildContext context) {
    // Pastikan progress berada di antara 0.0 - 1.0
    final validProgress = progress.clamp(0.0, 1.0);

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppSizes.xpBarRadius),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                width: constraints.maxWidth * validProgress,
                height: height,
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(AppSizes.xpBarRadius),
                  gradient: LinearGradient(
                    colors: [
                      fillColor,
                      AppColors.secondary,
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
