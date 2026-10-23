import 'dart:math' as math;
import 'dart:ui';

import '../models/drawing_models.dart';

/// Deterministic profile/test data. Not connected to any production route.
List<DrawingLayer> buildDrawingStressFixture(int count, Size paper,
    {bool longStrokes = false}) {
  final random = math.Random(1977);
  final layers = List.generate(3, (i) => DrawingLayer(id: 'stress-$i'));
  const shapes = [
    'lingkaran',
    'persegi',
    'persegi_panjang',
    'segitiga',
    'bintang',
    'love',
    'bunga',
  ];
  for (var i = 0; i < count; i++) {
    final tool = i % 17 == 0
        ? DrawingTool.eraser
        : i % 29 == 0
            ? DrawingTool.shape
            : i % 31 == 0
                ? DrawingTool.symbol
                : DrawingTool.pencil;
    final dot = i % 19 == 0;
    final straight = i % 23 == 0;
    final points = List.generate(
      dot
          ? 1
          : straight || tool == DrawingTool.shape || tool == DrawingTool.symbol
              ? 2
              : i % 7 == 0
                  ? (longStrokes ? 512 : 80)
                  : 12,
      (_) => Offset(
        random.nextDouble() * paper.width,
        random.nextDouble() * paper.height,
      ),
    );
    layers[i % layers.length].strokes.add(
          DrawingStroke(
            tool: tool,
            pencilType: PencilType.values[i % 4],
            points: points,
            color: Color.fromARGB(
              220,
              random.nextInt(256),
              random.nextInt(256),
              random.nextInt(256),
            ),
            thickness: i % 3 == 0 ? 40 : 2 + random.nextDouble() * 25,
            opacity: 0.8,
            isDot: dot,
            isStraightLine: straight,
            shapeType: shapes[(i ~/ 29) % shapes.length],
          ),
        );
  }
  return layers;
}
