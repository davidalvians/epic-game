/// Data model untuk leaderboard/ranking.
class ScoreModel {
  final String uid;
  final String nama;
  final String username;
  final String? avatarUrl;
  final String namaSekolah;
  final int totalPoin;
  final int gameSelesai;

  const ScoreModel({
    required this.uid,
    required this.nama,
    this.username = '',
    this.avatarUrl,
    required this.namaSekolah,
    required this.totalPoin,
    required this.gameSelesai,
  });

  factory ScoreModel.fromJson(Map<String, dynamic> json) {
    int parseSafeInt(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? 0;
    }

    return ScoreModel(
      uid: json['uid']?.toString() ?? '',
      nama: json['nama']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString(),
      namaSekolah: json['namaSekolah']?.toString() ?? '',
      totalPoin: parseSafeInt(json['totalPoin']),
      gameSelesai: parseSafeInt(json['gameSelesai']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'nama': nama,
      'username': username,
      'avatarUrl': avatarUrl,
      'namaSekolah': namaSekolah,
      'totalPoin': totalPoin,
      'gameSelesai': gameSelesai,
    };
  }

  ScoreModel copyWith({
    String? uid,
    String? nama,
    String? username,
    String? avatarUrl,
    String? namaSekolah,
    int? totalPoin,
    int? gameSelesai,
  }) {
    return ScoreModel(
      uid: uid ?? this.uid,
      nama: nama ?? this.nama,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      namaSekolah: namaSekolah ?? this.namaSekolah,
      totalPoin: totalPoin ?? this.totalPoin,
      gameSelesai: gameSelesai ?? this.gameSelesai,
    );
  }
}
