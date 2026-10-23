// Native-backend equivalence check; imported only by the isolated profile app.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:epic_app/features/games/menggambar/debug/drawing_stress_fixture.dart';
import 'package:epic_app/features/games/menggambar/drawing_render_cache.dart';
import 'package:epic_app/features/games/menggambar/models/drawing_models.dart';
import 'package:epic_app/features/games/menggambar/widgets/stroke_renderer.dart';

import '../test/fixtures/reference_stroke_renderer.dart';

Future<Uint8List> _pixels(
    Rect window, double density, void Function(Canvas canvas) draw) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..scale(density)
    ..translate(-window.left, -window.top)
    ..clipRect(window);
  draw(canvas);
  final picture = recorder.endRecording();
  ui.Image? image;
  try {
    image = await picture.toImage(
        (window.width * density).ceil(), (window.height * density).ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) throw StateError('Native pixel readback failed');
    return Uint8List.fromList(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
  } finally {
    image?.dispose();
    picture.dispose();
  }
}

Future<void> verifyDrawingDeviceQuality(
    void Function(Map<String, Object>) report) async {
  const paper = Size(160, 200);
  final layers = buildDrawingStressFixture(48, paper, longStrokes: true);
  final originals = [
    for (final layer in layers)
      [
        for (final stroke in layer.strokes)
          DrawingStroke.fromJson(stroke.toJson())
      ]
  ];
  void reference(Canvas canvas, double zoom) {
    for (final strokes in originals) {
      canvas.saveLayer(Offset.zero & paper, Paint());
      for (final stroke in strokes) {
        paintReferenceStroke(canvas, stroke, zoomScale: zoom);
      }
      canvas.restore();
    }
  }

  final cache = DrawingRenderCache()
    ..configure(paper, 2, 1, viewport: Offset.zero & paper)
    ..retainLayers(layers)
    ..enableScene();
  try {
    // Both original and optimized pressure outlines start at the same scale.
    await _pixels(Offset.zero & paper, 2, (c) => reference(c, 1));
    await cache.flush();
    for (final zoom in [1.0, 4.0, 20.0, 0.5]) {
      final window = Rect.fromCenter(
          center: const Offset(80, 100),
          width: paper.width / math.max(zoom, 1),
          height: paper.height / math.max(zoom, 1));
      final density = 2.0 * math.max(zoom, 1.0);
      cache.configure(paper, 2, zoom, viewport: window);
      await cache.flush();
      if (layers.any((l) => !cache.forLayer(l).isReady)) {
        throw StateError('Native quality cache is incomplete at $zoom');
      }
      final expected =
          await _pixels(window, density, (c) => reference(c, zoom));
      var sceneUsed = false;
      final actual = await _pixels(
          window, density, (c) => sceneUsed = cache.paintScene(c));
      if (!sceneUsed || actual.length != expected.length) {
        throw StateError('Native quality comparison has no valid scene');
      }
      var error = 0;
      var outliers = 0;
      for (var i = 0; i < expected.length; i++) {
        final difference = (actual[i] - expected[i]).abs();
        error += difference;
        if (difference > 8) outliers++;
      }
      final mean = error / expected.length;
      final fraction = outliers / expected.length;
      report({
        'phase': 'native-pixel-parity',
        'zoom': zoom,
        'meanChannelError': mean,
        'outlierFraction': fraction,
        'sceneUsed': sceneUsed,
        'qualityCacheMiB': cache.allocatedBytes / 1048576
      });
      if (mean >= .5 || fraction >= .005) {
        for (var layer = 0; layer < layers.length; layer++) {
          final expectedLayer = await _pixels(window, density, (c) {
            c.saveLayer(Offset.zero & paper, Paint());
            for (final s in originals[layer]) {
              paintReferenceStroke(c, s, zoomScale: zoom);
            }
            c.restore();
          });
          final actualLayer = await _pixels(
              window,
              density,
              (c) => cache
                  .forLayer(layers[layer])
                  .paint(c, paper, zoomScale: zoom));
          var layerError = 0;
          for (var p = 0; p < expectedLayer.length; p++) {
            layerError += (expectedLayer[p] - actualLayer[p]).abs();
          }
          report({
            'phase': 'native-layer-diagnostic',
            'layer': layer,
            'meanChannelError': layerError / expectedLayer.length
          });
          for (var i = 0; i < originals[layer].length; i++) {
            final e = await _pixels(window, density, (c) {
              c.saveLayer(Offset.zero & paper, Paint());
              paintReferenceStroke(c, originals[layer][i], zoomScale: zoom);
              c.restore();
            });
            final a = await _pixels(window, density, (c) {
              c.saveLayer(Offset.zero & paper, Paint());
              paintDrawingStroke(c, layers[layer].strokes[i],
                  zoomScale: zoom, rasterClip: window.inflate(10));
              c.restore();
            });
            var delta = 0;
            for (var p = 0; p < e.length; p++) {
              delta += (e[p] - a[p]).abs();
            }
            if (delta / e.length > .5) {
              final s = originals[layer][i];
              report({
                'phase': 'native-stroke-diagnostic',
                'layer': layer,
                'index': i,
                'tool': s.tool.name,
                'brush': s.pencilType.name,
                'expectedCenter': e
                    .sublist((e.length ~/ 8) * 4, (e.length ~/ 8) * 4 + 4)
                    .join(','),
                'actualCenter': a
                    .sublist((a.length ~/ 8) * 4, (a.length ~/ 8) * 4 + 4)
                    .join(','),
                'color': s.color.toARGB32(),
                'meanChannelError': delta / e.length
              });
            }
          }
        }
        throw StateError(
            'Native pixel parity failed at $zoom: $mean / $fraction');
      }
      if (zoom == 4 || zoom == 20) {
        for (final type in PencilType.values) {
          final live = DrawingStroke(
              tool: DrawingTool.pencil,
              pencilType: type,
              color: Colors.blue,
              opacity: .7,
              thickness: 40,
              points: const [Offset(68, 90), Offset(80, 99), Offset(91, 108)]);
          final oldLive = DrawingStroke.fromJson(live.toJson());
          final expectedLive = await _pixels(window, density, (c) {
            for (var l = 0; l < layers.length; l++) {
              c.saveLayer(Offset.zero & paper, Paint());
              for (final s in originals[l]) {
                paintReferenceStroke(c, s, zoomScale: zoom);
              }
              if (l == 1) paintReferenceStroke(c, oldLive, zoomScale: zoom);
              c.restore();
            }
          });
          final actualLive = await _pixels(window, density, (c) {
            for (var l = 0; l < layers.length; l++) {
              cache.forLayer(layers[l]).paint(c, paper,
                  zoomScale: zoom, liveStroke: l == 1 ? live : null);
            }
          });
          var delta = 0, outlying = 0;
          for (var p = 0; p < expectedLive.length; p++) {
            final d = (expectedLive[p] - actualLive[p]).abs();
            delta += d;
            if (d > 8) outlying++;
          }
          final liveMean = delta / expectedLive.length;
          final liveFraction = outlying / expectedLive.length;
          report({
            'phase': 'native-live-parity',
            'zoom': zoom,
            'brush': type.name,
            'meanChannelError': liveMean,
            'outlierFraction': liveFraction
          });
          if (liveMean >= .5 || liveFraction >= .005) {
            throw StateError(
                'Native live pixel parity failed for ${type.name} at $zoom');
          }
        }
      }
    }
  } finally {
    cache.dispose();
  }
}
