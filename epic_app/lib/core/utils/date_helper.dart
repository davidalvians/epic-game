// Helper sapaan berdasarkan waktu (pagi/siang/sore/malam)

/// Menghasilkan sapaan dinamis berdasarkan waktu saat ini.
class DateHelper {
  DateHelper._();

  /// Mendapatkan sapaan dengan nama dan emoji sesuai waktu.
  /// Contoh: "Selamat Pagi, Arif! ☀️"
  static String getGreeting(String name) {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 11) {
      return 'Selamat Pagi, $name! ☀️';
    } else if (hour >= 11 && hour < 15) {
      return 'Selamat Siang, $name! 🌤️';
    } else if (hour >= 15 && hour < 18) {
      return 'Selamat Sore, $name! 🌅';
    } else {
      return 'Selamat Malam, $name! 🌙';
    }
  }

  /// Mendapatkan emoji waktu saja.
  static String getTimeEmoji() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 11) return '☀️';
    if (hour >= 11 && hour < 15) return '🌤️';
    if (hour >= 15 && hour < 18) return '🌅';
    return '🌙';
  }

  /// Mendapatkan kata sapaan saja (tanpa nama dan emoji).
  static String getGreetingWord() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 11) return 'Selamat Pagi';
    if (hour >= 11 && hour < 15) return 'Selamat Siang';
    if (hour >= 15 && hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }
}
