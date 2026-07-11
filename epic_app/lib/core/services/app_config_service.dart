// AppConfigService — Memuat konfigurasi sistem dari Firestore (app_config/system_settings)
// dan menyediakannya secara global ke seluruh mobile app.
// Konfigurasi diatur oleh Admin melalui admin panel (Settings > Konfigurasi Sistem).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class AppConfigService extends GetxService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Observable Config Values ─────────────────────────────────────────────
  // Nilai default dipakai jika Firestore tidak tersedia (offline/error).
  // Default diselaraskan dengan default admin panel.

  /// Nyawa maksimal per hari. Default: 5 (sesuai default admin panel)
  final RxInt maxNyawa = 5.obs;

  /// Durasi pengerjaan game dalam detik. Default: 900 (15 menit)
  final RxInt timerDurasiDetik = 900.obs;

  /// Waktu pemulihan nyawa dalam menit. Default: 15 menit
  final RxInt recoveryTimeMin = 15.obs;

  /// Multiplier poin global (saat ini belum dipakai per-level, reserved)
  final RxDouble poinMultiplierGlobal = 1.0.obs;

  /// Level configs per game: levelConfigs[game][level] = {multiplier, minGrade}
  /// Contoh: levelConfigs['Batik'][1] = {'multiplier': 1.0, 'minGrade': 'C'}
  final Rx<Map<String, Map<int, Map<String, dynamic>>>> levelConfigs =
      Rx<Map<String, Map<int, Map<String, dynamic>>>>(_buildDefaultLevelConfigs());

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  @override
  void onInit() {
    super.onInit();
    _loadConfig();
  }

  /// Membangun default level configs (sesuai default admin panel)
  static Map<String, Map<int, Map<String, dynamic>>> _buildDefaultLevelConfigs() {
    return {
      'Batik': {
        1: {'multiplier': 1.0, 'minGrade': 'C'},
        2: {'multiplier': 1.2, 'minGrade': 'B'},
        3: {'multiplier': 1.5, 'minGrade': 'B'},
        4: {'multiplier': 2.0, 'minGrade': 'A'},
      },
      'Keris': {
        1: {'multiplier': 1.0, 'minGrade': 'C'},
        2: {'multiplier': 1.2, 'minGrade': 'B'},
        3: {'multiplier': 1.5, 'minGrade': 'B'},
        4: {'multiplier': 2.0, 'minGrade': 'A'},
      },
      'Anyaman': {
        1: {'multiplier': 1.0, 'minGrade': 'C'},
        2: {'multiplier': 1.2, 'minGrade': 'B'},
        3: {'multiplier': 1.5, 'minGrade': 'B'},
        4: {'multiplier': 2.0, 'minGrade': 'A'},
      },
    };
  }

  /// Memuat konfigurasi dari Firestore secara real-time (mendengarkan perubahan).
  void _loadConfig() {
    try {
      _db.collection('app_config').doc('system_settings').snapshots().listen((doc) {
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;

          // maxNyawa
          final rawMaxNyawa = data['maxNyawa'];
          if (rawMaxNyawa is int) {
            maxNyawa.value = rawMaxNyawa;
          } else if (rawMaxNyawa is double) {
            maxNyawa.value = rawMaxNyawa.toInt();
          }

          // timerDurationSec → timerDurasiDetik
          final rawTimer = data['timerDurationSec'];
          if (rawTimer is int && rawTimer > 0) {
            timerDurasiDetik.value = rawTimer;
          } else if (rawTimer is double && rawTimer > 0) {
            timerDurasiDetik.value = rawTimer.toInt();
          }

          // recoveryTimeMin
          final rawRecovery = data['recoveryTimeMin'];
          if (rawRecovery is int) {
            recoveryTimeMin.value = rawRecovery;
          } else if (rawRecovery is double) {
            recoveryTimeMin.value = rawRecovery.toInt();
          }

          // poinMultiplier global
          final rawMultiplier = data['poinMultiplier'];
          if (rawMultiplier is double) {
            poinMultiplierGlobal.value = rawMultiplier;
          } else if (rawMultiplier is int) {
            poinMultiplierGlobal.value = rawMultiplier.toDouble();
          }

          // levelConfigs
          final rawLevelConfigs = data['levelConfigs'];
          if (rawLevelConfigs is Map) {
            final parsedConfigs = _buildDefaultLevelConfigs(); // mulai dari default
            rawLevelConfigs.forEach((gameKey, levelData) {
              final gameStr = gameKey.toString();
              if (parsedConfigs.containsKey(gameStr) && levelData is Map) {
                levelData.forEach((lvlKey, config) {
                  final lvl = int.tryParse(lvlKey.toString());
                  if (lvl != null && parsedConfigs[gameStr]!.containsKey(lvl) && config is Map) {
                    parsedConfigs[gameStr]![lvl] = {
                      'multiplier': (config['multiplier'] is num)
                          ? (config['multiplier'] as num).toDouble()
                          : parsedConfigs[gameStr]![lvl]!['multiplier'],
                      'minGrade': config['minGrade']?.toString() ??
                          parsedConfigs[gameStr]![lvl]!['minGrade'],
                    };
                  }
                });
              }
            });
            levelConfigs.value = parsedConfigs;
          }

          _isLoaded = true;
          debugPrint('✅ AppConfigService: Konfigurasi sistem di-update secara real-time dari Firestore.');
          debugPrint('   maxNyawa=${maxNyawa.value}, timer=${timerDurasiDetik.value}s, recovery=${recoveryTimeMin.value}min');
        } else {
          _isLoaded = true;
          debugPrint('⚠️ AppConfigService: Dokumen system_settings tidak ditemukan. Menggunakan nilai default.');
        }
      }, onError: (error) {
        _isLoaded = true;
        debugPrint('⚠️ AppConfigService: Gagal memuat konfigurasi (stream error): $error. Menggunakan nilai default.');
      });
    } catch (e) {
      _isLoaded = true;
      debugPrint('⚠️ AppConfigService: Exception saat subscribe konfigurasi: $e. Menggunakan nilai default.');
    }
  }

  // ─── Helper Getters ──────────────────────────────────────────────────────

  /// Ambil multiplier skor untuk game dan level tertentu.
  double getMultiplier(String kategori, int level) {
    final gameKey = _normalizeGameKey(kategori);
    return (levelConfigs.value[gameKey]?[level]?['multiplier'] as double?) ?? 1.0;
  }

  /// Ambil grade minimal untuk lulus di game dan level tertentu.
  String getMinGrade(String kategori, int level) {
    final gameKey = _normalizeGameKey(kategori);
    return (levelConfigs.value[gameKey]?[level]?['minGrade'] as String?) ?? 'C';
  }

  /// Normalisasi nama game (case-insensitive)
  String _normalizeGameKey(String kategori) {
    switch (kategori.toLowerCase()) {
      case 'batik': return 'Batik';
      case 'keris': return 'Keris';
      case 'anyaman': return 'Anyaman';
      default: return kategori;
    }
  }

  /// Cek apakah grade tertentu memenuhi syarat lulus minimal.
  /// Grade order: S > A > B > C > D
  bool isGradeSufficient(String achievedGrade, String minGrade) {
    const gradeOrder = ['D', 'C', 'B', 'A', 'S'];
    final achievedIdx = gradeOrder.indexOf(achievedGrade.toUpperCase());
    final minIdx = gradeOrder.indexOf(minGrade.toUpperCase());
    if (achievedIdx == -1 || minIdx == -1) return true; // Fallback: lulus
    return achievedIdx >= minIdx;
  }
}
