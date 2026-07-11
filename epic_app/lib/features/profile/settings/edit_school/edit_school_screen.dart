import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:epic_app/core/constants/app_sizes.dart';
import 'package:epic_app/shared/widgets/epic_button.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'edit_school_controller.dart';

class EditSchoolScreen extends StatelessWidget {
  const EditSchoolScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EditSchoolController());
    final session = Get.find<SessionController>();
    final user = session.user;

    return Scaffold(
      backgroundColor: AppColors.light,
      appBar: AppBar(
        title: Text('Data Sekolah', style: AppFonts.heading3(color: AppColors.dark)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.dark),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSizes.paddingS),
            Text('Nama Sekolah', style: AppFonts.bodyText(weight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: controller.schoolController,
              decoration: const InputDecoration(
                hintText: 'Masukkan nama sekolah',
                prefixIcon: Icon(Icons.school_outlined),
              ),
            ),
            if (user != null && user.isMurid) ...[
              const SizedBox(height: AppSizes.paddingM),
              Text('Kelas', style: AppFonts.bodyText(weight: FontWeight.bold)),
              const SizedBox(height: 8),
              Obx(() => DropdownButtonFormField<String>(
                initialValue: controller.selectedKelas.value.isEmpty ? '1 SD' : controller.selectedKelas.value,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.class_outlined),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: const [
                  DropdownMenuItem(value: '1 SD', child: Text('1 SD')),
                  DropdownMenuItem(value: '2 SD', child: Text('2 SD')),
                  DropdownMenuItem(value: '3 SD', child: Text('3 SD')),
                  DropdownMenuItem(value: '4 SD', child: Text('4 SD')),
                  DropdownMenuItem(value: '5 SD', child: Text('5 SD')),
                  DropdownMenuItem(value: '6 SD', child: Text('6 SD')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    controller.selectedKelas.value = val;
                  }
                },
              )),
            ],
            const SizedBox(height: AppSizes.paddingM),
            Text('Provinsi', style: AppFonts.bodyText(weight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: controller.provinceController,
              decoration: const InputDecoration(
                hintText: 'Masukkan provinsi',
                prefixIcon: Icon(Icons.map_outlined),
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),
            Text('Kabupaten/Kota', style: AppFonts.bodyText(weight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: controller.regencyController,
              decoration: const InputDecoration(
                hintText: 'Masukkan kabupaten/kota',
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),
            Text('Kecamatan', style: AppFonts.bodyText(weight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: controller.districtController,
              decoration: const InputDecoration(
                hintText: 'Masukkan kecamatan',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: AppSizes.paddingXL),
            Obx(() => EpicButton(
              text: 'Simpan Data',
              isLoading: controller.isLoading.value,
              onPressed: controller.saveSchoolData,
            )),
          ],
        ),
      ),
    );
  }
}
