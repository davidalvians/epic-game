import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/services/app_config_service.dart';

/// Data model untuk profil pengguna/pemain.
/// Mendukung 3 role: murid, guru, admin.
class UserModel {
  final String uid;
  final String namaLengkap;
  final String namaPanggilan;
  final String username;         // Unik, 4-20 char, alphanumeric + underscore
  final String email;
  final String avatarUrl;
  final String role;             // 'murid' | 'guru' | 'admin'
  final bool isProfileComplete;  // false = redirect ke onboarding
  final bool geminiPermission;   // true = user sudah grant Gemini scope
  final int poin;                // Total poin
  final int nyawa;               // Sisa nyawa hari ini (max 3)
  final DateTime nyawaLastReset; // Kapan terakhir nyawa di-reset
  final String karakterAktif;
  final List<String> karakterDimiliki;
  final DateTime createdAt;

  // Data Sekolah & Domisili
  final String sekolah;          // WAJIB diisi saat onboarding
  final String provinsi;
  final String kabupaten;
  final String kecamatan;
  final String kelas;            // '1 SD' - '6 SD' (khusus murid, opsional)

  // Fitur Guru
  final String guruStatus;       // 'none' | 'pending' | 'approved' | 'rejected'
  final String? mataPelajaran;   // Opsional untuk guru
  final String? buktiUrl;
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final int totalKelas;

  // Kelas yang diikuti/dimiliki
  final List<String> kelasIds;

  // Status Keaktifan & Penangguhan (Suspended)
  final String status;           // 'active' | 'suspended'
  final bool isActive;           // true | false

  // Status Keaktifan
  final DateTime? lastActiveAt;

  // Sesi & Perangkat Keamanan Akun
  final List<Map<String, dynamic>> devices;
  final List<Map<String, dynamic>> loginHistory;

  static const int maxNyawa = 3;

  const UserModel({
    required this.uid,
    required this.namaLengkap,
    required this.namaPanggilan,
    this.username = '',
    required this.email,
    required this.avatarUrl,
    this.role = 'murid',
    this.isProfileComplete = false,
    this.geminiPermission = false,
    required this.poin,
    required this.nyawa,
    required this.nyawaLastReset,
    required this.karakterAktif,
    required this.karakterDimiliki,
    required this.createdAt,
    required this.sekolah,
    this.provinsi = '',
    this.kabupaten = '',
    this.kecamatan = '',
    this.kelas = '',
    this.guruStatus = 'none',
    this.mataPelajaran,
    this.buktiUrl,
    this.verifiedAt,
    this.verifiedBy,
    this.totalKelas = 0,
    this.kelasIds = const [],
    this.lastActiveAt,
    this.devices = const [],
    this.loginHistory = const [],
    this.status = 'active',
    this.isActive = true,
  });

  /// Cek apakah nyawa perlu direset (hari baru).
  bool get perluResetNyawa {
    final now = DateTime.now();
    final lastReset = nyawaLastReset.toLocal();
    return now.year != lastReset.year ||
        now.month != lastReset.month ||
        now.day != lastReset.day;
  }

  /// Nyawa efektif (sudah diperhitungkan reset harian).
  int get nyawaEfektif {
    int currentMaxNyawa = maxNyawa;
    try {
      if (Get.isRegistered<AppConfigService>()) {
        currentMaxNyawa = Get.find<AppConfigService>().maxNyawa.value;
      }
    } catch (_) {}
    return perluResetNyawa ? currentMaxNyawa : nyawa;
  }

  /// Apakah masih punya nyawa.
  bool get adaNyawa => nyawaEfektif > 0;

  /// Role helpers
  bool get isMurid => role == 'murid';
  bool get isGuru => role == 'guru';
  bool get isAdmin => role == 'admin';
  bool get isGuruVerified => isGuru && guruStatus == 'approved';
  bool get isGuruPending => isGuru && guruStatus == 'pending';
  bool get isGuruRejected => isGuru && guruStatus == 'rejected';

  UserModel copyWith({
    String? uid,
    String? namaLengkap,
    String? namaPanggilan,
    String? username,
    String? email,
    String? avatarUrl,
    String? role,
    bool? isProfileComplete,
    bool? geminiPermission,
    int? poin,
    int? nyawa,
    DateTime? nyawaLastReset,
    String? karakterAktif,
    List<String>? karakterDimiliki,
    DateTime? createdAt,
    String? sekolah,
    String? provinsi,
    String? kabupaten,
    String? kecamatan,
    String? kelas,
    String? guruStatus,
    String? mataPelajaran,
    String? buktiUrl,
    DateTime? verifiedAt,
    String? verifiedBy,
    int? totalKelas,
    List<String>? kelasIds,
    DateTime? lastActiveAt,
    List<Map<String, dynamic>>? devices,
    List<Map<String, dynamic>>? loginHistory,
    String? status,
    bool? isActive,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      namaLengkap: namaLengkap ?? this.namaLengkap,
      namaPanggilan: namaPanggilan ?? this.namaPanggilan,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      geminiPermission: geminiPermission ?? this.geminiPermission,
      poin: poin ?? this.poin,
      nyawa: nyawa ?? this.nyawa,
      nyawaLastReset: nyawaLastReset ?? this.nyawaLastReset,
      karakterAktif: karakterAktif ?? this.karakterAktif,
      karakterDimiliki: karakterDimiliki ?? this.karakterDimiliki,
      createdAt: createdAt ?? this.createdAt,
      sekolah: sekolah ?? this.sekolah,
      provinsi: provinsi ?? this.provinsi,
      kabupaten: kabupaten ?? this.kabupaten,
      kecamatan: kecamatan ?? this.kecamatan,
      kelas: kelas ?? this.kelas,
      guruStatus: guruStatus ?? this.guruStatus,
      mataPelajaran: mataPelajaran ?? this.mataPelajaran,
      buktiUrl: buktiUrl ?? this.buktiUrl,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      totalKelas: totalKelas ?? this.totalKelas,
      kelasIds: kelasIds ?? this.kelasIds,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      devices: devices ?? this.devices,
      loginHistory: loginHistory ?? this.loginHistory,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Konversi dari JSON (Firestore map).
  factory UserModel.fromJson(Map<String, dynamic> json) {
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

    return UserModel(
      uid: json['uid']?.toString() ?? '',
      namaLengkap: json['namaLengkap']?.toString() ?? '',
      namaPanggilan: json['namaPanggilan']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      role: json['role']?.toString() ?? 'murid',
      isProfileComplete: json['isProfileComplete'] == true,
      geminiPermission: json['geminiPermission'] == true,
      poin: parseSafeInt(json['poin'], 0),
      nyawa: parseSafeInt(json['nyawa'], maxNyawa),
      nyawaLastReset: parseTimestamp(json['nyawaLastReset']),
      karakterAktif: json['karakterAktif']?.toString() ?? 'epi_default',
      karakterDimiliki: json['karakterDimiliki'] is List
          ? (() {
              final list = List<String>.from(
                  json['karakterDimiliki'].map((e) => e.toString()));
              if (!list.contains('epi_default')) list.add('epi_default');
              if (!list.contains('ipeh_default')) list.add('ipeh_default');
              return list;
            })()
          : const ['epi_default', 'ipeh_default'],
      createdAt: parseTimestamp(json['createdAt']),
      sekolah: json['sekolah']?.toString() ?? '',
      provinsi: json['provinsi']?.toString() ?? '',
      kabupaten: json['kabupaten']?.toString() ?? '',
      kecamatan: json['kecamatan']?.toString() ?? '',
      kelas: json['kelas']?.toString() ?? '',
      guruStatus: json['guruStatus']?.toString() ?? json['verifikasiStatus']?.toString() ?? 'none', // Fallback to old key
      mataPelajaran: json['mataPelajaran']?.toString(),
      buktiUrl: json['buktiUrl']?.toString(),
      verifiedAt: json['verifiedAt'] != null ? parseTimestamp(json['verifiedAt']) : null,
      verifiedBy: json['verifiedBy']?.toString(),
      totalKelas: parseSafeInt(json['totalKelas'], 0),
      kelasIds: json['kelasIds'] is List
          ? List<String>.from(json['kelasIds'].map((e) => e.toString()))
          : [],
      lastActiveAt: json['lastActiveAt'] != null ? parseTimestamp(json['lastActiveAt']) : null,
      devices: json['devices'] is List
          ? List<Map<String, dynamic>>.from(
              (json['devices'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
          : const [],
      loginHistory: json['loginHistory'] is List
          ? List<Map<String, dynamic>>.from(
              (json['loginHistory'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
          : const [],
      status: json['status']?.toString() ?? 'active',
      isActive: json['isActive'] ?? true,
    );
  }

  /// Konversi ke JSON untuk disimpan di Firestore.
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'namaLengkap': namaLengkap,
      'namaPanggilan': namaPanggilan,
      'username': username,
      'email': email,
      'avatarUrl': avatarUrl,
      'role': role,
      'isProfileComplete': isProfileComplete,
      'geminiPermission': geminiPermission,
      'poin': poin,
      'nyawa': nyawa,
      'nyawaLastReset': Timestamp.fromDate(nyawaLastReset),
      'karakterAktif': karakterAktif,
      'karakterDimiliki': karakterDimiliki,
      'createdAt': Timestamp.fromDate(createdAt),
      'sekolah': sekolah,
      'provinsi': provinsi,
      'kabupaten': kabupaten,
      'kecamatan': kecamatan,
      'kelas': kelas,
      'guruStatus': guruStatus,
      'mataPelajaran': mataPelajaran,
      if (buktiUrl != null) 'buktiUrl': buktiUrl,
      if (verifiedAt != null) 'verifiedAt': Timestamp.fromDate(verifiedAt!),
      if (verifiedBy != null) 'verifiedBy': verifiedBy,
      'totalKelas': totalKelas,
      'kelasIds': kelasIds,
      if (lastActiveAt != null) 'lastActiveAt': Timestamp.fromDate(lastActiveAt!),
      'devices': devices,
      'loginHistory': loginHistory,
      'status': status,
      'isActive': isActive,
    };
  }
}
