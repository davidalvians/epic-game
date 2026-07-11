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
  // GlobalKey untuk mengambil posisi global pusat bentuk (dipakai untuk rotasi atan2)
  final GlobalKey _shapeKey = GlobalKey();

  // State rotasi — disimpan saat pan mulai
  double _stempelStartRotation = 0.0;
  double _rotStartAngle = 0.0;

  /// Dapatkan koordinat global pusat bentuk menggunakan RenderBox
  Offset _getShapeCenterGlobal() {
    final renderBox =
        _shapeKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) return Offset.zero;
    final size = renderBox.size;
    return renderBox.localToGlobal(Offset(size.width / 2, size.height / 2));
  }

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

      // Ukuran handle — selalu sama di layar terlepas dari zoom
      final double hr = 14.0 / zoom;
      final double iconLg = 13.0 / zoom;
      final double iconSm = 10.0 / zoom;

      final double contentW = 48.0 * stempel.scaleX.value;
      final double contentH = 48.0 * stempel.scaleY.value;
      // Kotak bentuk termasuk padding sentuh 8px tiap sisi
      final double shapeBoxW = contentW + 16.0;
      final double shapeBoxH = contentH + 16.0;

      // Margin di luar kotak bentuk agar handle berada DALAM SizedBox
      final double mSide = hr;              // kiri/kanan
      final double mTop = hr * 2 + 8.0 / zoom; // atas (ruang tombol layer)
      final double mBot = hr;              // bawah

      // Total ukuran SizedBox pembungkus
      final double totalW = shapeBoxW + mSide * 2;
      final double totalH = shapeBoxH + mTop + mBot;

      // Posisi kotak bentuk di dalam SizedBox
      final double sx = mSide;
      final double sy = mTop;

      return Positioned(
        // Offset Positioned agar bentuk muncul tepat di stempel.position
        // Matematika: layar = zoom × (left + sx) = zoom × (pos.dx - mSide + mSide) = zoom × pos.dx ✓
        left: stempel.position.value.dx - mSide,
        top: stempel.position.value.dy - mTop,
        child: IgnorePointer(
          // Abaikan sentuhan ketika tidak dalam mode kursor
          ignoring: controller.activeTool.value != DrawingTool.cursor &&
              !isActive,
          child: SizedBox(
            width: totalW,
            height: totalH,
            child: Stack(
              // Semua child berada DALAM bounds SizedBox → hit test benar ✓
              clipBehavior: Clip.none,
              children: [
                // ── Kotak Bentuk + Gesture Geser ──
                // ✨ GestureDetector di LUAR Transform.rotate
                //    → delta selalu dalam koordinat canvas (tidak dirotasi)
                //    → geser tidak kebalik setelah rotasi ✓
                Positioned(
                  left: sx,
                  top: sy,
                  width: shapeBoxW,
                  height: shapeBoxH,
                  child: GestureDetector(
                    key: _shapeKey, // ← GlobalKey untuk kalkulasi rotasi
                    behavior: isActive
                        ? HitTestBehavior.opaque
                        : HitTestBehavior.deferToChild,
                    onTapDown: (_) =>
                        controller.setActiveStempel(stempel.id),
                    onPanStart: (_) =>
                        controller.setActiveStempel(stempel.id),
                    onPanUpdate: (details) {
                      if (!stempel.isResizing.value) {
                        // Delta dalam koordinat TIDAK dirotasi → arah geser benar ✓
                        controller.updateStempelPosition(
                            stempel.id, details.delta);
                      }
                    },
                    child: Container(
                      decoration: isActive
                          ? BoxDecoration(
                              border: Border.all(
                                color: Colors.blueAccent,
                                width: 1.5 / zoom,
                              ),
                              color: Colors.blueAccent.withValues(alpha: 0.06),
                            )
                          : null,
                      // ✨ Transform.rotate HANYA memutar visual gambar,
                      //    BUKAN gesture atau handle → geser tidak kebalik ✓
                      child: Transform.rotate(
                        angle: stempel.rotation.value,
                        child: Container(
                          color: Colors.transparent,
                          padding: const EdgeInsets.all(8),
                          child: CustomPaint(
                            painter: StempelShapePainter(
                              shape: stempel.shape,
                              color: stempel.color.value,
                              strokeWidth: stempel.strokeWidth.value,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Handles (hanya tampil saat aktif) ──
                if (isActive) ...[

                  // ─── KIRI ATAS: Duplikat ─────────────────────────────────
                  Positioned(
                    left: sx - hr,
                    top: sy - hr,
                    width: hr * 2,
                    height: hr * 2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => controller.duplicateStempel(stempel),
                      child: _HandleCircle(
                        radius: hr,
                        color: Colors.blueAccent,
                        child: Icon(Icons.copy_rounded,
                            size: iconLg, color: Colors.white),
                      ),
                    ),
                  ),

                  // ─── KANAN ATAS: Hapus ───────────────────────────────────
                  Positioned(
                    left: sx + shapeBoxW - hr,
                    top: sy - hr,
                    width: hr * 2,
                    height: hr * 2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => controller.deleteStempel(stempel.id),
                      child: _HandleCircle(
                        radius: hr,
                        color: Colors.redAccent,
                        child: Icon(Icons.close_rounded,
                            size: iconLg, color: Colors.white),
                      ),
                    ),
                  ),

                  // ─── KIRI BAWAH: Rotasi ─────────────────────────────────
                  // ✨ Menggunakan atan2 dari pusat bentuk → rotasi akurat & intuitif
                  Positioned(
                    left: sx - hr,
                    top: sy + shapeBoxH - hr,
                    width: hr * 2,
                    height: hr * 2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (details) {
                        stempel.isResizing.value = true;
                        _stempelStartRotation = stempel.rotation.value;
                        // Hitung sudut awal dari pusat bentuk ke posisi handle
                        final center = _getShapeCenterGlobal();
                        if (center != Offset.zero) {
                          _rotStartAngle = math.atan2(
                            details.globalPosition.dy - center.dy,
                            details.globalPosition.dx - center.dx,
                          );
                        }
                      },
                      onPanUpdate: (details) {
                        // Hitung sudut saat ini dari pusat bentuk ke pointer
                        final center = _getShapeCenterGlobal();
                        if (center != Offset.zero) {
                          final currentAngle = math.atan2(
                            details.globalPosition.dy - center.dy,
                            details.globalPosition.dx - center.dx,
                          );
                          // Delta sudut = sudut sekarang - sudut awal
                          controller.setStempelRotation(
                            stempel.id,
                            _stempelStartRotation +
                                (currentAngle - _rotStartAngle),
                          );
                        }
                      },
                      onPanEnd: (_) => stempel.isResizing.value = false,
                      child: _HandleCircle(
                        radius: hr,
                        color: const Color(0xFF8B5CF6),
                        child: Icon(Icons.rotate_right_rounded,
                            size: iconLg, color: Colors.white),
                      ),
                    ),
                  ),

                  // ─── KANAN TENGAH: Resize Lebar ─────────────────────────
                  Positioned(
                    left: sx + shapeBoxW - hr,
                    top: sy + shapeBoxH / 2 - hr,
                    width: hr * 2,
                    height: hr * 2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (_) => stempel.isResizing.value = true,
                      onPanUpdate: (d) =>
                          controller.resizeStempelX(stempel.id, d.delta.dx),
                      onPanEnd: (_) => stempel.isResizing.value = false,
                      child: _HandleCircle(
                        radius: hr,
                        color: Colors.orange,
                        child: Icon(Icons.swap_horiz_rounded,
                            size: iconSm, color: Colors.white),
                      ),
                    ),
                  ),

                  // ─── BAWAH TENGAH: Resize Tinggi ────────────────────────
                  Positioned(
                    left: sx + shapeBoxW / 2 - hr,
                    top: sy + shapeBoxH - hr,
                    width: hr * 2,
                    height: hr * 2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (_) => stempel.isResizing.value = true,
                      onPanUpdate: (d) =>
                          controller.resizeStempelY(stempel.id, d.delta.dy),
                      onPanEnd: (_) => stempel.isResizing.value = false,
                      child: _HandleCircle(
                        radius: hr,
                        color: Colors.orange,
                        child: Icon(Icons.swap_vert_rounded,
                            size: iconSm, color: Colors.white),
                      ),
                    ),
                  ),

                  // ─── KANAN BAWAH: Resize Seragam ────────────────────────
                  Positioned(
                    left: sx + shapeBoxW - hr,
                    top: sy + shapeBoxH - hr,
                    width: hr * 2,
                    height: hr * 2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (_) => stempel.isResizing.value = true,
                      onPanUpdate: (d) =>
                          controller.resizeStempel(stempel.id, d.delta),
                      onPanEnd: (_) => stempel.isResizing.value = false,
                      child: _HandleCircle(
                        radius: hr,
                        color: const Color(0xFF10B981),
                        child: Icon(Icons.open_in_full_rounded,
                            size: iconSm, color: Colors.white),
                      ),
                    ),
                  ),

                  // ─── ATAS TENGAH: Kontrol Lapisan ────────────────────────
                  // Tap = geser 1 lapisan | Long press = ke ujung total
                  // ✨ Menggunakan SizedBox eksplisit agar touch area cukup besar
                  Positioned(
                    left: sx + shapeBoxW / 2 - hr * 2 - 3.0 / zoom,
                    top: 2.0 / zoom,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Kirim ke belakang
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () =>
                              controller.sendStempelBackward(stempel.id),
                          onLongPress: () =>
                              controller.sendStempelToBack(stempel.id),
                          child: SizedBox(
                            width: hr * 2,
                            height: hr * 2,
                            child: _HandleCircle(
                              radius: hr,
                              color: const Color(0xFF475569),
                              child: Icon(Icons.flip_to_back_rounded,
                                  size: iconSm, color: Colors.white),
                            ),
                          ),
                        ),
                        SizedBox(width: 4.0 / zoom),
                        // Bawa ke depan
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () =>
                              controller.bringStempelForward(stempel.id),
                          onLongPress: () =>
                              controller.bringStempelToFront(stempel.id),
                          child: SizedBox(
                            width: hr * 2,
                            height: hr * 2,
                            child: _HandleCircle(
                              radius: hr,
                              color: const Color(0xFF475569),
                              child: Icon(Icons.flip_to_front_rounded,
                                  size: iconSm, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
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
}

/// Widget bulat untuk handle dengan bayangan
class _HandleCircle extends StatelessWidget {
  final double radius;
  final Color color;
  final Widget child;

  const _HandleCircle({
    required this.radius,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(child: child),
    );
  }
}
