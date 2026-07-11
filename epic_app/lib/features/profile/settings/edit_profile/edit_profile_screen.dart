import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:epic_app/core/constants/app_sizes.dart';
import 'package:epic_app/shared/widgets/epic_button.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'edit_profile_controller.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EditProfileController());

    return Scaffold(
      backgroundColor: AppColors.light,
      appBar: AppBar(
        title: Text('Edit Profil', style: AppFonts.heading3(color: AppColors.dark)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.dark),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSizes.paddingL),
            Center(
              child: Obx(() {
                final user = Get.find<SessionController>().user;
                final avatarUrl = user?.avatarUrl ?? '';
                return Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 3),
                    color: AppColors.sky,
                  ),
                  child: ClipOval(
                    child: avatarUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: avatarUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                            errorWidget: (context, url, error) => const Icon(Icons.person_rounded, color: AppColors.primary, size: 60),
                          )
                        : const Icon(Icons.person_rounded, color: AppColors.primary, size: 60),
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSizes.paddingXL),
            Text('Nama Lengkap', style: AppFonts.bodyText(weight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: controller.nameController,
              decoration: const InputDecoration(
                hintText: 'Masukkan nama lengkap',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),
            Text('Nama Panggilan', style: AppFonts.bodyText(weight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: controller.nicknameController,
              decoration: const InputDecoration(
                hintText: 'Masukkan nama panggilan',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: AppSizes.paddingXL),
            Obx(() => EpicButton(
              text: 'Simpan Perubahan',
              isLoading: controller.isLoading.value,
              onPressed: controller.saveProfile,
            )),
          ],
        ),
      ),
    );
  }
}
