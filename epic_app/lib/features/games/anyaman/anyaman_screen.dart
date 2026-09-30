import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/utils/helpers.dart';
import 'package:epic_app/features/games/anyaman/anyaman_controller.dart';
import 'package:epic_app/features/games/anyaman/level4_bunga_api_pattern.dart';

/// Layar utama game Anyaman — canvas berupa grid interaktif
class AnyamanScreen extends StatefulWidget {
  final int level;
  const AnyamanScreen({super.key, required this.level});

  @override
  State<AnyamanScreen> createState() => _AnyamanScreenState();
}

class _AnyamanScreenState extends State<AnyamanScreen> {
  late final AnyamanController controller;
  late final TransformationController _canvasTransformationController;
  bool _isZoomMode = false;

  @override
  void initState() {
    super.initState();
    _canvasTransformationController = TransformationController();
    final tag = 'anyaman_${widget.level}';

    if (Get.isRegistered<AnyamanController>(tag: tag)) {
      Get.delete<AnyamanController>(tag: tag, force: true);
    }

    controller = Get.put(
      AnyamanController(level: widget.level),
      tag: tag,
    );
  }

  @override
  void dispose() {
    _canvasTransformationController.dispose();
    final tag = 'anyaman_${widget.level}';
    if (Get.isRegistered<AnyamanController>(tag: tag)) {
      Get.delete<AnyamanController>(tag: tag, force: true);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _showExitDialog(controller);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──
              _AnyamanHeader(
                controller: controller,
                onBeforeSubmit: _resetCanvasView,
              ),

              // ── Timer Bar ──
              Obx(() => RepaintBoundary(
                    child: LinearProgressIndicator(
                      value: controller.timerProgress.clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(controller.timerColor),
                    ),
                  )),

              // ── Banner Petunjuk Pipet (Hanya muncul jika mode pipet aktif) ──
              Obx(() {
                if (!controller.isEyedropper.value) {
                  return const SizedBox.shrink();
                }
                return Container(
                  color: const Color(0xFFFF9800),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.colorize_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Mode Pipet: Sentuh kotak anyaman untuk menyalin warna',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          controller.isEyedropper.value = false;
                        },
                        child: const Text(
                          'Batal',
                          style: TextStyle(
                            fontFamily: 'FredokaOne',
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              if ((widget.level == 2 ||
                      widget.level == 3 ||
                      widget.level == 4) &&
                  _isZoomMode)
                Container(
                  color: const Color(0xFF2563EB),
                  padding:
                      const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
                  child: const Row(
                    children: [
                      Icon(Icons.pinch_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mode Zoom/Geser aktif: cubit untuk zoom, lalu geser kanvas.',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Grid Canvas ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: RepaintBoundary(
                    key: controller.canvasKey,
                    child: _AnyamanGrid(
                      controller: controller,
                      isZoomMode: _isZoomMode,
                      transformationController:
                          _canvasTransformationController,
                    ),
                  ),
                ),
              ),

              // ── Toolbar ──
              _AnyamanToolbar(
                controller: controller,
                isZoomMode: _isZoomMode,
                onToggleZoomMode: _toggleZoomMode,
                onResetZoom: _resetCanvasView,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleZoomMode() {
    if (widget.level != 2 && widget.level != 3 && widget.level != 4) return;
    controller.isEyedropper.value = false;
    setState(() => _isZoomMode = !_isZoomMode);
  }

  void _resetCanvasView() {
    if (widget.level != 2 && widget.level != 3 && widget.level != 4) return;
    _canvasTransformationController.value = Matrix4.identity();
    if (_isZoomMode) {
      setState(() => _isZoomMode = false);
    }
  }

  void _showExitDialog(AnyamanController controller) {
    controller.pauseTimer();
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Keluar Game?',
            style: TextStyle(fontFamily: 'FredokaOne', fontSize: 18)),
        content: const Text(
          'Progress anyamanmu akan disimpan otomatis. Kamu bisa lanjutkan nanti!',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              controller.startTimer();
            },
            child:
                const Text('Tetap Main', style: TextStyle(fontFamily: 'Nunito')),
          ),
          ElevatedButton(
            onPressed: () async {
              await controller.forceSaveDraft();
              Get.back();
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Keluar & Simpan',
                style: TextStyle(fontFamily: 'FredokaOne')),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _AnyamanHeader extends StatelessWidget {
  final AnyamanController controller;
  final VoidCallback onBeforeSubmit;
  const _AnyamanHeader({
    required this.controller,
    required this.onBeforeSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Back Button, Title, and Timer
          Row(
            children: [
              // Premium back button
              GestureDetector(
                onTap: () {
                  controller.pauseTimer();
                  // We find the parent screen's exit dialog or trigger back pop
                  Navigator.of(context).maybePop();
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFF334155), size: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Helpers.getLevelLabel('anyaman', controller.level),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'FredokaOne',
                        fontSize: 16,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Anyaman • Level ${controller.level}',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Timer chip
              Obx(() => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: controller.timerColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: controller.timerColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_rounded,
                            size: 14, color: controller.timerColor),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 44,
                          child: Text(
                            controller.waktuFormatted,
                            style: TextStyle(
                              fontFamily: 'FredokaOne',
                              fontSize: 13,
                              color: controller.timerColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
          
          const SizedBox(height: 12),

          // Row 2: Grid Progress & Submit Button
          Row(
            children: [
              // Grid progress bar
              Expanded(
                child: Obx(() {
                  final pct = (controller.fillPercentage * 100).toStringAsFixed(0);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.grid_view_rounded,
                            size: 14, color: Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: controller.fillPercentage.clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$pct%',
                          style: const TextStyle(
                            fontFamily: 'FredokaOne',
                            fontSize: 12,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(width: 10),

              // Submit Button
              ElevatedButton.icon(
                onPressed: () {
                  onBeforeSubmit();
                  controller.pauseTimer();
                  Get.dialog(
                    AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      title: const Text('Kumpulkan Karya?',
                          style: TextStyle(fontFamily: 'FredokaOne')),
                      content: const Text(
                        'Anyamanmu akan dinilai. Pastikan sudah selesai ya!',
                        style: TextStyle(fontFamily: 'Nunito', fontSize: 14),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Get.back();
                            controller.startTimer();
                          },
                          child: const Text('Belum',
                              style: TextStyle(fontFamily: 'Nunito')),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Get.back();
                            controller.submitWork();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Kumpulkan! ✅',
                              style: TextStyle(fontFamily: 'FredokaOne')),
                        ),
                      ],
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: const Text(
                  'Kumpulkan',
                  style: TextStyle(
                    fontFamily: 'FredokaOne',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Grid Canvas ───────────────────────────────────────────────────────────────

class _AnyamanGrid extends StatelessWidget {
  final AnyamanController controller;
  final bool isZoomMode;
  final TransformationController transformationController;
  const _AnyamanGrid({
    required this.controller,
    required this.isZoomMode,
    required this.transformationController,
  });

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.of(context).size.width - 48; // padding

    if (controller.level == 2) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.maxHeight;
          final boardSize = availableHeight.isFinite && availableHeight < availableWidth
              ? availableHeight
              : availableWidth;
          return _buildLevel2Grid(boardSize);
        },
      );
    }

    if (controller.level == 3) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.maxHeight;
          final boardSize = availableHeight.isFinite && availableHeight < availableWidth
              ? availableHeight
              : availableWidth;
          return _buildLevel3Grid(boardSize);
        },
      );
    }

    if (controller.level == 4) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.maxHeight;
          final boardSize =
              availableHeight.isFinite && availableHeight < availableWidth
                  ? availableHeight
                  : availableWidth;
          return _buildLevel4Grid(boardSize);
        },
      );
    }

    return Obx(() {
      final size = controller.gridSize;
      final cellSize = availableWidth > 0 ? (availableWidth / size) - 1.0 : 32.0; // kurangi 1.0 untuk kompensasi margin 0.5 per sisi

      return InteractiveViewer(
          panEnabled: false, // Pan 1 jari untuk interaksi grid, pan 2 jari untuk zoom/geser layar
          scaleEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: GestureDetector(
              onPanStart: (d) => _handleTouch(d.localPosition, cellSize),
              onPanUpdate: (d) => _handleTouch(d.localPosition, cellSize),
              onTapDown: (d) => _handleTouch(d.localPosition, cellSize),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Shrink-wrap the grid vertically
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(size, (row) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min, // Shrink-wrap horizontally
                        children: List.generate(size, (col) {
                          return GetBuilder<AnyamanController>(
                            init: controller,
                            global: false,
                            id: 'grid_${row}_$col',
                            builder: (ctrl) {
                              // Safe check to prevent out of bounds when grid resizes
                              if (row >= ctrl.grid.length || col >= ctrl.grid[row].length) {
                                return SizedBox(width: cellSize, height: cellSize);
                              }
                              final color = ctrl.grid[row][col].value;
                              return _buildCell(color, cellSize, row, col);
                            },
                          );
                        }),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
      );
    });
  }

  Widget _buildLevel2Grid(double availableBoardSize) {
    const blockCount = AnyamanController.level2BlockCount;
    final boardSize = availableBoardSize > 0 ? availableBoardSize : 320.0;
    final blockSize = boardSize / blockCount;

    return InteractiveViewer(
      transformationController: transformationController,
      panEnabled: isZoomMode,
      scaleEnabled: isZoomMode,
      minScale: 1.0,
      maxScale: 4.0,
      child: Center(
        child: GestureDetector(
          onPanStart: isZoomMode
              ? null
              : (details) =>
                  _handleLevel2Touch(details.localPosition, blockSize),
          onPanUpdate: isZoomMode
              ? null
              : (details) =>
                  _handleLevel2Touch(details.localPosition, blockSize),
          onTapDown: isZoomMode
              ? null
              : (details) =>
                  _handleLevel2Touch(details.localPosition, blockSize),
          child: Container(
            width: boardSize,
            height: boardSize,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF475569).withValues(alpha: 0.7),
                width: 0.8,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Column(
                children: List.generate(blockCount, (blockRow) {
                  return Row(
                    children: List.generate(blockCount, (blockCol) {
                      return _buildLevel2Block(blockRow, blockCol, blockSize);
                    }),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLevel2Block(int blockRow, int blockCol, double blockSize) {
    const stripsPerBlock = AnyamanController.level2StripsPerBlock;
    final isVertical = (blockRow + blockCol).isEven;
    final startRow = blockRow * stripsPerBlock;
    final startCol = blockCol * stripsPerBlock;

    final strips = List.generate(stripsPerBlock, (stripIndex) {
      final row = startRow + (isVertical ? 0 : stripIndex);
      final col = startCol + (isVertical ? stripIndex : 0);

      return Expanded(
        child: GetBuilder<AnyamanController>(
          init: controller,
          global: false,
          id: 'grid_${row}_$col',
          builder: (ctrl) {
            final color = ctrl.grid[row][col].value;
            return _buildLevel2Strip(
              color,
              isVertical,
              isLastStrip: stripIndex == stripsPerBlock - 1,
            );
          },
        ),
      );
    });

    return Container(
      width: blockSize,
      height: blockSize,
      decoration: BoxDecoration(
        border: Border(
          right: blockCol < AnyamanController.level2BlockCount - 1
              ? BorderSide(
                  color: const Color(0xFF475569).withValues(alpha: 0.7),
                  width: 0.8,
                )
              : BorderSide.none,
          bottom: blockRow < AnyamanController.level2BlockCount - 1
              ? BorderSide(
                  color: const Color(0xFF475569).withValues(alpha: 0.7),
                  width: 0.8,
                )
              : BorderSide.none,
        ),
      ),
      child: isVertical ? Row(children: strips) : Column(children: strips),
    );
  }

  Widget _buildLevel2Strip(
    Color? color,
    bool isVertical, {
    required bool isLastStrip,
  }) {
    final baseColor = color ?? const Color(0xFFF8FAFC);
    final dividerSide = BorderSide(
      color: const Color(0xFF475569).withValues(alpha: 0.7),
      width: 0.8,
    );

    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: baseColor,
          border: Border(
            right: isVertical && !isLastStrip
                ? dividerSide
                : BorderSide.none,
            bottom: !isVertical && !isLastStrip
                ? dividerSide
                : BorderSide.none,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: isVertical ? Alignment.centerLeft : Alignment.topCenter,
              end: isVertical ? Alignment.centerRight : Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.10),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.04),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleLevel2Touch(Offset position, double blockSize) {
    const blockCount = AnyamanController.level2BlockCount;
    const stripsPerBlock = AnyamanController.level2StripsPerBlock;
    final blockCol = (position.dx / blockSize).floor();
    final blockRow = (position.dy / blockSize).floor();
    if (blockRow < 0 ||
        blockRow >= blockCount ||
        blockCol < 0 ||
        blockCol >= blockCount) {
      return;
    }

    final isVertical = (blockRow + blockCol).isEven;
    final localX = position.dx - (blockCol * blockSize);
    final localY = position.dy - (blockRow * blockSize);
    final stripExtent = blockSize / stripsPerBlock;
    final stripIndex = ((isVertical ? localX : localY) / stripExtent)
        .floor()
        .clamp(0, stripsPerBlock - 1)
        .toInt();
    controller.paintLevel2Strip(blockRow, blockCol, stripIndex);
  }

  Widget _buildLevel3Grid(double availableBoardSize) {
    final boardSize = availableBoardSize > 0 ? availableBoardSize : 320.0;

    return InteractiveViewer(
      transformationController: transformationController,
      panEnabled: isZoomMode,
      scaleEnabled: isZoomMode,
      minScale: 1.0,
      maxScale: 4.0,
      child: Center(
        child: GestureDetector(
          onPanStart: isZoomMode
              ? null
              : (details) =>
                  _handleLevel3Touch(details.localPosition, boardSize),
          onPanUpdate: isZoomMode
              ? null
              : (details) =>
                  _handleLevel3Touch(details.localPosition, boardSize),
          onTapDown: isZoomMode
              ? null
              : (details) =>
                  _handleLevel3Touch(details.localPosition, boardSize),
          child: Container(
            width: boardSize,
            height: boardSize,
            color: Colors.white,
            foregroundDecoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFF334155),
                width: 1,
              ),
            ),
            child: ClipRect(
              child: GetBuilder<AnyamanController>(
                init: controller,
                global: false,
                id: 'level3_grid',
                builder: (ctrl) {
                  return CustomPaint(
                    size: Size.square(boardSize),
                    painter: _Level3WeavePainter(controller: ctrl),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleLevel3Touch(Offset position, double boardSize) {
    const tileCount = AnyamanController.level3TileCount;
    final latticeExtent = boardSize * math.sqrt2;
    final tileSize = latticeExtent / tileCount;
    final centeredX = position.dx - boardSize / 2;
    final centeredY = position.dy - boardSize / 2;
    final cosAngle = math.cos(math.pi / 4);
    final sinAngle = math.sin(math.pi / 4);

    // Transformasi kebalikan dari rotasi painter agar sentuhan mengikuti bilah.
    final latticeX =
        cosAngle * centeredX + sinAngle * centeredY + latticeExtent / 2;
    final latticeY =
        -sinAngle * centeredX + cosAngle * centeredY + latticeExtent / 2;
    final tileCol = (latticeX / tileSize).floor();
    final tileRow = (latticeY / tileSize).floor();
    if (tileRow < 0 ||
        tileRow >= tileCount ||
        tileCol < 0 ||
        tileCol >= tileCount) {
      return;
    }

    final localPosition = Offset(
      latticeX - tileCol * tileSize,
      latticeY - tileRow * tileSize,
    );
    final segments = _level3SegmentRects(tileSize);
    final segmentIndex = segments.indexWhere(
      (segment) => segment.contains(localPosition),
    );
    if (segmentIndex >= 0) {
      controller.paintLevel3Segment(tileRow, tileCol, segmentIndex);
    }
  }

  Widget _buildLevel4Grid(double availableBoardSize) {
    final boardSize = availableBoardSize > 0 ? availableBoardSize : 320.0;

    return InteractiveViewer(
      transformationController: transformationController,
      panEnabled: isZoomMode,
      scaleEnabled: isZoomMode,
      minScale: 1.0,
      maxScale: 4.0,
      child: Center(
        child: GestureDetector(
          onPanStart: isZoomMode
              ? null
              : (details) =>
                  _handleLevel4Touch(details.localPosition, boardSize),
          onPanUpdate: isZoomMode
              ? null
              : (details) =>
                  _handleLevel4Touch(details.localPosition, boardSize),
          onTapDown: isZoomMode
              ? null
              : (details) =>
                  _handleLevel4Touch(details.localPosition, boardSize),
          child: Container(
            width: boardSize,
            height: boardSize,
            color: Colors.white,
            child: GetBuilder<AnyamanController>(
              init: controller,
              global: false,
              id: 'level4_grid',
              builder: (ctrl) {
                return CustomPaint(
                  size: Size.square(boardSize),
                  painter: _Level4BungaApiPainter(controller: ctrl),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _handleLevel4Touch(Offset position, double boardSize) {
    final cellSize = boardSize / level4BungaApiSize;
    final col = (position.dx / cellSize).floor();
    final row = (position.dy / cellSize).floor();
    if (row >= 0 &&
        row < level4BungaApiSize &&
        col >= 0 &&
        col < level4BungaApiSize) {
      controller.paintLevel4Region(row, col);
    }
  }

  void _handleTouch(Offset position, double cellSize) {
    final size = controller.gridSize;
    final col = (position.dx / (cellSize + 1)).floor();
    final row = (position.dy / (cellSize + 1)).floor();
    if (row >= 0 && row < size && col >= 0 && col < size) {
      controller.paintCell(row, col);
    }
  }

  Widget _buildCell(Color? color, double cellSize, int row, int col) {
    // Pola anyaman visual: ganjil-genap untuk efek "over-under"
    final isOdd = (row + col) % 2 == 0;

    // Tekstur serat bambu/anyaman
    Widget textureWidget;
    if (isOdd) {
      // Horizontal texture lines
      textureWidget = Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Container(height: 0.5, color: Colors.white.withValues(alpha: 0.15)),
          Container(height: 0.5, color: Colors.black.withValues(alpha: 0.08)),
          Container(height: 0.5, color: Colors.white.withValues(alpha: 0.15)),
        ],
      );
    } else {
      // Vertical texture lines
      textureWidget = Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Container(width: 0.5, color: Colors.white.withValues(alpha: 0.15)),
          Container(width: 0.5, color: Colors.black.withValues(alpha: 0.08)),
          Container(width: 0.5, color: Colors.white.withValues(alpha: 0.15)),
        ],
      );
    }

    return Container(
      width: cellSize,
      height: cellSize,
      margin: const EdgeInsets.all(0.5),
      decoration: BoxDecoration(
        color: color ?? (isOdd ? const Color(0xFFF8FAFC) : const Color(0xFFEFF6FF)),
        border: Border.all(
          color: const Color(0xFFCBD5E1).withValues(alpha: 0.5),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 1,
            offset: isOdd ? const Offset(0, 1) : const Offset(1, 0),
          )
        ],
        borderRadius: BorderRadius.circular(2),
      ),
      child: textureWidget,
    );
  }
}

List<Rect> _level3SegmentRects(double tileSize) {
  const ringCount = AnyamanController.level3RingsPerTile;
  final band = tileSize / 8;
  final segments = <Rect>[];

  for (int ring = 0; ring < ringCount; ring++) {
    final inset = ring * band;
    final left = inset;
    final top = inset;
    final right = tileSize - inset;
    final bottom = tileSize - inset;

    // Empat bilah membentuk satu putaran spiral tanpa saling menumpuk.
    segments.add(Rect.fromLTRB(left, top, right - band, top + band));
    segments.add(Rect.fromLTRB(right - band, top, right, bottom - band));
    segments.add(Rect.fromLTRB(left + band, bottom - band, right, bottom));
    segments.add(Rect.fromLTRB(left, top + band, left + band, bottom));
  }

  final centerInset = ringCount * band;
  segments.add(Rect.fromLTRB(
    centerInset,
    centerInset,
    tileSize - centerInset,
    tileSize - centerInset,
  ));
  return segments;
}

class _Level3WeavePainter extends CustomPainter {
  final AnyamanController controller;

  const _Level3WeavePainter({required this.controller});

  @override
  void paint(Canvas canvas, Size size) {
    const tileCount = AnyamanController.level3TileCount;
    final boardSize = size.shortestSide;
    final latticeExtent = boardSize * math.sqrt2;
    final tileSize = latticeExtent / tileCount;
    final segmentRects = _level3SegmentRects(tileSize);
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFF334155)
      ..isAntiAlias = true;

    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(math.pi / 4);
    canvas.translate(-latticeExtent / 2, -latticeExtent / 2);

    for (int tileRow = 0; tileRow < tileCount; tileRow++) {
      for (int tileCol = 0; tileCol < tileCount; tileCol++) {
        canvas.save();
        canvas.translate(tileCol * tileSize, tileRow * tileSize);

        for (int segment = 0;
            segment < segmentRects.length;
            segment++) {
          final rect = segmentRects[segment];
          fillPaint.color =
              controller.level3SegmentColor(tileRow, tileCol, segment) ??
                  Colors.white;
          canvas.drawRect(rect, fillPaint);
          canvas.drawRect(rect, linePaint);
        }
        canvas.restore();
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Level3WeavePainter oldDelegate) => true;
}

class _Level4BungaApiPainter extends CustomPainter {
  final AnyamanController controller;

  const _Level4BungaApiPainter({required this.controller});

  @override
  void paint(Canvas canvas, Size size) {
    final boardSize = size.shortestSide;
    final cellSize = boardSize / level4BungaApiSize;
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, boardSize / 480)
      ..strokeCap = StrokeCap.square
      ..color = const Color(0xFF334155)
      ..isAntiAlias = true;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, boardSize, boardSize),
      Paint()..color = Colors.white,
    );

    for (int row = 0; row < level4BungaApiSize; row++) {
      for (int col = 0; col < level4BungaApiSize; col++) {
        fillPaint.color = controller.grid[row][col].value ?? Colors.white;
        canvas.drawRect(
          Rect.fromLTWH(
            col * cellSize,
            row * cellSize,
            cellSize + 0.25,
            cellSize + 0.25,
          ),
          fillPaint,
        );
      }
    }

    for (int boundaryRow = 0;
        boundaryRow <= level4BungaApiSize;
        boundaryRow++) {
      for (int col = 0; col < level4BungaApiSize; col++) {
        if (!level4HasHorizontalEdge(boundaryRow, col)) continue;
        final y = boundaryRow * cellSize;
        canvas.drawLine(
          Offset(col * cellSize, y),
          Offset((col + 1) * cellSize, y),
          linePaint,
        );
      }
    }

    for (int row = 0; row < level4BungaApiSize; row++) {
      for (int boundaryCol = 0;
          boundaryCol <= level4BungaApiSize;
          boundaryCol++) {
        if (!level4HasVerticalEdge(row, boundaryCol)) continue;
        final x = boundaryCol * cellSize;
        canvas.drawLine(
          Offset(x, row * cellSize),
          Offset(x, (row + 1) * cellSize),
          linePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Level4BungaApiPainter oldDelegate) => true;
}

// ── Toolbar ───────────────────────────────────────────────────────────────────

class _AnyamanToolbar extends StatelessWidget {
  final AnyamanController controller;
  final bool isZoomMode;
  final VoidCallback onToggleZoomMode;
  final VoidCallback onResetZoom;
  const _AnyamanToolbar({
    required this.controller,
    required this.isZoomMode,
    required this.onToggleZoomMode,
    required this.onResetZoom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
        boxShadow: [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: Eraser + Clear
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text(
                      'Tools:',
                      style: TextStyle(
                        fontFamily: 'FredokaOne',
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 8),

                  // Cat (warna aktif)
                  Obx(() => GestureDetector(
                        onTap: () => controller.isEraser.value = false,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: !controller.isEraser.value
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: !controller.isEraser.value
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: controller.activeColor.value,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Cat',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: !controller.isEraser.value
                                      ? Colors.white
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),

                  // Penghapus
                  Obx(() => GestureDetector(
                        onTap: controller.toggleEraser,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: controller.isEraser.value
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: controller.isEraser.value
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_fix_high_rounded,
                                size: 14,
                                color: controller.isEraser.value
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Hapus',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: controller.isEraser.value
                                      ? Colors.white
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),

                  if (controller.level == 2 ||
                      controller.level == 3 ||
                      controller.level == 4)
                    GestureDetector(
                      onTap: onToggleZoomMode,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(left: 6, right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isZoomMode
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isZoomMode
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF93C5FD),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isZoomMode
                                  ? Icons.pan_tool_alt_rounded
                                  : Icons.zoom_in_rounded,
                              size: 15,
                              color: isZoomMode
                                  ? Colors.white
                                  : const Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isZoomMode ? 'Zoom Aktif' : 'Zoom',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isZoomMode
                                    ? Colors.white
                                    : const Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (controller.level == 2 ||
                      controller.level == 3 ||
                      controller.level == 4)
                    GestureDetector(
                      onTap: onResetZoom,
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.center_focus_strong_rounded,
                              size: 15,
                              color: Color(0xFF475569),
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Reset Zoom',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(width: 12),

                  // Reset semua
                  IconButton(
                    onPressed: () => Get.dialog(
                      AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        title: const Text('Hapus Semua?',
                            style: TextStyle(fontFamily: 'FredokaOne')),
                        content: const Text('Pola anyaman akan dikosongkan.',
                            style: TextStyle(fontFamily: 'Nunito')),
                        actions: [
                          TextButton(
                              onPressed: () => Get.back(),
                              child: const Text('Tidak')),
                          ElevatedButton(
                            onPressed: () {
                              Get.back();
                              controller.clearGrid();
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                foregroundColor: Colors.white),
                            child: const Text('Hapus Semua'),
                          ),
                        ],
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Color(0xFFEF4444)),
                    tooltip: 'Hapus Semua',
                  ),
                ],
              ),
            ),
          ),

            // Row 2: Palet warna
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Obx(() => Row(
                      children: [
                        ...AnyamanController.palette.map((color) {
                          final isSelected =
                              controller.activeColor.value.toARGB32() ==
                                  color.toARGB32() &&
                              !controller.isEraser.value;
                          return GestureDetector(
                            onTap: () => controller.setColor(color),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.only(right: 8),
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFE2E8F0),
                                  width: isSelected ? 3 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                            color: const Color(0xFF10B981)
                                                .withValues(alpha: 0.4),
                                            blurRadius: 6)
                                      ]
                                    : null,
                              ),
                            ),
                          );
                        }),
                        // Tombol Custom Color Picker
                        GestureDetector(
                          onTap: () => _showColorPicker(context),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.purple],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            child: const Center(
                              child: Icon(Icons.colorize_rounded, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    Color pickerColor = controller.activeColor.value;
    Get.dialog(
      AlertDialog(
        title: const Text('Pilih Warna Kustom', style: TextStyle(fontFamily: 'FredokaOne')),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) {
              pickerColor = color;
            },
            pickerAreaHeightPercent: 0.8,
            enableAlpha: false,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.colorize_rounded),
            label: const Text('Pipet'),
            onPressed: () {
              Get.back();
              controller.isEyedropper.value = true;
            },
          ),
          TextButton(
            child: const Text('Batal'),
            onPressed: () => Get.back(),
          ),
          ElevatedButton(
            child: const Text('Pilih'),
            onPressed: () {
              controller.setColor(pickerColor);
              Get.back();
            },
          ),
        ],
      ),
    );
  }
}
