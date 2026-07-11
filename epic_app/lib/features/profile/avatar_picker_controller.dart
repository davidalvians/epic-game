import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/data/repositories/user_repository.dart';
import 'package:epic_app/data/services/storage_service.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';

class AvatarPickerController extends GetxController {
  final _userRepo = UserRepository();
  final _storage = Get.find<StorageService>();
  final _session = Get.find<SessionController>();
  final _picker = ImagePicker();

  var isUploading = false.obs;

  void showPickerDialog() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ganti Foto Profil',
              style: TextStyle(
                fontFamily: 'FredokaOne',
                fontSize: 18,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFF1F5F9),
                child: Icon(Icons.photo_library_rounded, color: AppColors.primary),
              ),
              title: const Text('Pilih dari Galeri', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.bold)),
              onTap: () {
                Get.back();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFF1F5F9),
                child: Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              ),
              title: const Text('Ambil Foto', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.bold)),
              onTap: () {
                Get.back();
                _pickImage(ImageSource.camera);
              },
            ),
            if (_session.currentUser.value?.avatarUrl.isNotEmpty ?? false)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFEF2F2),
                  child: Icon(Icons.delete_rounded, color: Colors.red),
                ),
                title: const Text('Hapus Foto', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.bold, color: Colors.red)),
                onTap: () {
                  Get.back();
                  _deleteAvatar();
                },
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (pickedFile == null) return;
      final file = File(pickedFile.path);
      
      final user = _session.currentUser.value;
      if (user == null) return;

      isUploading.value = true;
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        barrierDismissible: false,
      );

      // Upload to Storage (sesuai storage.rules: avatars/{uid}/{filename})
      final String path = 'avatars/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String url = await _storage.uploadFile(path, file);

      // Update Firestore
      final updatedUser = await _userRepo.updateAvatar(user, url);
      
      // Update local state
      _session.updateUser(updatedUser);

      Get.back(); // Tutup dialog loading
      Get.snackbar(
        'Berhasil', 
        'Foto profil berhasil diperbarui!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.back(); // Tutup dialog loading
      Get.snackbar(
        'Error', 
        'Gagal mengunggah foto profil: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> _deleteAvatar() async {
    final user = _session.currentUser.value;
    if (user == null || user.avatarUrl.isEmpty) return;
    
    Get.dialog(
      AlertDialog(
        title: const Text('Hapus Foto Profil', style: TextStyle(fontFamily: 'FredokaOne')),
        content: const Text('Yakin ingin menghapus foto profil ini?', style: TextStyle(fontFamily: 'Nunito')),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back(); // Tutup confirm dialog
              
              isUploading.value = true;
              Get.dialog(
                const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                barrierDismissible: false,
              );

              try {
                // Ignore errors on delete from storage if file already missing
                try {
                  await _storage.deleteFile(user.avatarUrl);
                } catch (e) {
                  debugPrint('Storage file not found or could not be deleted: $e');
                }

                // Update Firestore
                final updatedUser = await _userRepo.updateAvatar(user, '');
                
                // Update local state
                _session.updateUser(updatedUser);

                Get.back(); // Tutup dialog loading
                Get.snackbar('Berhasil', 'Foto profil dihapus.', backgroundColor: Colors.green, colorText: Colors.white);
              } catch (e) {
                Get.back();
                Get.snackbar('Error', 'Gagal menghapus foto profil.', backgroundColor: Colors.red, colorText: Colors.white);
              } finally {
                isUploading.value = false;
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
