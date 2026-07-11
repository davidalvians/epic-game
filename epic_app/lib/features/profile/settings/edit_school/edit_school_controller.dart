import 'package:epic_app/core/utils/epic_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/data/repositories/auth_repository.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';

class EditSchoolController extends GetxController {
  final AuthRepository _authRepo = Get.find<AuthRepository>();
  final SessionController _sessionController = Get.find<SessionController>();

  final schoolController = TextEditingController();
  final provinceController = TextEditingController();
  final regencyController = TextEditingController();
  final districtController = TextEditingController();
  final selectedKelas = ''.obs;

  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    final user = _sessionController.user;
    if (user != null) {
      schoolController.text = user.sekolah;
      provinceController.text = user.provinsi;
      regencyController.text = user.kabupaten;
      districtController.text = user.kecamatan;
      if (user.isMurid) {
        selectedKelas.value = user.kelas.isNotEmpty ? user.kelas : '1 SD';
      }
    }
  }

  Future<void> saveSchoolData() async {
    final user = _sessionController.user;
    if (user == null) return;

    final schoolName = schoolController.text.trim();
    if (schoolName.isEmpty) {
      EpicSnackbar.error('Gagal', 'Nama sekolah tidak boleh kosong.');
      return;
    }

    isLoading.value = true;
    try {
      final updatedUser = user.copyWith(
        sekolah: schoolName,
        provinsi: provinceController.text.trim(),
        kabupaten: regencyController.text.trim(),
        kecamatan: districtController.text.trim(),
        kelas: user.isMurid ? selectedKelas.value : user.kelas,
      );

      await _authRepo.updateProfile(updatedUser);
      _sessionController.setUser(updatedUser);
      
      Get.back();
      EpicSnackbar.success('Sukses', 'Data sekolah berhasil diperbarui.');
    } catch (e) {
      EpicSnackbar.error('Gagal', e.toString().replaceAll('Exception: ', ''));
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    schoolController.dispose();
    provinceController.dispose();
    regencyController.dispose();
    districtController.dispose();
    super.onClose();
  }
}
