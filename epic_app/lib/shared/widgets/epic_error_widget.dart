// Tampilan error custom
import 'package:flutter/material.dart';
import 'package:epic_app/core/constants/app_assets.dart';
import 'package:epic_app/core/constants/app_strings.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:epic_app/core/constants/app_sizes.dart';
import 'package:epic_app/shared/widgets/epic_button.dart';

/// Tampilan standar saat terjadi error.
class EpicErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const EpicErrorWidget({
    super.key,
    this.message = AppStrings.errorGeneral,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingXXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Placeholder untuk ilustrasi Epi Sedih
            Image.asset(
              AppAssets.epiBody,
              height: 120,
            ),
            const SizedBox(height: AppSizes.paddingXL),
            Text(
              message,
              style: AppFonts.bodyText(),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSizes.paddingXL),
              EpicButton(
                text: AppStrings.retry,
                onPressed: onRetry!,
                width: 150,
              ),
            ]
          ],
        ),
      ),
    );
  }
}
