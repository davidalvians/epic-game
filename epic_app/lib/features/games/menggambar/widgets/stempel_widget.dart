part of '../drawing_screen.dart';

class _StempelWidget extends StatefulWidget {
  final StempelModel stempel;
  final DrawingController controller;

  const _StempelWidget({
    super.key,
    required this.stempel,
    required this.controller,
  });

  @override
  State<_StempelWidget> createState() => _StempelWidgetState();
}

class _StempelWidgetState extends State<_StempelWidget> {
  // State interaksi gesture
  double _lastTouchAngle = 0.0;
  double _currentRotation = 0.0;
  Offset _lastDragCanvasPos = Offset.zero;
  Offset _lastResizeCanvasPos = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final stempel = widget.stempel;
      final controller = widget.controller;
      final isActive = controller.activeStempelId.value == stempel.id;
      final zoom =
          controller.canvasZoomScale.value > 0
              ? controller.canvasZoomScale.value
              : 1.0;

      // Dimensi bentuk
      final double contentW = 48.0 * stempel.scaleX.value;
      final double contentH = 48.0 * stempel.scaleY.value;
      final double shapeBoxW = contentW + 16.0;
      final double shapeBoxH = contentH + 16.0;

      // Ukuran visual handle
      final double cornerR = 7.0 / zoom; // Lingkaran sudut diameter 14px
      final double rotR = 13.0 / zoom;   // Tombol rotasi diameter 26px
      final double iconSm = 12.0 / zoom;
      final double iconAction = 14.0 / zoom;

      // Area sentuh aman
      final double touchSize = math.max(28.0 / zoom, 38.0 / zoom);

      // Titik pusat bentuk dalam koordinat kanvas
      final centerCanvas = Offset(
        stempel.position.value.dx + shapeBoxW / 2,
        stempel.position.value.dy + shapeBoxH / 2,
      );

      // Panjang diagonal maksimum bentuk + padding ekstra untuk toolbar dan tombol rotasi
      final double diag = math.sqrt(shapeBoxW * shapeBoxW + shapeBoxH * shapeBoxH);
      final double m = math.max(100.0 / zoom, 100.0);
      final double boxSize = diag + m * 2;

      // Posisi bentuk dalam ruang lokal boxSize
      final double shapeLeft = (boxSize - shapeBoxW) / 2;
      final double shapeTop = (boxSize - shapeBoxH) / 2;
      final double shapeRight = (boxSize + shapeBoxW) / 2;
      final double shapeBottom = (boxSize + shapeBoxH) / 2;
      final double shapeCenterX = boxSize / 2;
      final double shapeCenterY = boxSize / 2;

      return Positioned(
        left: centerCanvas.dx - boxSize / 2,
        top: centerCanvas.dy - boxSize / 2,
        width: boxSize,
        height: boxSize,
        child: IgnorePointer(
          ignoring: controller.activeTool.value != DrawingTool.cursor && !isActive,
          child: Transform.rotate(
            angle: stempel.rotation.value,
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── 1. Kotak Bentuk & Gesture Geser (Move) ──
                Positioned(
                  left: shapeLeft,
                  top: shapeTop,
                  width: shapeBoxW,
                  height: shapeBoxH,
                  child: Listener(
                    behavior: isActive
                        ? HitTestBehavior.opaque
                        : HitTestBehavior.deferToChild,
                    onPointerDown: (event) {
                      if (stempel.isResizing.value) return;
                      controller.isInteractingWithStempel.value = true;
                      controller.setActiveStempel(stempel.id);
                      _lastDragCanvasPos =
                          controller.screenToCanvas(event.position);
                    },
                    onPointerMove: (event) {
                      if (stempel.isResizing.value) return;
                      if (controller.activeStempelId.value != stempel.id) return;
                      final currentCanvasPos =
                          controller.screenToCanvas(event.position);
                      final deltaCanvas = currentCanvasPos - _lastDragCanvasPos;
                      _lastDragCanvasPos = currentCanvasPos;
                      controller.updateStempelPosition(stempel.id, deltaCanvas);
                    },
                    onPointerUp: (_) {
                      controller.isInteractingWithStempel.value = false;
                      controller.persistState();
                    },
                    onPointerCancel: (_) {
                      controller.isInteractingWithStempel.value = false;
                    },
                    child: Container(
                      decoration: isActive
                          ? BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF8B5CF6),
                                width: 1.5 / zoom,
                              ),
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(4),
                            )
                          : null,
                      padding: const EdgeInsets.all(8),
                      child: CustomPaint(
                        painter: StempelShapePainter(
                          shape: stempel.shape,
                          color: stempel.color.value,
                          strokeWidth: stempel.strokeWidth.value,
                          opacity: stempel.opacity.value,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── 2. Handle & Toolbar Interaktif (Tampil saat aktif) ──
                if (isActive) ...[
                  // ─── A. FLOATING ACTION BAR (Atas Mengambang) ─────────────
                  Positioned(
                    key: const ValueKey('stempel_floating_toolbar'),
                    left: shapeCenterX - (66.0 / zoom),
                    top: shapeTop - (42.0 / zoom),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.0 / zoom,
                        vertical: 4.0 / zoom,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Duplikat
                          _buildActionButton(
                            icon: Icons.copy_rounded,
                            size: iconAction,
                            zoom: zoom,
                            tooltip: 'Duplikat',
                            onTap: () => controller.duplicateStempel(stempel),
                          ),
                          SizedBox(width: 4.0 / zoom),
                          // Hapus
                          _buildActionButton(
                            icon: Icons.delete_outline_rounded,
                            size: iconAction,
                            zoom: zoom,
                            tooltip: 'Hapus',
                            color: const Color(0xFFF87171),
                            onTap: () => controller.deleteStempel(stempel.id),
                          ),
                          SizedBox(width: 6.0 / zoom),
                          Container(
                            width: 1.0,
                            height: 14.0 / zoom,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          SizedBox(width: 6.0 / zoom),
                          // Majukan Lapisan
                          _buildActionButton(
                            icon: Icons.flip_to_front_rounded,
                            size: iconAction,
                            zoom: zoom,
                            tooltip: 'Bawa ke Depan',
                            onTap: () => controller.bringStempelForward(stempel.id),
                            onLongPress: () => controller.bringStempelToFront(stempel.id),
                          ),
                          SizedBox(width: 4.0 / zoom),
                          // Mundurkan Lapisan
                          _buildActionButton(
                            icon: Icons.flip_to_back_rounded,
                            size: iconAction,
                            zoom: zoom,
                            tooltip: 'Kirim ke Belakang',
                            onTap: () => controller.sendStempelBackward(stempel.id),
                            onLongPress: () => controller.sendStempelToBack(stempel.id),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ─── B. CORNER HANDLES (4 Sudut - Lingkaran Putih Border Ungu) ──
                  // Kiri Atas (TL)
                  _buildCornerHandle(
                    key: const ValueKey('stempel_corner_tl'),
                    left: shapeLeft - cornerR,
                    top: shapeTop - cornerR,
                    radius: cornerR,
                    touchSize: touchSize,
                    onPointerDown: (event) => _initResize(event),
                    onPointerMove: (event) => _updateResize(event, controller.resizeCornerTopLeft),
                    onPointerUp: _finishResize,
                    onPointerCancel: _finishResize,
                  ),

                  // Kanan Atas (TR)
                  _buildCornerHandle(
                    key: const ValueKey('stempel_corner_tr'),
                    left: shapeRight - cornerR,
                    top: shapeTop - cornerR,
                    radius: cornerR,
                    touchSize: touchSize,
                    onPointerDown: (event) => _initResize(event),
                    onPointerMove: (event) => _updateResize(event, controller.resizeCornerTopRight),
                    onPointerUp: _finishResize,
                    onPointerCancel: _finishResize,
                  ),

                  // Kiri Bawah (BL)
                  _buildCornerHandle(
                    key: const ValueKey('stempel_corner_bl'),
                    left: shapeLeft - cornerR,
                    top: shapeBottom - cornerR,
                    radius: cornerR,
                    touchSize: touchSize,
                    onPointerDown: (event) => _initResize(event),
                    onPointerMove: (event) => _updateResize(event, controller.resizeCornerBottomLeft),
                    onPointerUp: _finishResize,
                    onPointerCancel: _finishResize,
                  ),

                  // Kanan Bawah (BR)
                  _buildCornerHandle(
                    key: const ValueKey('stempel_corner_br'),
                    left: shapeRight - cornerR,
                    top: shapeBottom - cornerR,
                    radius: cornerR,
                    touchSize: touchSize,
                    onPointerDown: (event) => _initResize(event),
                    onPointerMove: (event) => _updateResize(event, controller.resizeCornerBottomRight),
                    onPointerUp: _finishResize,
                    onPointerCancel: _finishResize,
                  ),

                  // ─── C. EDGE PILL HANDLES (4 Sisi - Kapsul Pipih) ─────────
                  // Atas Tengah (Top)
                  _buildPillHandle(
                    key: const ValueKey('stempel_pill_top'),
                    left: shapeCenterX - (8.0 / zoom),
                    top: shapeTop - (3.5 / zoom),
                    width: 16.0 / zoom,
                    height: 7.0 / zoom,
                    touchSize: touchSize,
                    onPointerDown: (event) => _initResize(event),
                    onPointerMove: (event) => _updateResize(event, controller.resizeTop),
                    onPointerUp: _finishResize,
                    onPointerCancel: _finishResize,
                  ),

                  // Bawah Tengah (Bottom)
                  _buildPillHandle(
                    key: const ValueKey('stempel_pill_bottom'),
                    left: shapeCenterX - (8.0 / zoom),
                    top: shapeBottom - (3.5 / zoom),
                    width: 16.0 / zoom,
                    height: 7.0 / zoom,
                    touchSize: touchSize,
                    onPointerDown: (event) => _initResize(event),
                    onPointerMove: (event) => _updateResize(event, controller.resizeBottom),
                    onPointerUp: _finishResize,
                    onPointerCancel: _finishResize,
                  ),

                  // Kiri Tengah (Left)
                  _buildPillHandle(
                    key: const ValueKey('stempel_pill_left'),
                    left: shapeLeft - (3.5 / zoom),
                    top: shapeCenterY - (8.0 / zoom),
                    width: 7.0 / zoom,
                    height: 16.0 / zoom,
                    touchSize: touchSize,
                    onPointerDown: (event) => _initResize(event),
                    onPointerMove: (event) => _updateResize(event, controller.resizeLeft),
                    onPointerUp: _finishResize,
                    onPointerCancel: _finishResize,
                  ),

                  // Kanan Tengah (Right)
                  _buildPillHandle(
                    key: const ValueKey('stempel_pill_right'),
                    left: shapeRight - (3.5 / zoom),
                    top: shapeCenterY - (8.0 / zoom),
                    width: 7.0 / zoom,
                    height: 16.0 / zoom,
                    touchSize: touchSize,
                    onPointerDown: (event) => _initResize(event),
                    onPointerMove: (event) => _updateResize(event, controller.resizeRight),
                    onPointerUp: _finishResize,
                    onPointerCancel: _finishResize,
                  ),

                  // ─── D. FLOATING ROTATION HANDLE (Bawah Mengambang) ───────
                  Positioned(
                    key: const ValueKey('stempel_handle_rotate'),
                    left: shapeCenterX - touchSize / 2,
                    top: shapeBottom + (24.0 / zoom) - (touchSize - rotR * 2) / 2,
                    width: touchSize,
                    height: touchSize,
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (event) {
                        controller.isInteractingWithStempel.value = true;
                        stempel.isResizing.value = true;
                        final shapeW = 48.0 * stempel.scaleX.value + 16.0;
                        final shapeH = 48.0 * stempel.scaleY.value + 16.0;
                        final center = Offset(
                          stempel.position.value.dx + shapeW / 2,
                          stempel.position.value.dy + shapeH / 2,
                        );
                        final canvasPos =
                            controller.screenToCanvas(event.position);
                        _lastTouchAngle = math.atan2(
                          canvasPos.dy - center.dy,
                          canvasPos.dx - center.dx,
                        );
                        _currentRotation = stempel.rotation.value;
                      },
                      onPointerMove: (event) {
                        final shapeW = 48.0 * stempel.scaleX.value + 16.0;
                        final shapeH = 48.0 * stempel.scaleY.value + 16.0;
                        final center = Offset(
                          stempel.position.value.dx + shapeW / 2,
                          stempel.position.value.dy + shapeH / 2,
                        );
                        final canvasPos =
                            controller.screenToCanvas(event.position);
                        final currentAngle = math.atan2(
                          canvasPos.dy - center.dy,
                          canvasPos.dx - center.dx,
                        );

                        double deltaAngle = currentAngle - _lastTouchAngle;
                        while (deltaAngle > math.pi) {
                          deltaAngle -= 2 * math.pi;
                        }
                        while (deltaAngle < -math.pi) {
                          deltaAngle += 2 * math.pi;
                        }

                        _currentRotation += deltaAngle;
                        _lastTouchAngle = currentAngle;
                        controller.setStempelRotation(stempel.id, _currentRotation);
                      },
                      onPointerUp: (_) {
                        stempel.isResizing.value = false;
                        controller.isInteractingWithStempel.value = false;
                        controller.persistState();
                      },
                      onPointerCancel: (_) {
                        stempel.isResizing.value = false;
                        controller.isInteractingWithStempel.value = false;
                      },
                      child: Center(
                        child: Container(
                          width: rotR * 2,
                          height: rotR * 2,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF8B5CF6),
                              width: 1.5 / zoom,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.sync_rounded,
                            size: iconSm,
                            color: const Color(0xFF8B5CF6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }

  // ── Helper Resize Gestures ────────────────────────────────────────────────

  void _initResize(PointerDownEvent event) {
    widget.controller.isInteractingWithStempel.value = true;
    widget.stempel.isResizing.value = true;
    _lastResizeCanvasPos = widget.controller.screenToCanvas(event.position);
  }

  void _updateResize(PointerMoveEvent event, void Function(String, Offset) resizeFunc) {
    final currentCanvasPos = widget.controller.screenToCanvas(event.position);
    final deltaCanvas = currentCanvasPos - _lastResizeCanvasPos;
    _lastResizeCanvasPos = currentCanvasPos;
    resizeFunc(widget.stempel.id, deltaCanvas);
  }

  void _finishResize(PointerEvent event) {
    widget.stempel.isResizing.value = false;
    widget.controller.isInteractingWithStempel.value = false;
    widget.controller.persistState();
  }

  // ── Helper Widgets ────────────────────────────────────────────────────────

  Widget _buildActionButton({
    required IconData icon,
    required double size,
    required double zoom,
    required String tooltip,
    Color color = Colors.white,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: EdgeInsets.all(4.0 / zoom),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: size, color: color),
      ),
    );
  }

  Widget _buildCornerHandle({
    Key? key,
    required double left,
    required double top,
    required double radius,
    required double touchSize,
    required PointerDownEventListener onPointerDown,
    required PointerMoveEventListener onPointerMove,
    required PointerUpEventListener onPointerUp,
    required PointerCancelEventListener onPointerCancel,
  }) {
    return Positioned(
      key: key,
      left: left - (touchSize - radius * 2) / 2,
      top: top - (touchSize - radius * 2) / 2,
      width: touchSize,
      height: touchSize,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: onPointerDown,
        onPointerMove: onPointerMove,
        onPointerUp: onPointerUp,
        onPointerCancel: onPointerCancel,
        child: Center(
          child: Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF8B5CF6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPillHandle({
    Key? key,
    required double left,
    required double top,
    required double width,
    required double height,
    required double touchSize,
    required PointerDownEventListener onPointerDown,
    required PointerMoveEventListener onPointerMove,
    required PointerUpEventListener onPointerUp,
    required PointerCancelEventListener onPointerCancel,
  }) {
    return Positioned(
      key: key,
      left: left - (touchSize - width) / 2,
      top: top - (touchSize - height) / 2,
      width: touchSize,
      height: touchSize,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: onPointerDown,
        onPointerMove: onPointerMove,
        onPointerUp: onPointerUp,
        onPointerCancel: onPointerCancel,
        child: Center(
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: const Color(0xFF8B5CF6),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
