import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:get/get.dart';
import 'package:perfect_freehand/perfect_freehand.dart' as pf;
import 'package:epic_app/core/utils/helpers.dart';
import 'package:epic_app/features/games/menggambar/drawing_controller.dart';
import 'package:epic_app/features/games/menggambar/template_selector_sheet.dart';
import 'package:epic_app/features/games/menggambar/stempel_painter.dart';
import 'package:epic_app/features/games/menggambar/models/stempel_model.dart';

part 'widgets/drawing_canvas.dart';
part 'widgets/stempel_widget.dart';
part 'widgets/drawing_toolbar.dart';
part 'widgets/drawing_painter.dart';
/// Layar menggambar utama dengan canvas, toolbar, dan timer.
class DrawingScreen extends StatefulWidget {
  final String kategori;
  final int level;

  const DrawingScreen({
    super.key,
    required this.kategori,
    required this.level,
  });

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  late final DrawingController controller;

  @override
  void initState() {
    super.initState();
    final tag = '${widget.kategori}_${widget.level}';

    // Hapus controller lama jika masih ada di memori GetX (misalnya dari sesi submit sebelumnya),
    // agar setiap sesi baru selalu dimulai dengan state yang benar-benar bersih.
    if (Get.isRegistered<DrawingController>(tag: tag)) {
      Get.delete<DrawingController>(tag: tag, force: true);
    }

    controller = Get.put(
      DrawingController(kategori: widget.kategori, level: widget.level),
      tag: tag,
    );
  }

  @override
  void dispose() {
    final tag = '${widget.kategori}_${widget.level}';
    if (Get.isRegistered<DrawingController>(tag: tag)) {
      Get.delete<DrawingController>(tag: tag, force: true);
    }
    super.dispose();
  }

  void _showExitDialog() {
    controller.pauseTimer();
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Keluar?',
            style: TextStyle(fontFamily: 'FredokaOne')),
        content: const Text(
            'Progres gambarmu akan otomatis tersimpan di Draf dan bisa dilanjutkan nanti.',
            style: TextStyle(fontFamily: 'Nunito')),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              controller.resumeTimer();
            },
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Simpan secara paksa sebelum keluar
              await controller.forceSaveDraft();
              Get.back(); // Tutup dialog
              Get.back(); // Keluar screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _showExitDialog();
        }
      },
      child: Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      body: Stack(
        children: [
          // ── Canvas Layer ──
          Positioned.fill(
            child: ClipRect(
              child: _DrawingCanvas(controller: controller),
            ),
          ),

          // ── Header (Floating) ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: _DrawingHeader(
                controller: controller,
                onBack: _showExitDialog,
              ),
            ),
          ),

          // ── Toolbar & Popups Overlay Layer (Floating) ──
          Positioned.fill(
            child: SafeArea(
              top: false,
              child: _DrawingToolbar(controller: controller),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ─── Header ────────────────────────────────────────────────────────────────────

class _DrawingHeader extends StatelessWidget {
  final DrawingController controller;
  final VoidCallback onBack;

  const _DrawingHeader({required this.controller, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.85),
              border: Border.all(color: const Color(0xFF334155), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ─── Row 1: Info & Actions ───
                Row(
                  children: [
                    // Back Button
                    GestureDetector(
                      onTap: onBack,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF334155).withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                    const SizedBox(width: 10),
                    
                    // Title
                    Expanded(
                      child: Text(
                        '${Helpers.getKategoriEmoji(controller.kategori)} ${Helpers.getLevelLabel(controller.kategori, controller.level)}',
                        style: const TextStyle(
                          fontFamily: 'FredokaOne',
                          fontSize: 14,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Timer
                    Obx(() {
                      final isWarning = controller.isWarningTime;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isWarning
                              ? const Color(0xFF7F1D1D).withOpacity(0.8)
                              : const Color(0xFF14532D).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isWarning
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF22C55E)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: isWarning ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              controller.waktuFormatted,
                              style: TextStyle(
                                fontFamily: 'FredokaOne',
                                fontSize: 13,
                                color: isWarning ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(width: 8),

                    // Kumpulkan Button
                    ElevatedButton(
                      onPressed: () {
                        controller.pauseTimer();
                        Get.dialog(
                          AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Text('Kumpulkan Karya?',
                                style: TextStyle(fontFamily: 'FredokaOne')),
                            content: const Text(
                                'Pastikan gambarmu sudah selesai! Setelah dikumpulkan, gambar tidak bisa diedit lagi.',
                                style: TextStyle(fontFamily: 'Nunito')),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Get.back();
                                  controller.resumeTimer();
                                },
                                child: const Text('Batal'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Get.back();
                                  controller.submitDrawing();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF22C55E),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Kumpulkan'),
                              ),
                            ],
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Kumpulkan',
                          style: TextStyle(fontFamily: 'FredokaOne', fontSize: 12)),
                    ),
                  ],
                ),
                
                const SizedBox(height: 2),
                
                // ─── Row 2: Tools (Centered) ───
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Undo
                      Obx(() => IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            iconSize: 16,
                            onPressed: controller.canUndo ? controller.undo : null,
                            icon: Icon(Icons.undo_rounded,
                                color: controller.canUndo ? Colors.white : const Color(0xFF475569)),
                          )),
                      const SizedBox(width: 8),
                      // Redo
                      Obx(() => IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            iconSize: 16,
                            onPressed: controller.canRedo ? controller.redo : null,
                            icon: Icon(Icons.redo_rounded,
                                color: controller.canRedo ? Colors.white : const Color(0xFF475569)),
                          )),
                      const SizedBox(width: 8),
                      // Reset View
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        iconSize: 16,
                        onPressed: controller.resetCanvasView,
                        icon: const Icon(Icons.center_focus_strong_rounded, color: Colors.white),
                        tooltip: 'Pusatkan Kertas',
                      ),
                      const SizedBox(width: 8),
                      // Clear
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        iconSize: 16,
                        onPressed: () => Get.dialog(
                          AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Text('Hapus Semua?', style: TextStyle(fontFamily: 'FredokaOne')),
                            content: const Text('Canvas akan dikosongkan.', style: TextStyle(fontFamily: 'Nunito')),
                            actions: [
                              TextButton(onPressed: () => Get.back(), child: const Text('Batal')),
                              ElevatedButton(
                                onPressed: () {
                                  Get.back();
                                  controller.clearCanvas();
                                },
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
                                child: const Text('Hapus'),
                              ),
                            ],
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFCA5A5)),
                        tooltip: 'Bersihkan Kertas',
                      ),
                      const SizedBox(width: 16),
                      // Layer
                      Obx(() {
                        final layerCount = controller.layers.length;
                        return GestureDetector(
                          onTap: () => _showLayerPanel(context, controller),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.layers_rounded, color: Color(0xFFC4B5FD), size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '${layerCount}',
                                  style: const TextStyle(
                                    fontFamily: 'FredokaOne',
                                    fontSize: 12,
                                    color: Color(0xFFC4B5FD),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Progress Bar
                Obx(() {
                  return RepaintBoundary(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: controller.timerProgress,
                        minHeight: 3,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(controller.timerColor),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Layer Panel Helper ────────────────────────────────────────────────────────

void _showLayerPanel(BuildContext context, DrawingController controller) {
  Get.dialog(
    Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: _LayerPanel(controller: controller),
    ),
  );
}

// ─── Layer Panel Widget ────────────────────────────────────────────────────────

class _LayerPanel extends StatelessWidget {
  final DrawingController controller;
  const _LayerPanel({required this.controller});

  void _showRenameDialog(BuildContext context, int modelIndex) {
    final layer = controller.layers[modelIndex];
    final textController = TextEditingController(text: layer.name.value);
    
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ganti Nama Layer', style: TextStyle(fontFamily: 'FredokaOne', color: Colors.white)),
        content: TextField(
          controller: textController,
          style: const TextStyle(color: Colors.white, fontFamily: 'Nunito', fontSize: 15),
          cursorColor: const Color(0xFF8B5CF6),
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nama Layer',
            hintStyle: const TextStyle(color: Color(0xFF475569)),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = textController.text.trim();
              if (newName.isNotEmpty) {
                controller.renameLayer(modelIndex, newName);
              }
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Simpan', style: TextStyle(fontFamily: 'FredokaOne')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 450),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF334155), width: 1),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  const Icon(Icons.layers_rounded, color: Color(0xFFA78BFA), size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Layer',
                    style: TextStyle(
                      fontFamily: 'FredokaOne',
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  // Tombol Tambah Layer
                  GestureDetector(
                    onTap: () => controller.addLayer(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Tambah',
                            style: TextStyle(
                              fontFamily: 'FredokaOne',
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Tombol Tutup
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                    onPressed: () => Get.back(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF334155), height: 1),
            // Layer List
            Flexible(
              child: Obx(() {
                final layers = controller.layers;
                final activeIdx = controller.activeLayerIndex.value;
                // List for ReorderableListView is display-order (top layer is index 0)
                return ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: layers.length,
                  onReorder: controller.reorderVisualLayer,
                  proxyDecorator: (child, index, animation) {
                    return Material(
                      color: Colors.transparent,
                      child: child,
                    );
                  },
                  itemBuilder: (context, displayPos) {
                    final modelIndex = layers.length - 1 - displayPos;
                    final layer = layers[modelIndex];
                    final isActive = modelIndex == activeIdx;
                    
                    return SizedBox(
                      key: ValueKey(layer.id),
                      child: Obx(() {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF7C3AED).withValues(alpha: 0.2)
                              : const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive ? const Color(0xFF7C3AED) : const Color(0xFF334155),
                            width: isActive ? 1.5 : 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => controller.setActiveLayer(modelIndex),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                // Visibility toggle
                                GestureDetector(
                                  onTap: () => controller.toggleLayerVisibility(modelIndex),
                                  child: Icon(
                                    layer.isVisible.value
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_rounded,
                                    color: layer.isVisible.value
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF475569),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Preview Mini Canvas
                                Container(
                                  width: 32,
                                  height: 32 * 1.414,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFF334155)),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: FittedBox(
                                      fit: BoxFit.contain,
                                      child: SizedBox(
                                        // Gunakan perkiraan ukuran kanvas asli (lebar layar)
                                        width: MediaQuery.of(context).size.width,
                                        height: MediaQuery.of(context).size.width * 1.414,
                                        child: CustomPaint(
                                          painter: _DrawingPainter(
                                            layers: [layer],
                                            activeLayerIndex: -1,
                                            currentStroke: null,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Layer name + Edit Icon
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _showRenameDialog(context, modelIndex),
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            layer.name.value,
                                            style: TextStyle(
                                              fontFamily: 'FredokaOne',
                                              fontSize: 14,
                                              color: isActive
                                                  ? const Color(0xFFC4B5FD)
                                                  : Colors.white,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.edit_rounded, color: Color(0xFF475569), size: 14),
                                      ],
                                    ),
                                  ),
                                ),
                                // Active dot
                                if (isActive)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF7C3AED),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                // Delete
                                GestureDetector(
                                  onTap: layers.length > 1
                                      ? () {
                                          Get.dialog(AlertDialog(
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(20)),
                                            backgroundColor: const Color(0xFF1E293B),
                                            title: Text(
                                              'Hapus ${layer.name.value}?',
                                              style: const TextStyle(fontFamily: 'FredokaOne', color: Colors.white),
                                            ),
                                            content: const Text(
                                              'Semua goresan di layer ini akan dihapus.',
                                              style: TextStyle(fontFamily: 'Nunito', color: Color(0xFF94A3B8)),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Get.back(),
                                                child: const Text('Batal', style: TextStyle(color: Color(0xFF94A3B8))),
                                              ),
                                              ElevatedButton(
                                                onPressed: () {
                                                  Get.back();
                                                  controller.deleteLayer(modelIndex);
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFFEF4444),
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                                child: const Text('Hapus', style: TextStyle(fontFamily: 'FredokaOne')),
                                              ),
                                            ],
                                          ));
                                        }
                                      : null,
                                  child: Icon(
                                    Icons.delete_outline_rounded,
                                    color: layers.length > 1
                                        ? const Color(0xFFFCA5A5)
                                        : const Color(0xFF334155),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Drag Handle Indicator
                                const Icon(
                                  Icons.drag_indicator_rounded,
                                  color: Color(0xFF475569),
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                      }),
                    );
                  },
                );
              }),
            ),
            // Tip
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: const Text(
                '💡 Tahan & geser untuk mengubah urutan layer',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


