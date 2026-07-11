// Overlay gembok untuk game terkunci
import 'package:flutter/material.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:epic_app/core/constants/app_sizes.dart';
import 'package:epic_app/core/constants/app_strings.dart';

/// Overlay semi-transparan dengan ikon gembok untuk game/fitur yang terkunci.
class LockedOverlay extends StatelessWidget {
  const LockedOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.overlayDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_rounded,
              color: Colors.white,
              size: AppSizes.iconXL,
            ),
            const SizedBox(height: AppSizes.paddingS),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingM,
                vertical: AppSizes.paddingXS,
              ),
              decoration: BoxDecoration(
                color: AppColors.dark,
                borderRadius: BorderRadius.circular(AppSizes.radiusRound),
              ),
              child: Text(
                AppStrings.noGamesYet,
                style: AppFonts.badge(color: AppColors.inactive),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
