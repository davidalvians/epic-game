part of '../drawing_screen.dart';

class _DrawingPainter extends CustomPainter {
  final List<DrawingLayer> layers;
  final DrawingStroke? currentStroke;
  final int activeLayerIndex;
  final double zoomScale;

  const _DrawingPainter({
    required this.layers,
    required this.currentStroke,
    required this.activeLayerIndex,
    this.zoomScale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < layers.length; i++) {
      final layer = layers[i];
      if (!layer.isVisible.value) continue;

      if (size.width <= 0 || size.height <= 0) continue;
      
      canvas.saveLayer(Offset.zero & size, Paint());

      for (final stroke in layer.strokes) {
        _paintStroke(canvas, stroke, size);
      }
      
      // Render current stroke on the active layer
      if (currentStroke != null && i == activeLayerIndex) {
        _paintStroke(canvas, currentStroke!, size);
      }
      
      canvas.restore();
    }

    // Gambar pratinjau penghapus (eraser preview circle) di luar saveLayer
    if (currentStroke != null && currentStroke!.tool == DrawingTool.eraser && currentStroke!.points.isNotEmpty) {
      final previewPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(
        currentStroke!.points.last,
        currentStroke!.thickness,
        previewPaint,
      );
    }
  }

  void _paintStroke(Canvas canvas, DrawingStroke stroke, Size size) {
    if (stroke.points.isEmpty) return;

    final pencilType = stroke.pencilType;
    final paint = Paint()
      ..strokeCap = stroke.tool == DrawingTool.eraser
          ? StrokeCap.round
          : pencilType.strokeCap
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = stroke.thickness * (
          stroke.tool == DrawingTool.eraser ? 2.0 : pencilType.thicknessMultiplier)
      ..style = PaintingStyle.stroke
      ..blendMode = stroke.tool == DrawingTool.eraser
          ? BlendMode.clear
          : pencilType.blendMode;

    if (stroke.tool == DrawingTool.eraser) {
      paint.color = Colors.transparent; // Akan clear pixels
    } else {
      final opacity = pencilType.opacityFactor;
      final a = stroke.color.a; // nilai double 0.0 - 1.0 pada Flutter 3.27+
      paint.color = stroke.color.withValues(
        alpha: a * opacity,
      );

      // Tambahkan efek realistis
      switch (pencilType) {
        case PencilType.pencil:
          paint.maskFilter = const MaskFilter.blur(BlurStyle.solid, 1.0);
          break;
        case PencilType.watercolor:
          paint.maskFilter = MaskFilter.blur(BlurStyle.normal, stroke.thickness * 0.4);
          break;
        case PencilType.marker:
          // Spidol tajam dan flat
          break;
        case PencilType.ballpoint:
          // Bolpoin tajam dan bersih
          break;
      }
    }

    if (stroke.isDot) {
      canvas.drawCircle(
        stroke.points.first,
        stroke.thickness / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    if (stroke.isStraightLine && stroke.points.length == 2) {
      canvas.drawLine(stroke.points.first, stroke.points.last, paint);
      return;
    }

    if ((stroke.tool == DrawingTool.shape ||
            stroke.tool == DrawingTool.symbol) &&
        stroke.points.length == 2) {
      _paintShapeOrSymbol(canvas, stroke, paint);
      return;
    }

    // Free draw path
    if (stroke.points.length < 2) return;

    // Bolpoin & Spidol: pakai perfect_freehand untuk efek kecepatan (makin cepat = makin tipis)
    final bool usePressureSensitive =
        stroke.tool == DrawingTool.pencil &&
        (pencilType == PencilType.ballpoint || pencilType == PencilType.marker);
    final bool isEraser = stroke.tool == DrawingTool.eraser;

    if (usePressureSensitive || isEraser) {
      // Configure stroke based on tool type
      if (stroke.cachedPath == null) {
        final double thinning = isEraser
            ? 0.0
            : (pencilType == PencilType.ballpoint ? 0.7 : 0.5);
            
        // Limit zoomScale to avoid perfect_freehand blowing up with massive coordinates
        final effectiveZoomScale = zoomScale.clamp(0.2, 4.0);
            
        final options = pf.StrokeOptions(
          size: stroke.thickness * effectiveZoomScale * (isEraser ? 2.0 : pencilType.thicknessMultiplier),
          thinning: thinning,
          smoothing: 0.5,
          streamline: 0.5,
          simulatePressure: true,
        );

        final scaledPoints = stroke.points.map((p) => pf.PointVector(p.dx * effectiveZoomScale, p.dy * effectiveZoomScale)).toList();
        final outlinePoints = pf.getStroke(
          scaledPoints,
          options: options,
        );

        if (outlinePoints.isNotEmpty) {
          final path = Path();
          path.moveTo(outlinePoints[0].dx / effectiveZoomScale, outlinePoints[0].dy / effectiveZoomScale);
          for (int i = 1; i < outlinePoints.length; i++) {
            path.lineTo(outlinePoints[i].dx / effectiveZoomScale, outlinePoints[i].dy / effectiveZoomScale);
          }
          path.close();
          stroke.cachedPath = path;
        } else {
          stroke.cachedPath = Path(); // empty
        }
      }

      paint.style = PaintingStyle.fill;
      canvas.drawPath(stroke.cachedPath!, paint);
      return;
    }

    // Pensil & Cat Air: garis konsisten (tidak berubah tebal berdasarkan kecepatan)
    if (stroke.cachedPath == null) {
      final path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (int i = 1; i < stroke.points.length - 1; i++) {
        final mid = Offset(
          (stroke.points[i].dx + stroke.points[i + 1].dx) / 2,
          (stroke.points[i].dy + stroke.points[i + 1].dy) / 2,
        );
        path.quadraticBezierTo(
          stroke.points[i].dx,
          stroke.points[i].dy,
          mid.dx,
          mid.dy,
        );
      }
      path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
      stroke.cachedPath = path;
    }

    paint.style = PaintingStyle.stroke;
    canvas.drawPath(stroke.cachedPath!, paint);
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter old) => true;

  void _paintShapeOrSymbol(Canvas canvas, DrawingStroke stroke, Paint paint) {
    final p1 = stroke.points.first;
    final p2 = stroke.points.last;
    final center = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
    final radius = (p2 - p1).distance / 2;
    final shapeType = stroke.shapeType ?? 'lingkaran';

    switch (shapeType) {
      case 'lingkaran':
        canvas.drawCircle(center, radius, paint);
        break;
      case 'persegi':
        final rect = Rect.fromPoints(p1, p2);
        canvas.drawRect(rect, paint);
        break;
      case 'persegi_panjang':
        final rect2 = Rect.fromPoints(p1, p2);
        canvas.drawRect(rect2, paint);
        break;
      case 'segitiga':
        final path = Path();
        path.moveTo(center.dx, p1.dy);
        path.lineTo(p2.dx, p2.dy);
        path.lineTo(p1.dx, p2.dy);
        path.close();
        canvas.drawPath(path, paint);
        break;
      case 'bintang':
        _drawStar(canvas, center, radius, paint);
        break;
      case 'love':
        _drawHeart(canvas, center, radius, paint);
        break;
      case 'bunga':
        _drawFlower(canvas, center, radius, paint);
        break;
      default:
        canvas.drawCircle(center, radius, paint);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    const int points = 5;
    final innerRadius = radius * 0.4;
    for (int i = 0; i <= points * 2; i++) {
      final angle = (i * math.pi / points) - math.pi / 2;
      final r = i.isEven ? radius : innerRadius;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawHeart(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    path.moveTo(center.dx, center.dy + radius * 0.3);
    path.cubicTo(
      center.dx + radius, center.dy - radius * 0.5,
      center.dx + radius * 1.5, center.dy + radius * 0.8,
      center.dx, center.dy + radius * 1.3,
    );
    path.cubicTo(
      center.dx - radius * 1.5, center.dy + radius * 0.8,
      center.dx - radius, center.dy - radius * 0.5,
      center.dx, center.dy + radius * 0.3,
    );
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawFlower(Canvas canvas, Offset center, double radius, Paint paint) {
    const petals = 6;
    for (int i = 0; i < petals; i++) {
      final angle = (i * 2 * math.pi / petals);
      final petalCenter = Offset(
        center.dx + radius * 0.6 * math.cos(angle),
        center.dy + radius * 0.6 * math.sin(angle),
      );
      canvas.drawCircle(petalCenter, radius * 0.45, paint);
    }
    canvas.drawCircle(center, radius * 0.3, paint);
  }
}
