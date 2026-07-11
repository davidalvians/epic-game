import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model untuk karya seni/gambar yang disimpan oleh pemain.
class ArtworkModel {
  final String uid;
  final String idKarya;
  final String judulKarya;
  final String imageUrl;
  final String kategori;       // keris / batik / anyaman
  final int level;             // 1-4
  final String? templateId;   // ID template yang digunakan
  final int? skorAI;            // Skor dari penilaian AI (0-100), null jika pending
  final String grade;           // S/A/B/C/D/E, atau '-' jika pending
  final String feedback;        // Feedback teks dari AI
  final Map<String, dynamic> detailPenilaian; // Detail skor per kriteria
  final String modelAI;         // Model yang digunakan untuk scoring
  final int? poinDapat;         // Poin yang didapat dari karya ini
  final int waktuPengerjaan;   // Detik yang digunakan menggambar
  final int nyawaDigunakan;    // Berapa nyawa terpakai untuk tambah waktu
  final String? kelasId;       // ID Kelas terkait karya ini (opsional)
  final bool deletedByMurid;   // Flag untuk status dihapus logis oleh murid (namun tetap ada di guru)
  final String status;         // 'dinilai' atau 'pending'
  final DateTime createdAt;

  const ArtworkModel({
    required this.uid,
    required this.idKarya,
    required this.judulKarya,
    required this.imageUrl,
    required this.kategori,
    required this.level,
    this.templateId,
    this.skorAI,
    this.grade = 'C',
    this.feedback = '',
    this.detailPenilaian = const {},
    this.modelAI = 'gemini-2.5-flash-lite',
    this.poinDapat,
    required this.waktuPengerjaan,
    this.nyawaDigunakan = 0,
    this.kelasId,
    this.deletedByMurid = false,
    this.status = 'dinilai',
    required this.createdAt,
  });

  /// Hitung grade dari skor secara seragam sesuai standar aplikasi (S/A/B/C/D).
  static String calculateGrade(int? skor) {
    if (skor == null) return '-';
    if (skor >= 90) return 'S';
    if (skor >= 80) return 'A';
    if (skor >= 70) return 'B';
    if (skor >= 60) return 'C';
    if (skor >= 50) return 'D';
    return 'E';
  }

  /// Getter untuk mendapatkan grade aktual berdasarkan skorAI secara dinamis & real-time.
  String get actualGrade => skorAI == null ? '-' : grade;

  /// Multiplier poin berdasarkan level.
  static double multiplierForLevel(int level) {
    switch (level) {
      case 1: return 1.0;
      case 2: return 1.5;
      case 3: return 2.0;
      case 4: return 3.0;
      default: return 1.0;
    }
  }

  /// Hitung poin dari skor AI dan level.
  static int hitungPoin(int? skorAI, int level) {
    if (skorAI == null) return 0;
    return (skorAI * multiplierForLevel(level)).round();
  }

  factory ArtworkModel.fromJson(Map<String, dynamic> json) {
    DateTime parseTimestamp(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    int parseSafeInt(dynamic value, int defaultValue) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    int? parseSafeIntNullable(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    return ArtworkModel(
      uid: json['uid']?.toString() ?? '',
      idKarya: json['idKarya']?.toString() ?? '',
      judulKarya: json['judulKarya']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      kategori: json['kategori']?.toString() ?? 'keris',
      level: parseSafeInt(json['level'], 1),
      templateId: json['templateId']?.toString(),
      skorAI: parseSafeIntNullable(json['skorAI']),
      grade: json['grade']?.toString() ?? 'C',
      feedback: json['feedback']?.toString() ?? '',
      detailPenilaian: json['detailPenilaian'] is Map
          ? Map<String, dynamic>.from(json['detailPenilaian'])
          : {},
      modelAI: json['modelAI']?.toString() ?? 'gemini-2.5-flash-lite',
      poinDapat: parseSafeIntNullable(json['poinDapat']),
      waktuPengerjaan: parseSafeInt(json['waktuPengerjaan'], 0),
      nyawaDigunakan: parseSafeInt(json['nyawaDigunakan'], 0),
      kelasId: json['kelasId']?.toString(),
      deletedByMurid: json['deletedByMurid'] == true,
      status: json['status']?.toString() ?? 'dinilai',
      createdAt: parseTimestamp(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'idKarya': idKarya,
      'judulKarya': judulKarya,
      'imageUrl': imageUrl,
      'kategori': kategori,
      'level': level,
      'templateId': templateId,
      'skorAI': skorAI,
      'grade': grade,
      'feedback': feedback,
      'detailPenilaian': detailPenilaian,
      'modelAI': modelAI,
      'poinDapat': poinDapat,
      'waktuPengerjaan': waktuPengerjaan,
      'nyawaDigunakan': nyawaDigunakan,
      'kelasId': kelasId,
      'deletedByMurid': deletedByMurid,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  ArtworkModel copyWith({
    String? uid,
    String? idKarya,
    String? judulKarya,
    String? imageUrl,
    String? kategori,
    int? level,
    Object? templateId = const Object(),
    int? skorAI,
    String? grade,
    String? feedback,
    Map<String, dynamic>? detailPenilaian,
    String? modelAI,
    int? poinDapat,
    int? waktuPengerjaan,
    int? nyawaDigunakan,
    Object? kelasId = const Object(),
    bool? deletedByMurid,
    String? status,
    DateTime? createdAt,
  }) {
    return ArtworkModel(
      uid: uid ?? this.uid,
      idKarya: idKarya ?? this.idKarya,
      judulKarya: judulKarya ?? this.judulKarya,
      imageUrl: imageUrl ?? this.imageUrl,
      kategori: kategori ?? this.kategori,
      level: level ?? this.level,
      templateId: templateId is String? ? templateId : this.templateId,
      skorAI: skorAI ?? this.skorAI,
      grade: grade ?? this.grade,
      feedback: feedback ?? this.feedback,
      detailPenilaian: detailPenilaian ?? this.detailPenilaian,
      modelAI: modelAI ?? this.modelAI,
      poinDapat: poinDapat ?? this.poinDapat,
      waktuPengerjaan: waktuPengerjaan ?? this.waktuPengerjaan,
      nyawaDigunakan: nyawaDigunakan ?? this.nyawaDigunakan,
      kelasId: kelasId is String? ? kelasId : this.kelasId,
      deletedByMurid: deletedByMurid ?? this.deletedByMurid,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
