import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';

/// Jenis notifikasi popup EPIC
enum EpicNotificationType {
  success,
  error,
  warning,
  info,
  reward,
  custom,
}

/// Sistem Notifikasi Pop-Up Modern & Terpadu untuk Aplikasi EPIC.
/// Menampilkan floating card/capsule di bagian atas layar dengan animasi halus,
/// glassmorphism premium, haptic feedback, dan gestur swipe-to-dismiss.
class EpicNotification {
  EpicNotification._();

  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;
  static _EpicNotificationState? _activeState;

  // ─── Public API ─────────────────────────────────────────────────────────────

  /// Notifikasi Sukses (Warna Hijau Emerald dengan getaran haptic ringan)
  static void success(
    String title,
    String message, {
    Duration duration = const Duration(seconds: 3),
    IconData icon = Icons.check_circle_rounded,
    VoidCallback? onTap,
  }) {
    show(
      title: title,
      message: message,
      type: EpicNotificationType.success,
      icon: icon,
      duration: duration,
      onTap: onTap,
    );
  }

  /// Notifikasi Error / Kegagalan (Warna Merah Crimson dengan getaran haptic medium)
  static void error(
    String title,
    String message, {
    Duration duration = const Duration(seconds: 4),
    IconData icon = Icons.error_rounded,
    VoidCallback? onTap,
  }) {
    show(
      title: title,
      message: message,
      type: EpicNotificationType.error,
      icon: icon,
      duration: duration,
      onTap: onTap,
    );
  }

  /// Notifikasi Peringatan / Warning (Warna Oranye Amber)
  static void warning(
    String title,
    String message, {
    Duration duration = const Duration(seconds: 3),
    IconData icon = Icons.warning_amber_rounded,
    VoidCallback? onTap,
  }) {
    show(
      title: title,
      message: message,
      type: EpicNotificationType.warning,
      icon: icon,
      duration: duration,
      onTap: onTap,
    );
  }

  /// Notifikasi Informasi (Warna Biru Elektrik)
  static void info(
    String title,
    String message, {
    Duration duration = const Duration(seconds: 3),
    IconData icon = Icons.info_outline_rounded,
    VoidCallback? onTap,
  }) {
    show(
      title: title,
      message: message,
      type: EpicNotificationType.info,
      icon: icon,
      duration: duration,
      onTap: onTap,
    );
  }

  /// Notifikasi Hadiah / Reward / Poin (Warna Emas Arcade dengan bintang)
  static void reward(
    String title,
    String message, {
    Duration duration = const Duration(seconds: 4),
    IconData icon = Icons.stars_rounded,
    VoidCallback? onTap,
  }) {
    show(
      title: title,
      message: message,
      type: EpicNotificationType.reward,
      icon: icon,
      duration: duration,
      onTap: onTap,
    );
  }

  /// Notifikasi Custom dengan warna dan icon pilihan
  static void custom(
    String title,
    String message, {
    required Color color,
    required IconData icon,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onTap,
  }) {
    show(
      title: title,
      message: message,
      type: EpicNotificationType.custom,
      customColor: color,
      icon: icon,
      duration: duration,
      onTap: onTap,
    );
  }

  /// Menampilkan Pop-Up Notifikasi secara instan
  static void show({
    required String title,
    required String message,
    EpicNotificationType type = EpicNotificationType.info,
    Color? customColor,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onTap,
  }) {
    // Jalankan haptic feedback yang sesuai
    _triggerHaptic(type);

    // Dapatkan context overlay yang valid
    final overlayState = _getOverlayState();
    if (overlayState == null) {
      // Fallback post frame callback jika context belum siap saat startup/navigasi
      WidgetsBinding.instance.addPostFrameCallback((_) {
        show(
          title: title,
          message: message,
          type: type,
          customColor: customColor,
          icon: icon,
          duration: duration,
          onTap: onTap,
        );
      });
      return;
    }

    // Bersihkan notifikasi sebelumnya jika masih ada
    _dismissCurrent(immediate: true);

    final resolvedColor = customColor ?? _getThemeColor(type);
    final resolvedIcon = icon ?? _getDefaultIcon(type);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _EpicNotificationWidget(
        title: title,
        message: message,
        color: resolvedColor,
        icon: resolvedIcon,
        duration: duration,
        type: type,
        onTap: onTap,
        onDismiss: () => _dismissCurrent(),
        onReady: (state) => _activeState = state,
      ),
    );

    _currentEntry = entry;
    try {
      overlayState.insert(entry);
    } catch (e) {
      debugPrint('⚠️ Gagal insert overlay notifikasi: $e');
    }
  }

  /// Menutup notifikasi yang sedang aktif
  static void dismiss() {
    _dismissCurrent();
  }

  // ─── Helper Internal ────────────────────────────────────────────────────────

  static OverlayState? _getOverlayState() {
    try {
      if (Get.key.currentState?.overlay != null) {
        return Get.key.currentState!.overlay;
      }
      if (Get.overlayContext != null) {
        return Overlay.of(Get.overlayContext!);
      }
      if (Get.context != null) {
        return Overlay.of(Get.context!);
      }
    } catch (_) {}
    return null;
  }

  static void _dismissCurrent({bool immediate = false}) {
    _dismissTimer?.cancel();
    _dismissTimer = null;

    if (_currentEntry == null) return;

    if (immediate || _activeState == null) {
      _removeEntrySafely(_currentEntry);
      _currentEntry = null;
      _activeState = null;
    } else {
      _activeState?.animateOut().then((_) {
        _removeEntrySafely(_currentEntry);
        _currentEntry = null;
        _activeState = null;
      });
    }
  }

  static void _removeEntrySafely(OverlayEntry? entry) {
    if (entry == null) return;
    try {
      if (entry.mounted) {
        entry.remove();
      }
    } catch (_) {}
  }

  static Color _getThemeColor(EpicNotificationType type) {
    switch (type) {
      case EpicNotificationType.success:
        return const Color(0xFF10B981); // Emerald Green
      case EpicNotificationType.error:
        return const Color(0xFFEF4444); // Crimson Red
      case EpicNotificationType.warning:
        return const Color(0xFFF59E0B); // Amber Orange
      case EpicNotificationType.info:
        return const Color(0xFF0EA5E9); // Sky/Ocean Blue
      case EpicNotificationType.reward:
        return const Color(0xFFF59E0B); // Arcade Gold
      case EpicNotificationType.custom:
        return AppColors.primary;
    }
  }

  static IconData _getDefaultIcon(EpicNotificationType type) {
    switch (type) {
      case EpicNotificationType.success:
        return Icons.check_circle_rounded;
      case EpicNotificationType.error:
        return Icons.error_rounded;
      case EpicNotificationType.warning:
        return Icons.warning_amber_rounded;
      case EpicNotificationType.info:
        return Icons.info_outline_rounded;
      case EpicNotificationType.reward:
        return Icons.stars_rounded;
      case EpicNotificationType.custom:
        return Icons.notifications_rounded;
    }
  }

  static void _triggerHaptic(EpicNotificationType type) {
    try {
      switch (type) {
        case EpicNotificationType.success:
        case EpicNotificationType.reward:
          HapticFeedback.lightImpact();
          break;
        case EpicNotificationType.error:
          HapticFeedback.mediumImpact();
          break;
        case EpicNotificationType.warning:
        case EpicNotificationType.info:
        case EpicNotificationType.custom:
          HapticFeedback.selectionClick();
          break;
      }
    } catch (_) {}
  }
}

// ─── Widget Notifikasi Pop-Up Modern ──────────────────────────────────────────

abstract class _EpicNotificationState {
  Future<void> animateOut();
}

class _EpicNotificationWidget extends StatefulWidget {
  final String title;
  final String message;
  final Color color;
  final IconData icon;
  final Duration duration;
  final EpicNotificationType type;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;
  final void Function(_EpicNotificationState state) onReady;

  const _EpicNotificationWidget({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
    required this.duration,
    required this.type,
    this.onTap,
    required this.onDismiss,
    required this.onReady,
  });

  @override
  State<_EpicNotificationWidget> createState() => _EpicNotificationWidgetState();
}

class _EpicNotificationWidgetState extends State<_EpicNotificationWidget>
    with SingleTickerProviderStateMixin
    implements _EpicNotificationState {
  late AnimationController _animController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _autoDismissTimer;
  double _dragOffsetY = 0.0;

  @override
  void initState() {
    super.initState();
    widget.onReady(this);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _slideAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ),
    );

    _animController.forward();

    _startAutoDismissTimer();
  }

  void _startAutoDismissTimer() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(widget.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  @override
  Future<void> animateOut() async {
    _autoDismissTimer?.cancel();
    if (mounted) {
      await _animController.reverse();
    }
  }

  void _dismiss() {
    _autoDismissTimer?.cancel();
    if (mounted) {
      _animController.reverse().then((_) {
        if (mounted) {
          widget.onDismiss();
        }
      });
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final accentColor = widget.color;

    return Positioned(
      top: topPadding + 10 + _dragOffsetY,
      left: 16,
      right: 16,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, (1 - _slideAnimation.value) * -60),
                child: Opacity(
                  opacity: _fadeAnimation.value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  ),
                ),
              );
            },
            child: GestureDetector(
              onTap: () {
                if (widget.onTap != null) {
                  widget.onTap!();
                }
                _dismiss();
              },
              onVerticalDragUpdate: (details) {
                if (details.primaryDelta != null && details.primaryDelta! < 0) {
                  setState(() {
                    _dragOffsetY += details.primaryDelta!;
                  });
                }
              },
              onVerticalDragEnd: (details) {
                if (_dragOffsetY < -20 || (details.primaryVelocity != null && details.primaryVelocity! < -300)) {
                  _dismiss();
                } else {
                  setState(() {
                    _dragOffsetY = 0.0;
                  });
                }
              },
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      // Ambient dark shadow
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 20,
                        spreadRadius: 0,
                        offset: const Offset(0, 8),
                      ),
                      // Colored neon ambient glow
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.22),
                        blurRadius: 18,
                        spreadRadius: -2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        decoration: BoxDecoration(
                          // Luxury frosted dark slate gradient
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF1E2235).withValues(alpha: 0.94),
                              const Color(0xFF111422).withValues(alpha: 0.96),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.45),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Left Icon Badge with glowing background
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          accentColor.withValues(alpha: 0.35),
                                          accentColor.withValues(alpha: 0.12),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: accentColor.withValues(alpha: 0.5),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Icon(
                                      widget.icon,
                                      color: accentColor,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Title & Message Column
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          widget.title,
                                          style: AppFonts.heading4(color: Colors.white).copyWith(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          widget.message,
                                          style: AppFonts.bodyText(
                                            color: Colors.white.withValues(alpha: 0.88),
                                          ).copyWith(
                                            fontSize: 13,
                                            height: 1.3,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Close button
                                  GestureDetector(
                                    onTap: _dismiss,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                        color: Colors.white.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Micro Progress Indicator Line at bottom
                            _ProgressBar(
                              duration: widget.duration,
                              color: accentColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Progress bar tipis di bagian bawah notifikasi yang menyusut sesuai durasi
class _ProgressBar extends StatefulWidget {
  final Duration duration;
  final Color color;

  const _ProgressBar({
    required this.duration,
    required this.color,
  });

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..reverse(from: 1.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(22),
            bottomRight: Radius.circular(22),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: _controller.value,
              child: Container(
                height: 2.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.color.withValues(alpha: 0.7),
                      widget.color,
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
