import 'dart:math';

/// Struktur vektor motif Kelarai Bunga Api untuk Anyaman Level 4.
///
/// Setiap karakter mewakili satu segmen garis pada kisi 29 x 29. Pola ini
/// diturunkan dari referensi visual agar bidang horizontal dan vertikal tetap
/// dapat diwarnai sebagai satu bilah utuh.
const int level4BungaApiSize = 29;

const List<String> level4BungaApiHorizontalEdges = [
  '11111111111111111111111111111',
  '00000111101111111110111100000',
  '00100111010111111101011100100',
  '00100111010111111101011100100',
  '00000111101111111110111100000',
  '01010011111111111111111001010',
  '11011001111111011111110011011',
  '11011101111110101111110111011',
  '11011111111110101111111111011',
  '10101111111111011111111110101',
  '10101111110111011101111110101',
  '11011111110011011001111111011',
  '11111111111001010011111111111',
  '11111110111100000111101111111',
  '11111101011100100111010111111',
  '11111101011100100111010111111',
  '11111110111100000111101111111',
  '11111111111001010011111111111',
  '11011111110011011001111111011',
  '10101111110111011101111110101',
  '10101111111111011111111110101',
  '11011111111110101111111111011',
  '11011101111110101111110111011',
  '11011001111111011111110011011',
  '01010011111111111111111001010',
  '00000111101111111110111100000',
  '00100111010111111101011100100',
  '00100111010111111101011100100',
  '00000111101111111110111100000',
  '11111111111111111111111111111',
];

const List<String> level4BungaApiVerticalEdges = [
  '111111100110110011011001111111',
  '111111001111011110111100111111',
  '111111111111101101111111111111',
  '111111001111011110111100111111',
  '111111100110110011011001111111',
  '111111110001101101100011111111',
  '101101111011011110110111101101',
  '101100110110111111011011001101',
  '111110001100011110001100011111',
  '111111011011001100110110111111',
  '111110110111101101111011011111',
  '101101100011111111110001101101',
  '110011011001111111100110110011',
  '111110111100111111001111011111',
  '101101111111111111111111101101',
  '111110111100111111001111011111',
  '110011011001111111100110110011',
  '101101100011111111110001101101',
  '111110110111101101111011011111',
  '111111011011001100110110111111',
  '111110001100011110001100011111',
  '101100110110111111011011001101',
  '101101111011011110110111101101',
  '111111110001101101100011111111',
  '111111100110110011011001111111',
  '111111001111011110111100111111',
  '111111111111101101111111111111',
  '111111001111011110111100111111',
  '111111100110110011011001111111',
];

bool level4HasHorizontalEdge(int boundaryRow, int column) =>
    level4BungaApiHorizontalEdges[boundaryRow].codeUnitAt(column) == 49;

bool level4HasVerticalEdge(int row, int boundaryColumn) =>
    level4BungaApiVerticalEdges[row].codeUnitAt(boundaryColumn) == 49;

final List<List<Point<int>>> level4BungaApiRegions = _buildLevel4Regions();

final List<int> _level4BungaApiRegionIndexByCell =
    _buildLevel4RegionIndexByCell();

List<Point<int>> level4BungaApiRegionForCell(int row, int column) {
  if (row < 0 ||
      row >= level4BungaApiSize ||
      column < 0 ||
      column >= level4BungaApiSize) {
    return const [];
  }

  final regionIndex =
      _level4BungaApiRegionIndexByCell[row * level4BungaApiSize + column];
  return level4BungaApiRegions[regionIndex];
}

List<List<Point<int>>> _buildLevel4Regions() {
  final regions = <List<Point<int>>>[];
  final assigned = <int>{};
  for (int row = 0; row < level4BungaApiSize; row++) {
    for (int column = 0; column < level4BungaApiSize; column++) {
      final key = row * level4BungaApiSize + column;
      if (assigned.contains(key)) continue;
      final region = _findLevel4Region(row, column);
      regions.add(region);
      for (final cell in region) {
        assigned.add(cell.y * level4BungaApiSize + cell.x);
      }
    }
  }
  return regions;
}

List<int> _buildLevel4RegionIndexByCell() {
  final indexes = List<int>.filled(
    level4BungaApiSize * level4BungaApiSize,
    -1,
  );
  for (int index = 0; index < level4BungaApiRegions.length; index++) {
    for (final cell in level4BungaApiRegions[index]) {
      indexes[cell.y * level4BungaApiSize + cell.x] = index;
    }
  }
  return indexes;
}

List<Point<int>> _findLevel4Region(int row, int column) {

  final result = <Point<int>>[];
  final pending = <Point<int>>[Point(column, row)];
  final visited = <int>{row * level4BungaApiSize + column};

  while (pending.isNotEmpty) {
    final cell = pending.removeLast();
    result.add(cell);
    final cellRow = cell.y;
    final cellColumn = cell.x;

    void addCell(int nextRow, int nextColumn, bool isBlocked) {
      if (isBlocked ||
          nextRow < 0 ||
          nextRow >= level4BungaApiSize ||
          nextColumn < 0 ||
          nextColumn >= level4BungaApiSize) {
        return;
      }
      final key = nextRow * level4BungaApiSize + nextColumn;
      if (visited.add(key)) {
        pending.add(Point(nextColumn, nextRow));
      }
    }

    addCell(
      cellRow - 1,
      cellColumn,
      level4HasHorizontalEdge(cellRow, cellColumn),
    );
    addCell(
      cellRow + 1,
      cellColumn,
      level4HasHorizontalEdge(cellRow + 1, cellColumn),
    );
    addCell(
      cellRow,
      cellColumn - 1,
      level4HasVerticalEdge(cellRow, cellColumn),
    );
    addCell(
      cellRow,
      cellColumn + 1,
      level4HasVerticalEdge(cellRow, cellColumn + 1),
    );
  }

  return result;
}
