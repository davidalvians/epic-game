part of '../drawing_screen.dart';

class _DrawingPainter extends CustomPainter {
  final List<DrawingLayer> layers;
  final ValueGetter<DrawingStroke?>? liveStroke;
  final DrawingLayerCache? cache;
  final bool useRaster;
  final int strokeCount;
  final int contentRevision;
  final int activeLayerIndex;
  final double zoomScale;
  final bool renderStempels;
  final bool lowCostLivePreview;

  _DrawingPainter({
    required this.layers,
    this.liveStroke,
    this.cache,
    this.useRaster = true,
    this.contentRevision = 0,
    super.repaint,
    required this.activeLayerIndex,
    this.zoomScale = 1.0,
    this.renderStempels = true,
    this.lowCostLivePreview = false,
  }) : strokeCount = layers.fold<int>(
          0,
          (n, layer) => n + layer.strokes.length,
        );

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final currentStroke = liveStroke?.call();
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    for (int i = 0; i < layers.length; i++) {
      final layer = layers[i];
      if (!layer.isVisible.value) continue;

      if (cache != null && !renderStempels) {
        cache!.paint(
          canvas,
          size,
          liveStroke: i == activeLayerIndex ? currentStroke : null,
          lowCostLivePreview: lowCostLivePreview,
          zoomScale: zoomScale,
          useRaster: useRaster,
        );
        continue;
      }
      canvas.saveLayer(Offset.zero & size, Paint());
      if (cache != null) {
        cache!.paint(canvas, size, zoomScale: zoomScale);
      } else {
        for (final stroke in layer.strokes) {
          paintDrawingStroke(canvas, stroke, zoomScale: zoomScale);
        }
      }

      // Render stempels
      if (renderStempels) {
        for (final stempel in layer.stempels) {
          canvas.save();

          // stempel.position.value adalah titik awal dari shape box (sebelum margin).
          // _StempelWidget menggunakan box berukuran:
          final double shapeBoxW = 48.0 * stempel.scaleX.value + 16.0;
          final double shapeBoxH = 48.0 * stempel.scaleY.value + 16.0;

          // Pindah ke pusat shape box untuk melakukan rotasi
          final double centerX = stempel.position.value.dx + shapeBoxW / 2;
          final double centerY = stempel.position.value.dy + shapeBoxH / 2;

          canvas.translate(centerX, centerY);
          canvas.rotate(stempel.rotation.value);
          canvas.translate(-centerX, -centerY);

          // Pindah ke posisi gambar aktual (tambah padding 8px dari _StempelWidget)
          canvas.translate(
            stempel.position.value.dx + 8.0,
            stempel.position.value.dy + 8.0,
          );

          final shapePainter = StempelShapePainter(
            shape: stempel.shape,
            color: stempel.color.value,
            strokeWidth: stempel.strokeWidth.value,
            opacity: stempel.opacity.value,
          );

          // Gambar dengan ukuran asli konten
          shapePainter.paint(
            canvas,
            Size(48.0 * stempel.scaleX.value, 48.0 * stempel.scaleY.value),
          );

          canvas.restore();
        }
      }

      // Render current stroke on the active layer
      if (currentStroke != null && i == activeLayerIndex) {
        paintDrawingStroke(
          canvas,
          currentStroke,
          zoomScale: zoomScale,
          isLive: true,
        );
      }

      canvas.restore();
    }

    // Gambar pratinjau penghapus (eraser preview circle) di luar saveLayer
    if (currentStroke != null &&
        currentStroke.tool == DrawingTool.eraser &&
        currentStroke.points.isNotEmpty) {
      final previewPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(
        currentStroke.points.last,
        currentStroke.thickness,
        previewPaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter old) =>
      !listEquals(old.layers, layers) ||
      old.activeLayerIndex != activeLayerIndex ||
      old.zoomScale != zoomScale ||
      old.renderStempels != renderStempels ||
      old.cache != cache ||
      old.useRaster != useRaster ||
      old.contentRevision != contentRevision ||
      old.strokeCount != strokeCount;
}
