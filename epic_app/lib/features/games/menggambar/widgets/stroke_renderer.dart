import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:perfect_freehand/perfect_freehand.dart' as pf;

import '../models/drawing_models.dart';

final _resetProofs = Expando<(Path, Map<Rect, bool>)>();

bool _segmentHitsRect(double ax, double ay, double bx, double by, double left,
    double top, double right, double bottom) {
  // Conservative numerical guard, followed by an exact slab intersection.
  // Bounding boxes alone grossly over-count long diagonal edges in scribbles.
  left -= 1e-10;
  top -= 1e-10;
  right += 1e-10;
  bottom += 1e-10;
  if (math.max(ax, bx) < left ||
      math.min(ax, bx) > right ||
      math.max(ay, by) < top ||
      math.min(ay, by) > bottom) {
    return false;
  }
  var first = 0.0, last = 1.0;
  final dx = bx - ax, dy = by - ay;
  if (dx != 0) {
    final a = (left - ax) / dx, b = (right - ax) / dx;
    first = math.max(first, math.min(a, b));
    last = math.min(last, math.max(a, b));
  }
  if (dy != 0) {
    final a = (top - ay) / dy, b = (bottom - ay) / dy;
    first = math.max(first, math.min(a, b));
    last = math.min(last, math.max(a, b));
  }
  return first <= last + 1e-12;
}

/// Only a proven full clear/opaque replacement may discard older raster work.
/// Editable source strokes are never removed. Geometry runs off the UI isolate.
Future<bool> drawingStrokeOverwritesRegion(
    DrawingStroke stroke, Rect region) async {
  final eraser = stroke.tool == DrawingTool.eraser;
  final opaque = stroke.tool == DrawingTool.pencil &&
      stroke.color.a == 1 &&
      stroke.opacity == 1 &&
      stroke.pencilType.opacityFactor == 1 &&
      stroke.pencilType.blendMode == BlendMode.srcOver;
  if ((!eraser && !opaque) || stroke.isDot || stroke.isStraightLine) {
    return false;
  }
  final outline = _pressureOutlines[stroke];
  if (outline == null ||
      !identical(outline.path, stroke.cachedPath) ||
      outline.points.isEmpty) {
    return false;
  }
  var cached = _resetProofs[stroke];
  if (cached == null || !identical(cached.$1, outline.path)) {
    cached = (outline.path, <Rect, bool>{});
    _resetProofs[stroke] = cached;
  }
  final known = cached.$2[region];
  if (known != null) return known;
  final data = <double>[
    region.left,
    region.top,
    region.right,
    region.bottom,
    for (final p in outline.points) ...[
      p.dx / outline.zoom,
      p.dy / outline.zoom
    ]
  ];
  final result = await compute(_filledOutlineContainsRect, data);
  if (cached.$2.length >= 64) cached.$2.clear();
  cached.$2[region] = result;
  return result;
}

bool _filledOutlineContainsRect(List<double> data, [int maxBudget = 500000]) {
  var budget = maxBudget;
  bool covered(
      double left, double top, double right, double bottom, int depth) {
    final cx = (left + right) / 2;
    final cy = (top + bottom) / 2;
    var winding = 0;
    var decreases = 0;
    var increases = 0;
    var ax = data[data.length - 2];
    var ay = data.last;
    for (var i = 4; i < data.length; i += 2) {
      if (--budget <= 0) return false;
      final bx = data[i];
      final by = data[i + 1];
      final side = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax);
      if (ay <= cy && by > cy && side > 0) winding++;
      if (ay > cy && by <= cy && side < 0) winding--;
      // A segment whose bounding box misses this cell cannot change its
      // winding. Crossing from its left to right decreases winding by one;
      // crossing from right to left increases it. Over-counting is safe.
      if (_segmentHitsRect(ax, ay, bx, by, left, top, right, bottom)) {
        if (side >= 0) decreases++;
        if (side <= 0) increases++;
      }
      ax = bx;
      ay = by;
    }
    if (winding == 0) return false;
    if (winding - decreases > 0 || winding + increases < 0) return true;
    if (depth >= 6) return false;
    return covered(left, top, cx, cy, depth + 1) &&
        covered(cx, top, right, cy, depth + 1) &&
        covered(left, cy, cx, bottom, depth + 1) &&
        covered(cx, cy, right, bottom, depth + 1);
  }

  return covered(data[0], data[1], data[2], data[3], 0);
}

Future<bool> drawingStrokesOverwriteRegion(
    List<DrawingStroke> strokes, Rect region, double margin) async {
  final outlines = <List<double>>[];
  for (final stroke in strokes) {
    final eraser = stroke.tool == DrawingTool.eraser;
    final opaque = stroke.tool == DrawingTool.pencil &&
        stroke.color.a == 1 &&
        stroke.opacity == 1 &&
        stroke.pencilType.opacityFactor == 1 &&
        stroke.pencilType.blendMode == BlendMode.srcOver;
    if ((!eraser && !opaque) || stroke.isDot || stroke.isStraightLine) continue;
    final outline = _pressureOutlines[stroke];
    if (outline == null || !identical(outline.path, stroke.cachedPath)) {
      continue;
    }
    outlines.add([
      for (final p in outline.points) ...[
        p.dx / outline.zoom,
        p.dy / outline.zoom
      ]
    ]);
  }
  if (outlines.isEmpty) return false;
  return compute(_filledOutlinesCoverRect, (
    [region.left, region.top, region.right, region.bottom, margin],
    outlines
  ));
}

bool _filledOutlinesCoverRect((List<double>, List<List<double>>) input) {
  final box = input.$1;
  var budget = 8000000;
  bool covered(
      double left, double top, double right, double bottom, int depth) {
    final cx = (left + right) / 2;
    final cy = (top + bottom) / 2;
    var insideAny = false;
    // Inflate EACH cell, not just the outer rectangle: coverage from two
    // half-antialiased edges must never be mistaken for one full clear.
    final l = left - box[4], t = top - box[4];
    final r = right + box[4], b = bottom + box[4];
    for (final points in input.$2) {
      if (points.isEmpty) continue;
      var winding = 0, increases = 0, decreases = 0;
      var ax = points[points.length - 2], ay = points.last;
      for (var i = 0; i < points.length; i += 2) {
        if (--budget <= 0) return false;
        final bx = points[i], by = points[i + 1];
        final side = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax);
        if (ay <= cy && by > cy && side > 0) winding++;
        if (ay > cy && by <= cy && side < 0) winding--;
        if (_segmentHitsRect(ax, ay, bx, by, l, t, r, b)) {
          if (side >= 0) decreases++;
          if (side <= 0) increases++;
        }
        ax = bx;
        ay = by;
      }
      insideAny |= winding != 0;
      if (winding - decreases > 0 || winding + increases < 0) return true;
      if (winding != 0) {
        // Resolve conservative segment bounding-box overlaps inside this
        // polygon's already-expanded cell. Do not expand those inner proof
        // subdivisions again, which would reject valid overlapping coverage.
        budget -= 20000;
        if (budget <= 0) return false;
        if (_filledOutlineContainsRect([l, t, r, b, ...points], 20000)) {
          return true;
        }
      }
    }
    if (!insideAny || depth >= 6) return false;
    return covered(left, top, cx, cy, depth + 1) &&
        covered(cx, top, right, cy, depth + 1) &&
        covered(left, cy, cx, bottom, depth + 1) &&
        covered(cx, cy, right, bottom, depth + 1);
  }

  return covered(box[0], box[1], box[2], box[3], 0);
}

enum DrawingPaintWork { empty, constantMask, normal }

bool shouldUseLowCostLivePreview(DrawingStroke stroke, double zoomScale) =>
    zoomScale >= 4 &&
    stroke.thickness >= 32 &&
    stroke.tool == DrawingTool.pencil &&
    (stroke.pencilType == PencilType.ballpoint ||
        stroke.pencilType == PencilType.watercolor);

bool canOverlayLiveStroke(DrawingStroke stroke, double zoomScale) =>
    (stroke.tool == DrawingTool.pencil ||
            stroke.tool == DrawingTool.straightLine ||
            stroke.tool == DrawingTool.shape ||
            stroke.tool == DrawingTool.symbol) &&
        stroke.pencilType.blendMode == BlendMode.srcOver ||
    shouldUseLowCostLivePreview(stroke, zoomScale);

// Conservative bounds first, then the same exact clipped path used for paint.
// Empty paths must not force a native image job just to copy an unchanged tile.
bool _strokeTouchesRegion(DrawingStroke stroke, Rect region, double zoom) {
  final pressure = !stroke.isDot &&
      !stroke.isStraightLine &&
      (stroke.tool == DrawingTool.eraser ||
          stroke.tool == DrawingTool.pencil &&
              (stroke.pencilType == PencilType.ballpoint ||
                  stroke.pencilType == PencilType.marker));
  final sigma = zoom >= 5 || stroke.tool == DrawingTool.eraser
      ? 0.0
      : stroke.pencilType == PencilType.watercolor
          ? (stroke.thickness * .4 / zoom.clamp(.1, 10.0)).clamp(.05, 8.0)
          : stroke.pencilType == PencilType.pencil
              ? (1 / zoom.clamp(.1, 10.0)).clamp(.05, 2.0)
              : 0.0;
  final radius = pressure
      ? 0.0
      : stroke.thickness *
          (stroke.tool == DrawingTool.eraser
              ? 2
              : stroke.pencilType.thicknessMultiplier) /
          2;
  final path = stroke.cachedPath;
  Rect bounds;
  if (path != null) {
    bounds = path.getBounds();
  } else {
    var left = stroke.points.first.dx, right = left;
    var top = stroke.points.first.dy, bottom = top;
    for (final point in stroke.points.skip(1)) {
      left = math.min(left, point.dx);
      right = math.max(right, point.dx);
      top = math.min(top, point.dy);
      bottom = math.max(bottom, point.dy);
    }
    bounds = Rect.fromLTRB(left, top, right, bottom);
    if (stroke.tool == DrawingTool.shape || stroke.tool == DrawingTool.symbol) {
      bounds = bounds.inflate(bounds.longestSide * 2 + stroke.thickness * 3);
    }
  }
  // A path without a cached pressure outline still needs its full nib bounds.
  final padding = path == null && pressure ? stroke.thickness * 2 : radius;
  if (!bounds.inflate(padding + 4 * sigma + 2).overlaps(region)) return false;
  if (path == null ||
      stroke.isDot ||
      stroke.isStraightLine ||
      stroke.tool == DrawingTool.shape ||
      stroke.tool == DrawingTool.symbol) {
    return true;
  }
  final clipped = pressure
      ? _windowedFilledPath(stroke, region.inflate(2))
      : _windowedSmoothedPath(stroke, region.inflate(radius + 3 * sigma + 2));
  final clippedBounds = clipped.getBounds();
  if (clippedBounds.width != 0 || clippedBounds.height != 0) return true;
  // Keep degenerate centerlines: a round cap can still paint a dot.
  return !pressure && bounds.width == 0 && bounds.height == 0;
}

DrawingPaintWork paintDrawingStroke(
  Canvas canvas,
  DrawingStroke stroke, {
  double zoomScale = 1,
  bool isLive = false,
  bool lowCostLivePreview = false,
  Rect? rasterClip,
}) {
  if (stroke.points.isEmpty) return DrawingPaintWork.empty;
  final lightWatercolor = lowCostLivePreview &&
      isLive &&
      stroke.tool == DrawingTool.pencil &&
      stroke.pencilType == PencilType.watercolor &&
      zoomScale >= 4 &&
      stroke.thickness >= 32;
  if (rasterClip != null &&
      !_strokeTouchesRegion(stroke, rasterClip, zoomScale)) {
    if (!isLive) {
      stroke.smoothingPrefix = null;
      stroke.smoothedPointCount = 0;
    }
    return DrawingPaintWork.empty;
  }
  final solid = stroke.pencilType == PencilType.pencil;
  if (rasterClip != null &&
      stroke.tool == DrawingTool.pencil &&
      !stroke.isDot &&
      !stroke.isStraightLine &&
      stroke.points.length >= 2 &&
      (solid || stroke.pencilType == PencilType.watercolor)) {
    final sigma = zoomScale >= 5
        ? 0.0
        : solid
            ? (1 / zoomScale.clamp(.1, 10.0)).clamp(.05, 2.0)
            : ((stroke.thickness *
                    (lightWatercolor ? .12 : .4) /
                    zoomScale.clamp(.1, 10.0)))
                .clamp(.05, lightWatercolor ? 2.0 : 8.0);
    final radius = stroke.thickness * stroke.pencilType.thicknessMultiplier / 2;
    if (_fullyCovered(stroke, rasterClip.inflate(4 * sigma + 2), radius)) {
      _coverageHits++;
      // Keep the native mask operation: Impeller and Skia differ in how a
      // translucent solid mask is composed. Replacing it with a plain fill
      // changes the original brush's opacity on a real Android device.
      canvas.save();
      canvas.clipRect(rasterClip);
      canvas.drawRect(
          rasterClip.inflate(4 * sigma + 2),
          Paint()
            ..isAntiAlias = false
            ..maskFilter = zoomScale < 5 && !lightWatercolor
                ? MaskFilter.blur(
                    solid ? BlurStyle.solid : BlurStyle.normal, sigma)
                : null
            ..blendMode = lightWatercolor
                ? BlendMode.srcOver
                : stroke.pencilType.blendMode
            ..color = stroke.color.withValues(
                alpha: (stroke.color.a *
                        stroke.opacity *
                        stroke.pencilType.opacityFactor)
                    .clamp(0, 1)));
      canvas.restore();
      return DrawingPaintWork.constantMask;
    }
  }
  if (rasterClip != null &&
      zoomScale < 5 &&
      stroke.tool == DrawingTool.pencil &&
      stroke.pencilType == PencilType.watercolor &&
      !stroke.isDot &&
      !lightWatercolor) {
    final sigma =
        (stroke.thickness * .4 / zoomScale.clamp(.1, 10.0)).clamp(.05, 8.0);
    final input = rasterClip.inflate(4 * sigma + 2);
    canvas.save();
    canvas.clipRect(input);
    canvas.saveLayer(
        input,
        Paint()
          ..blendMode = stroke.pencilType.blendMode
          ..imageFilter = ui.ImageFilter.blur(
              sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal));
    _paintDrawingStroke(canvas, stroke,
        zoomScale: zoomScale,
        isLive: isLive,
        lowCostLivePreview: lowCostLivePreview,
        rasterClip: input,
        disableMask: true,
        blendOverride: BlendMode.srcOver);
    canvas.restore();
    canvas.restore();
    return DrawingPaintWork.normal;
  }
  _paintDrawingStroke(canvas, stroke,
      zoomScale: zoomScale,
      isLive: isLive,
      lowCostLivePreview: lowCostLivePreview,
      rasterClip: rasterClip);
  return DrawingPaintWork.normal;
}

final _coverageIndices = Expando<_CoverageIndex>();
int _coverageHits = 0;
@visibleForTesting
int get debugCoverageFastPathHits => _coverageHits;

class _CoverageIndex {
  _CoverageIndex(this.radius, this.count, this.cells);
  final double radius;
  final int count;
  final Map<(int, int), List<Offset>> cells;
}

bool _fullyCovered(DrawingStroke stroke, Rect region, double radius) {
  final safeRadius =
      radius - 2; // Keep antialiasing strictly outside the proof.
  if (safeRadius <= 0 ||
      stroke.points.length * 2 * math.pi * safeRadius * safeRadius <
          region.width * region.height) {
    return false;
  }
  var index = _coverageIndices[stroke];
  if (index == null ||
      index.radius != radius ||
      index.count != stroke.points.length) {
    final cells = <(int, int), List<Offset>>{};
    void add(Offset p) =>
        (cells[((p.dx / radius).floor(), (p.dy / radius).floor())] ??= [])
            .add(p);
    final points = stroke.points;
    var a = points.first;
    add(a);
    for (var i = 1; i < points.length - 1; i++) {
      final c = (points[i] + points[i + 1]) / 2;
      add(a * .25 + points[i] * .5 + c * .25);
      add(c);
      a = c;
    }
    add((a + points.last) / 2);
    add(points.last);
    index = _CoverageIndex(radius, points.length, cells);
    _coverageIndices[stroke] = index;
  }
  final cells = index.cells;
  final squared = safeRadius * safeRadius;
  bool covered(Rect r, int depth) {
    final center = r.center;
    final x = (center.dx / radius).floor();
    final y = (center.dy / radius).floor();
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        for (final p in cells[(x + dx, y + dy)] ?? const <Offset>[]) {
          final farX = math.max((p.dx - r.left).abs(), (p.dx - r.right).abs());
          final farY = math.max((p.dy - r.top).abs(), (p.dy - r.bottom).abs());
          if (farX * farX + farY * farY <= squared) return true;
        }
      }
    }
    if (depth == 6) return false;
    return covered(
            Rect.fromLTRB(r.left, r.top, center.dx, center.dy), depth + 1) &&
        covered(
            Rect.fromLTRB(center.dx, r.top, r.right, center.dy), depth + 1) &&
        covered(
            Rect.fromLTRB(r.left, center.dy, center.dx, r.bottom), depth + 1) &&
        covered(
            Rect.fromLTRB(center.dx, center.dy, r.right, r.bottom), depth + 1);
  }

  return covered(region, 0);
}

@visibleForTesting
bool debugStrokeCoversRegion(DrawingStroke stroke, Rect region, double zoom) {
  final sigma = zoom >= 5
      ? 0.0
      : stroke.pencilType == PencilType.pencil
          ? (1 / zoom.clamp(.1, 10.0)).clamp(.05, 2.0)
          : (stroke.thickness * .4 / zoom.clamp(.1, 10.0)).clamp(.05, 8.0);
  return _fullyCovered(stroke, region.inflate(4 * sigma + 2),
      stroke.thickness * stroke.pencilType.thicknessMultiplier / 2);
}

void _paintDrawingStroke(
  Canvas canvas,
  DrawingStroke stroke, {
  double zoomScale = 1.0,
  bool isLive = false,
  bool lowCostLivePreview = false,
  Rect? rasterClip,
  bool disableMask = false,
  BlendMode? blendOverride,
}) {
  if (stroke.points.isEmpty) return;

  final pencilType = stroke.pencilType;
  final paint = Paint()
    ..strokeCap = stroke.tool == DrawingTool.eraser
        ? StrokeCap.round
        : pencilType.strokeCap
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = stroke.thickness *
        (stroke.tool == DrawingTool.eraser
            ? 2.0
            : pencilType.thicknessMultiplier)
    ..style = PaintingStyle.stroke
    ..blendMode = blendOverride ??
        (stroke.tool == DrawingTool.eraser
            ? BlendMode.clear
            : lowCostLivePreview &&
                    isLive &&
                    stroke.tool == DrawingTool.pencil &&
                    pencilType == PencilType.watercolor &&
                    zoomScale >= 4 &&
                    stroke.thickness >= 32
                ? BlendMode.srcOver
                : pencilType.blendMode);

  if (stroke.tool == DrawingTool.eraser) {
    paint.color = Colors.transparent; // Akan clear pixels
  } else {
    final opacity = stroke.opacity * pencilType.opacityFactor;
    final a = stroke.color.a; // nilai double 0.0 - 1.0 pada Flutter 3.27+
    paint.color = stroke.color.withValues(alpha: (a * opacity).clamp(0.0, 1.0));

    // Tambahkan efek realistis
    // PENTING: Blur sigma HARUS dibagi zoomScale agar ukuran blur di layar
    // tetap konstan. Tanpa ini, saat zoom=20x:
    //   Pensil:  sigma_layar = 1.0 × 20 = 20px  (berat)
    //   Stabilo: sigma_layar = (thickness×0.4) × 20 → crash GPU!
    //
    // BATASAN ENGINE (Impeller): Saat zoom sangat besar (misal > 5x),
    // bounding box dari path yang diberi MaskFilter bisa melampaui
    // batas tekstur maksimum (16384x16384) dan menyebabkan CRASH.
    // Solusi: Matikan efek blur sama sekali jika zoom sangat besar.
    if (!disableMask && zoomScale < 5.0) {
      final double z = zoomScale.clamp(0.1, 10.0);
      switch (pencilType) {
        case PencilType.pencil:
          // Blur konstan di layar: sigma_canvas = 1.0/zoom
          paint.maskFilter = MaskFilter.blur(
            BlurStyle.solid,
            (1.0 / z).clamp(0.05, 2.0),
          );
          break;
        case PencilType.watercolor:
          // Blur proporsional ketebalan, tapi dibatasi di screen
          final simpleLivePreview = lowCostLivePreview &&
              isLive &&
              stroke.tool == DrawingTool.pencil &&
              stroke.thickness >= 32 &&
              zoomScale >= 4;
          if (!simpleLivePreview) {
            paint.maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              (stroke.thickness * .4 / z).clamp(.05, 8.0),
            );
          }
          break;
        case PencilType.marker:
          // Spidol tajam dan flat
          break;
        case PencilType.ballpoint:
          // Bolpoin tajam dan bersih
          break;
      }
    }
  }

  if (stroke.isDot) {
    canvas.drawCircle(
      stroke.points.first,
      stroke.thickness / 2,
      paint..style = PaintingStyle.fill,
    );
    return;
  }

  if (stroke.isStraightLine && stroke.points.length == 2) {
    if (rasterClip != null && (paint.maskFilter != null || disableMask)) {
      final sigma = pencilType == PencilType.watercolor
          ? (stroke.thickness * .4 / zoomScale.clamp(.1, 10.0)).clamp(.05, 8.0)
          : (1 / zoomScale.clamp(.1, 10.0)).clamp(.05, 2.0);
      canvas.drawPath(
          _windowedSmoothedPath(stroke,
              rasterClip.inflate(paint.strokeWidth / 2 + 3 * sigma + 2)),
          paint);
    } else {
      canvas.drawLine(stroke.points.first, stroke.points.last, paint);
    }
    return;
  }

  if ((stroke.tool == DrawingTool.shape || stroke.tool == DrawingTool.symbol) &&
      stroke.points.length == 2) {
    _paintShapeOrSymbol(canvas, stroke, paint);
    return;
  }

  // Free draw path
  if (stroke.points.length < 2) return;

  // Keep very wide pressure-sensitive previews cheap while the pointer is
  // down. The committed vector stroke still takes the full pressure renderer.
  if (lowCostLivePreview &&
      isLive &&
      stroke.tool == DrawingTool.pencil &&
      (pencilType == PencilType.ballpoint ||
          pencilType == PencilType.watercolor) &&
      zoomScale >= 4 &&
      stroke.thickness >= 32) {
    paint
      ..maskFilter = null
      ..style = PaintingStyle.stroke
      // Watercolor's committed width multiplier is 2.5x, which makes a
      // temporary live path cover a very large raster area at high zoom. Keep
      // the in-progress guide visibly broad while bounding that transient cost;
      // the committed/exported vector always uses the full brush width.
      ..strokeWidth = stroke.thickness *
          (pencilType == PencilType.watercolor ? .75 : .8);
    // The live overlay already has a screen-space scissor. Re-windowing every
    // quadratic segment on every pointer update costs CPU and rebuilds a path
    // with no visible benefit for this temporary centerline preview.
    final previewPath = pencilType == PencilType.watercolor || rasterClip == null
        ? _smoothedCenterline(stroke)
        : _windowedSmoothedPath(
            stroke, rasterClip.inflate(paint.strokeWidth / 2 + 2));
    canvas.drawPath(previewPath, paint);
    return;
  }

  // Bolpoin & Spidol: pakai perfect_freehand untuk efek kecepatan (makin cepat = makin tipis)
  final bool usePressureSensitive = stroke.tool == DrawingTool.pencil &&
      (pencilType == PencilType.ballpoint || pencilType == PencilType.marker);
  final bool isEraser = stroke.tool == DrawingTool.eraser;

  if (usePressureSensitive || isEraser) {
    if (stroke.cachedPath == null) {
      final double thinning =
          isEraser ? 0.0 : (pencilType == PencilType.ballpoint ? 0.7 : 0.5);

      // ─── Normalisasi Zoom untuk simulatePressure ────────────────────────
      // perfect_freehand dengan simulatePressure menggunakan JARAK antar titik
      // untuk menghitung "kecepatan" → menentukan ketebalan (lambat = tebal).
      //
      // Masalah: saat zoom=2x, 1px layar = 0.5px canvas → titik lebih rapat
      //          → terlihat "lambat" → garis tebal. Sebaliknya saat zoom out.
      //
      // Solusi:
      //   1. Scale titik × zoom  → jarak antar titik kelihatan sama di semua zoom
      //   2. Scale size × zoom   → rasio (jarak/size) tetap sama → pressure sama
      //   3. Bagi path ÷ zoom   → kembalikan ke canvas space
      //   Hasil: visual thickness = (size × zoom) / zoom = size  (zoom-invariant) ✓
      final double z = zoomScale.clamp(0.1, 10.0);

      final options = pf.StrokeOptions(
        size: stroke.thickness *
            z *
            (isEraser ? 2.0 : pencilType.thicknessMultiplier),
        thinning: thinning,
        smoothing: 0.5,
        streamline: 0.5,
        simulatePressure: true,
      );

      final scaledPoints =
          stroke.points.map((p) => pf.PointVector(p.dx * z, p.dy * z)).toList();
      final outlinePoints = pf.getStroke(scaledPoints, options: options);

      if (outlinePoints.isNotEmpty) {
        final path = Path();
        path.moveTo(outlinePoints[0].dx / z, outlinePoints[0].dy / z);
        for (int i = 1; i < outlinePoints.length; i++) {
          path.lineTo(outlinePoints[i].dx / z, outlinePoints[i].dy / z);
        }
        path.close();
        stroke.cachedPath = path;
      } else {
        stroke.cachedPath = Path();
      }
      _pressureOutlines[stroke] =
          _PressureOutline(outlinePoints, z, stroke.cachedPath!);
    }

    paint.style = PaintingStyle.fill;
    if (rasterClip != null) {
      final outline = _pressureOutlines[stroke];
      final region = rasterClip.inflate(2);
      final bounds = stroke.cachedPath!.getBounds();
      if (outline != null &&
          bounds.left <= region.left &&
          bounds.top <= region.top &&
          bounds.right >= region.right &&
          bounds.bottom >= region.bottom &&
          _filledOutlineContainsRect([
            region.left,
            region.top,
            region.right,
            region.bottom,
            for (final p in outline.points) ...[
              p.dx / outline.zoom,
              p.dy / outline.zoom
            ]
          ], isLive ? 1500 : 5000)) {
        canvas.drawRect(
            rasterClip,
            Paint()
              ..color = paint.color
              ..blendMode = paint.blendMode
              ..isAntiAlias = false);
        return;
      }
    }
    canvas.drawPath(
        rasterClip == null
            ? stroke.cachedPath!
            : _windowedFilledPath(stroke, rasterClip.inflate(2)),
        paint);
    return;
  }

  // Pensil & Cat Air: garis konsisten (tidak berubah tebal berdasarkan kecepatan)
  if (stroke.cachedPath == null) {
    if (stroke.smoothingPrefix == null ||
        stroke.smoothedPointCount > stroke.points.length) {
      stroke.smoothingPrefix = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      stroke.smoothedPointCount = 0;
    }
    final prefix = stroke.smoothingPrefix!;
    final start = math.max(1, stroke.smoothedPointCount - 1);
    for (int i = start; i < stroke.points.length - 1; i++) {
      final mid = Offset(
        (stroke.points[i].dx + stroke.points[i + 1].dx) / 2,
        (stroke.points[i].dy + stroke.points[i + 1].dy) / 2,
      );
      prefix.quadraticBezierTo(
        stroke.points[i].dx,
        stroke.points[i].dy,
        mid.dx,
        mid.dy,
      );
    }
    stroke.smoothedPointCount = stroke.points.length;
    final path = Path.from(prefix);
    path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
    stroke.cachedPath = path;
  }

  paint.style = PaintingStyle.stroke;
  final sigma = pencilType == PencilType.watercolor
      ? (stroke.thickness * .4 / zoomScale.clamp(.1, 10.0)).clamp(.05, 8.0)
      : (1 / zoomScale.clamp(.1, 10.0)).clamp(.05, 2.0);
  final blurGutter =
      paint.maskFilter != null || disableMask ? 3 * sigma + 2 : 2.0;
  // At high zoom some brushes intentionally omit blur to stay within GPU
  // texture limits. Clip those plain paths too; otherwise Impeller tessellates
  // the entire off-screen stroke on every viewport repaint.
  final clipped = rasterClip != null
      ? _windowedSmoothedPath(
          stroke, rasterClip.inflate(paint.strokeWidth / 2 + blurGutter))
      : stroke.cachedPath!;
  canvas.drawPath(clipped, paint);
  if (!isLive) {
    stroke.smoothingPrefix = null;
    stroke.smoothedPointCount = 0;
  }
}

final _windowPaths = Expando<_WindowPath>();
final _pressureOutlines = Expando<_PressureOutline>();

class _PressureOutline {
  const _PressureOutline(this.points, this.zoom, this.path);
  final List<Offset> points;
  final double zoom;
  final Path path;
}

/// Clip the original filled outline before Impeller tessellates it. A canvas
/// scissor alone does not avoid tessellating all off-screen self intersections.
Path _windowedFilledPath(DrawingStroke stroke, Rect rect) {
  final source = stroke.cachedPath!;
  final previous = _windowPaths[stroke];
  if (previous != null &&
      previous.rect == rect &&
      identical(previous.source, source)) {
    return previous.path;
  }
  final bounds = source.getBounds();
  if (rect.left <= bounds.left &&
      rect.top <= bounds.top &&
      rect.right >= bounds.right &&
      rect.bottom >= bounds.bottom) {
    return source;
  }
  final outline = _pressureOutlines[stroke];
  if (outline == null || !identical(outline.path, source)) return source;
  var vertices = outline.points
      .map((p) => Offset(p.dx / outline.zoom, p.dy / outline.zoom))
      .toList();
  for (var edge = 0; edge < 4 && vertices.isNotEmpty; edge++) {
    final output = <Offset>[];
    final vertical = edge < 2;
    final lower = edge == 0 || edge == 2;
    final limit = edge == 0
        ? rect.left
        : edge == 1
            ? rect.right
            : edge == 2
                ? rect.top
                : rect.bottom;
    double coordinate(Offset p) => vertical ? p.dx : p.dy;
    bool inside(Offset p) =>
        lower ? coordinate(p) >= limit : coordinate(p) <= limit;
    var a = vertices.last;
    var aInside = inside(a);
    for (final b in vertices) {
      final bInside = inside(b);
      if (aInside != bInside) {
        final t = (limit - coordinate(a)) / (coordinate(b) - coordinate(a));
        output.add(vertical
            ? Offset(limit, a.dy + (b.dy - a.dy) * t)
            : Offset(a.dx + (b.dx - a.dx) * t, limit));
      }
      if (bInside) output.add(b);
      a = b;
      aInside = bInside;
    }
    vertices = output;
  }
  final reduced = <Offset>[];
  for (final p in vertices) {
    if (reduced.isNotEmpty && p == reduced.last) continue;
    while (reduced.length >= 2) {
      final a = reduced[reduced.length - 2], b = reduced.last;
      if ((b.dx - a.dx) * (p.dy - b.dy) != (b.dy - a.dy) * (p.dx - b.dx)) break;
      reduced.removeLast();
    }
    reduced.add(p);
  }
  vertices = reduced;
  var path = Path();
  if (vertices.length >= 3) {
    path.moveTo(vertices.first.dx, vertices.first.dy);
    Offset? last;
    for (final p in vertices.skip(1)) {
      if (p != last) path.lineTo(p.dx, p.dy);
      last = p;
    }
    path.close();
  }
  _windowPaths[stroke] = _WindowPath(rect, source, path);
  return path;
}

class _WindowPath {
  const _WindowPath(this.rect, this.source, this.path);
  final Rect rect;
  final Path source;
  final Path path;
}

Path _smoothedCenterline(DrawingStroke stroke) {
  final points = stroke.points;
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (var i = 1; i < points.length - 1; i++) {
    final mid = Offset(
      (points[i].dx + points[i + 1].dx) / 2,
      (points[i].dy + points[i + 1].dy) / 2,
    );
    path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
  }
  path.lineTo(points.last.dx, points.last.dy);
  return path;
}

/// Exact De Casteljau subdivision. Only contours outside an expanded viewport
/// are removed; endpoints/caps introduced there are outside the visible image.
Path _windowedSmoothedPath(DrawingStroke stroke, Rect rect) {
  final previous = _windowPaths[stroke];
  if (previous != null &&
      previous.rect == rect &&
      identical(previous.source, stroke.cachedPath)) {
    return previous.path;
  }
  final output = Path();
  Offset? end;
  void begin(Offset p) {
    if (end == null || (end! - p).distanceSquared > 1e-12) {
      output.moveTo(p.dx, p.dy);
    }
  }

  void quadratic(Offset a, Offset b, Offset c, int depth) {
    final left = math.min(a.dx, math.min(b.dx, c.dx));
    final top = math.min(a.dy, math.min(b.dy, c.dy));
    final right = math.max(a.dx, math.max(b.dx, c.dx));
    final bottom = math.max(a.dy, math.max(b.dy, c.dy));
    if (right < rect.left ||
        left > rect.right ||
        bottom < rect.top ||
        top > rect.bottom) {
      return;
    }
    if ((left >= rect.left &&
            right <= rect.right &&
            top >= rect.top &&
            bottom <= rect.bottom) ||
        depth == 16) {
      begin(a);
      output.quadraticBezierTo(b.dx, b.dy, c.dx, c.dy);
      end = c;
      return;
    }
    final ab = (a + b) / 2;
    final bc = (b + c) / 2;
    final mid = (ab + bc) / 2;
    quadratic(a, ab, mid, depth + 1);
    quadratic(mid, bc, c, depth + 1);
  }

  void line(Offset a, Offset b) {
    var from = 0.0;
    var to = 1.0;
    final delta = b - a;
    for (final pair in [
      (-delta.dx, a.dx - rect.left),
      (delta.dx, rect.right - a.dx),
      (-delta.dy, a.dy - rect.top),
      (delta.dy, rect.bottom - a.dy)
    ]) {
      final p = pair.$1;
      final q = pair.$2;
      if (p == 0) {
        if (q < 0) return;
      } else {
        final ratio = q / p;
        if (p < 0) {
          from = math.max(from, ratio);
        } else {
          to = math.min(to, ratio);
        }
        if (from > to) return;
      }
    }
    final start = a + delta * from;
    final finish = a + delta * to;
    begin(start);
    output.lineTo(finish.dx, finish.dy);
    end = finish;
  }

  final points = stroke.points;
  var a = points.first;
  for (var i = 1; i < points.length - 1; i++) {
    final c = (points[i] + points[i + 1]) / 2;
    quadratic(a, points[i], c, 0);
    a = c;
  }
  line(a, points.last);
  if (stroke.cachedPath != null) {
    _windowPaths[stroke] = _WindowPath(rect, stroke.cachedPath!, output);
  }
  return output;
}

void _paintShapeOrSymbol(Canvas canvas, DrawingStroke stroke, Paint paint) {
  final p1 = stroke.points.first;
  final p2 = stroke.points.last;
  final center = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
  final radius = (p2 - p1).distance / 2;
  final shapeType = stroke.shapeType ?? 'lingkaran';

  switch (shapeType) {
    case 'lingkaran':
      canvas.drawCircle(center, radius, paint);
      break;
    case 'persegi':
      final rect = Rect.fromPoints(p1, p2);
      canvas.drawRect(rect, paint);
      break;
    case 'persegi_panjang':
      final rect2 = Rect.fromPoints(p1, p2);
      canvas.drawRect(rect2, paint);
      break;
    case 'segitiga':
      final path = Path();
      path.moveTo(center.dx, p1.dy);
      path.lineTo(p2.dx, p2.dy);
      path.lineTo(p1.dx, p2.dy);
      path.close();
      canvas.drawPath(path, paint);
      break;
    case 'bintang':
      _drawStar(canvas, center, radius, paint);
      break;
    case 'love':
      _drawHeart(canvas, center, radius, paint);
      break;
    case 'bunga':
      _drawFlower(canvas, center, radius, paint);
      break;
    default:
      canvas.drawCircle(center, radius, paint);
  }
}

void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
  final path = Path();
  const int points = 5;
  final innerRadius = radius * 0.4;
  for (int i = 0; i <= points * 2; i++) {
    final angle = (i * math.pi / points) - math.pi / 2;
    final r = i.isEven ? radius : innerRadius;
    final x = center.dx + r * math.cos(angle);
    final y = center.dy + r * math.sin(angle);
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();
  canvas.drawPath(path, paint);
}

void _drawHeart(Canvas canvas, Offset center, double radius, Paint paint) {
  final path = Path();
  path.moveTo(center.dx, center.dy + radius * 0.3);
  path.cubicTo(
    center.dx + radius,
    center.dy - radius * 0.5,
    center.dx + radius * 1.5,
    center.dy + radius * 0.8,
    center.dx,
    center.dy + radius * 1.3,
  );
  path.cubicTo(
    center.dx - radius * 1.5,
    center.dy + radius * 0.8,
    center.dx - radius,
    center.dy - radius * 0.5,
    center.dx,
    center.dy + radius * 0.3,
  );
  path.close();
  canvas.drawPath(path, paint);
}

void _drawFlower(Canvas canvas, Offset center, double radius, Paint paint) {
  void circle(Offset position, double r) {
    canvas.drawCircle(position, r, paint);
  }

  const petals = 6;
  for (int i = 0; i < petals; i++) {
    final angle = i * 2 * math.pi / petals;
    final petalCenter = Offset(center.dx + radius * .6 * math.cos(angle),
        center.dy + radius * .6 * math.sin(angle));
    circle(petalCenter, radius * .45);
  }
  circle(center, radius * .3);
}
