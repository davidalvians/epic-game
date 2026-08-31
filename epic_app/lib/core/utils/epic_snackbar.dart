import 'package:flutter/material.dart';
import 'package:epic_app/core/utils/epic_notification.dart';

/// Notifikasi modern dengan gaya Glassmorphism Pop-Up.
/// Diarahkan langsung ke sistem [EpicNotification] untuk performa optimal dan stabilitas tinggi.
class EpicSnackbar {
  EpicSnackbar._();

  /// Notifikasi Berhasil (Pop-Up Hijau Emerald)
  static void success(
    String title,
    String message, {
    Duration duration = const Duration(seconds: 3),
    IconData icon = Icons.check_circle_rounded,
    VoidCallback? onTap,
  }) {
    EpicNotification.success(
      title,
      message,
      duration: duration,
      icon: icon,
      onTap: onTap,
    );
  }

  /// Notifikasi Gagal / Error (Pop-Up Merah Crimson)
  static void error(
    String title,
    String message, {
    Duration duration = const Duration(seconds: 4),
    IconData icon = Icons.error_rounded,
    VoidCallback? onTap,
  }) {
    EpicNotification.error(
      title,
      message,
      duration: duration,
      icon: icon,
      onTap: onTap,
    );
  }

  /// Notifikasi Informasi (Pop-Up Biru Elektrik)
  static void info(
    String title,
    String message, {
    Duration duration = const Duration(seconds: 3),
    IconData icon = Icons.info_outline_rounded,
    VoidCallback? onTap,
  }) {
    EpicNotification.info(
      title,
      message,
      duration: duration,
      icon: icon,
      onTap: onTap,
    );
  }

  /// Notifikasi Peringatan / Warning (Pop-Up Kuning Amber)
  static void warning(
    String title,
    String message, {
    Duration duration = const Duration(seconds: 3),
    IconData icon = Icons.warning_amber_rounded,
    VoidCallback? onTap,
  }) {
    EpicNotification.warning(
      title,
      message,
      duration: duration,
      icon: icon,
      onTap: onTap,
    );
  }

  /// Notifikasi Hadiah / Reward Misi / Koin Emas
  static void reward(
    String title,
    String message, {
    Duration duration = const Duration(seconds: 4),
    IconData icon = Icons.stars_rounded,
    VoidCallback? onTap,
  }) {
    EpicNotification.reward(
      title,
      message,
      duration: duration,
      icon: icon,
      onTap: onTap,
    );
  }

  /// Notifikasi Kustom
  static void custom(
    String title,
    String message, {
    required Color color,
    required IconData icon,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onTap,
  }) {
    EpicNotification.custom(
      title,
      message,
      color: color,
      icon: icon,
      duration: duration,
      onTap: onTap,
    );
  }
}
