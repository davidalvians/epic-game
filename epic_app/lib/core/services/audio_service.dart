import 'package:audioplayers/audioplayers.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:epic_app/data/services/local_storage_service.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';

/// Service tata suara cerdas & multi-channel untuk EPIC App.
/// Mengelola BGM, SFX umum, pemindaian AI, fanfare penilaian, dan efek arcade.
class AudioService extends GetxService {
  late final AudioPlayer _sfxPlayer;
  late final AudioPlayer _scanPlayer;
  late final AudioPlayer _fanfarePlayer;
  late final AudioPlayer _tickPlayer;
  late final AudioPlayer _rewardPlayer;
  
  @override
  void onInit() {
    super.onInit();
    _sfxPlayer = AudioPlayer();
    _scanPlayer = AudioPlayer();
    _fanfarePlayer = AudioPlayer();
    _tickPlayer = AudioPlayer();
    _rewardPlayer = AudioPlayer();
  }

  @override
  void onClose() {
    _sfxPlayer.dispose();
    _scanPlayer.dispose();
    _fanfarePlayer.dispose();
    _tickPlayer.dispose();
    _rewardPlayer.dispose();
    super.onClose();
  }

  /// Cek apakah pengguna saat ini adalah Guru
  bool _isGuru() {
    if (Get.isRegistered<SessionController>()) {
      return Get.find<SessionController>().isGuru;
    }
    return false;
  }

  /// Cek apakah efek suara diaktifkan
  bool _canPlaySound() {
    if (_isGuru()) return false;
    if (Get.isRegistered<LocalStorageService>()) {
      return Get.find<LocalStorageService>().isSoundEnabled;
    }
    return true;
  }

  String _cleanPath(String assetPath) {
    if (assetPath.startsWith('assets/')) {
      return assetPath.replaceFirst('assets/', '');
    }
    return assetPath;
  }

  /// Memutar efek suara (SFX) generik
  Future<void> playSfx(String assetPath, {double volume = 1.0}) async {
    if (!_canPlaySound()) return;

    try {
      final path = _cleanPath(assetPath);
      await _sfxPlayer.setVolume(volume);
      await _sfxPlayer.play(AssetSource(path));
    } catch (e) {
      debugPrint('Error playing SFX ($assetPath): $e');
    }
  }

  /// Memutar suara pemindaian teknologi AI (looping)
  Future<void> startScanHum() async {
    if (!_canPlaySound()) return;
    try {
      await _scanPlayer.setReleaseMode(ReleaseMode.loop);
      await _scanPlayer.setVolume(0.65);
      await _scanPlayer.play(AssetSource('audio/sfx_scan_tech.wav'));
    } catch (e) {
      debugPrint('Error startScanHum: $e');
    }
  }

  /// Menghentikan suara pemindaian teknologi AI
  Future<void> stopScanHum() async {
    try {
      await _scanPlayer.stop();
    } catch (e) {
      debugPrint('Error stopScanHum: $e');
    }
  }

  /// Memutar efek swoosh / whoosh transisi
  Future<void> playWhoosh() async {
    if (!_canPlaySound()) return;
    try {
      await _sfxPlayer.setVolume(0.7);
      await _sfxPlayer.play(AssetSource('audio/sfx_whoosh.wav'));
    } catch (e) {
      debugPrint('Error playWhoosh: $e');
    }
  }

  /// Memutar efek dentuman lencana grade mendarat (impact slam)
  Future<void> playRevealImpact() async {
    if (!_canPlaySound()) return;
    try {
      await _fanfarePlayer.setVolume(0.9);
      await _fanfarePlayer.play(AssetSource('audio/sfx_reveal_impact.wav'));
    } catch (e) {
      debugPrint('Error playRevealImpact: $e');
    }
  }

  /// Memutar fanfare kemenangan/apresiasi berdasarkan Grade (S, A, B, C, D)
  Future<void> playGradeReveal(String grade) async {
    if (!_canPlaySound()) return;
    try {
      String soundFile;
      if (grade == 'S') {
        soundFile = 'audio/sfx_grade_s_fanfare.wav';
      } else if (grade == 'A') {
        soundFile = 'audio/sfx_grade_a.wav';
      } else {
        soundFile = 'audio/sfx_grade_encourage.wav';
      }
      await _fanfarePlayer.setVolume(0.95);
      await _fanfarePlayer.play(AssetSource(soundFile));
    } catch (e) {
      debugPrint('Error playGradeReveal: $e');
    }
  }

  /// Memutar detak cepat saat angka skor AI bergulir naik (tally rolling)
  Future<void> playScoreCounter() async {
    if (!_canPlaySound()) return;
    try {
      await _tickPlayer.setVolume(0.45);
      await _tickPlayer.play(AssetSource('audio/sfx_counter_tick.wav'));
    } catch (e) {
      debugPrint('Error playScoreCounter: $e');
    }
  }

  /// Memutar suara bubble pop saat kriteria rubrik terisi
  Future<void> playStarPop() async {
    if (!_canPlaySound()) return;
    try {
      await _rewardPlayer.setVolume(0.75);
      await _rewardPlayer.play(AssetSource('audio/sfx_star_pop.wav'));
    } catch (e) {
      debugPrint('Error playStarPop: $e');
    }
  }

  /// Memutar efek gemerincing koin emas & poin reward
  Future<void> playCoinReward() async {
    if (!_canPlaySound()) return;
    try {
      await _rewardPlayer.setVolume(0.85);
      await _rewardPlayer.play(AssetSource('audio/sfx_coin_burst.wav'));
    } catch (e) {
      debugPrint('Error playCoinReward: $e');
    }
  }

  /// Fungsi khusus untuk Button Click agar backward compatible
  Future<void> playButtonClick() async {
    if (!_canPlaySound()) return;
    await playSfx('audio/button_click.mp3');
  }
}

