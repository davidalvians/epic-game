// Data model untuk merepresentasikan game yang ada di aplikasi.

class GameModel {
  final String id;
  final String nama;
  final String deskripsi;
  final String iconPath;
  final bool isLocked;
  final String kategori;
  final int urutan; // Urutan tampil di list
  final bool isActive; // Apakah game aktif/tersedia

  const GameModel({
    required this.id,
    required this.nama,
    required this.deskripsi,
    required this.iconPath,
    required this.isLocked,
    required this.kategori,
    this.urutan = 0,
    this.isActive = true,
  });

  factory GameModel.fromJson(Map<String, dynamic> json) {
    final rawUrutan = json['urutan'] ?? json['order'];
    return GameModel(
      id: json['id']?.toString() ?? '',
      nama: (json['nama'] ?? json['title'])?.toString() ?? '',
      deskripsi: (json['deskripsi'] ?? json['description'])?.toString() ?? '',
      iconPath: json['iconPath']?.toString() ?? '',
      isLocked: json['isLocked'] as bool? ?? true,
      kategori: json['kategori']?.toString() ?? '',
      urutan: rawUrutan is num ? rawUrutan.toInt() : 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama': nama,
      'deskripsi': deskripsi,
      'iconPath': iconPath,
      'isLocked': isLocked,
      'kategori': kategori,
      'urutan': urutan,
      'isActive': isActive,
    };
  }

  GameModel copyWith({
    String? id,
    String? nama,
    String? deskripsi,
    String? iconPath,
    bool? isLocked,
    String? kategori,
    int? urutan,
    bool? isActive,
  }) {
    return GameModel(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      deskripsi: deskripsi ?? this.deskripsi,
      iconPath: iconPath ?? this.iconPath,
      isLocked: isLocked ?? this.isLocked,
      kategori: kategori ?? this.kategori,
      urutan: urutan ?? this.urutan,
      isActive: isActive ?? this.isActive,
    );
  }
}
