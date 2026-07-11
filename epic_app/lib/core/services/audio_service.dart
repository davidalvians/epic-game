import 'package:audioplayers/audioplayers.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:epic_app/data/services/local_storage_service.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';

class AudioService extends GetxService {
  late final AudioPlayer _sfxPlayer;
  
  @override
  void onInit() {
    super.onInit();
    _sfxPlayer = AudioPlayer();
  }

  @override
  void onClose() {
    _sfxPlayer.dispose();
    super.onClose();
  }

  /// Cek apakah pengguna saat ini adalah Guru
  bool _isGuru() {
    if (Get.isRegistered<SessionController>()) {
      return Get.find<SessionController>().isGuru;
    }
    return false;
  }

  /// Memutar efek suara (SFX) generik
  /// [assetPath] adalah path lengkap dari AppAssets (misal: 'assets/audio/sfx_tap.mp3')
  /// atau path relatif ke folder assets/
  Future<void> playSfx(String assetPath) async {
    // 1. Matikan suara sepenuhnya jika akun adalah Guru
    if (_isGuru()) return;

    // 2. Cek apakah suara diizinkan di pengaturan (hanya relevan untuk murid)
    final storage = Get.find<LocalStorageService>();
    if (!storage.isSoundEnabled) {
      return; 
    }

    try {
      // audioplayers 4.x ke atas membutuhkan path relatif jika menggunakan AssetSource
      String path = assetPath;
      if (path.startsWith('assets/')) {
        path = path.replaceFirst('assets/', '');
      }

      await _sfxPlayer.play(AssetSource(path));
    } catch (e) {
      debugPrint('Error playing SFX ($assetPath): $e');
    }
  }

  /// Fungsi khusus untuk Button Click agar *backward compatible*
  /// dengan baris kode lama yang memanggil playButtonClick()
  Future<void> playButtonClick() async {
    // Matikan suara sepenuhnya jika akun adalah Guru
    if (_isGuru()) return;
    
    await playSfx('audio/button_click.mp3');
  }
}
