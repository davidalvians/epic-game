import 'package:epic_app/core/utils/epic_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/utils/image_picker_helper.dart';
import 'package:epic_app/data/repositories/auth_repository.dart';
import 'package:epic_app/data/services/storage_service.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';

class EditProfileController extends GetxController {
  final AuthRepository _authRepo = Get.find<AuthRepository>();
  final SessionController _sessionController = Get.find<SessionController>();
  final StorageService _storageService = Get.find<StorageService>();

  final nameController = TextEditingController();
  final nicknameController = TextEditingController();
  
  var isLoading = false.obs;
  var isImageUploading = false.obs;

  @override
  void onInit() {
    super.onInit();
    final user = _sessionController.user;
    if (user != null) {
      nameController.text = user.namaLengkap;
      nicknameController.text = user.namaPanggilan;
    }
  }

  Future<void> pickAndUploadImage() async {
    try {
      final picked = await ImagePickerHelper.pickFromGallery();
      if (picked == null) return;

      final user = _sessionController.user;
      if (user == null) return;

      isImageUploading.value = true;
      
      // Upload ke Firebase Storage
      final String path = 'profile_pictures/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String downloadUrl = await _storageService.uploadBytes(path, picked.bytes);
      
      // Simpan URL lama jika ada untuk dihapus
      final oldUrl = user.avatarUrl;

      // Update Firestore user profile
      final updatedUser = user.copyWith(avatarUrl: downloadUrl);
      await _authRepo.updateProfile(updatedUser);
      _sessionController.setUser(updatedUser);

      // Hapus foto lama jika ada
      if (oldUrl.isNotEmpty && oldUrl.contains('firebasestorage')) {
        await _storageService.deleteFile(oldUrl);
      }

      EpicSnackbar.success('Sukses', 'Foto profil berhasil diperbarui');
    } catch (e) {
      EpicSnackbar.error('Gagal', 'Terjadi kesalahan saat mengunggah foto: $e');
    } finally {
      isImageUploading.value = false;
    }
  }

  Future<void> saveProfile() async {
    final user = _sessionController.user;
    if (user == null) return;

    final name = nameController.text.trim();
    final nickname = nicknameController.text.trim();

    if (name.isEmpty || nickname.isEmpty) {
      EpicSnackbar.error('Ups!', 'Nama lengkap dan nama panggilan tidak boleh kosong.');
      return;
    }

    isLoading.value = true;
    try {
      final updatedUser = user.copyWith(
        namaLengkap: name,
        namaPanggilan: nickname,
      );

      await _authRepo.updateProfile(updatedUser);
      _sessionController.setUser(updatedUser);
      
      Get.back();
      EpicSnackbar.success('Sukses', 'Profil berhasil diperbarui.');
    } catch (e) {
      EpicSnackbar.error('Gagal', e.toString().replaceAll('Exception: ', ''));
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    nicknameController.dispose();
    super.onClose();
  }
}
