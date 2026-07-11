import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';

/// Notifikasi modern dengan gaya Glassmorphism
class EpicSnackbar {
  static void success(String title, String message) {
    _show(
      title: title,
      message: message,
      color: AppColors.success,
      icon: Icons.check_circle_rounded,
    );
  }

  static void error(String title, String message) {
    _show(
      title: title,
      message: message,
      color: AppColors.error,
      icon: Icons.error_rounded,
    );
  }

  static void info(String title, String message) {
    _show(
      title: title,
      message: message,
      color: AppColors.secondary,
      icon: Icons.info_rounded,
    );
  }

  static void _show({
    required String title,
    required String message,
    required Color color,
    required IconData icon,
  }) {
    // Tutup snackbar yang sedang aktif jika ada
    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }

    Get.snackbar(
      '',
      '',
      titleText: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.heading3(color: AppColors.textOnDark).copyWith(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: AppFonts.bodyText(color: Colors.white70).copyWith(fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      messageText: const SizedBox.shrink(),
      backgroundColor: AppColors.dark.withValues(alpha: 0.85),
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 20,
      barBlur: 10, // Efek Glassmorphism
      isDismissible: true,
      forwardAnimationCurve: Curves.easeOutCirc,
      reverseAnimationCurve: Curves.easeInCirc,
      duration: const Duration(seconds: 3),
      boxShadows: [
        BoxShadow(
          color: color.withValues(alpha: 0.2),
          blurRadius: 15,
          spreadRadius: 2,
          offset: const Offset(0, 5),
        ),
      ],
      borderWidth: 1,
      borderColor: color.withValues(alpha: 0.3),
    );
  }
}
