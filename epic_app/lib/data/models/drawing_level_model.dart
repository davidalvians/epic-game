/// Model untuk satu level dalam game menggambar.
class DrawingLevel {
  final int level;           // 1-4
  final String kategori;     // keris / batik / anyaman
  final String judul;
  final String deskripsi;
  final int bestSkor;        // Skor terbaik yang pernah dicapai (0-100)
  final int bestPoin;        // Poin terbaik yang pernah didapat
  final bool isUnlocked;     // Apakah level ini sudah bisa dimainkan
  final bool isCompleted;    // Apakah sudah pernah diselesaikan (skor > 0)

  const DrawingLevel({
    required this.level,
    required this.kategori,
    required this.judul,
    required this.deskripsi,
    required this.bestSkor,
    required this.bestPoin,
    required this.isUnlocked,
    required this.isCompleted,
  });

  /// Level dianggap selesai jika skor >= 60 (untuk unlock level berikutnya).
  bool get cukupUntukUnlockBerikutnya => bestSkor >= 60;

  DrawingLevel copyWith({
    int? bestSkor,
    int? bestPoin,
    bool? isUnlocked,
    bool? isCompleted,
  }) {
    return DrawingLevel(
      level: level,
      kategori: kategori,
      judul: judul,
      deskripsi: deskripsi,
      bestSkor: bestSkor ?? this.bestSkor,
      bestPoin: bestPoin ?? this.bestPoin,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
