import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/utils/helpers.dart';
import 'package:epic_app/features/games/anyaman/anyaman_controller.dart';

/// Layar utama game Anyaman — canvas berupa grid interaktif
class AnyamanScreen extends StatelessWidget {
  final int level;
  const AnyamanScreen({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AnyamanController(level: level));

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
              _AnyamanHeader(controller: controller),

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



              // ── Grid Canvas ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: RepaintBoundary(
                    key: controller.canvasKey,
                    child: _AnyamanGrid(controller: controller),
                  ),
                ),
              ),

              // ── Toolbar ──
              _AnyamanToolbar(controller: controller),
            ],
          ),
        ),
      ),
    );
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
            onPressed: () {
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
  const _AnyamanHeader({required this.controller});

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
  const _AnyamanGrid({required this.controller});

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.of(context).size.width - 48; // padding

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

// ── Toolbar ───────────────────────────────────────────────────────────────────

class _AnyamanToolbar extends StatelessWidget {
  final AnyamanController controller;
  const _AnyamanToolbar({required this.controller});

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
            // Row Simetri Cermin (Hanya muncul di Level 4)
            if (controller.level == 4)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.compare_arrows_rounded, size: 16, color: Color(0xFFFF7A00)),
                    const SizedBox(width: 8),
                    const Text(
                      'Simetri Cermin:',
                      style: TextStyle(
                        fontFamily: 'FredokaOne',
                        fontSize: 13,
                        color: Color(0xFFFF7A00),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildSymmetryBtn('Nonaktif', 'none', Icons.block_rounded),
                            _buildSymmetryBtn('Kiri-Kanan', 'vertical', Icons.align_horizontal_center_rounded),
                            _buildSymmetryBtn('Atas-Bawah', 'horizontal', Icons.align_vertical_center_rounded),
                            _buildSymmetryBtn('Kedua Sumbu', 'both', Icons.grid_4x4_rounded),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

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

                  const SizedBox(width: 12),

                  // Tombol Ukuran Grid (Hanya di Level 4)
                  if (controller.level == 4)
                    GestureDetector(
                      onTap: () => _showGridSizeSelector(context),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.aspect_ratio, color: Color(0xFF3B82F6), size: 16),
                            SizedBox(width: 6),
                            Text('Ukuran', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
                          ],
                        ),
                      ),
                    ),

                  // Tombol Pola (Hanya di Level 4)
                  if (controller.level == 4)
                    GestureDetector(
                      onTap: () => _showPatternSelector(context),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.grid_view_rounded, color: Color(0xFF10B981), size: 16),
                            SizedBox(width: 6),
                            Text('Pola', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                          ],
                        ),
                      ),
                    ),

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

  Widget _buildSymmetryBtn(String label, String value, IconData icon) {
    return GestureDetector(
      onTap: () => controller.activeSymmetry.value = value,
      child: Obx(() {
        final isActive = controller.activeSymmetry.value == value;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFF7A00) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? const Color(0xFFFF7A00) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _showGridSizeSelector(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Ubah Resolusi Anyaman',
              style: TextStyle(
                fontFamily: 'FredokaOne',
                fontSize: 18,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Perhatian: Mengubah ukuran akan menghapus anyamanmu saat ini.',
              style: TextStyle(fontFamily: 'Nunito', color: Color(0xFFEF4444)),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildGridOption('8 x 8', 8, Icons.grid_3x3),
                _buildGridOption('10 x 10', 10, Icons.grid_4x4),
                _buildGridOption('12 x 12', 12, Icons.apps),
                _buildGridOption('16 x 16', 16, Icons.blur_on),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildGridOption(String label, int size, IconData icon) {
    return InkWell(
      onTap: () {
        Get.back();
        controller.changeGridSize(size);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: controller.gridSize == size ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          border: Border.all(color: controller.gridSize == size ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: controller.gridSize == size ? const Color(0xFF3B82F6) : const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.bold, color: controller.gridSize == size ? const Color(0xFF3B82F6) : const Color(0xFF334155))),
          ],
        ),
      ),
    );
  }

  void _showPatternSelector(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Pilih Pola Dasar',
              style: TextStyle(
                fontFamily: 'FredokaOne',
                fontSize: 18,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gunakan pola ini sebagai panduan anyamanmu.',
              style: TextStyle(fontFamily: 'Nunito', color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildPatternOption('Kosong', 'clear', Icons.check_box_outline_blank),
                _buildPatternOption('Catur', 'catur', Icons.grid_on),
                _buildPatternOption('Vertikal', 'vertikal', Icons.view_column),
                _buildPatternOption('Horizontal', 'horizontal', Icons.view_stream),
                _buildPatternOption('Zig-zag', 'zigzag', Icons.water),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildPatternOption(String label, String type, IconData icon) {
    return InkWell(
      onTap: () {
        Get.back();
        controller.applyPattern(type);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF10B981)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.bold, color: Color(0xFF334155))),
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
