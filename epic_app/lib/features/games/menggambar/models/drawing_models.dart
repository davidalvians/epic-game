import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'stempel_model.dart';

// ─── Enum Tools ────────────────────────────────────────────────────────────────

enum DrawingTool {
  cursor, // Kursor untuk mengatur bentuk
  pencil, // Pensil bebas
  straightLine, // Garis lurus
  shape, // Bangun datar (keris) - old
  symbol, // Simbol dekoratif (batik) - old
  eraser, // Penghapus
  stempel, // Tool stempel/bentuk baru
  eyedropper, // Pipet warna (menyalin warna dari kanvas)
}

// ─── Jenis Pensil ──────────────────────────────────────────────────────────────

enum PencilType {
  ballpoint, // Bolpoin — garis halus, konsisten, opacity penuh
  pencil, // Pensil — sedikit kasar, opacity 85%, variasi tipis
  marker, // Spidol — tebal, flat, opaque
  watercolor, // Cat air — soft edges, semi-transparan
}

extension PencilTypeExt on PencilType {
  String get label {
    switch (this) {
      case PencilType.ballpoint:
        return 'Bolpoin';
      case PencilType.pencil:
        return 'Pensil';
      case PencilType.marker:
        return 'Spidol';
      case PencilType.watercolor:
        return 'Cat Air';
    }
  }

  String get emoji {
    switch (this) {
      case PencilType.ballpoint:
        return '🖊️';
      case PencilType.pencil:
        return '✏️';
      case PencilType.marker:
        return '🖍️';
      case PencilType.watercolor:
        return '🎨';
    }
  }

  double get opacityFactor {
    switch (this) {
      case PencilType.ballpoint:
        return 1.0;
      case PencilType.pencil:
        return 0.8;
      case PencilType.marker:
        return 1.0;
      case PencilType.watercolor:
        return 0.5;
    }
  }

  double get thicknessMultiplier {
    switch (this) {
      case PencilType.ballpoint:
        return 1.0;
      case PencilType.pencil:
        return 1.1;
      case PencilType.marker:
        return 2.0;
      case PencilType.watercolor:
        return 2.5;
    }
  }

  StrokeCap get strokeCap {
    switch (this) {
      case PencilType.ballpoint:
        return StrokeCap.round;
      case PencilType.pencil:
        return StrokeCap.round;
      case PencilType.marker:
        return StrokeCap.round;
      case PencilType.watercolor:
        return StrokeCap.round;
    }
  }

  BlendMode get blendMode {
    switch (this) {
      case PencilType.watercolor:
        return BlendMode.multiply;
      default:
        return BlendMode.srcOver;
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

  // Retain finalized smoothing segments while the active stroke grows. The
  // trailing line is added to a copy, so its previous endpoint never survives.
  Path? smoothingPrefix;
  int smoothedPointCount = 0;

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
          .map(
            (p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
          )
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

  Map<String, dynamic> toJson({
    Map<String, dynamic> Function(DrawingStroke)? encodeStroke,
  }) => {
    'id': id,
    'name': name.value,
    'strokes': strokes.map((s) => encodeStroke?.call(s) ?? s.toJson()).toList(),
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
