import 'package:cloud_firestore/cloud_firestore.dart';

/// Model kelas untuk sistem gabung kelas guru-murid.
class KelasModel {
  final String kelasId;
  final String namaKelas;
  final String kodeKelas;      // Format EPIC-XXXX (4 karakter alfanumerik)
  final String qrData;
  final String guruUid;
  final String guruNama;
  final String namaSekolah;
  final String tingkat;         // '1 SD' - '6 SD'
  final String tahunAjaran;
  final String mataPelajaran;
  final String status;          // 'aktif' | 'nonaktif'
  final List<String> muridIds;
  final List<Map<String, dynamic>> exitedMurids; // Riwayat murid keluar/dikeluarkan
  final int totalMurid;
  final int totalKarya;
  final double avgNilai;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? nonaktifkanAt;

  const KelasModel({
    required this.kelasId,
    required this.namaKelas,
    required this.kodeKelas,
    this.qrData = '',
    required this.guruUid,
    required this.guruNama,
    this.namaSekolah = '',
    this.tingkat = '',
    this.tahunAjaran = '',
    this.mataPelajaran = '',
    this.status = 'aktif',
    this.muridIds = const [],
    this.exitedMurids = const [],
    this.totalMurid = 0,
    this.totalKarya = 0,
    this.avgNilai = 0.0,
    required this.createdAt,
    required this.updatedAt,
    this.nonaktifkanAt,
  });

  bool get isActive => status == 'aktif';

  /// Jumlah murid di kelas.
  int get jumlahMurid => muridIds.length;

  /// Cek apakah user tertentu adalah anggota kelas.
  bool isMember(String uid) => muridIds.contains(uid);

  /// Cek apakah user tertentu adalah guru kelas ini.
  bool isOwner(String uid) => guruUid == uid;

  factory KelasModel.fromJson(Map<String, dynamic> json) {
    DateTime parseTimestamp(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return KelasModel(
      kelasId: json['kelasId']?.toString() ?? '',
      namaKelas: json['namaKelas']?.toString() ?? json['nama']?.toString() ?? '',
      kodeKelas: json['kodeKelas']?.toString() ?? json['kode']?.toString() ?? '',
      qrData: json['qrData']?.toString() ?? '',
      guruUid: json['guruUid']?.toString() ?? json['guruId']?.toString() ?? '',
      guruNama: json['guruNama']?.toString() ?? '',
      namaSekolah: json['namaSekolah']?.toString() ?? '',
      tingkat: json['tingkat']?.toString() ?? '',
      tahunAjaran: json['tahunAjaran']?.toString() ?? '',
      mataPelajaran: json['mataPelajaran']?.toString() ?? '',
      status: json['status']?.toString() ?? (json['isActive'] == false ? 'nonaktif' : 'aktif'),
      muridIds: json['muridIds'] is List
          ? List<String>.from(json['muridIds'].map((e) => e.toString()))
          : [],
      exitedMurids: json['exitedMurids'] is List
          ? List<Map<String, dynamic>>.from(
              (json['exitedMurids'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
          : const [],
      totalMurid: json['totalMurid'] is num ? (json['totalMurid'] as num).toInt() : (json['muridIds'] is List ? (json['muridIds'] as List).length : 0),
      totalKarya: json['totalKarya'] is num ? (json['totalKarya'] as num).toInt() : 0,
      avgNilai: json['avgNilai'] is num ? (json['avgNilai'] as num).toDouble() : 0.0,
      createdAt: parseTimestamp(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? parseTimestamp(json['updatedAt']) : parseTimestamp(json['createdAt']),
      nonaktifkanAt: json['nonaktifkanAt'] != null ? parseTimestamp(json['nonaktifkanAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kelasId': kelasId,
      'namaKelas': namaKelas,
      'kodeKelas': kodeKelas,
      'qrData': qrData,
      'guruUid': guruUid,
      'guruNama': guruNama,
      'namaSekolah': namaSekolah,
      'tingkat': tingkat,
      'tahunAjaran': tahunAjaran,
      'mataPelajaran': mataPelajaran,
      'status': status,
      'muridIds': muridIds,
      'exitedMurids': exitedMurids,
      'totalMurid': totalMurid,
      'totalKarya': totalKarya,
      'avgNilai': avgNilai,
      'isActive': isActive, // for backward compatibility
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (nonaktifkanAt != null) 'nonaktifkanAt': Timestamp.fromDate(nonaktifkanAt!),
    };
  }

  KelasModel copyWith({
    String? kelasId,
    String? namaKelas,
    String? kodeKelas,
    String? qrData,
    String? guruUid,
    String? guruNama,
    String? namaSekolah,
    String? tingkat,
    String? tahunAjaran,
    String? mataPelajaran,
    String? status,
    List<String>? muridIds,
    List<Map<String, dynamic>>? exitedMurids,
    int? totalMurid,
    int? totalKarya,
    double? avgNilai,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? nonaktifkanAt,
  }) {
    return KelasModel(
      kelasId: kelasId ?? this.kelasId,
      namaKelas: namaKelas ?? this.namaKelas,
      kodeKelas: kodeKelas ?? this.kodeKelas,
      qrData: qrData ?? this.qrData,
      guruUid: guruUid ?? this.guruUid,
      guruNama: guruNama ?? this.guruNama,
      namaSekolah: namaSekolah ?? this.namaSekolah,
      tingkat: tingkat ?? this.tingkat,
      tahunAjaran: tahunAjaran ?? this.tahunAjaran,
      mataPelajaran: mataPelajaran ?? this.mataPelajaran,
      status: status ?? this.status,
      muridIds: muridIds ?? this.muridIds,
      exitedMurids: exitedMurids ?? this.exitedMurids,
      totalMurid: totalMurid ?? this.totalMurid,
      totalKarya: totalKarya ?? this.totalKarya,
      avgNilai: avgNilai ?? this.avgNilai,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      nonaktifkanAt: nonaktifkanAt ?? this.nonaktifkanAt,
    );
  }
}
