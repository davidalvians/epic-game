// Tombol custom EPIC (Pill-shaped, animasi bounce)
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/services/audio_service.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:epic_app/core/constants/app_sizes.dart';

/// Tombol kustom utama aplikasi EPIC.
/// Memiliki efek scale (bounce) saat ditekan.
class EpicButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? color;
  final Color? textColor;
  final double? width;
  final bool isLoading;
  final IconData? icon;

  const EpicButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color,
    this.textColor,
    this.width,
    this.isLoading = false,
    this.icon,
  });

  @override
  State<EpicButton> createState() => _EpicButtonState();
}

class _EpicButtonState extends State<EpicButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (!widget.isLoading) {
      _controller.forward();
      // Mainkan efek suara tombol
      try {
        if (Get.isRegistered<AudioService>()) {
          Get.find<AudioService>().playButtonClick();
        }
      } catch (_) {}
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (!widget.isLoading) {
      _controller.reverse();
      widget.onPressed();
    }
  }

  void _onTapCancel() {
    if (!widget.isLoading) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.color ?? AppColors.primary;
    final txtColor = widget.textColor ?? Colors.white;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.width ?? double.infinity,
          height: AppSizes.buttonHeight,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppSizes.radiusRound),
            boxShadow: [
              BoxShadow(
                color: bgColor.withValues(alpha: 0.3),
                offset: const Offset(0, 4),
                blurRadius: 8,
              ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: txtColor, size: 20),
                        const SizedBox(width: AppSizes.paddingS),
                      ],
                      Text(
                        widget.text,
                        style: AppFonts.button(color: txtColor),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
