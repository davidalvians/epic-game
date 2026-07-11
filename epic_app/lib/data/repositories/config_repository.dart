import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ConfigRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Nilai default jika gagal memuat dari Firestore.
  // Nilai ini HARUS konsisten dengan:
  // - AppConfigService._timerDurasiDetik (= 900)
  // - DrawingController._timerDurasiDetik (= 900)
  // - UserModel.maxNyawa (= 3, sebagai ultimate fallback)
  final Map<String, dynamic> _defaultSettings = {
    'poinMultiplier': 1.0,
    'maxNyawa': 3,
    'timerDurationSec': 900, // 15 menit = 900 detik (sebelumnya salah: 60 detik)
    'gradeThresholds': {
      'S': 90,
      'A': 80,
      'B': 70,
      'C': 60,
    }
  };

  /// Mengambil konfigurasi sistem dari Firestore
  Future<Map<String, dynamic>> getSystemSettings() async {
    try {
      final doc = await _db.collection('app_config').doc('system_settings').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return {
          'poinMultiplier': (data['poinMultiplier'] ?? _defaultSettings['poinMultiplier'] as num).toDouble(),
          'maxNyawa': (data['maxNyawa'] ?? _defaultSettings['maxNyawa'] as num).toInt(),
          'timerDurationSec': (data['timerDurationSec'] ?? _defaultSettings['timerDurationSec'] as num).toInt(),
          'gradeThresholds': data['gradeThresholds'] ?? _defaultSettings['gradeThresholds'],
        };
      }
      return _defaultSettings;
    } catch (e) {
      debugPrint('⚠️ Error memuat app_config/system_settings: $e');
      return _defaultSettings;
    }
  }
}
