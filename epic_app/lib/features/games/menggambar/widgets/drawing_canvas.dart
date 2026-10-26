part of '../drawing_screen.dart';

class _DrawingCanvas extends StatelessWidget {
  final DrawingController controller;
  const _DrawingCanvas({required this.controller});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final maxHeight = constraints.maxHeight;
          final landscape =
              MediaQuery.orientationOf(context) == Orientation.landscape;
          final reservedHeight = landscape ? 32.0 : 220.0;
          if (maxWidth <= 32 || maxHeight <= reservedHeight) {
            return const SizedBox.shrink();
          }
          double fitWidth = maxWidth - 32;
          double fitHeight = fitWidth * 1.414;
          if (fitHeight > maxHeight - reservedHeight) {
            fitHeight = maxHeight - reservedHeight;
            fitWidth = fitHeight / 1.414;
          }
          // Keep stroke/template coordinates stable when the viewport rotates.
          final paperWidth = controller.paperWidth > 0
              ? controller.paperWidth
              : landscape
                  ? MediaQuery.sizeOf(context).shortestSide - 32
                  : fitWidth;
          final paperHeight = controller.paperHeight > 0
              ? controller.paperHeight
              : landscape
                  ? paperWidth * 1.414
                  : fitHeight;
          final pixelRatio = MediaQuery.devicePixelRatioOf(context);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!controller.isClosed) {
              controller.setDefaultCanvasSize(
                maxWidth,
                maxHeight,
                paperWidth,
                paperHeight,
                pixelRatio: pixelRatio,
                fitWidth: fitWidth,
                fitHeight: fitHeight,
              );
            }
          });
          // Reuse this child while only the transform changes.
          final paper = _DrawingPaper(
            controller: controller,
            paperWidth: paperWidth,
            paperHeight: paperHeight,
          );
          return Listener(
            onPointerDown: controller.onPointerDown,
            onPointerMove: controller.onPointerMove,
            onPointerUp: controller.onPointerUp,
            onPointerCancel: controller.onPointerCancel,
            behavior: HitTestBehavior.opaque,
            child: Container(
              color: Colors.transparent,
              child: ClipRect(
                  child: Obx(
                () => Transform(
                  transform: controller.canvasMatrix.value,
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: paperWidth,
                    maxWidth: paperWidth,
                    minHeight: paperHeight,
                    maxHeight: paperHeight,
                    child: paper,
                  ),
                ),
              )),
            ),
          );
        },
      );
}

class _DrawingPaper extends StatelessWidget {
  const _DrawingPaper({
    required this.controller,
    required this.paperWidth,
    required this.paperHeight,
  });
  final DrawingController controller;
  final double paperWidth;
  final double paperHeight;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        key: controller.canvasKey,
        child: SizedBox(
          width: paperWidth,
          height: paperHeight,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRect(
              child: Obx(
                () => Stack(
                  fit: StackFit.expand,
                  children: [
                    // ── Template overlay (di belakang drawing/kertas bawah) ──
                    if (controller.activeTemplate.value != null &&
                        !controller.isCapturing.value)
                      Positioned.fill(
                        child: Opacity(
                          opacity: controller.templateOpacity.value,
                          child: Image.network(
                            controller.activeTemplate.value!.outlineUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              // Jika gagal load, gunakan asset lokal dummy sesuai permintaan user
                              return Image.asset(
                                'assets/images/asetcontoh.png',
                                fit: BoxFit.contain,
                              );
                            },
                          ),
                        ),
                      ),

                    // ── Drawing canvas (per layer) ──
                    if (controller.layers.length > 1 &&
                        controller.layers.every((l) => l.stempels.isEmpty))
                      _CombinedLayerDrawing(controller: controller)
                    else
                      ...controller.layers.expand((layer) {
                        if (!layer.isVisible.value) return <Widget>[];

                        final layerIndex = controller.layers.indexOf(layer);
                        return [
                          // 1. Coretan untuk layer ini
                          // IgnorePointer wajib agar CustomPaint tidak memblokir hit test
                          // ke stempel/bentuk di layer-layer di bawahnya.
                          _LayerDrawing(
                            key: ValueKey(layer),
                            controller: controller,
                            layer: layer,
                            layerIndex: layerIndex,
                          ),
                          // 2. Stempel/Bentuk untuk layer ini
                          ...layer.stempels.map((stempel) {
                            return _StempelWidget(
                              key: ValueKey(stempel.id),
                              stempel: stempel,
                              controller: controller,
                            );
                          }),
                        ];
                      }),
                    // End of Layers & Stempels

                    // ── Garis Panduan Sumbu Simetri (Hanya untuk Batik Level 2) ──
                    if (controller.kategori.toLowerCase() == 'batik' &&
                        controller.level == 2 &&
                        !controller.isCapturing.value)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                              painter: _CenterSymmetryLinePainter()),
                        ),
                      ),

                    // ── Preview Pipet Warna Melayang ──
                    if (controller.activeTool.value == DrawingTool.eyedropper &&
                        controller.eyedropperPosition.value != null &&
                        !controller.isCapturing.value)
                      Positioned(
                        left: controller.eyedropperPosition.value!.dx - 30,
                        top: controller.eyedropperPosition.value!.dy -
                            90, // Tampil di atas jari agar tidak tertutup
                        child: IgnorePointer(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: controller.activeColor.value,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.colorize_rounded,
                                color: Colors.white,
                                size: 24,
                                shadows: [
                                  Shadow(
                                    color: Colors.black45,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _CombinedLayerDrawing extends StatelessWidget {
  const _CombinedLayerDrawing({required this.controller});
  final DrawingController controller;
  @override
  Widget build(BuildContext context) => Obx(() {
        final layers = controller.layers.toList();
        // Observe visibility here as well as in paint.
        final visible = layers.where((l) => l.isVisible.value).toList();
        final active = controller.activeLayerIndex.value;
        final activeLayer =
            active >= 0 && active < layers.length ? layers[active] : null;
        final live = controller.currentStroke.value;
        final liveCanOverlay = live != null &&
            visible.isNotEmpty &&
            identical(activeLayer, visible.last) &&
            canOverlayLiveStroke(live, controller.canvasZoomScale.value);
        controller.renderCache.enableScene();
        return IgnorePointer(
            child: Stack(fit: StackFit.expand, children: [
          RepaintBoundary(
            child: CustomPaint(
              willChange: true,
              painter: _CombinedLayerPainter(
                  controller,
                  visible,
                  activeLayer,
                  controller.canvasZoomScale.value,
                  liveCanOverlay ? null : live,
                  Listenable.merge([
                    controller.renderCache,
                    if (!liveCanOverlay) controller.liveTick,
                    for (final layer in layers)
                      controller.renderCache.forLayer(layer)
                  ])),
              child: const SizedBox.expand(),
            ),
          ),
          if (liveCanOverlay)
            RepaintBoundary(
              child: CustomPaint(
                willChange: true,
                painter: _LiveStrokeOverlayPainter(
                  controller,
                  controller.canvasZoomScale.value,
                  controller.liveTick,
                ),
                child: const SizedBox.expand(),
              ),
            ),
        ]));
      });
}

class _CombinedLayerPainter extends CustomPainter {
  _CombinedLayerPainter(this.controller, this.layers, this.active, this.zoom,
      this.liveStroke, Listenable repaint)
      : super(repaint: repaint);
  final DrawingController controller;
  final List<DrawingLayer> layers;
  final DrawingLayer? active;
  final double zoom;
  final DrawingStroke? liveStroke;
  @override
  void paint(Canvas canvas, Size size) {
    final live = liveStroke == null ? null : controller.currentStroke.value;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (live == null) {
      if (controller.renderCache.paintScene(canvas)) {
        canvas.restore();
        return;
      }
    }
    for (final layer in layers) {
      controller.renderCache.forLayer(layer).paint(canvas, size,
          liveStroke: identical(layer, active) ? live : null,
          lowCostLivePreview: live != null &&
              identical(layer, active) &&
              shouldUseLowCostLivePreview(live, zoom),
          zoomScale: zoom);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CombinedLayerPainter old) =>
      old.zoom != zoom ||
      old.active != active ||
      old.liveStroke != liveStroke ||
      !listEquals(old.layers, layers);
}

class _LiveStrokeOverlayPainter extends CustomPainter {
  _LiveStrokeOverlayPainter(this.controller, this.zoom, Listenable repaint)
      : super(repaint: repaint);
  final DrawingController controller;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = controller.currentStroke.value;
    if (stroke == null || !canOverlayLiveStroke(stroke, zoom)) {
      return;
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    paintDrawingStroke(canvas, stroke,
        zoomScale: zoom,
        isLive: true,
        lowCostLivePreview: shouldUseLowCostLivePreview(stroke, zoom),
        rasterClip: zoom > 1 ? controller.renderCache.viewport : null);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LiveStrokeOverlayPainter old) =>
      old.zoom != zoom;
}

class _LayerDrawing extends StatelessWidget {
  const _LayerDrawing({
    super.key,
    required this.controller,
    required this.layer,
    required this.layerIndex,
  });
  final DrawingController controller;
  final DrawingLayer layer;
  final int layerIndex;

  @override
  Widget build(BuildContext context) => Obx(() {
        final active = controller.activeLayerIndex.value == layerIndex;
        final cache = controller.renderCache.forLayer(layer);
        final live = active ? controller.currentStroke.value : null;
        final liveCanOverlay = live != null &&
            canOverlayLiveStroke(live, controller.canvasZoomScale.value);
        return IgnorePointer(
          child: Stack(fit: StackFit.expand, children: [
            RepaintBoundary(
              child: CustomPaint(
                // Cache textures are already at the requested viewport density.
                willChange: true,
                painter: _DrawingPainter(
                  layers: [layer],
                  activeLayerIndex: active ? 0 : -1,
                  liveStroke: active && !liveCanOverlay
                      ? () => controller.currentStroke.value
                      : null,
                  cache: cache,
                  lowCostLivePreview: live != null &&
                      shouldUseLowCostLivePreview(
                          live, controller.canvasZoomScale.value),
                  repaint: active && !liveCanOverlay
                      ? Listenable.merge([cache, controller.liveTick])
                      : cache,
                  zoomScale: controller.canvasZoomScale.value,
                  // Capture prepares this cache at the requested output density.
                  useRaster: true,
                  renderStempels: false,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            if (liveCanOverlay)
              RepaintBoundary(
                child: CustomPaint(
                  willChange: true,
                  painter: _LiveStrokeOverlayPainter(
                    controller,
                    controller.canvasZoomScale.value,
                    controller.liveTick,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
          ]),
        );
      });
}

class _CenterSymmetryLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final double centerX = size.width / 2;
    const double dashHeight = 8.0;
    const double dashSpace = 6.0;

    double startY = 0.0;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(centerX, startY),
        Offset(centerX, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
