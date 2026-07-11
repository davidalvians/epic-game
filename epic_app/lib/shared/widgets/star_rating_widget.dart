// Widget bintang rating animasi
import 'package:flutter/material.dart';
import 'package:epic_app/core/constants/app_colors.dart';

/// Menampilkan 1-3 bintang untuk reward.
/// Bisa dianimasikan muncul satu persatu.
class StarRatingWidget extends StatelessWidget {
  final int rating; // 1-3
  final double size;
  final bool animate;

  const StarRatingWidget({
    super.key,
    required this.rating,
    this.size = 32.0,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isFilled = index < rating;
        
        Widget star = Icon(
          isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
          color: isFilled ? AppColors.secondary : AppColors.inactive,
          size: isFilled && index == 1 ? size * 1.2 : size, // Bintang tengah lebih besar
        );

        if (animate && isFilled) {
          // Animasi scale sederhana jika dibutuhkan
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 300 + (index * 200)),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: child,
              );
            },
            child: star,
          );
        }

        return star;
      }),
    );
  }
}
