abstract class AnyamanConfig {
  static const Map<int, int> gridSizes = {
    1: 8,
    // 6 x 6 blok, masing-masing berisi 4 bilah persegi panjang.
    2: 24,
    // 5 x 5 motif spiral diagonal, masing-masing memakai 4 slot logis.
    3: 20,
    4: 29,
  };
  
  static const int timerDurasiDetik = 15 * 60; // 15 menit default
}
