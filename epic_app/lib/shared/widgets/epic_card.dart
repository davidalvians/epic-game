// Card custom EPIC (Rounded 20px)
import 'package:flutter/material.dart';
import 'package:epic_app/core/constants/app_sizes.dart';

/// Container kustom bergaya card dengan border radius khas EPIC.
class EpicCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final double padding;
  final VoidCallback? onTap;
  final bool hasShadow;
  final double? width;
  final double? height;

  const EpicCard({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = AppSizes.paddingL,
    this.onTap,
    this.hasShadow = true,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final Widget card = Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}
