// Loading custom animasi
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_assets.dart';

/// Widget loading standar untuk aplikasi EPIC.
/// Menggunakan animasi Lottie jika tersedia, fallback ke CircularProgressIndicator.
class LoadingWidget extends StatelessWidget {
  final double size;
  final bool fullScreen;

  const LoadingWidget({
    super.key,
    this.size = 100.0,
    this.fullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget loader;
    
    try {
      loader = Lottie.asset(
        AppAssets.animLoading,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback jika file lottie gagal dimuat
          return const _FallbackLoader();
        },
      );
    } catch (e) {
      loader = const _FallbackLoader();
    }

    if (fullScreen) {
      return Center(
        child: Container(
          color: AppColors.light.withValues(alpha: 0.8),
          alignment: Alignment.center,
          child: loader,
        ),
      );
    }

    return Center(child: loader);
  }
}

class _FallbackLoader extends StatelessWidget {
  const _FallbackLoader();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 40,
      height: 40,
      child: CircularProgressIndicator(
        color: AppColors.primary,
        strokeWidth: 4,
      ),
    );
  }
}
