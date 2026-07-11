// Fungsi utilitas umum untuk EPIC

/// Helper functions yang digunakan di seluruh aplikasi.
class Helpers {
  Helpers._();

  // ─── Nyawa ─────────────────────────────────────────────────────────────────

  /// Poin minimum untuk tier karakter.
  static const Map<String, int> tierPoinThreshold = {
    'common': 0,
    'uncommon': 500,
    'rare': 1500,
    'legendary': 5000,
  };

  /// Label tier karakter.
  static String getTierLabel(String tier) {
    switch (tier.toLowerCase()) {
      case 'common':   return 'Umum';
      case 'uncommon': return 'Langka';
      case 'rare':     return 'Sangat Langka';
      case 'legendary': return 'Legendaris';
      default:         return tier;
    }
  }

  // ─── Poin ──────────────────────────────────────────────────────────────────

  /// Format angka dengan separator ribuan (titik).
  static String formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]}.',
        );
  }

  /// Kategori label untuk game menggambar.
  static String getKategoriLabel(String kategori) {
    switch (kategori.toLowerCase()) {
      case 'keris':   return 'Keris';
      case 'batik':   return 'Batik';
      case 'anyaman': return 'Anyaman';
      default:        return kategori;
    }
  }

  /// Label level game menggambar.
  static String getLevelLabel(String kategori, int level) {
    final cleanKategori = kategori.toLowerCase();
    if (cleanKategori == 'keris') {
      switch (level) {
        case 1: return 'Gagang Keris';
        case 2: return 'Bilah Keris';
        case 3: return 'Warangka';
        case 4: return 'Keris Sempurna';
        default: return 'Level $level';
      }
    } else if (cleanKategori == 'batik') {
      switch (level) {
        case 1: return 'Pola Berulang';
        case 2: return 'Simetri Cermin';
        case 3: return 'Bangun Geometri';
        case 4: return 'Kreatifitas Batik Bebas';
        default: return 'Level $level';
      }
    } else if (cleanKategori == 'anyaman') {
      switch (level) {
        case 1: return 'Anyaman 2 Warna';
        case 2: return 'Anyaman 3 Warna';
        case 3: return 'Anyaman 4 Warna';
        case 4: return 'Anyaman Bebas';
        default: return 'Level $level';
      }
    }
    return 'Level $level';
  }

  /// Ikon kategori game menggambar.
  static String getKategoriEmoji(String kategori) {
    switch (kategori.toLowerCase()) {
      case 'keris':   return '🗡️';
      case 'batik':   return '🎨';
      case 'anyaman': return '🧺';
      default:        return '🎮';
    }
  }

  /// Poin maksimal yang bisa didapat per level.
  static int maxPoinPerLevel(int level) {
    switch (level) {
      case 1: return 100;
      case 2: return 150;
      case 3: return 200;
      case 4: return 300;
      default: return 100;
    }
  }
}
