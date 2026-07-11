part of '../drawing_screen.dart';

class _DrawingCanvas extends StatelessWidget {
  final DrawingController controller;

  const _DrawingCanvas({required this.controller});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final double maxHeight = constraints.maxHeight;
        
        // Calculate paper size (A4 ratio)
        double paperWidth = maxWidth - 32;
        double paperHeight = paperWidth * 1.414;
        if (paperHeight > maxHeight - 220) {
          paperHeight = maxHeight - 220;
          paperWidth = paperHeight / 1.414;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.setDefaultCanvasSize(maxWidth, maxHeight, paperWidth, paperHeight);
        });

        return Listener(
          onPointerDown: controller.onPointerDown,
          onPointerMove: controller.onPointerMove,
          onPointerUp: controller.onPointerUp,
          onPointerCancel: controller.onPointerCancel,
          behavior: HitTestBehavior.opaque,
          child: Container(
            color: Colors.transparent,
            child: Obx(() {
              return Transform(
                transform: controller.canvasMatrix.value,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: RepaintBoundary(
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
                          )
                        ],
                      ),
                      child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Template overlay (di belakang drawing/kertas bawah) ──
                if (controller.activeTemplate.value != null)
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
                ...controller.layers.expand((layer) {
                  if (!layer.isVisible.value) return <Widget>[];
                  
                  final layerIndex = controller.layers.indexOf(layer);
                  return [
                    // 1. Coretan untuk layer ini
                    CustomPaint(
                      painter: _DrawingPainter(
                        layers: [layer],
                        currentStroke: controller.activeLayerIndex.value == layerIndex 
                                       ? controller.currentStroke.value : null,
                        activeLayerIndex: 0,
                        zoomScale: controller.canvasMatrix.value.getMaxScaleOnAxis(),
                      ),
                      child: Container(),
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
                if (controller.kategori.toLowerCase() == 'batik' && controller.level == 2)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _CenterSymmetryLinePainter(),
                      ),
                    ),
                  ),

                // ── Preview Pipet Warna Melayang ──
                if (controller.activeTool.value == DrawingTool.eyedropper &&
                    controller.eyedropperPosition.value != null)
                  Positioned(
                    left: controller.eyedropperPosition.value!.dx - 30,
                    top: controller.eyedropperPosition.value!.dy - 90, // Tampil di atas jari agar tidak tertutup
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
  }),
),
);
      },
    );
  }
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
