/// Data model untuk karakter yang bisa di-unlock.
/// Sistem: tidak dibeli, melainkan di-unlock ketika poin user mencapai threshold.
class CharacterModel {
  final String id;
  final String nama;
  final String deskripsi;
  final String tier;           // common, uncommon, rare, legendary
  final int poinUnlock;        // Poin minimum untuk unlock karakter ini
  final String imageUrl;
  final bool isActive;         // Apakah karakter tampil di toko

  const CharacterModel({
    required this.id,
    required this.nama,
    required this.deskripsi,
    required this.tier,
    required this.poinUnlock,
    required this.imageUrl,
    this.isActive = true,
  });

  factory CharacterModel.fromJson(Map<String, dynamic> json) {
    return CharacterModel(
      id: json['id']?.toString() ?? '',
      nama: json['nama']?.toString() ?? '',
      deskripsi: json['deskripsi']?.toString() ?? '',
      tier: json['tier']?.toString() ?? 'common',
      poinUnlock: json['poinUnlock'] as int? ?? 0,
      imageUrl: json['imageUrl']?.toString() ?? '',
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama': nama,
      'deskripsi': deskripsi,
      'tier': tier,
      'poinUnlock': poinUnlock,
      'imageUrl': imageUrl,
      'isActive': isActive,
    };
  }

  CharacterModel copyWith({
    String? id,
    String? nama,
    String? deskripsi,
    String? tier,
    int? poinUnlock,
    String? imageUrl,
    bool? isActive,
  }) {
    return CharacterModel(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      deskripsi: deskripsi ?? this.deskripsi,
      tier: tier ?? this.tier,
      poinUnlock: poinUnlock ?? this.poinUnlock,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
    );
  }
}
