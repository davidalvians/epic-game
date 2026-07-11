import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:epic_app/core/routes/app_routes.dart';
import 'package:epic_app/core/utils/epic_snackbar.dart';
import 'package:epic_app/data/repositories/auth_repository.dart';
import 'package:epic_app/data/services/storage_service.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';

/// Controller untuk Profile Setup (onboarding setelah Google Sign-In).
class ProfileSetupController extends GetxController {
  final AuthRepository _authRepo = Get.find<AuthRepository>();
  final SessionController _sessionController = Get.find<SessionController>();

  // Form controllers
  final namaController = TextEditingController();
  final usernameController = TextEditingController();
  final sekolahController = TextEditingController();
  final provinsiController = TextEditingController();
  final kabupatenController = TextEditingController();
  final kecamatanController = TextEditingController();
  final selectedKelas = ''.obs; // Murid
  final selectedRole = 'murid'.obs; // 'murid' atau 'guru'
  final mataPelajaranController = TextEditingController(); // Guru

  final RxBool isLoading = false.obs;
  final RxBool isCheckingUsername = false.obs;
  final RxBool isUsernameAvailable = true.obs;
  final RxString usernameError = ''.obs;

  // Upload Bukti Mengajar (Guru)
  final Rxn<File> buktiFile = Rxn<File>();
  final RxString buktiFileName = ''.obs;
  final RxBool isUploadingBukti = false.obs;

  // Debounce timer untuk username check
  final RxString usernameInput = ''.obs;
  Worker? _usernameDebounce;

  @override
  void onInit() {
    super.onInit();
    // Pre-fill nama dari Google account
    final user = _sessionController.user;
    if (user != null) {
      namaController.text = user.namaLengkap;
    }

    // Setup debounce untuk username check
    _usernameDebounce = debounce(
      usernameInput,
      (value) => checkUsername(value),
      time: const Duration(milliseconds: 500),
    );
  }

  void onUsernameChanged(String value) {
    usernameInput.value = value;
  }

  /// Cek ketersediaan username secara real-time.
  Future<void> checkUsername(String username) async {
    final cleaned = username.trim().toLowerCase();

    // Validasi format
    if (cleaned.isEmpty) {
      usernameError.value = '';
      isUsernameAvailable.value = true;
      return;
    }

    if (cleaned.length < 4) {
      usernameError.value = 'Minimal 4 karakter';
      isUsernameAvailable.value = false;
      return;
    }

    if (cleaned.length > 20) {
      usernameError.value = 'Maksimal 20 karakter';
      isUsernameAvailable.value = false;
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(cleaned)) {
      usernameError.value = 'Hanya huruf, angka, dan underscore';
      isUsernameAvailable.value = false;
      return;
    }

    // Cek ke Firestore
    isCheckingUsername.value = true;
    try {
      final available = await _authRepo.checkUsernameAvailable(cleaned);
      isUsernameAvailable.value = available;
      usernameError.value =
          available ? '' : 'Username sudah dipakai';
    } catch (e) {
      usernameError.value = 'Gagal mengecek username';
    } finally {
      isCheckingUsername.value = false;
    }
  }

  /// Pilih file bukti mengajar dari galeri.
  Future<void> pickBuktiFile() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (picked == null) return;

      final file = File(picked.path);
      final fileSizeBytes = await file.length();
      const maxSize = 5 * 1024 * 1024; // 5 MB

      if (fileSizeBytes > maxSize) {
        EpicSnackbar.error(
          'File Terlalu Besar',
          'Maksimal 5 MB. Coba pilih file lain atau kompres gambar.',
        );
        return;
      }

      buktiFile.value = file;
      buktiFileName.value = picked.name;
    } catch (e) {
      debugPrint('❌ Error pick bukti: $e');
      EpicSnackbar.error('Ups!', 'Gagal memilih file. Coba lagi.');
    }
  }

  /// Hapus file bukti yang sudah dipilih.
  void removeBuktiFile() {
    buktiFile.value = null;
    buktiFileName.value = '';
  }

  /// Upload bukti ke Firebase Storage.
  /// Returns download URL jika berhasil, null jika gagal.
  Future<String?> _uploadBuktiToStorage(String uid) async {
    if (buktiFile.value == null) return null;

    try {
      isUploadingBukti.value = true;
      final storage = Get.find<StorageService>();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'guru_bukti/$uid/bukti_$timestamp.jpg';
      final url = await storage.uploadFile(path, buktiFile.value!);
      return url;
    } catch (e) {
      debugPrint('❌ Error upload bukti: $e');
      return null;
    } finally {
      isUploadingBukti.value = false;
    }
  }

  /// Submit profil dan selesaikan onboarding.
  Future<void> submitProfile() async {
    // Validasi
    final nama = namaController.text.trim();
    final username = usernameController.text.trim().toLowerCase();
    final sekolah = sekolahController.text.trim();

    if (nama.length < 3) {
      EpicSnackbar.error('Ups!', 'Nama minimal 3 karakter ya!');
      return;
    }

    if (username.length < 4) {
      EpicSnackbar.error('Ups!', 'Username minimal 4 karakter!');
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      EpicSnackbar.error(
          'Ups!', 'Username hanya boleh huruf, angka, dan underscore!');
      return;
    }

    if (!isUsernameAvailable.value) {
      EpicSnackbar.error('Ups!', 'Username sudah dipakai. Pilih yang lain!');
      return;
    }

    if (sekolah.length < 5) {
      EpicSnackbar.error('Ups!', 'Nama sekolah minimal 5 karakter!');
      return;
    }

    // Validasi WAJIB: Bukti mengajar untuk guru
    if (selectedRole.value == 'guru' && buktiFile.value == null) {
      EpicSnackbar.error(
        'Bukti Wajib!',
        'Upload bukti mengajar (SK Guru / Kartu GTK / ID resmi) untuk mendaftar sebagai guru.',
      );
      return;
    }

    final uid = _sessionController.user?.uid;
    if (uid == null) {
      EpicSnackbar.error('Error', 'Sesi login tidak valid. Coba lagi.');
      return;
    }

    isLoading.value = true;
    try {
      // Upload bukti ke Storage jika role guru
      String? buktiUrl;
      if (selectedRole.value == 'guru') {
        buktiUrl = await _uploadBuktiToStorage(uid);
        if (buktiUrl == null) {
          EpicSnackbar.error('Ups!', 'Gagal mengupload bukti mengajar. Periksa koneksi internet dan coba lagi.');
          return;
        }
      }

      final updatedUser = await _authRepo.completeOnboarding(
        uid: uid,
        namaLengkap: nama,
        username: username,
        sekolah: sekolah,
        role: selectedRole.value,
        kelas: selectedKelas.value,
        provinsi: provinsiController.text.trim(),
        kabupaten: kabupatenController.text.trim(),
        kecamatan: kecamatanController.text.trim(),
        mataPelajaran: selectedRole.value == 'guru'
            ? mataPelajaranController.text.trim()
            : null,
        buktiMengajarUrl: buktiUrl,
      );

      _sessionController.setUser(updatedUser);

      if (selectedRole.value == 'guru') {
        EpicSnackbar.success(
          'Berhasil!',
          'Profil tersimpan. Permohonan verifikasi guru sedang diproses (estimasi 1x24 jam).',
        );
      } else {
        EpicSnackbar.success('Berhasil!', 'Profil tersimpan. Ayo mulai bermain!');
      }

      Get.offAllNamed(Routes.home);
    } catch (e) {
      EpicSnackbar.error('Ups!', e.toString().replaceAll('Exception: ', ''));
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    namaController.dispose();
    usernameController.dispose();
    sekolahController.dispose();
    provinsiController.dispose();
    kabupatenController.dispose();
    kecamatanController.dispose();
    mataPelajaranController.dispose();
    _usernameDebounce?.dispose();
    super.onClose();
  }
}
