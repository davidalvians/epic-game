import 'anyaman_config.dart';
import 'batik_config.dart';
import 'keris_config.dart';

abstract class GameConfig {
  static int getTimerDurasi(String kategori, int level) {
    switch (kategori.toLowerCase()) {
      case 'anyaman':
        return AnyamanConfig.timerDurasiDetik;
      case 'batik':
        return BatikConfig.timerDurasiDetik;
      case 'keris':
      default:
        return KerisConfig.timerDurasiDetik;
    }
  }

  static int getGridSize(String kategori, int level) {
    if (kategori.toLowerCase() == 'anyaman') {
      return AnyamanConfig.gridSizes[level] ?? 8;
    }
    return 0; // Not applicable for other games
  }
}
