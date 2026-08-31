import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epic_app/data/models/scoring_instrument_model.dart';
import 'package:epic_app/data/models/drawing_session_model.dart';
import 'package:epic_app/data/models/drawing_template_model.dart';
import 'package:epic_app/features/games/menggambar/models/stempel_model.dart';
import 'package:epic_app/features/games/menggambar/drawing_result_screen.dart';
import 'package:epic_app/core/services/gemini_token_service.dart';
import 'package:epic_app/core/services/draft_service.dart';
import 'package:epic_app/core/services/app_config_service.dart';
import 'package:epic_app/core/utils/epic_notification.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'package:epic_app/features/games/menggambar/template_selector_sheet.dart';
import 'package:epic_app/features/games/menggambar/stempel_painter.dart';
import 'package:epic_app/shared/widgets/epic_transition_overlay.dart';

// ─── Enum Tools ────────────────────────────────────────────────────────────────

enum DrawingTool {
  cursor,       // Kursor untuk mengatur bentuk
  pencil,       // Pensil bebas
  straightLine, // Garis lurus
  shape,        // Bangun datar (keris) - old
  symbol,       // Simbol dekoratif (batik) - old
  eraser,       // Penghapus
  stempel,      // Tool stempel/bentuk baru
  eyedropper,   // Pipet warna (menyalin warna dari kanvas)
}

// ─── Jenis Pensil ──────────────────────────────────────────────────────────────

enum PencilType {
  ballpoint,  // Bolpoin — garis halus, konsisten, opacity penuh
  pencil,     // Pensil — sedikit kasar, opacity 85%, variasi tipis
  marker,     // Spidol — tebal, flat, opaque
  watercolor, // Cat air — soft edges, semi-transparan
}

extension PencilTypeExt on PencilType {
  String get label {
    switch (this) {
      case PencilType.ballpoint: return 'Bolpoin';
      case PencilType.pencil: return 'Pensil';
      case PencilType.marker: return 'Spidol';
      case PencilType.watercolor: return 'Cat Air';
    }
  }

  String get emoji {
    switch (this) {
      case PencilType.ballpoint: return '🖊️';
      case PencilType.pencil: return '✏️';
      case PencilType.marker: return '🖍️';
      case PencilType.watercolor: return '🎨';
    }
  }

  double get opacityFactor {
    switch (this) {
      case PencilType.ballpoint: return 1.0;
      case PencilType.pencil: return 0.8;
      case PencilType.marker: return 1.0;
      case PencilType.watercolor: return 0.5;
    }
  }

  double get thicknessMultiplier {
    switch (this) {
      case PencilType.ballpoint: return 1.0;
      case PencilType.pencil: return 1.1;
      case PencilType.marker: return 2.0;
      case PencilType.watercolor: return 2.5;
    }
  }

  StrokeCap get strokeCap {
    switch (this) {
      case PencilType.ballpoint: return StrokeCap.round;
      case PencilType.pencil: return StrokeCap.round;
      case PencilType.marker: return StrokeCap.round;
      case PencilType.watercolor: return StrokeCap.round;
    }
  }

  BlendMode get blendMode {
    switch (this) {
      case PencilType.watercolor: return BlendMode.multiply;
      default: return BlendMode.srcOver;
    }
  }
}

// ─── Stroke Model ──────────────────────────────────────────────────────────────

class DrawingStroke {
  final DrawingTool tool;
  final PencilType pencilType;
  final List<Offset> points;
  final Color color;
  final double thickness;
  final double opacity;
  final bool isDot;
  final bool isStraightLine;
  final String? shapeType;

  Path? cachedPath;

  DrawingStroke({
    required this.tool,
    required this.points,
    required this.color,
    required this.thickness,
    this.opacity = 1.0,
    this.pencilType = PencilType.ballpoint,
    this.isDot = false,
    this.isStraightLine = false,
    this.shapeType,
  });

  Map<String, dynamic> toJson() => {
    'tool': tool.name,
    'pencilType': pencilType.name,
    'points': points.map((p) => [p.dx, p.dy]).toList(),
    'color': color.toARGB32(),
    'thickness': thickness,
    'opacity': opacity,
    'isDot': isDot,
    'isStraightLine': isStraightLine,
    'shapeType': shapeType,
  };

  factory DrawingStroke.fromJson(Map<String, dynamic> json) {
    return DrawingStroke(
      tool: DrawingTool.values.firstWhere(
        (e) => e.name == json['tool'],
        orElse: () => DrawingTool.pencil,
      ),
      pencilType: PencilType.values.firstWhere(
        (e) => e.name == json['pencilType'],
        orElse: () => PencilType.ballpoint,
      ),
      points: (json['points'] as List)
          .map((p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
          .toList(),
      color: Color(json['color'] as int),
      thickness: (json['thickness'] as num).toDouble(),
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      isDot: json['isDot'] as bool? ?? false,
      isStraightLine: json['isStraightLine'] as bool? ?? false,
      shapeType: json['shapeType'] as String?,
    );
  }
}

// ─── Layer Model ───────────────────────────────────────────────────────────────

class DrawingLayer {
  final String id;
  final RxString name;
  final RxList<DrawingStroke> strokes;
  final RxList<DrawingStroke> undoStack;
  final RxList<StempelModel> stempels;
  final RxBool isVisible;

  DrawingLayer({required this.id, String? name})
      : name = (name ?? 'Layer').obs,
        strokes = <DrawingStroke>[].obs,
        undoStack = <DrawingStroke>[].obs,
        stempels = <StempelModel>[].obs,
        isVisible = true.obs;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name.value,
    'strokes': strokes.map((s) => s.toJson()).toList(),
    'stempels': stempels.map((s) => s.toJson()).toList(),
    'isVisible': isVisible.value,
  };

  factory DrawingLayer.fromJson(Map<String, dynamic> json) {
    final layer = DrawingLayer(
      id: json['id'] as String,
      name: json['name'] as String?,
    );
    final strokeList = (json['strokes'] as List? ?? [])
        .map((e) => DrawingStroke.fromJson(e as Map<String, dynamic>))
        .toList();
    layer.strokes.assignAll(strokeList);
    
    final stempelList = (json['stempels'] as List? ?? [])
        .map((e) => StempelModel.fromJson(e as Map<String, dynamic>))
        .toList();
    layer.stempels.assignAll(stempelList);
    
    layer.isVisible.value = json['isVisible'] as bool? ?? true;
    return layer;
  }
}

// ─── Drawing Controller ────────────────────────────────────────────────────────

/// Controller utama untuk canvas menggambar.
class DrawingController extends GetxController with WidgetsBindingObserver {
  final String kategori;
  final int level;

  DrawingController({required this.kategori, required this.level});

  // ─── Onboarding / Instrument ─────────────────────────────────────────────
  final RxBool isLoadingInstrument = true.obs;
  ScoringInstrumentModel? instrument;
  String? onboardingKonteksBudaya;
  String? onboardingMateriMatematika;

  Future<void> _loadInstrument() async {
    isLoadingInstrument.value = true;
    try {
      final docId = '${kategori.toLowerCase()}_$level';
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('game_settings')
          .collection('instruments')
          .doc(docId)
          .get();

      if (doc.exists && doc.data() != null) {
        instrument = ScoringInstrumentModel.fromJson(doc.data()!);
      } else {
        instrument = ScoringInstrumentModel.getDefault(kategori, level);
      }

      final onboardingDoc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('game_settings')
          .collection('onboardings')
          .doc(docId)
          .get();

      if (onboardingDoc.exists && onboardingDoc.data() != null) {
        final data = onboardingDoc.data()!;
        onboardingKonteksBudaya = data['konteksBudaya']?.toString();
        onboardingMateriMatematika = data['materiMatematika']?.toString();
      }

      final localDefault = ScoringInstrumentModel.getDefault(kategori, level);
      onboardingKonteksBudaya ??= localDefault.konteksBudaya;
      onboardingMateriMatematika ??= localDefault.materiMatematika;
    } catch (e) {
      debugPrint('Error loading instrument & onboarding: $e');
      instrument = ScoringInstrumentModel.getDefault(kategori, level);
      final localDefault = ScoringInstrumentModel.getDefault(kategori, level);
      onboardingKonteksBudaya = localDefault.konteksBudaya;
      onboardingMateriMatematika = localDefault.materiMatematika;
    } finally {
      isLoadingInstrument.value = false;
    }
  }

  Future<void> _showLevelInstructionsDialog() async {
    pauseTimer();
    final inst = instrument ?? ScoringInstrumentModel.getDefault(kategori, level);

    await Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFF8FAFC)],
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.auto_stories_rounded,
                    color: Color(0xFFFF7A00),
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Petunjuk Level $level',
                      style: const TextStyle(
                        fontFamily: 'FredokaOne',
                        fontSize: 20,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Scrollable Content
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Konteks Budaya
                      _buildInfoCard(
                        title: 'Konteks Budaya',
                        icon: Icons.account_balance_rounded,
                        content: onboardingKonteksBudaya ?? inst.konteksBudaya,
                        cardColor: const Color(0xFFFFF7ED),
                        iconColor: const Color(0xFFEA580C),
                        textColor: const Color(0xFF7C2D12),
                      ),
                      const SizedBox(height: 12),

                      // Materi Matematika
                      _buildInfoCard(
                        title: 'Materi Matematika',
                        icon: Icons.calculate_rounded,
                        content: onboardingMateriMatematika ?? inst.materiMatematika,
                        cardColor: const Color(0xFFF0FDF4),
                        iconColor: const Color(0xFF16A34A),
                        textColor: const Color(0xFF14532D),
                      ),
                      const SizedBox(height: 12),

                      // Kriteria Juri AI
                      _buildCriteriaCard(
                        criteria: inst.criteria,
                        cardColor: const Color(0xFFEFF6FF),
                        iconColor: const Color(0xFF2563EB),
                        textColor: const Color(0xFF1E3A8A),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Button
              ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A00),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Mulai Menggambar',
                  style: TextStyle(
                    fontFamily: 'FredokaOne',
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );

    resumeTimer();
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required String content,
    required Color cardColor,
    required Color iconColor,
    required Color textColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.15), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'FredokaOne',
                  fontSize: 14,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              height: 1.4,
              color: textColor.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriteriaCard({
    required List<ScoringCriteria> criteria,
    required Color cardColor,
    required Color iconColor,
    required Color textColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.15), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.stars_rounded, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Kriteria Juri AI',
                style: TextStyle(
                  fontFamily: 'FredokaOne',
                  fontSize: 14,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...criteria.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_outline_rounded, color: iconColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${c.name} (${c.weight}%)',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      height: 1.4,
                      color: textColor.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // Track pointers for panning/zooming vs drawing
  final Map<int, Offset> activePointersMap = {};
  
  // Canvas Transform State
  final Rx<Matrix4> canvasMatrix = Matrix4.identity().obs;
  Matrix4 _initialMatrix = Matrix4.identity();
  bool _isCanvasInitialized = false;  final RxDouble canvasZoomScale = 1.0.obs;

  Offset? _prevFocalPoint;
  double? _prevDistance;
  double? _prevAngle;
  bool _isDrawing = false;
  bool _isDraggingStempel = false;

  /// Helper to convert screen coordinates to canvas coordinates
  Offset screenToCanvas(Offset screenPos) => _screenToCanvas(screenPos);
  
  Offset _screenToCanvas(Offset screenPos) {
    final renderBox = canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      return renderBox.globalToLocal(screenPos);
    }
    final inverse = Matrix4.tryInvert(canvasMatrix.value);
    if (inverse == null) return screenPos;
    return MatrixUtils.transformPoint(inverse, screenPos);
  }

  void resetCanvasView() {
    canvasMatrix.value = _initialMatrix.clone();
    _prevFocalPoint = null;
    _prevDistance = null;
    _prevAngle = null;
    canvasZoomScale.value = 1.0;
  }

  void setDefaultCanvasSize(double screenW, double screenH, double paperW, double paperH) {
    if (!_isCanvasInitialized) {
      final dx = (screenW - paperW) / 2;
      // Posisi di tengah layar (sudah tidak dikurangi -40 karena padding canvas sudah aman)
      final dy = (screenH - paperH) / 2;
      _initialMatrix = Matrix4.identity()..translate(dx, dy);
      canvasMatrix.value = _initialMatrix.clone();
      _isCanvasInitialized = true;
    }
  }

  // ─── Session ─────────────────────────────────────────────────────────────

  DrawingSessionModel? _session;
  DrawingSessionModel? get session => _session;

  // ─── Timer ───────────────────────────────────────────────────────────────

  /// Fallback default durasi timer (15 menit) jika AppConfigService belum tersedia
  static const int _timerDurasiDetik = 15 * 60;

  /// Durasi timer aktual — dari AppConfigService jika tersedia, fallback ke 15 menit
  int get _timerDurasi {
    if (Get.isRegistered<AppConfigService>()) {
      return Get.find<AppConfigService>().timerDurasiDetik.value;
    }
    return _timerDurasiDetik;
  }

  Timer? _timer;
  final RxInt sisaWaktu = _timerDurasiDetik.obs; // Diisi ulang di _initSession()
  final RxInt waktuTerpakai = 0.obs;
  final RxBool isPaused = false.obs;
  final RxBool isTimeUp = false.obs;

  String get waktuFormatted {
    final m = sisaWaktu.value ~/ 60;
    final s = sisaWaktu.value % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get timerProgress {
    int total = _timerDurasi * (1 + nyawaDigunakan.value);
    if (total <= 0) total = 1; // Prevent division by zero
    return sisaWaktu.value / total;
  }

  Color get timerColor {
    final sisa = sisaWaktu.value;
    if (sisa > 120) return const Color(0xFF22C55E);
    if (sisa > 60) return const Color(0xFFFBBF24);
    return const Color(0xFFEF4444);
  }

  bool get isWarningTime => sisaWaktu.value <= 60;

  // ─── Tool State ──────────────────────────────────────────────────────────

  final Rx<DrawingTool> activeTool = DrawingTool.pencil.obs;
  final Rx<PencilType> activePencilType = PencilType.ballpoint.obs;
  final Rx<Color> activeColor = const Color(0xFF1E293B).obs;
  final RxDouble thickness = 4.0.obs;
  final RxDouble opacity = 1.0.obs;
  final Rx<String?> activeShape = Rx<String?>(null);

  // ─── Layers (Layer System) ────────────────────────────────────────────────

  final RxList<DrawingLayer> layers = <DrawingLayer>[].obs;
  final RxInt activeLayerIndex = 0.obs;
  // Stack undo global dihapus, diganti dengan per-layer undo stack.

  /// Layer yang sedang aktif untuk menggambar
  DrawingLayer get activeLayer {
    if (layers.isEmpty) return DrawingLayer(id: 'dummy');
    return layers[activeLayerIndex.value.clamp(0, layers.length - 1)];
  }

  /// Getter backward-compat — strokes dari layer aktif
  RxList<DrawingStroke> get strokes => activeLayer.strokes;

  /// Total strokes semua layer (untuk scoring)
  int get totalStrokeCount => layers.fold(0, (sum, l) => sum + l.strokes.length);

  bool get canUndo => activeLayer.strokes.isNotEmpty;
  bool get canRedo => activeLayer.undoStack.isNotEmpty;

  // ─── Stempel (Bangun Datar / Motif Batik) ────────────────────────────────────

  final RxString activeStempelId = ''.obs;
  final Rx<StempelShape?> activeStempelShape = Rx<StempelShape?>(null);

  StempelModel? _findStempel(String id) {
    for (final layer in layers) {
      final s = layer.stempels.firstWhereOrNull((s) => s.id == id);
      if (s != null) return s;
    }
    return null;
  }

  void addStempel(StempelShape shape) {
    activeTool.value = DrawingTool.cursor;
    activeStempelShape.value = shape;
    activeStempelId.value = ''; // Deselect current, wait for user to touch canvas
  }

  void placeNewStempel(Offset position) {
    if (activeStempelShape.value == null) return;
    if (layers.isEmpty) return; // Butuh setidaknya 1 layer

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final nextZ = activeLayer.stempels.isEmpty
        ? 0
        : activeLayer.stempels.map((s) => s.zIndex.value).reduce(math.max) + 1;
    final isLine = activeStempelShape.value == StempelShape.garisLurus;
    activeLayer.stempels.add(StempelModel(
      id: id,
      shape: activeStempelShape.value!,
      initialPosition: position - const Offset(24, 24),
      initialColor: activeColor.value,
      initialStrokeWidth: thickness.value,
      initialOpacity: opacity.value,
      initialScaleX: isLine ? 2.0 : 1.0,
      initialScaleY: 1.0,
      initialRotation: 0.0,
      initialZIndex: nextZ,
    ));
    activeStempelId.value = id;
    
    // Clear the active shape so it only spawns once per selection from the menu.
    // Subsequent touches on empty canvas will just deselect the active stempel.
    activeStempelShape.value = null;
    layers.refresh();
  }

  void duplicateStempel(StempelModel stempel) {
    if (layers.isEmpty) return;
    
    // Temukan layer yang memiliki stempel ini
    DrawingLayer targetLayer = activeLayer;
    for (final layer in layers) {
      if (layer.stempels.any((s) => s.id == stempel.id)) {
        targetLayer = layer;
        break;
      }
    }

    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final nextZ = targetLayer.stempels.isEmpty
        ? 0
        : targetLayer.stempels.map((s) => s.zIndex.value).reduce(math.max) + 1;
    targetLayer.stempels.add(StempelModel(
      id: newId,
      shape: stempel.shape,
      initialPosition: stempel.position.value + const Offset(24, 24),
      initialColor: stempel.color.value,
      initialStrokeWidth: stempel.strokeWidth.value,
      initialOpacity: stempel.opacity.value,
      initialScaleX: stempel.scaleX.value,
      initialScaleY: stempel.scaleY.value,
      initialRotation: stempel.rotation.value,
      initialZIndex: nextZ,
    ));
    activeStempelId.value = newId;
    _persistState();
    layers.refresh();
  }

  void deleteStempel(String id) {
    for (final layer in layers) {
      layer.stempels.removeWhere((s) => s.id == id);
    }
    if (activeStempelId.value == id) {
      activeStempelId.value = '';
    }
    // ✅ Simpan langsung agar penghapusan tersimpan ke draft sebelum user keluar
    _persistState();
    layers.refresh();
  }

  final RxBool isInteractingWithStempel = false.obs;

  // ─── 8-Point Precise Resizing with Anchor Pinning ─────────────────────────

  /// Resize Kanan (Sumbu Lebar / X) - Sisi Kiri Tetap Terkunci
  void resizeRight(String id, Offset canvasDelta) {
    final stempel = _findStempel(id);
    if (stempel == null) return;
    
    final rot = stempel.rotation.value;
    final cosR = math.cos(rot);
    final sinR = math.sin(rot);
    final localDx = canvasDelta.dx * cosR + canvasDelta.dy * sinR;
    
    final deltaScale = localDx / 48.0;
    final oldSx = stempel.scaleX.value;
    final newSx = (oldSx + deltaScale).clamp(0.2, 30.0);
    final deltaW = 48.0 * (newSx - oldSx);
    
    final shiftX = (deltaW / 2.0) * cosR;
    final shiftY = (deltaW / 2.0) * sinR;
    
    stempel.position.value = Offset(
      stempel.position.value.dx + shiftX - deltaW / 2.0,
      stempel.position.value.dy + shiftY,
    );
    stempel.scaleX.value = newSx;
  }

  /// Resize Kiri (Sumbu Lebar / X) - Sisi Kanan Tetap Terkunci
  void resizeLeft(String id, Offset canvasDelta) {
    final stempel = _findStempel(id);
    if (stempel == null) return;
    
    final rot = stempel.rotation.value;
    final cosR = math.cos(rot);
    final sinR = math.sin(rot);
    final localDx = canvasDelta.dx * cosR + canvasDelta.dy * sinR;
    
    final deltaScale = -localDx / 48.0;
    final oldSx = stempel.scaleX.value;
    final newSx = (oldSx + deltaScale).clamp(0.2, 30.0);
    final deltaW = 48.0 * (newSx - oldSx);
    
    final shiftX = -(deltaW / 2.0) * cosR;
    final shiftY = -(deltaW / 2.0) * sinR;
    
    stempel.position.value = Offset(
      stempel.position.value.dx + shiftX - deltaW / 2.0,
      stempel.position.value.dy + shiftY,
    );
    stempel.scaleX.value = newSx;
  }

  /// Resize Bawah (Sumbu Tinggi / Y) - Sisi Atas Tetap Terkunci
  void resizeBottom(String id, Offset canvasDelta) {
    final stempel = _findStempel(id);
    if (stempel == null) return;
    
    final rot = stempel.rotation.value;
    final cosR = math.cos(rot);
    final sinR = math.sin(rot);
    final localDy = -canvasDelta.dx * sinR + canvasDelta.dy * cosR;
    
    final deltaScale = localDy / 48.0;
    final oldSy = stempel.scaleY.value;
    final newSy = (oldSy + deltaScale).clamp(0.2, 30.0);
    final deltaH = 48.0 * (newSy - oldSy);
    
    final shiftX = -(deltaH / 2.0) * sinR;
    final shiftY = (deltaH / 2.0) * cosR;
    
    stempel.position.value = Offset(
      stempel.position.value.dx + shiftX,
      stempel.position.value.dy + shiftY - deltaH / 2.0,
    );
    stempel.scaleY.value = newSy;
  }

  /// Resize Atas (Sumbu Tinggi / Y) - Sisi Bawah Tetap Terkunci
  void resizeTop(String id, Offset canvasDelta) {
    final stempel = _findStempel(id);
    if (stempel == null) return;
    
    final rot = stempel.rotation.value;
    final cosR = math.cos(rot);
    final sinR = math.sin(rot);
    final localDy = -canvasDelta.dx * sinR + canvasDelta.dy * cosR;
    
    final deltaScale = -localDy / 48.0;
    final oldSy = stempel.scaleY.value;
    final newSy = (oldSy + deltaScale).clamp(0.2, 30.0);
    final deltaH = 48.0 * (newSy - oldSy);
    
    final shiftX = (deltaH / 2.0) * sinR;
    final shiftY = -(deltaH / 2.0) * cosR;
    
    stempel.position.value = Offset(
      stempel.position.value.dx + shiftX,
      stempel.position.value.dy + shiftY - deltaH / 2.0,
    );
    stempel.scaleY.value = newSy;
  }

  /// Resize Sudut Kanan Bawah (BR) - Sudut Kiri Atas Tetap Terkunci
  void resizeCornerBottomRight(String id, Offset canvasDelta) {
    final stempel = _findStempel(id);
    if (stempel == null) return;
    
    final rot = stempel.rotation.value;
    final cosR = math.cos(rot);
    final sinR = math.sin(rot);
    
    final oldSx = stempel.scaleX.value;
    final oldSy = stempel.scaleY.value;
    final oldW = 48.0 * oldSx + 16.0;
    final oldH = 48.0 * oldSy + 16.0;
    
    // Diagonal vector from pinned anchor (TL) to active handle (BR)
    final vx = oldW * cosR - oldH * sinR;
    final vy = oldW * sinR + oldH * cosR;
    final diag = math.sqrt(oldW * oldW + oldH * oldH);
    
    // Project finger delta directly along the true diagonal vector
    final deltaProj = (canvasDelta.dx * vx + canvasDelta.dy * vy) / diag;
    final scaleFactor = (diag + deltaProj) / diag;
    
    final newSx = (oldSx * scaleFactor).clamp(0.2, 30.0);
    final newSy = (oldSy * scaleFactor).clamp(0.2, 30.0);
    
    final deltaW = 48.0 * (newSx - oldSx);
    final deltaH = 48.0 * (newSy - oldSy);
    
    final shiftX = (deltaW / 2.0) * cosR - (deltaH / 2.0) * sinR;
    final shiftY = (deltaW / 2.0) * sinR + (deltaH / 2.0) * cosR;
    
    stempel.position.value = Offset(
      stempel.position.value.dx + shiftX - deltaW / 2.0,
      stempel.position.value.dy + shiftY - deltaH / 2.0,
    );
    stempel.scaleX.value = newSx;
    stempel.scaleY.value = newSy;
  }

  /// Resize Sudut Kiri Bawah (BL) - Sudut Kanan Atas Tetap Terkunci
  void resizeCornerBottomLeft(String id, Offset canvasDelta) {
    final stempel = _findStempel(id);
    if (stempel == null) return;
    
    final rot = stempel.rotation.value;
    final cosR = math.cos(rot);
    final sinR = math.sin(rot);
    
    final oldSx = stempel.scaleX.value;
    final oldSy = stempel.scaleY.value;
    final oldW = 48.0 * oldSx + 16.0;
    final oldH = 48.0 * oldSy + 16.0;
    
    // Diagonal vector from pinned anchor (TR) to active handle (BL)
    final vx = -oldW * cosR - oldH * sinR;
    final vy = -oldW * sinR + oldH * cosR;
    final diag = math.sqrt(oldW * oldW + oldH * oldH);
    
    final deltaProj = (canvasDelta.dx * vx + canvasDelta.dy * vy) / diag;
    final scaleFactor = (diag + deltaProj) / diag;
    
    final newSx = (oldSx * scaleFactor).clamp(0.2, 30.0);
    final newSy = (oldSy * scaleFactor).clamp(0.2, 30.0);
    
    final deltaW = 48.0 * (newSx - oldSx);
    final deltaH = 48.0 * (newSy - oldSy);
    
    final shiftX = -(deltaW / 2.0) * cosR - (deltaH / 2.0) * sinR;
    final shiftY = -(deltaW / 2.0) * sinR + (deltaH / 2.0) * cosR;
    
    stempel.position.value = Offset(
      stempel.position.value.dx + shiftX - deltaW / 2.0,
      stempel.position.value.dy + shiftY - deltaH / 2.0,
    );
    stempel.scaleX.value = newSx;
    stempel.scaleY.value = newSy;
  }

  /// Resize Sudut Kanan Atas (TR) - Sudut Kiri Bawah Tetap Terkunci
  void resizeCornerTopRight(String id, Offset canvasDelta) {
    final stempel = _findStempel(id);
    if (stempel == null) return;
    
    final rot = stempel.rotation.value;
    final cosR = math.cos(rot);
    final sinR = math.sin(rot);
    
    final oldSx = stempel.scaleX.value;
    final oldSy = stempel.scaleY.value;
    final oldW = 48.0 * oldSx + 16.0;
    final oldH = 48.0 * oldSy + 16.0;
    
    // Diagonal vector from pinned anchor (BL) to active handle (TR)
    final vx = oldW * cosR + oldH * sinR;
    final vy = oldW * sinR - oldH * cosR;
    final diag = math.sqrt(oldW * oldW + oldH * oldH);
    
    final deltaProj = (canvasDelta.dx * vx + canvasDelta.dy * vy) / diag;
    final scaleFactor = (diag + deltaProj) / diag;
    
    final newSx = (oldSx * scaleFactor).clamp(0.2, 30.0);
    final newSy = (oldSy * scaleFactor).clamp(0.2, 30.0);
    
    final deltaW = 48.0 * (newSx - oldSx);
    final deltaH = 48.0 * (newSy - oldSy);
    
    final shiftX = (deltaW / 2.0) * cosR + (deltaH / 2.0) * sinR;
    final shiftY = (deltaW / 2.0) * sinR - (deltaH / 2.0) * cosR;
    
    stempel.position.value = Offset(
      stempel.position.value.dx + shiftX - deltaW / 2.0,
      stempel.position.value.dy + shiftY - deltaH / 2.0,
    );
    stempel.scaleX.value = newSx;
    stempel.scaleY.value = newSy;
  }

  /// Resize Sudut Kiri Atas (TL) - Sudut Kanan Bawah Tetap Terkunci
  void resizeCornerTopLeft(String id, Offset canvasDelta) {
    final stempel = _findStempel(id);
    if (stempel == null) return;
    
    final rot = stempel.rotation.value;
    final cosR = math.cos(rot);
    final sinR = math.sin(rot);
    
    final oldSx = stempel.scaleX.value;
    final oldSy = stempel.scaleY.value;
    final oldW = 48.0 * oldSx + 16.0;
    final oldH = 48.0 * oldSy + 16.0;
    
    // Diagonal vector from pinned anchor (BR) to active handle (TL)
    final vx = -oldW * cosR + oldH * sinR;
    final vy = -oldW * sinR - oldH * cosR;
    final diag = math.sqrt(oldW * oldW + oldH * oldH);
    
    final deltaProj = (canvasDelta.dx * vx + canvasDelta.dy * vy) / diag;
    final scaleFactor = (diag + deltaProj) / diag;
    
    final newSx = (oldSx * scaleFactor).clamp(0.2, 30.0);
    final newSy = (oldSy * scaleFactor).clamp(0.2, 30.0);
    
    final deltaW = 48.0 * (newSx - oldSx);
    final deltaH = 48.0 * (newSy - oldSy);
    
    final shiftX = -(deltaW / 2.0) * cosR + (deltaH / 2.0) * sinR;
    final shiftY = -(deltaW / 2.0) * sinR - (deltaH / 2.0) * cosR;
    
    stempel.position.value = Offset(
      stempel.position.value.dx + shiftX - deltaW / 2.0,
      stempel.position.value.dy + shiftY - deltaH / 2.0,
    );
    stempel.scaleX.value = newSx;
    stempel.scaleY.value = newSy;
  }

  // Alias kompatibilitas
  void resizeStempel(String id, Offset canvasDelta) => resizeCornerBottomRight(id, canvasDelta);
  void resizeStempelX(String id, Offset canvasDelta) => resizeRight(id, canvasDelta);
  void resizeStempelY(String id, Offset canvasDelta) => resizeBottom(id, canvasDelta);

  void updateStempelPosition(String id, Offset delta) {
    final stempel = _findStempel(id);
    if (stempel != null) {
      stempel.position.value += delta;
    }
  }

  void setActiveStempel(String id) {
    if (id.isNotEmpty) {
      // Pindah ke layer yang mengandung stempel ini secara otomatis
      for (int i = 0; i < layers.length; i++) {
        final index = layers[i].stempels.indexWhere((s) => s.id == id);
        if (index != -1) {
          if (activeLayerIndex.value != i) {
            activeLayerIndex.value = i;
          }
          break;
        }
      }
      activeStempelId.value = id;
      activeTool.value = DrawingTool.cursor;
      _isDraggingStempel = true;
      final stempel = _findStempel(id);
      if (stempel != null) {
        activeColor.value = stempel.color.value;
        thickness.value = stempel.strokeWidth.value;
        opacity.value = stempel.opacity.value;
      }
    } else {
      activeStempelId.value = '';
      _isDraggingStempel = false;
    }
  }// ─── Rotasi Stempel ───────────────────────────────────────────────────────

  /// Tambahkan rotasi [deltaAngle] (dalam radian) ke stempel
  void rotateStempel(String id, double deltaAngle) {
    final stempel = _findStempel(id);
    if (stempel == null) return;
    stempel.rotation.value += deltaAngle;
  }

  /// Set rotasi absolut stempel
  void setStempelRotation(String id, double angle) {
    final stempel = _findStempel(id);
    if (stempel == null) return;
    stempel.rotation.value = angle;
  }

  // ─── Layer Control (Z-Order) ──────────────────────────────────────────────

  /// Bawa stempel ke lapisan paling depan
  void bringStempelToFront(String id) {
    for (final layer in layers) {
      final idx = layer.stempels.indexWhere((s) => s.id == id);
      if (idx >= 0) {
        if (idx < layer.stempels.length - 1) {
          final stempel = layer.stempels.removeAt(idx);
          layer.stempels.add(stempel);
          layers.refresh();
        }
        return;
      }
    }
  }

  /// Kirim stempel ke lapisan paling belakang
  void sendStempelToBack(String id) {
    for (final layer in layers) {
      final idx = layer.stempels.indexWhere((s) => s.id == id);
      if (idx > 0) {
        final stempel = layer.stempels.removeAt(idx);
        layer.stempels.insert(0, stempel);
        layers.refresh();
        return;
      }
    }
  }

  /// Maju satu lapisan
  void bringStempelForward(String id) {
    for (final layer in layers) {
      final idx = layer.stempels.indexWhere((s) => s.id == id);
      if (idx >= 0 && idx < layer.stempels.length - 1) {
        final stempel = layer.stempels.removeAt(idx);
        layer.stempels.insert(idx + 1, stempel);
        layers.refresh();
        return;
      }
    }
  }

  /// Mundur satu lapisan
  void sendStempelBackward(String id) {
    for (final layer in layers) {
      final idx = layer.stempels.indexWhere((s) => s.id == id);
      if (idx > 0) {
        final stempel = layer.stempels.removeAt(idx);
        layer.stempels.insert(idx - 1, stempel);
        layers.refresh();
        return;
      }
    }
  }


  bool _isPositionOnAnyStempel(Offset canvasPos) {
    final zoom = canvasZoomScale.value > 0 ? canvasZoomScale.value : 1.0;
    final double pad = 18.0 / zoom; // Toleransi sentuh 18px di sekeliling bentuk/handle

    // 1. Periksa stempel yang sedang aktif (beserta handle sudut/sisi, toolbar atas, dan rotate bawah)
    if (activeStempelId.value.isNotEmpty) {
      final active = _findStempel(activeStempelId.value);
      if (active != null) {
        final shapeW = 48.0 * active.scaleX.value + 16.0;
        final shapeH = 48.0 * active.scaleY.value + 16.0;
        final center = Offset(
          active.position.value.dx + shapeW / 2,
          active.position.value.dy + shapeH / 2,
        );

        final dx = canvasPos.dx - center.dx;
        final dy = canvasPos.dy - center.dy;

        final cosA = math.cos(-active.rotation.value);
        final sinA = math.sin(-active.rotation.value);
        final localX = dx * cosA - dy * sinA;
        final localY = dx * sinA + dy * cosA;

        // A. Kotak bentuk & 8 handle di sekelilingnya
        if (localX.abs() <= shapeW / 2 + pad && localY.abs() <= shapeH / 2 + pad) {
          return true;
        }

        // B. Floating Toolbar di atas bentuk
        if (localX.abs() <= (80.0 / zoom) &&
            localY >= -shapeH / 2 - (65.0 / zoom) &&
            localY <= -shapeH / 2) {
          return true;
        }

        // C. Floating Rotate Button di bawah bentuk
        if (localX.abs() <= (28.0 / zoom) &&
            localY >= shapeH / 2 &&
            localY <= shapeH / 2 + (55.0 / zoom)) {
          return true;
        }
      }
    }

    // 2. Periksa stempel lain yang tidak aktif (hanya kotak bentuknya)
    for (final layer in layers) {
      if (!layer.isVisible.value) continue;
      for (var s in layer.stempels) {
        if (s.id == activeStempelId.value) continue;
        final shapeW = 48.0 * s.scaleX.value + 16.0;
        final shapeH = 48.0 * s.scaleY.value + 16.0;
        final center = Offset(
          s.position.value.dx + shapeW / 2,
          s.position.value.dy + shapeH / 2,
        );

        final dx = canvasPos.dx - center.dx;
        final dy = canvasPos.dy - center.dy;

        final cosA = math.cos(-s.rotation.value);
        final sinA = math.sin(-s.rotation.value);
        final localX = dx * cosA - dy * sinA;
        final localY = dx * sinA + dy * cosA;

        if (localX.abs() <= shapeW / 2 + pad && localY.abs() <= shapeH / 2 + pad) {
          return true;
        }
      }
    }
    return false;
  }

  // ─── Canvas Transform ─────────────────────────────────────────────────────

  final GlobalKey canvasKey = GlobalKey();
  final RxBool isCapturing = false.obs;

  // ─── Template ─────────────────────────────────────────────────────────────

  final Rx<DrawingTemplateModel?> activeTemplate = Rx<DrawingTemplateModel?>(null);
  final RxDouble templateOpacity = 0.25.obs;
  final RxBool hasTemplate = false.obs;
  bool _templateSelectionMade = false;

  // ─── Eyedropper State ──────────────────────────────────────────────────────
  ByteData? _eyedropperBytes;
  int _eyedropperWidth = 0;
  int _eyedropperHeight = 0;
  double _eyedropperScaleX = 1.0;
  double _eyedropperScaleY = 1.0;
  DrawingTool _toolBeforeEyedropper = DrawingTool.pencil;
  final Rx<Offset?> eyedropperPosition = Rx<Offset?>(null);

  // ─── Current Drawing ──────────────────────────────────────────────────────

  final Rx<DrawingStroke?> currentStroke = Rx<DrawingStroke?>(null);

  // ─── Loading / Submitting ─────────────────────────────────────────────────

  final RxBool isSubmitting = false.obs;
  final RxBool isSaving = false.obs;

  // ─── Nyawa ───────────────────────────────────────────────────────────────

  final RxInt nyawaDigunakan = 0.obs;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  // State untuk mengelola pop-up menu di toolbar
  final popupMenu = ''.obs;
  
  // State untuk toolbar mode ciut (collapsible)
  final RxBool isToolbarExpanded = true.obs;

  void toggleToolbar() {
    isToolbarExpanded.toggle();
    if (!isToolbarExpanded.value) {
      popupMenu.value = ''; // Tutup popup jika toolbar diciutkan
    }
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    ever(canvasMatrix, (matrix) {
      canvasZoomScale.value = matrix.getMaxScaleOnAxis();
    });
  }

  @override
  void onReady() {
    super.onReady();
    _initSession();
  }

  bool _wasPausedByLifecycle = false;

  /// Flag untuk mencegah draft disimpan kembali setelah submit
  bool _isSubmitted = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (!isPaused.value) {
        _wasPausedByLifecycle = true;
        pauseTimer();
      }
      // Jangan simpan draft jika sudah di-submit
      if (!_isSubmitted) {
        _persistState();
      }
    } else if (state == AppLifecycleState.resumed) {
      _loadTimerState();
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    // Jangan simpan draft jika sudah di-submit
    if (!_isSubmitted) {
      _persistState();
    }
    super.onClose();
  }



  // ─── Session Init ─────────────────────────────────────────────────────────

  Future<void> _initSession() async {
    await _loadInstrument();
    final sessionController = Get.find<SessionController>();
    final uid = sessionController.currentUser.value?.uid ?? '';
    final isLanjutkan = Get.arguments?['isLanjutkan'] ?? false;
    
    // Cari draft
    final draftService = Get.find<DraftService>();
    final existingDraft = draftService.drafts.firstWhereOrNull(
      (d) => d.kategori == kategori && d.level == level
    );

    if (existingDraft != null && existingDraft.remainingSeconds < _timerDurasi) {
      _session = existingDraft;
      sisaWaktu.value = existingDraft.remainingSeconds;
      waktuTerpakai.value = existingDraft.waktuTerpakai;
      
      // Load strokes
      if (existingDraft.strokesData != null) {
        _loadStrokesFromJson(existingDraft.strokesData!);
      }
      // Load template
      if (existingDraft.templateId != null) {
        try {
          final tMap = jsonDecode(existingDraft.templateId!); 
          setTemplate(DrawingTemplateModel.fromJson(tMap));
        } catch (_) {}
      }
      // Load stempels (Migrasi stempel lama ke layer terbawah)
      if (existingDraft.stempelsData != null) {
        try {
          final List<dynamic> sList = jsonDecode(existingDraft.stempelsData!);
          final oldStempels = sList.map((e) => StempelModel.fromJson(e)).toList();
          if (oldStempels.isNotEmpty) {
            if (layers.isEmpty) {
               addLayer();
            }
            layers[0].stempels.assignAll(oldStempels);
          }
        } catch (_) {}
      }

      if (isLanjutkan) {
        startTimer();
        if (activeTemplate.value == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _showTemplateSelector());
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) => _showLevelInstructionsDialog());
        }
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showContinueDialog());
      }
    } else {
      // Jika dari layar awal ingin lanjut tapi gak ada draft, paksa mulai baru.
      if (isLanjutkan) {
        EpicNotification.info('Draft Tidak Ditemukan', 'Memulai canvas baru.');
      }
      
      sisaWaktu.value = _timerDurasi;
      waktuTerpakai.value = 0;
      final sessionId = 'drawing_session_${uid}_${kategori}_$level';
        _session = DrawingSessionModel(
          id: sessionId,
          uid: uid,
          kategori: kategori,
          level: level,
          remainingSeconds: _timerDurasi,
          status: DrawingSessionStatus.draft,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        draftService.saveDraft(_session!);
        _ensureDefaultLayer(); // Pastikan ada layer default
        startTimer();
        if (activeTemplate.value == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _showTemplateSelector());
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) => _showLevelInstructionsDialog());
        }
      }
    }

  Future<void> _showContinueDialog() async {
    final sessionController = Get.find<SessionController>();
    final result = await Get.dialog<String>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Lanjutkan Gambar?',
          style: TextStyle(fontFamily: 'FredokaOne', fontSize: 18),
        ),
        content: const Text(
          'Kamu punya draft sebelumnya dengan sisa waktu . '
          'Mau lanjutkan atau mulai baru?',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back(result: 'new');
            },
            child: const Text('Mulai Baru',
                style: TextStyle(color: Colors.grey, fontFamily: 'Nunito')),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back(result: 'continue');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Lanjutkan',
                style: TextStyle(fontFamily: 'FredokaOne')),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    if (result == null) {
      Get.back(); // Pop the parent screen
      return;
    }

    if (result == 'new') {
      clearCanvas();
      sisaWaktu.value = _timerDurasi;
      waktuTerpakai.value = 0;
      final uid2 = sessionController.currentUser.value?.uid ?? '';
      final sessionId2 = 'drawing_session_${uid2}_${kategori}_$level';
      _session = DrawingSessionModel(
        id: sessionId2,
        uid: uid2,
        kategori: kategori,
        level: level,
        remainingSeconds: _timerDurasi,
        status: DrawingSessionStatus.draft,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      Get.find<DraftService>().saveDraft(_session!);
      _ensureDefaultLayer(); // Pastikan ada layer default
      startTimer();
      if (activeTemplate.value == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showTemplateSelector());
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showLevelInstructionsDialog());
      }
    } else if (result == 'continue') {
      startTimer();
    }
  }


  // ─── Stroke / Layer Persistence ───────────────────────────────────────────

  /// Inisialisasi 1 layer default jika kosong
  void _ensureDefaultLayer() {
    if (layers.isEmpty) {
      layers.add(DrawingLayer(id: 'layer_${DateTime.now().millisecondsSinceEpoch}', name: 'Layer 1'));
      activeLayerIndex.value = 0;
    }
  }

  void _loadStrokesFromJson(String jsonStr) {
    try {
      final list = jsonDecode(jsonStr) as List;
      if (list.isEmpty) {
        _ensureDefaultLayer();
        return;
      }
      final first = list.first;
      // Deteksi format baru (layer) vs format lama (stroke langsung)
      if (first is Map && first.containsKey('id') && first.containsKey('strokes')) {
        // Format baru: array of layers
        final loadedLayers = list
            .map((item) => DrawingLayer.fromJson(item as Map<String, dynamic>))
            .toList();
        layers.assignAll(loadedLayers);
        activeLayerIndex.value = 0;
      } else {
        // Format lama: array of strokes — bungkus jadi 1 layer
        final layer = DrawingLayer(id: 'layer_legacy', name: 'Layer 1');
        final loaded = list
            .map((item) => DrawingStroke.fromJson(item as Map<String, dynamic>))
            .toList();
        layer.strokes.assignAll(loaded);
        layers.assignAll([layer]);
        activeLayerIndex.value = 0;
      }
    } catch (_) {
      _ensureDefaultLayer();
    }
  }

  String _strokesToJson() {
    return jsonEncode(layers.map((l) => l.toJson()).toList());
  }

  // ─── Layer Management ─────────────────────────────────────────────────────

  void addLayer() {
    final idx = layers.length + 1;
    final newLayer = DrawingLayer(
      id: 'layer_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Layer $idx',
    );
    // Tambahkan layer baru di atas layer aktif
    final insertAt = activeLayerIndex.value + 1;
    layers.insert(insertAt, newLayer);
    activeLayerIndex.value = insertAt;
  }

  void deleteLayer(int index) {
    if (layers.length <= 1) return; // Minimal 1 layer harus ada
    layers.removeAt(index);
    // Pastikan activeLayerIndex masih valid
    if (activeLayerIndex.value >= layers.length) {
      activeLayerIndex.value = layers.length - 1;
    }
  }

  void setActiveLayer(int index) {
    if (index < 0 || index >= layers.length) return;
    activeLayerIndex.value = index;
  }

  void toggleLayerVisibility(int index) {
    if (index < 0 || index >= layers.length) return;
    layers[index].isVisible.value = !layers[index].isVisible.value;
    layers.refresh();
  }

  void moveLayerUp(int index) {
    if (index <= 0 || index >= layers.length) return;
    final layer = layers.removeAt(index);
    layers.insert(index - 1, layer);
    if (activeLayerIndex.value == index) {
      activeLayerIndex.value = index - 1;
    } else if (activeLayerIndex.value == index - 1) {
      activeLayerIndex.value = index;
    }
  }

  void moveLayerDown(int index) {
    if (index < 0 || index >= layers.length - 1) return;
    final layer = layers.removeAt(index);
    layers.insert(index + 1, layer);
    if (activeLayerIndex.value == index) {
      activeLayerIndex.value = index + 1;
    } else if (activeLayerIndex.value == index + 1) {
      activeLayerIndex.value = index;
    }
  }

  void reorderVisualLayer(int oldVisualIndex, int newVisualIndex) {
    if (oldVisualIndex < newVisualIndex) {
      newVisualIndex -= 1;
    }
    
    final activeLayerId = layers[activeLayerIndex.value].id;
    
    final visualList = layers.reversed.toList();
    final layer = visualList.removeAt(oldVisualIndex);
    visualList.insert(newVisualIndex, layer);
    
    layers.assignAll(visualList.reversed.toList());
    
    // Update activeLayerIndex
    final newActiveIdx = layers.indexWhere((l) => l.id == activeLayerId);
    if (newActiveIdx != -1) {
      activeLayerIndex.value = newActiveIdx;
    }
  }

  void renameLayer(int index, String newName) {
    if (index < 0 || index >= layers.length) return;
    layers[index].name.value = newName;
  }

  // ─── Timer Control ────────────────────────────────────────────────────────

  void startTimer() {
    isPaused.value = false;
    isTimeUp.value = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (sisaWaktu.value <= 0) {
        timer.cancel();
        _onTimeUp();
      } else {
        sisaWaktu.value--;
        waktuTerpakai.value++;
        if (sisaWaktu.value % 30 == 0) {
          _persistState();
        }
      }
    });
  }

  void pauseTimer() {
    _timer?.cancel();
    isPaused.value = true;
  }

  void resumeTimer() {
    if (isTimeUp.value) return;
    startTimer();
  }

  void _onTimeUp() {
    isTimeUp.value = true;
    isPaused.value = true;
    _showTimeUpDialog();
  }

  void _showTimeUpDialog() {
    final user = Get.find<SessionController>().currentUser.value;
    final nyawaSisa = user?.nyawaEfektif ?? 0;

    // Ambil maxNyawa & durasi timer dari AppConfigService jika tersedia
    final configService = Get.isRegistered<AppConfigService>()
        ? Get.find<AppConfigService>()
        : null;
    final maxNyawaDisplay = configService?.maxNyawa.value ?? 3;
    final timerMenit = ((configService?.timerDurasiDetik.value ?? _timerDurasiDetik) / 60).round();

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Waktu Habis! ⏰',
          style: TextStyle(fontFamily: 'FredokaOne', fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Waktu $timerMenit menit sudah habis. Mau tambah waktu $timerMenit menit dengan nyawa?',
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(maxNyawaDisplay, (i) {
                return Icon(
                  i < nyawaSisa
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: i < nyawaSisa
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFCBD5E1),
                  size: 24,
                );
              }),
            ),
            const SizedBox(height: 4),
            Text(
              '$nyawaSisa nyawa tersisa',
              style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              submitDrawing();
            },
            child: const Text('Kumpulkan Sekarang',
                style: TextStyle(color: Colors.grey, fontFamily: 'Nunito')),
          ),
          if (nyawaSisa > 0)
            ElevatedButton(
              onPressed: () async {
                Get.back();
                await _gunakanNyawaUntukTambahWaktu();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Pakai ❤️ +$timerMenit menit',
                  style: const TextStyle(fontFamily: 'FredokaOne', fontSize: 13)),
            ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  bool _isUsingNyawa = false;

  Future<void> _gunakanNyawaUntukTambahWaktu() async {
    if (_isUsingNyawa) return;
    _isUsingNyawa = true;
    try {
      await Get.find<SessionController>().gunakanNyawa();
      nyawaDigunakan.value++;
      sisaWaktu.value = _timerDurasi;
      isTimeUp.value = false;
      startTimer();
    } catch (e) {
      EpicNotification.error('Ups!', e.toString().replaceAll('Exception: ', ''));
    } finally {
      _isUsingNyawa = false;
    }
  }

  /// Memaksa penyimpanan draft secara instan (digunakan saat exit)
  Future<void> forceSaveDraft() async {
    await _persistState();
  }

  void persistState() {
    _persistState();
  }

  Future<void> _persistState() async {
    if (_isSubmitted) return;
    if (_session == null) return;

    // Selalu serialize semua stroke agar tidak ada gambar yang hilang
    final String strokesData = _strokesToJson();

    // ✅ SELALU serialisasi stempelsData dengan list kosong untuk kompatibilitas ke belakang
    // Stempel yang sebenarnya sekarang disimpan di dalam strokesData sebagai bagian dari layer.
    const stempelsData = '[]';

    String? templateData;
    if (activeTemplate.value != null) {
      templateData = jsonEncode(activeTemplate.value!.toJson());
    }

    // Buat session baru dengan stempelsData yang pasti diisi (bukan null)
    _session = DrawingSessionModel(
      id: _session!.id,
      uid: _session!.uid,
      kategori: _session!.kategori,
      level: _session!.level,
      templateId: templateData ?? _session!.templateId,
      remainingSeconds: sisaWaktu.value,
      nyawaDigunakan: _session!.nyawaDigunakan,
      status: _session!.status,
      createdAt: _session!.createdAt,
      updatedAt: DateTime.now(),
      strokesData: strokesData,
      stempelsData: stempelsData, // ← selalu ditulis, tidak pernah null
      anyamanData: _session!.anyamanData,
      waktuTerpakai: waktuTerpakai.value,
    );

    await Get.find<DraftService>().saveDraft(_session!);
  }

  // ─── Eyedropper Logic ─────────────────────────────────────────────────────

  Future<void> _initEyedropper(Offset localPosition) async {
    try {
      final context = canvasKey.currentContext;
      if (context == null) return;
      final boundary = context.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) return;
      final size = renderBox.size;

      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return;

      _eyedropperBytes = byteData;
      _eyedropperWidth = image.width;
      _eyedropperHeight = image.height;

      _eyedropperScaleX = _eyedropperWidth / size.width;
      _eyedropperScaleY = _eyedropperHeight / size.height;

      _sampleColorAt(localPosition);
    } catch (e) {
      debugPrint('Error initiating eyedropper: $e');
    }
  }

  void _sampleColorAt(Offset localPosition) {
    if (_eyedropperBytes == null) return;

    final int x = (localPosition.dx * _eyedropperScaleX).clamp(0, _eyedropperWidth - 1).toInt();
    final int y = (localPosition.dy * _eyedropperScaleY).clamp(0, _eyedropperHeight - 1).toInt();

    final int pixelIndex = (y * _eyedropperWidth + x) * 4;
    if (pixelIndex >= _eyedropperBytes!.lengthInBytes - 4) return;

    final int r = _eyedropperBytes!.getUint8(pixelIndex);
    final int g = _eyedropperBytes!.getUint8(pixelIndex + 1);
    final int b = _eyedropperBytes!.getUint8(pixelIndex + 2);
    final int a = _eyedropperBytes!.getUint8(pixelIndex + 3);

    final Color color = a == 0 ? Colors.white : Color.fromARGB(255, r, g, b);
    activeColor.value = color;
  }

  // ─── Drawing Gestures ─────────────────────────────────────────────────────

  void onPointerDown(PointerDownEvent event) {
    final position = event.localPosition;
    
    // Eyedropper logic
    if (activeTool.value == DrawingTool.eyedropper) {
      eyedropperPosition.value = position;
      _initEyedropper(position);
      return;
    }
    
    activePointersMap[event.pointer] = position;
    
    // Stempel cursor logic
    if (activeTool.value == DrawingTool.cursor && activePointersMap.length == 1) {
      final canvasPos = _screenToCanvas(position);
      final onStempel = _isPositionOnAnyStempel(canvasPos);
      final active = activeStempelId.value.isNotEmpty ? _findStempel(activeStempelId.value) : null;
      
      if (onStempel || isInteractingWithStempel.value || (active != null && active.isResizing.value)) {
        // User clicked on a stempel or handle. Let the stempel gesture detector handle it.
        _isDraggingStempel = true;
      } else {
        activeStempelId.value = '';
        if (activeStempelShape.value != null) {
          placeNewStempel(canvasPos);
          _isDraggingStempel = true; // prevent panning while placing
        } else {
          _isDraggingStempel = false;
        }
      }
    } else if (activeTool.value != DrawingTool.cursor) {
      activeStempelId.value = '';
      _isDraggingStempel = false;
    }

    if (activePointersMap.length == 1) {
      if (activeTool.value == DrawingTool.cursor) {
         final active = activeStempelId.value.isNotEmpty ? _findStempel(activeStempelId.value) : null;
         final isResizing = active != null && active.isResizing.value;
         if (!_isDraggingStempel && !isResizing && !isInteractingWithStempel.value) {
            _setupTransform();
         }
      } else {
         _isDrawing = true;
         onPanStart(_screenToCanvas(position));
      }
    } else if (activePointersMap.length >= 2) {
      if (_isDrawing) {
        onPanCancel();
        _isDrawing = false;
      }
      _isDraggingStempel = false; // 2 fingers overrides stempel drag -> zooms canvas
      _setupTransform();
    }
  }

  void onPointerMove(PointerMoveEvent event) {
    final position = event.localPosition;
    
    if (activeTool.value == DrawingTool.eyedropper) {
      eyedropperPosition.value = position;
      _sampleColorAt(position);
      return;
    }
    
    if (activePointersMap.containsKey(event.pointer)) {
      activePointersMap[event.pointer] = position;
    }
    
    if (activePointersMap.length == 1) {
      if (_isDrawing) {
        onPanUpdate(_screenToCanvas(position));
      } else if (activeTool.value == DrawingTool.cursor) {
        final active = activeStempelId.value.isNotEmpty ? _findStempel(activeStempelId.value) : null;
        final isResizing = active != null && active.isResizing.value;
        if (!_isDraggingStempel && !isResizing && !isInteractingWithStempel.value) {
          _updateTransform();
        }
      }
    } else if (activePointersMap.length >= 2) {
      _updateTransform();
    }
  }

  void onPointerUp(PointerEvent event) {
    if (activeTool.value == DrawingTool.eyedropper) {
      eyedropperPosition.value = null;
      _eyedropperBytes = null;
      
      final color = activeColor.value;
      EpicNotification.custom(
        'Warna Disalin',
        'Berhasil mengambil warna dari kanvas.',
        color: color,
        icon: Icons.colorize_rounded,
        duration: const Duration(seconds: 2),
      );
      
      activeTool.value = _toolBeforeEyedropper;
      return;
    }
    
    activePointersMap.remove(event.pointer);
    
    if (activePointersMap.isEmpty) {
      if (_isDrawing) {
        onPanEnd();
        _isDrawing = false;
      }
      _isDraggingStempel = false;
    } else if (activePointersMap.length == 1) {
      _isDrawing = false; // Do not resume drawing if dropping to 1 finger
      _setupTransform(); // Reset pivot points for 1 finger pan
    } else if (activePointersMap.length >= 2) {
      _setupTransform();
    }
  }

  void onPointerCancel(PointerEvent event) {
    if (activeTool.value == DrawingTool.eyedropper) {
      eyedropperPosition.value = null;
      _eyedropperBytes = null;
      activeTool.value = _toolBeforeEyedropper;
      return;
    }
    
    activePointersMap.remove(event.pointer);
    
    if (activePointersMap.isEmpty) {
      if (_isDrawing) {
        onPanCancel();
        _isDrawing = false;
      }
      _isDraggingStempel = false;
    } else {
      if (_isDrawing) {
        onPanCancel();
        _isDrawing = false;
      }
      _setupTransform();
    }
  }

  void _setupTransform() {
    if (activePointersMap.isEmpty) return;
    
    final points = activePointersMap.values.toList();
    if (points.length == 1) {
      _prevFocalPoint = points[0];
      _prevDistance = 0.0;
      _prevAngle = 0.0;
    } else {
      final p1 = points[0];
      final p2 = points[1];
      _prevFocalPoint = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      _prevDistance = (p1 - p2).distance;
      _prevAngle = math.atan2(p1.dy - p2.dy, p1.dx - p2.dx);
    }
  }

  void _updateTransform() {
    if (activePointersMap.isEmpty || _prevFocalPoint == null) return;
    
    final points = activePointersMap.values.toList();
    Offset currentFocalPoint;
    double currentDistance = 0.0;
    double currentAngle = 0.0;
    
    if (points.length == 1) {
      currentFocalPoint = points[0];
    } else {
      final p1 = points[0];
      final p2 = points[1];
      currentFocalPoint = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      currentDistance = (p1 - p2).distance;
      currentAngle = math.atan2(p1.dy - p2.dy, p1.dx - p2.dx);
    }
    
    // Scale limit check
    double deltaScale = 1.0;
    if (points.length >= 2 && _prevDistance != null && _prevDistance! > 0 && currentDistance > 0) {
        deltaScale = currentDistance / _prevDistance!;
    }
    
    double deltaAngle = 0.0;
    if (points.length >= 2 && _prevAngle != null) {
        deltaAngle = currentAngle - _prevAngle!;
    }
    
    final currentScale = canvasMatrix.value.getMaxScaleOnAxis();
    final projectedScale = currentScale * deltaScale;
    
    // Sangat dekat: No limit for zoom in. Lower limit slightly to 0.05 for zooming out
    final actualScaleDelta = projectedScale < 0.05 ? (0.05 / currentScale) : deltaScale;

    final deltaMatrix = Matrix4.identity()
      ..translate(currentFocalPoint.dx, currentFocalPoint.dy)
      ..scale(actualScaleDelta, actualScaleDelta)
      ..rotateZ(deltaAngle)
      ..translate(-_prevFocalPoint!.dx, -_prevFocalPoint!.dy);

    canvasMatrix.value = deltaMatrix.multiplied(canvasMatrix.value);
    
    _prevFocalPoint = currentFocalPoint;
    _prevDistance = currentDistance;
    _prevAngle = currentAngle;
  }

  void _loadTimerState() {
    if (_wasPausedByLifecycle) {
      _wasPausedByLifecycle = false;
      resumeTimer();
    } else if (!isPaused.value && !isTimeUp.value) {
      resumeTimer();
    }
  }

  // ─── Template Control ─────────────────────────────────────────────────────

  void setTemplate(DrawingTemplateModel? template) {
    activeTemplate.value = template;
    hasTemplate.value = template != null;
  }

  void setTemplateOpacity(double val) {
    templateOpacity.value = val.clamp(0.0, 1.0);
  }

  // ─── Tool Control ─────────────────────────────────────────────────────────

  void setTool(DrawingTool tool) {
    if (tool != DrawingTool.eyedropper) {
      _toolBeforeEyedropper = tool;
    }
    activeTool.value = tool;
    currentStroke.value = null;
    if (tool != DrawingTool.cursor) {
      activeStempelId.value = '';
    }
  }

  void setPencilType(PencilType type) {
    activePencilType.value = type;
    // Pastikan tool adalah pensil
    if (activeTool.value == DrawingTool.eraser) {
      activeTool.value = DrawingTool.pencil;
    }
  }

  void setColor(Color color) {
    activeColor.value = color;
    if (activeStempelId.value.isNotEmpty) {
      final stempel = _findStempel(activeStempelId.value);
      if (stempel != null) {
        stempel.color.value = color;
      }
    }
  }

  void setThickness(double val) {
    thickness.value = val.clamp(1.0, 40.0);
    if (activeStempelId.value.isNotEmpty) {
      final stempel = _findStempel(activeStempelId.value);
      if (stempel != null) {
        stempel.strokeWidth.value = thickness.value;
      }
    }
  }

  void setOpacity(double val) {
    opacity.value = val.clamp(0.01, 1.0);
    if (activeStempelId.value.isNotEmpty) {
      final stempel = _findStempel(activeStempelId.value);
      if (stempel != null) {
        stempel.opacity.value = opacity.value;
      }
    }
  }

  void setShape(String? shape) {
    activeShape.value = shape;
  }

  void onPanCancel() {
    currentStroke.value = null;
  }

  void onPanStart(Offset position) {
    if (isPaused.value || isTimeUp.value) return;

    popupMenu.value = '';

    if (activeTool.value == DrawingTool.straightLine) {
      currentStroke.value = DrawingStroke(
        tool: activeTool.value,
        pencilType: activePencilType.value,
        points: [position, position],
        color: activeColor.value,
        thickness: thickness.value,
        opacity: opacity.value,
        isStraightLine: true,
      );
    } else if (activeTool.value == DrawingTool.shape ||
        activeTool.value == DrawingTool.symbol) {
      currentStroke.value = DrawingStroke(
        tool: activeTool.value,
        pencilType: activePencilType.value,
        points: [position, position],
        color: activeColor.value,
        thickness: thickness.value,
        opacity: opacity.value,
        shapeType: activeShape.value,
      );
    } else {
      currentStroke.value = DrawingStroke(
        tool: activeTool.value,
        pencilType: activeTool.value == DrawingTool.eraser
            ? PencilType.ballpoint
            : activePencilType.value,
        points: [position],
        color: activeTool.value == DrawingTool.eraser
            ? Colors.transparent
            : activeColor.value,
        thickness: activeTool.value == DrawingTool.eraser
            ? thickness.value * 2
            : thickness.value,
        opacity: activeTool.value == DrawingTool.eraser
            ? 1.0
            : opacity.value,
      );
    }
  }

  void onPanUpdate(Offset position) {
    if (isPaused.value || isTimeUp.value) return;
    final stroke = currentStroke.value;
    if (stroke == null) return;

    if (activeTool.value == DrawingTool.straightLine ||
        activeTool.value == DrawingTool.shape ||
        activeTool.value == DrawingTool.symbol) {
      currentStroke.value = DrawingStroke(
        tool: stroke.tool,
        pencilType: stroke.pencilType,
        points: [stroke.points.first, position],
        color: stroke.color,
        thickness: stroke.thickness,
        opacity: stroke.opacity,
        isStraightLine: stroke.isStraightLine,
        shapeType: stroke.shapeType,
      );
    } else {
      // Smoothing: Distance threshold to filter points that are too close (removes jitter & prevents pf crashes)
      if (stroke.points.isNotEmpty) {
        final lastPoint = stroke.points.last;
        final distance = (position - lastPoint).distance;
        
        final scale = canvasMatrix.value.getMaxScaleOnAxis();
        // Prevent perfect_freehand from crashing due to points being too close relative to stroke thickness
        final minCanvasDistByThickness = stroke.thickness * 0.15; // At least 15% of thickness
        final screenDistInCanvas = 2.0 / scale; // At least 2 pixels on screen
        final threshold = math.max(minCanvasDistByThickness, screenDistInCanvas);
        
        if (distance < threshold) return;
      }

      final newPoints = [...stroke.points, position];
      currentStroke.value = DrawingStroke(
        tool: stroke.tool,
        pencilType: stroke.pencilType,
        points: newPoints,
        color: stroke.color,
        thickness: stroke.thickness,
        opacity: stroke.opacity,
        isDot: false,
      );
    }
  }

  void onPanEnd() {
    if (isPaused.value || isTimeUp.value) return;
    final stroke = currentStroke.value;
    if (stroke == null) return;

    if (stroke.points.length == 1) {
      activeLayer.strokes.add(DrawingStroke(
        tool: stroke.tool,
        pencilType: stroke.pencilType,
        points: stroke.points,
        color: stroke.color,
        thickness: stroke.thickness,
        opacity: stroke.opacity,
        isDot: true,
      ));
    } else {
      activeLayer.strokes.add(stroke);
    }

    currentStroke.value = null;
    if (layers.isNotEmpty) {
      activeLayer.undoStack.clear();
    }
  }

  void onTap(Offset position) {
    if (isPaused.value || isTimeUp.value) return;
    activeLayer.strokes.add(DrawingStroke(
      tool: activeTool.value,
      pencilType: activeTool.value == DrawingTool.eraser
          ? PencilType.ballpoint
          : activePencilType.value,
      points: [position],
      color: activeTool.value == DrawingTool.eraser
          ? Colors.transparent
          : activeColor.value,
      thickness: thickness.value,
      opacity: activeTool.value == DrawingTool.eraser ? 1.0 : opacity.value,
      isDot: true,
    ));
    // Pastikan tidak merusak layer dummy (safety check)
    if (layers.isEmpty) return;
    
    activeLayer.undoStack.clear();
  }

  // ─── Undo / Redo ──────────────────────────────────────────────────────────

  void undo() {
    if (layers.isEmpty) return;
    if (activeLayer.strokes.isEmpty) return;
    final last = activeLayer.strokes.removeLast();
    activeLayer.undoStack.add(last);
    layers.refresh();
  }

  void redo() {
    if (layers.isEmpty) return;
    if (activeLayer.undoStack.isEmpty) return;
    activeLayer.strokes.add(activeLayer.undoStack.removeLast());
    layers.refresh();
  }


  void _showTemplateSelector() {
    pauseTimer();
    _templateSelectionMade = false;
    Get.bottomSheet(
      TemplateSelectorSheet(
        kategori: kategori,
        level: level,
        currentTemplateId: activeTemplate.value?.id,
        onSelected: (template) {
          _templateSelectionMade = true;
          setTemplate(template);
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
    ).then((_) {
      if (!_templateSelectionMade) {
        // User cancelled template selection, exit drawing screen
        Get.back();
      } else {
        _showLevelInstructionsDialog();
      }
    });
  }

  void clearCanvas() {
    for (final layer in layers) {
      layer.strokes.clear();
      layer.undoStack.clear();
      layer.stempels.clear(); // Hapus juga bentuk (stempel) di semua layer
    }
    activeStempelId.value = '';
    currentStroke.value = null;
  }

  // ─── Timer Logic ───────────────────────────────────────────────────────────────

  Future<Uint8List?> captureCanvas() async {
    try {
      debugPrint('🎨 [captureCanvas] Memulai proses capture (hiding template/overlays)...');
      // Sembunyikan overlay template, garis bantu simetri, dan preview alat
      isCapturing.value = true;

      // Tunggu frame selesai di-paint ulang dalam keadaan bersih (berfungsi di debug DAN release)
      await Future.delayed(const Duration(milliseconds: 150));
      await WidgetsBinding.instance.endOfFrame;

      final context = canvasKey.currentContext;
      if (context == null || !context.mounted) {
        debugPrint('🎨 [captureCanvas] ERROR: canvasKey.currentContext is null or unmounted');
        return null;
      }
      final boundary = context.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('🎨 [captureCanvas] ERROR: RenderRepaintBoundary is null');
        return null;
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      debugPrint('🎨 [captureCanvas] Selesai. Ukuran bytes: ${bytes?.length}');
      return bytes;
    } catch (e) {
      debugPrint('🎨 [captureCanvas] ERROR: Terjadi exception -> $e');
      return null;
    } finally {
      isCapturing.value = false;
    }
  }

  Future<void> submitDrawing() async {
    debugPrint('🚀 [submitDrawing] Dipanggil!');
    pauseTimer();
    // ✅ Validasi elemen gambar (coretan dan stempel)
    final totalStempelCount = layers.fold<int>(0, (acc, l) => acc + l.stempels.length);
    final totalElements = totalStrokeCount + totalStempelCount;

    if (totalElements == 0) {
      EpicNotification.warning(
        'Kanvas Kosong',
        'Kamu belum menggambar apa pun! Gambarlah sesuatu sebelum mengumpulkan.',
      );
      resumeTimer();
      return;
    }

    // 🛡️ Pengaman: Minimal harus ada 5 goresan/elemen agar tidak dinilai hanya dari coretan asal-asalan
    if (totalElements < 5) {
      EpicNotification.warning(
        'Perlu Lebih Banyak Goresan',
        'Goresanmu masih terlalu sedikit. Lanjutkan Menggambar',
      );
      resumeTimer();
      return;
    }

    // Cek izin akses Gemini (Google Auth)
    final tokenService = GeminiTokenService.instance;
    bool hasPermission = await tokenService.hasGeminiPermission();
    if (!hasPermission) {
      debugPrint('⚠️ Izin Gemini belum diberikan, meminta izin...');
      hasPermission = await tokenService.requestGeminiPermission();
      if (!hasPermission) {
        debugPrint('❌ Izin ditolak! Kembali ke kanvas.');
        EpicNotification.error(
          'Izin Diperlukan',
          'Kamu harus memberikan izin akses untuk mengumpulkan karya ini.',
        );
        resumeTimer();
        return;
      }
    }

    activeStempelId.value = ''; // Deselect stempel so UI buttons hide
    
    // Tandai sudah submit SEBELUM async apapun, agar _persistState() tidak bisa
    // menimpa draft kembali saat lifecycle change atau onClose() dipanggil.
    _isSubmitted = true;
    debugPrint('✅ [submitDrawing] _isSubmitted = true, draft tidak akan disimpan lagi.');

    await Future.delayed(const Duration(milliseconds: 100)); // Wait for UI update

    // 🧹 Hapus draft secara instan dari list memori agar hilang dari UI home.
    final uid = Get.find<SessionController>().currentUser.value?.uid ?? '';
    try {
      Get.find<DraftService>().clearDraftImmediately(uid, kategori, level);
      // Null-kan _session agar _persistState() di onClose() tidak menimpa kembali.
      _session = null;
      debugPrint('✅ Session di-null untuk kategori $kategori level $level');
    } catch (e) {
      debugPrint('Error deleting draft: $e');
    }

    final waktuPengerjaan = waktuTerpakai.value;

    debugPrint('🚀 [submitDrawing] Menjalankan captureCanvas...');
    final imageBytes = await captureCanvas();
    if (imageBytes == null) {
      debugPrint('🚀 [submitDrawing] GAGAL: imageBytes null, submit dibatalkan!');
      EpicNotification.error(
        'Gagal Menyimpan',
        'Terjadi masalah saat mengambil gambar kanvas.',
      );
      return;
    }

    debugPrint('🚀 [submitDrawing] Berhasil capture. Pindah ke DrawingResultScreen...');
    final context = Get.context;
    if (context != null && context.mounted) {
      EpicTransitionOverlay.show(
        context: context,
        kategori: kategori,
        onComplete: () {
          Get.to(
            () => DrawingResultScreen(
              kategori: kategori,
              level: level,
              nyawaDigunakan: nyawaDigunakan.value,
              waktuPengerjaan: waktuPengerjaan.clamp(0, _timerDurasi * 4),
              strokeCount: totalStrokeCount,
              imageBytes: imageBytes,
              templateId: activeTemplate.value?.id,
            ),
            transition: Transition.fadeIn,
          );
        },
      );
    } else {
      Get.to(
        () => DrawingResultScreen(
          kategori: kategori,
          level: level,
          nyawaDigunakan: nyawaDigunakan.value,
          waktuPengerjaan: waktuPengerjaan.clamp(0, _timerDurasi * 4),
          strokeCount: totalStrokeCount,
          imageBytes: imageBytes,
          templateId: activeTemplate.value?.id,
        ),
        transition: Transition.fadeIn,
      );
    }
  }
}

// ─── Stempel Model ─────────────────────────────────────────────────────────────
