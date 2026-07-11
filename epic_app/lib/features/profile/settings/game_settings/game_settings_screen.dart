import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:epic_app/core/constants/app_sizes.dart';
import 'game_settings_controller.dart';

class GameSettingsScreen extends StatelessWidget {
  const GameSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(GameSettingsController());

    return Scaffold(
      backgroundColor: AppColors.light,
      appBar: AppBar(
        title: Text('Pengaturan Game', style: AppFonts.heading3(color: AppColors.dark)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.dark),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Obx(() => SwitchListTile(
                    activeThumbColor: AppColors.primary,
                    title: const Text('Efek Suara (SFX)', style: TextStyle(fontFamily: 'FredokaOne')),
                    subtitle: const Text('Suara tombol dan animasi', style: TextStyle(fontFamily: 'Nunito', fontSize: 12)),
                    value: controller.isSoundEnabled.value,
                    onChanged: controller.toggleSound,
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.volume_up_rounded, color: AppColors.primary),
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
