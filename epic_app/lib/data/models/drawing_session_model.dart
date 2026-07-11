import 'package:cloud_firestore/cloud_firestore.dart';

/// Status sesi menggambar.
enum DrawingSessionStatus { draft, submitted, scored }

/// Model untuk sesi menggambar yang sedang berlangsung (disimpan lokal).
class DrawingSessionModel {
  final String id;
  final String uid;
  final String kategori;      // keris / batik / anyaman
  final int level;            // 1-4
  final String? templateId;  // ID template yang dipilih
  final int remainingSeconds; // Sisa waktu menggambar (detik)
  final int nyawaDigunakan;   // Berapa nyawa terpakai untuk tambah waktu
  final DrawingSessionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? strokesData;
  final String? stempelsData;
  final String? anyamanData;
  final int waktuTerpakai;

  const DrawingSessionModel({
    required this.id,
    required this.uid,
    required this.kategori,
    required this.level,
    this.templateId,
    required this.remainingSeconds,
    this.nyawaDigunakan = 0,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.strokesData,
    this.stempelsData,
    this.anyamanData,
    this.waktuTerpakai = 0,
  });

  bool get isDraft => status == DrawingSessionStatus.draft;
  bool get isSubmitted => status == DrawingSessionStatus.submitted;
  String get gameType => kategori.toLowerCase() == 'anyaman' ? 'anyaman' : 'menggambar';

  /// Key unik untuk SharedPreferences / SQLite.
  String get storageKey => 'drawing_session_${uid}_${kategori}_$level';

  factory DrawingSessionModel.fromJson(Map<String, dynamic> json) {
    DateTime parseTimestamp(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return DrawingSessionModel(
      id: json['id']?.toString() ?? '',
      uid: json['uid']?.toString() ?? '',
      kategori: json['kategori']?.toString() ?? '',
      level: json['level'] as int? ?? 1,
      templateId: json['templateId']?.toString(),
      remainingSeconds: json['remainingSeconds'] as int? ?? 900,
      nyawaDigunakan: json['nyawaDigunakan'] as int? ?? 0,
      status: DrawingSessionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DrawingSessionStatus.draft,
      ),
      createdAt: parseTimestamp(json['createdAt']),
      updatedAt: parseTimestamp(json['updatedAt']),
      strokesData: json['strokesData']?.toString(),
      stempelsData: json['stempelsData']?.toString(),
      anyamanData: json['anyamanData']?.toString(),
      waktuTerpakai: json['waktuTerpakai'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'kategori': kategori,
      'level': level,
      'templateId': templateId,
      'remainingSeconds': remainingSeconds,
      'nyawaDigunakan': nyawaDigunakan,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'strokesData': strokesData,
      'stempelsData': stempelsData,
      'anyamanData': anyamanData,
      'waktuTerpakai': waktuTerpakai,
    };
  }

  DrawingSessionModel copyWith({
    String? templateId,
    int? remainingSeconds,
    int? nyawaDigunakan,
    DrawingSessionStatus? status,
    DateTime? updatedAt,
    String? strokesData,
    String? stempelsData,
    String? anyamanData,
    int? waktuTerpakai,
  }) {
    return DrawingSessionModel(
      id: id,
      uid: uid,
      kategori: kategori,
      level: level,
      templateId: templateId ?? this.templateId,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      nyawaDigunakan: nyawaDigunakan ?? this.nyawaDigunakan,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      strokesData: strokesData ?? this.strokesData,
      stempelsData: stempelsData ?? this.stempelsData,
      anyamanData: anyamanData ?? this.anyamanData,
      waktuTerpakai: waktuTerpakai ?? this.waktuTerpakai,
    );
  }
}
