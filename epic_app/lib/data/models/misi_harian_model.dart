import 'package:cloud_firestore/cloud_firestore.dart';

/// Model misi harian pemain.
class MisiHarianModel {
  final String misiId;
  final String judul;          // e.g. "Mainkan 2 game hari ini"
  final String deskripsi;      // detail misi
  final String tipe;           // 'play_game' | 'complete_level' | 'earn_points' | 'submit_artwork'
  final int target;            // target jumlah (e.g. 2 game, 1 level, 50 poin)
  final int progress;          // progress saat ini
  final int reward;            // poin reward
  final bool isCompleted;
  final bool isClaimed;        // sudah diklaim oleh user
  final DateTime tanggal;

  const MisiHarianModel({
    required this.misiId,
    required this.judul,
    required this.deskripsi,
    required this.tipe,
    required this.target,
    this.progress = 0,
    required this.reward,
    this.isCompleted = false,
    this.isClaimed = false,
    required this.tanggal,
  });

  /// Progress dalam persen 0.0 - 1.0.
  double get progressPersen => target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;

  /// Label progress: "1/3".
  String get progressLabel => '$progress/$target';

  /// Apakah misi bisa diklaim (sudah selesai tapi belum diklaim).
  bool get canClaim => isCompleted && !isClaimed;

  /// Emoji berdasarkan tipe misi.
  String get emoji {
    switch (tipe) {
      case 'play_game': return '🎮';
      case 'complete_level': return '⭐';
      case 'earn_points': return '💰';
      case 'submit_artwork': return '🎨';
      default: return '📋';
    }
  }

  factory MisiHarianModel.fromJson(Map<String, dynamic> json) {
    DateTime parseTimestamp(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    int safeParse(dynamic val, int def) {
      if (val is int) return val;
      if (val is double) return val.toInt();
      return def;
    }

    return MisiHarianModel(
      misiId: json['misiId']?.toString() ?? '',
      judul: json['judul']?.toString() ?? '',
      deskripsi: json['deskripsi']?.toString() ?? '',
      tipe: json['tipe']?.toString() ?? 'play_game',
      target: safeParse(json['target'], 1),
      progress: safeParse(json['progress'], 0),
      reward: safeParse(json['reward'], 10),
      isCompleted: json['isCompleted'] == true,
      isClaimed: json['isClaimed'] == true,
      tanggal: parseTimestamp(json['tanggal']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'misiId': misiId,
      'judul': judul,
      'deskripsi': deskripsi,
      'tipe': tipe,
      'target': target,
      'progress': progress,
      'reward': reward,
      'isCompleted': isCompleted,
      'isClaimed': isClaimed,
      'tanggal': Timestamp.fromDate(tanggal),
    };
  }

  MisiHarianModel copyWith({
    String? misiId,
    String? judul,
    String? deskripsi,
    String? tipe,
    int? target,
    int? progress,
    int? reward,
    bool? isCompleted,
    bool? isClaimed,
    DateTime? tanggal,
  }) {
    return MisiHarianModel(
      misiId: misiId ?? this.misiId,
      judul: judul ?? this.judul,
      deskripsi: deskripsi ?? this.deskripsi,
      tipe: tipe ?? this.tipe,
      target: target ?? this.target,
      progress: progress ?? this.progress,
      reward: reward ?? this.reward,
      isCompleted: isCompleted ?? this.isCompleted,
      isClaimed: isClaimed ?? this.isClaimed,
      tanggal: tanggal ?? this.tanggal,
    );
  }

  /// Generate misi default harian.
  static List<MisiHarianModel> generateDaily(DateTime tanggal) {
    return [
      MisiHarianModel(
        misiId: 'daily_play_${tanggal.millisecondsSinceEpoch}',
        judul: 'Mainkan 2 game hari ini',
        deskripsi: 'Mainkan game batik atau anyaman sebanyak 2 kali',
        tipe: 'play_game',
        target: 2,
        reward: 20,
        tanggal: tanggal,
      ),
      MisiHarianModel(
        misiId: 'daily_artwork_${tanggal.millisecondsSinceEpoch}',
        judul: 'Kirim 1 karya',
        deskripsi: 'Selesaikan dan kirimkan 1 karya gambar atau anyaman',
        tipe: 'submit_artwork',
        target: 1,
        reward: 30,
        tanggal: tanggal,
      ),
      MisiHarianModel(
        misiId: 'daily_points_${tanggal.millisecondsSinceEpoch}',
        judul: 'Kumpulkan 50 poin',
        deskripsi: 'Dapatkan total 50 poin dari bermain hari ini',
        tipe: 'earn_points',
        target: 50,
        reward: 25,
        tanggal: tanggal,
      ),
    ];
  }
}
