import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:epic_app/features/games/menggambar/drawing_render_cache.dart';
import 'package:epic_app/features/games/menggambar/models/drawing_models.dart';
import 'package:epic_app/features/games/menggambar/widgets/stroke_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/reference_stroke_renderer.dart';

const paper = Size(160, 200);

List<DrawingStroke> fixture([int count = 48]) {
  final random = math.Random(1977);
  const shapes = [
    'lingkaran',
    'persegi',
    'persegi_panjang',
    'segitiga',
    'bintang',
    'love',
    'bunga',
  ];
  return List.generate(count, (i) {
    final points = List.generate(
      12,
      (_) => Offset(
        random.nextDouble() * paper.width,
        random.nextDouble() * paper.height,
      ),
    );
    final tool = i % 11 == 0
        ? DrawingTool.eraser
        : i % 7 == 0
            ? DrawingTool.shape
            : i % 13 == 0
                ? DrawingTool.symbol
                : DrawingTool.pencil;
    final straight = i % 9 == 0;
    return DrawingStroke(
      tool: tool,
      pencilType: PencilType.values[i % PencilType.values.length],
      points: i % 8 == 0
          ? [points.first]
          : straight || tool == DrawingTool.shape || tool == DrawingTool.symbol
              ? [points.first, points.last]
              : points,
      color: Color.fromARGB(
        200,
        random.nextInt(256),
        random.nextInt(256),
        random.nextInt(256),
      ),
      thickness: 1 + random.nextDouble() * 35,
      opacity: 0.8,
      isDot: i % 8 == 0,
      isStraightLine: straight,
      shapeType: shapes[(i ~/ 7) % shapes.length],
    );
  });
}

Future<Uint8List> pixels(void Function(Canvas) paint,
    {double density = 2}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(density);
  canvas.clipRect(Offset.zero & paper);
  paint(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (paper.width * density).ceil(),
    (paper.height * density).ceil(),
  );
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return Uint8List.fromList(data!.buffer.asUint8List());
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Future<Uint8List> windowPixels(
    Rect window, double density, void Function(Canvas) paint) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..scale(density)
    ..translate(-window.left, -window.top)
    ..clipRect(window);
  paint(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
      (window.width * density).ceil(), (window.height * density).ceil());
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return Uint8List.fromList(bytes!.buffer.asUint8List());
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void reference(
  Canvas canvas,
  Iterable<DrawingStroke> strokes, {
  double zoom = 1,
}) {
  canvas.saveLayer(Offset.zero & paper, Paint());
  for (final stroke in strokes) {
    paintReferenceStroke(canvas, stroke, zoomScale: zoom);
  }
  canvas.restore();
}

void expectEquivalent(Uint8List expected, Uint8List actual) {
  expect(actual.length, expected.length);
  var totalError = 0;
  var outliers = 0;
  for (var i = 0; i < expected.length; i++) {
    final difference = (actual[i] - expected[i]).abs();
    totalError += difference;
    if (difference > 8) outliers++;
  }
  // Allow small 8-bit rounding differences at intermediate alpha composites.
  expect(totalError / expected.length, lessThan(0.5));
  expect(outliers / expected.length, lessThan(0.005));
}

Future<void> flushFrames(WidgetTester tester, DrawingRenderCache cache) async {
  var done = false;
  final pending = cache.flush().whenComplete(() => done = true);
  while (!done) {
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  await pending;
}

void main() {
  testWidgets(
      'live blending over lower layers preserves alpha and clear isolation',
      (tester) async {
    final layer = DrawingLayer(id: 'live-over-background')
      ..strokes.addAll(fixture(12));
    final original = fixture(12);
    final cache = DrawingRenderCache()
      ..configure(paper, 2, 1, viewport: Offset.zero & paper);
    final entry = cache.forLayer(layer);
    void background(Canvas c) => c.drawRect(
        Offset.zero & paper, Paint()..color = const Color(0x80884734));
    await tester.runAsync(() async {
      await flushFrames(tester, cache);
      await pixels((c) => reference(c, original));
      for (final zoom in [4.0, 20.0]) {
        final window = Rect.fromCenter(
            center: const Offset(80, 100),
            width: paper.width / zoom,
            height: paper.height / zoom);
        cache.configure(paper, 2, zoom, viewport: window);
        await flushFrames(tester, cache);
        for (var brush = 0; brush <= PencilType.values.length; brush++) {
          final live = DrawingStroke(
              tool: brush == 4 ? DrawingTool.eraser : DrawingTool.pencil,
              pencilType: PencilType.values[brush % 4],
              color: const Color(0xb04278db),
              opacity: .6,
              thickness: 40,
              points: const [Offset(60, 88), Offset(80, 100), Offset(98, 112)]);
          final old = DrawingStroke.fromJson(live.toJson());
          expectEquivalent(
              await windowPixels(window, 2 * zoom, (c) {
                background(c);
                reference(c, [...original, old], zoom: zoom);
              }),
              await windowPixels(window, 2 * zoom, (c) {
                background(c);
                entry.paint(c, paper, liveStroke: live, zoomScale: zoom);
              }));
        }
      }
    });
    cache.dispose();
    await tester.pump();
  });

  testWidgets('cached scene keeps source-over live paint pixel-equivalent',
      (tester) async {
    final lower = DrawingLayer(id: 'scene-lower')..strokes.addAll(fixture(12));
    final upper = DrawingLayer(id: 'scene-upper')..strokes.addAll(fixture(12));
    final cache = DrawingRenderCache()
      ..configure(paper, 2, 1, viewport: Offset.zero & paper)
      ..retainLayers([lower, upper])
      ..enableScene();
    final live = DrawingStroke(
        tool: DrawingTool.pencil,
        pencilType: PencilType.ballpoint,
        color: const Color(0xc04c8bdc),
        thickness: 18,
        points: const [Offset(32, 46), Offset(88, 113), Offset(129, 159)]);
    final eraser = DrawingStroke(
        tool: DrawingTool.eraser,
        pencilType: PencilType.ballpoint,
        color: Colors.transparent,
        thickness: 18,
        points: const [Offset(32, 46), Offset(88, 113), Offset(129, 159)]);
    await tester.runAsync(() async {
      await flushFrames(tester, cache);
      final expected = await pixels((canvas) {
        reference(canvas, lower.strokes);
        reference(canvas, upper.strokes);
        paintReferenceStroke(canvas, live);
      });
      final actual = await pixels((canvas) {
        expect(cache.paintSceneWithLiveStroke(canvas, live), isTrue);
      });
      expectEquivalent(expected, actual);
      await pixels((canvas) {
        expect(cache.paintSceneWithLiveStroke(canvas, eraser), isFalse);
      });
    });
    cache.dispose();
    await tester.pump();
  });

  testWidgets(
      'combined clears preserve intervening paint and earlier undo data',
      (tester) async {
    final source = [
      ...fixture(48),
      DrawingStroke(
          tool: DrawingTool.eraser,
          color: Colors.black,
          points: const [Offset(15, 20), Offset(15, 180)],
          thickness: 45),
      DrawingStroke(
          tool: DrawingTool.pencil,
          color: Colors.orange,
          points: const [Offset(80, 100)],
          isDot: true,
          thickness: 100,
          opacity: .4),
      DrawingStroke(
          tool: DrawingTool.eraser,
          color: Colors.black,
          points: const [Offset(100, 20), Offset(100, 180)],
          thickness: 50),
      DrawingStroke(
          tool: DrawingTool.pencil,
          color: Colors.green,
          points: const [Offset(80, 100)],
          isDot: true,
          thickness: 12,
          opacity: .3),
    ];
    final jsonBefore = source.map((s) => s.toJson()).toList();
    final original =
        source.map((s) => DrawingStroke.fromJson(s.toJson())).toList();
    final layer = DrawingLayer(id: 'union-undo')..strokes.addAll(source);
    final cache = DrawingRenderCache()
      ..configure(paper, 2, 1, viewport: Offset.zero & paper);
    final entry = cache.forLayer(layer);
    const window = Rect.fromLTWH(40, 70, 80, 60);
    await tester.runAsync(() async {
      await flushFrames(tester, cache);
      await pixels((c) => reference(c, original));
      cache.configure(paper, 2, 8, viewport: window);
      await flushFrames(tester, cache);
      expect(cache.skippedTileStrokeJobs, greaterThan(0));
      expect(layer.strokes.map((s) => s.toJson()).toList(), jsonBefore);
      for (var undo = 0; undo <= 2; undo++) {
        expectEquivalent(
            await windowPixels(
                window, 16, (c) => reference(c, original, zoom: 8)),
            await windowPixels(
                window, 16, (c) => entry.paint(c, paper, zoomScale: 8)));
        if (undo < 2) {
          layer.strokes.removeLast();
          original.removeLast();
          await flushFrames(tester, cache);
        }
      }
    });
    cache.dispose();
    await tester.pump();
  });

  testWidgets('overlapping clears can prove coverage while gaps cannot',
      (tester) async {
    DrawingStroke eraser(double x) => DrawingStroke(
        tool: DrawingTool.eraser,
        color: Colors.black,
        points: [Offset(x, 20), Offset(x, 180)],
        thickness: 40);
    final left = eraser(55), right = eraser(105), separated = eraser(150);
    const region = Rect.fromLTWH(40, 70, 80, 60);
    await tester.runAsync(() async {
      for (final stroke in [left, right, separated]) {
        await pixels((c) => paintDrawingStroke(c, stroke));
      }
      expect(await drawingStrokeOverwritesRegion(left, region), isFalse);
      expect(await drawingStrokeOverwritesRegion(right, region), isFalse);
      expect(await drawingStrokesOverwriteRegion([left, right], region, 1),
          isTrue);
      expect(await drawingStrokesOverwriteRegion([left, separated], region, 1),
          isFalse);
    });
  });

  testWidgets('high-zoom viewport clips unfiltered smooth paths exactly',
      (tester) async {
    final stroke = DrawingStroke(
      tool: DrawingTool.pencil,
      pencilType: PencilType.watercolor,
      color: Colors.deepPurple,
      thickness: 34,
      opacity: .75,
      points: [
        for (var i = 0; i <= 180; i++)
          Offset(i.toDouble(), 70 + math.sin(i / 8) * 45),
      ],
    );
    const window = Rect.fromLTWH(74, 62, 22, 24);
    await tester.runAsync(() async {
      expectEquivalent(
        await windowPixels(window, 20,
            (canvas) => paintReferenceStroke(canvas, stroke, zoomScale: 20)),
        await windowPixels(window, 20, (canvas) {
          paintDrawingStroke(canvas, stroke, zoomScale: 20, rasterClip: window);
        }),
      );
    });
  });

  testWidgets('low-cost preview never changes committed watercolor pixels',
      (tester) async {
    final stroke = DrawingStroke(
        tool: DrawingTool.pencil,
        pencilType: PencilType.watercolor,
        points: List.generate(
            96,
            (i) => Offset(12 + i * 1.4, 75 + math.sin(i * .13) * 18)),
        color: const Color.fromARGB(190, 22, 108, 214),
        thickness: 40,
        opacity: .72);
    await tester.runAsync(() async {
      final committed = await pixels((canvas) =>
          paintDrawingStroke(canvas, stroke, zoomScale: 4));
      final flaggedButCommitted = await pixels((canvas) => paintDrawingStroke(
          canvas,
          stroke,
          zoomScale: 4,
          isLive: false,
          lowCostLivePreview: true));
      expectEquivalent(committed, flaggedButCommitted);
    });
  });

  testWidgets('wide live brushes and erasing retain original zoom pixels',
      (tester) async {
    final layer = DrawingLayer(id: 'live-zoom')..strokes.addAll(fixture(24));
    final original = fixture(24);
    final cache = DrawingRenderCache()
      ..configure(paper, 2, 1, viewport: Offset.zero & paper);
    final entry = cache.forLayer(layer);
    await tester.runAsync(() async {
      await flushFrames(tester, cache);
      await pixels((c) => reference(c, original));
      for (final zoom in [4.0, 20.0]) {
        final window = Rect.fromCenter(
            center: const Offset(80, 100),
            width: paper.width / zoom,
            height: paper.height / zoom);
        cache.configure(paper, 2, zoom, viewport: window);
        await flushFrames(tester, cache);
        for (final type in ['ballpoint', 'pencil', 'watercolor', 'eraser']) {
          final live = DrawingStroke(
              tool: type == 'eraser' ? DrawingTool.eraser : DrawingTool.pencil,
              pencilType: type == 'pencil'
                  ? PencilType.pencil
                  : type == 'watercolor'
                      ? PencilType.watercolor
                      : PencilType.ballpoint,
              color: Colors.blue,
              thickness: 80,
              opacity: .7,
              points: const [
                Offset(78, 100),
                Offset(82, 100),
                Offset(80, 101),
                Offset(79, 99)
              ]);
          final liveOriginal = DrawingStroke.fromJson(live.toJson());
          expectEquivalent(
              await windowPixels(window, 2 * zoom,
                  (c) => reference(c, [...original, liveOriginal], zoom: zoom)),
              await windowPixels(
                  window,
                  2 * zoom,
                  (c) => entry.paint(c, paper,
                      liveStroke: live, zoomScale: zoom)));
        }
      }
    });
    cache.dispose();
    await tester.pump();
  });

  testWidgets('only proven opaque or clear coverage can replace history',
      (tester) async {
    await tester.runAsync(() async {
      for (final tool in [DrawingTool.eraser, DrawingTool.pencil]) {
        final stroke = DrawingStroke(
            tool: tool,
            pencilType: PencilType.marker,
            color: Colors.blue,
            points: const [Offset(20, 100), Offset(140, 100)],
            thickness: 80);
        await pixels((c) => paintDrawingStroke(c, stroke));
        expect(
            await drawingStrokeOverwritesRegion(
                stroke, const Rect.fromLTWH(60, 80, 40, 40)),
            isTrue);
        expect(
            await drawingStrokeOverwritesRegion(
                stroke, const Rect.fromLTWH(-300, -300, 40, 40)),
            isFalse);
      }
      final translucent = DrawingStroke(
          tool: DrawingTool.pencil,
          pencilType: PencilType.marker,
          color: Colors.blue,
          points: const [Offset(20, 100), Offset(140, 100)],
          thickness: 80,
          opacity: .5);
      await pixels((c) => paintDrawingStroke(c, translucent));
      expect(
          await drawingStrokeOverwritesRegion(
              translucent, const Rect.fromLTWH(60, 80, 40, 40)),
          isFalse);
    });
  });

  testWidgets('covered history remains identical and available for undo',
      (tester) async {
    final source = [
      ...fixture(48),
      DrawingStroke(
          tool: DrawingTool.eraser,
          color: Colors.black,
          points: const [Offset(20, 100), Offset(140, 100)],
          thickness: 80),
      DrawingStroke(
          tool: DrawingTool.pencil,
          color: Colors.green,
          points: const [Offset(70, 90), Offset(90, 110)],
          isStraightLine: true,
          thickness: 5,
          opacity: .6)
    ];
    final original =
        source.map((s) => DrawingStroke.fromJson(s.toJson())).toList();
    final layer = DrawingLayer(id: 'covered-history')..strokes.addAll(source);
    final cache = DrawingRenderCache()
      ..configure(paper, 6, 1, viewport: Offset.zero & paper);
    final entry = cache.forLayer(layer);
    const window = Rect.fromLTWH(60, 75, 40, 50);
    await tester.runAsync(() async {
      await flushFrames(tester, cache);
      await pixels((c) => reference(c, original));
      cache.configure(paper, 6, 4, viewport: window);
      await flushFrames(tester, cache);
      expect(entry.isReady, isTrue);
      expect(layer.strokes.length, source.length);
      expect(cache.skippedTileStrokeJobs, greaterThan(0));
      expectEquivalent(
          await windowPixels(
              window, 24, (c) => reference(c, original, zoom: 4)),
          await windowPixels(
              window, 24, (c) => entry.paint(c, paper, zoomScale: 4)));
      layer.strokes.removeLast();
      original.removeLast();
      await flushFrames(tester, cache);
      expectEquivalent(
          await windowPixels(
              window, 24, (c) => reference(c, original, zoom: 4)),
          await windowPixels(
              window, 24, (c) => entry.paint(c, paper, zoomScale: 4)));
    });
    cache.dispose();
    await tester.pump();
  });

  testWidgets('combined preview preserves layer blending and invalidates edits',
      (tester) async {
    final lower = DrawingLayer(id: 'composite-lower')
      ..strokes.addAll(fixture(24));
    final upper = DrawingLayer(id: 'composite-upper')
      ..strokes.addAll(fixture(30));
    final cache = DrawingRenderCache()
      ..configure(paper, 2, 1, viewport: Offset.zero & paper)
      ..retainLayers([lower, upper])
      ..enableScene();
    await tester.runAsync(() async {
      await flushFrames(tester, cache);
      var used = false;
      expectEquivalent(
          await pixels((c) {
            reference(c, lower.strokes);
            reference(c, upper.strokes);
          }),
          await pixels((c) {
            used = cache.paintScene(c);
          }));
      expect(used, isTrue);
      upper.strokes.add(DrawingStroke(
          tool: DrawingTool.eraser,
          color: Colors.black,
          points: const [Offset(20, 20), Offset(140, 180)],
          thickness: 28));
      await pixels((c) {
        used = cache.paintScene(c);
      });
      expect(used, isFalse);
      await flushFrames(tester, cache);
      expectEquivalent(
          await pixels((c) {
            reference(c, lower.strokes);
            reference(c, upper.strokes);
          }),
          await pixels((c) {
            used = cache.paintScene(c);
          }));
      expect(used, isTrue);
      upper.isVisible.value = false;
      cache.enableScene();
      await flushFrames(tester, cache);
      expectEquivalent(
          await pixels((c) => reference(c, lower.strokes)),
          await pixels((c) {
            used = cache.paintScene(c);
          }));
      expect(used, isTrue);
    });
    cache.dispose();
    await tester.pump();
  });

  testWidgets('memory pressure preserves a bounded restore prefix',
      (tester) async {
    late DrawingRenderCache cache;
    var jobs = 0;
    cache = DrawingRenderCache.withRasterizer((picture, width, height) async {
      jobs++;
      if (jobs == 2) cache.releaseImages();
      return picture.toImage(width, height);
    })
      ..configure(paper, 2, 1, viewport: Offset.zero & paper);
    final layer = DrawingLayer(id: 'pressure-prefix')
      ..strokes.addAll(fixture(80));
    final entry = cache.forLayer(layer);
    await tester.runAsync(() async {
      await flushFrames(tester, cache);
      expect(entry.isReady, isTrue);
      expect(jobs, (80 / DrawingRenderCache.maxBatchStrokes).ceil());
      expectEquivalent(await pixels((c) => reference(c, fixture(80))),
          await pixels((c) => entry.paint(c, paper)));
    });
    cache.dispose();
    await tester.pump();
  });

  testWidgets('a new gesture interrupts detail tiles and retains all coverage',
      (tester) async {
    late DrawingRenderCache cache;
    var interrupt = false;
    var interrupted = false;
    cache = DrawingRenderCache.withRasterizer((picture, width, height) async {
      final image = await picture.toImage(width, height);
      if (interrupt && !interrupted) {
        interrupted = true;
        cache.setGestureActive(true);
      }
      return image;
    })
      ..configure(paper, 6, 1, viewport: Offset.zero & paper);
    final layer = DrawingLayer(id: 'interrupt-tiles')
      ..strokes.addAll(fixture(24));
    final entry = cache.forLayer(layer);
    const window = Rect.fromLTWH(60, 75, 40, 50);
    await tester.runAsync(() async {
      await flushFrames(tester, cache);
      final preview = entry.image;
      interrupt = true;
      cache.configure(paper, 6, 4, viewport: window);
      await flushFrames(tester, cache);
      expect(interrupted, isTrue);
      expect(entry.image, same(preview));
      expect(entry.bakedCount, layer.strokes.length);
      expect(entry.isReady, isFalse);
      cache.setGestureActive(false);
      await flushFrames(tester, cache);
      expect(entry.isReady, isTrue);
    });
    cache.dispose();
    await tester.pump();
  });

  testWidgets('tiled zoom preserves blur, transparency and tile boundaries',
      (tester) async {
    final cache = DrawingRenderCache()
      ..configure(paper, 6, 1, viewport: Offset.zero & paper);
    final layer = DrawingLayer(id: 'tile-seams')..strokes.addAll(fixture(24));
    final original = fixture(24);
    final entry = cache.forLayer(layer);
    const window = Rect.fromLTWH(60, 75, 40, 50);
    await tester.runAsync(() async {
      await flushFrames(tester, cache);
      await pixels((c) => reference(c, original));
      cache.configure(paper, 6, 4, viewport: window);
      await flushFrames(tester, cache);
      expect(entry.isReady, isTrue);
      expectEquivalent(
          await windowPixels(
              window, 24, (c) => reference(c, original, zoom: 4)),
          await windowPixels(
              window, 24, (c) => entry.paint(c, paper, zoomScale: 4)));
      expect(cache.allocatedBytes,
          lessThanOrEqualTo(DrawingRenderCache.maxTotalBytes));
    });
    cache.dispose();
    await tester.pump();
  });

  testWidgets(
      'clipped pressure outlines preserve self intersections and erasing',
      (tester) async {
    final random = math.Random(9182);
    final points = List.generate(
        512,
        (_) => Offset(random.nextDouble() * paper.width,
            random.nextDouble() * paper.height));
    await tester.runAsync(() async {
      for (final kind in ['ballpoint', 'marker', 'eraser']) {
        final stroke = DrawingStroke(
            tool: kind == 'eraser' ? DrawingTool.eraser : DrawingTool.pencil,
            pencilType:
                kind == 'marker' ? PencilType.marker : PencilType.ballpoint,
            points: points,
            color: Colors.blue,
            thickness: 14,
            opacity: .6);
        final original = DrawingStroke.fromJson(stroke.toJson());
        final background = DrawingStroke(
            tool: DrawingTool.pencil,
            points: const [Offset(80, 100)],
            color: Colors.green,
            thickness: 600,
            isDot: true);
        await pixels((c) => reference(c, [background, original]));
        await pixels((c) {
          c.saveLayer(Offset.zero & paper, Paint());
          paintDrawingStroke(c, stroke);
          c.restore();
        });
        for (final zoom in [4.0, 20.0]) {
          final window = Rect.fromCenter(
              center: const Offset(80, 100),
              width: paper.width / zoom,
              height: paper.height / zoom);
          expectEquivalent(
              await windowPixels(window, zoom * 2,
                  (c) => reference(c, [background, original], zoom: zoom)),
              await windowPixels(window, zoom * 2, (c) {
                c.saveLayer(Offset.zero & paper, Paint());
                paintDrawingStroke(c, background, zoomScale: zoom);
                paintDrawingStroke(c, stroke,
                    zoomScale: zoom, rasterClip: window.inflate(16));
                c.restore();
              }));
        }
      }
    });
  });

  testWidgets(
      'certified dense coverage has identical translucent vector pixels',
      (tester) async {
    final points = <Offset>[];
    for (var repeat = 0; repeat < 8; repeat++) {
      for (var row = 30; row <= 170; row += 10) {
        points.add(Offset(10, row.toDouble()));
        points.add(Offset(150, row.toDouble()));
      }
    }
    const window = Rect.fromLTWH(65, 85, 30, 30);
    await tester.runAsync(() async {
      for (final type in [PencilType.pencil, PencilType.watercolor]) {
        final stroke = DrawingStroke(
            tool: DrawingTool.pencil,
            pencilType: type,
            points: points,
            thickness: 60,
            opacity: .4,
            color: Colors.purple);
        expect(debugStrokeCoversRegion(stroke, window, 4), isTrue);
        expectEquivalent(
            await windowPixels(
                window,
                8,
                (c) => reference(c, [DrawingStroke.fromJson(stroke.toJson())],
                    zoom: 4)),
            await windowPixels(window, 8, (c) {
              c.saveLayer(Offset.zero & paper, Paint());
              paintDrawingStroke(c, stroke, zoomScale: 4, rasterClip: window);
              c.restore();
            }));
      }
    });
  });

  testWidgets('isolated translucent blur primitives match the frozen renderer',
      (tester) async {
    const window = Rect.fromLTWH(40, 50, 80, 100);
    await tester.runAsync(() async {
      for (final type in [PencilType.pencil, PencilType.watercolor]) {
        for (final kind in ['curve', 'line', 'dot', 'bunga']) {
          final stroke = DrawingStroke(
              tool: kind == 'bunga' ? DrawingTool.shape : DrawingTool.pencil,
              pencilType: type,
              points: kind == 'dot'
                  ? const [Offset(80, 100)]
                  : kind == 'curve'
                      ? const [
                          Offset(0, 70),
                          Offset(30, 30),
                          Offset(110, 170),
                          Offset(160, 120)
                        ]
                      : const [Offset(45, 65), Offset(115, 135)],
              color: const Color.fromARGB(180, 26, 88, 230),
              thickness: 8,
              opacity: .4,
              isDot: kind == 'dot',
              isStraightLine: kind == 'line',
              shapeType: kind == 'bunga' ? kind : null);
          expectEquivalent(
              await windowPixels(
                  window,
                  8,
                  (c) => reference(c, [DrawingStroke.fromJson(stroke.toJson())],
                      zoom: 4)),
              await windowPixels(window, 8, (c) {
                c.saveLayer(Offset.zero & paper, Paint());
                paintDrawingStroke(c, stroke,
                    zoomScale: 4, rasterClip: window.inflate(32));
                c.restore();
              }));
        }
      }
    });
  });

  testWidgets(
      'zoom-out preview partitions alpha without a seam or double blend',
      (tester) async {
    final cache = DrawingRenderCache()
      ..configure(paper, 2, 1, viewport: Offset.zero & paper);
    final stroke = DrawingStroke(
        tool: DrawingTool.pencil,
        points: const [Offset(80, 100)],
        color: Colors.red,
        thickness: 600,
        opacity: .5,
        isDot: true);
    final layer = DrawingLayer(id: 'preview-alpha')..strokes.add(stroke);
    final entry = cache.forLayer(layer);
    await tester.runAsync(() async {
      await flushFrames(tester, cache);
      cache.configure(paper, 2, 20,
          viewport: const Rect.fromLTWH(70, 90, 10, 10));
      await flushFrames(tester, cache);
      cache.setGestureActive(true);
      cache.configure(paper, 2, .5, viewport: Offset.zero & paper);
      expect(entry.isReady, isFalse);
      expectEquivalent(await pixels((c) => reference(c, [stroke])),
          await pixels((c) => entry.paint(c, paper, zoomScale: .5)));
    });
    cache.dispose();
    await tester.pump();
  });

  testWidgets(
      'bounded blur retains long curves, lines and individual flower blends',
      (tester) async {
    final strokes = [
      DrawingStroke(
          tool: DrawingTool.pencil,
          pencilType: PencilType.pencil,
          points: List.generate(
              512,
              (i) => Offset(
                  80 + math.sin(i * .17) * 75, 100 + math.cos(i * .23) * 95)),
          color: Colors.blue,
          thickness: 8),
      DrawingStroke(
          tool: DrawingTool.pencil,
          pencilType: PencilType.watercolor,
          points: const [
            Offset(0, 40),
            Offset(150, 70),
            Offset(10, 130),
            Offset(160, 190)
          ],
          color: Colors.green,
          thickness: 20,
          opacity: .7),
      DrawingStroke(
          tool: DrawingTool.shape,
          pencilType: PencilType.watercolor,
          points: const [Offset(10, 20), Offset(150, 180)],
          color: Colors.red,
          thickness: 3,
          opacity: .6,
          shapeType: 'bunga'),
      DrawingStroke(
          tool: DrawingTool.pencil,
          pencilType: PencilType.pencil,
          points: const [Offset(0, 0), Offset(160, 200)],
          color: Colors.purple,
          thickness: 10,
          isStraightLine: true),
    ];
    const window = Rect.fromLTWH(50, 70, 40, 60);
    await tester.runAsync(() async {
      expectEquivalent(
          await windowPixels(
              window,
              8,
              (c) => reference(
                  c, strokes.map((s) => DrawingStroke.fromJson(s.toJson())),
                  zoom: 4)),
          await windowPixels(window, 8, (c) {
            c.saveLayer(Offset.zero & paper, Paint());
            for (final stroke in strokes) {
              paintDrawingStroke(c, stroke,
                  zoomScale: 4, rasterClip: window.inflate(32));
            }
            c.restore();
          }));
    });
  });

  testWidgets('undo at high zoom reuses both detail and full-paper checkpoints',
      (tester) async {
    var allocations = 0;
    final cache = DrawingRenderCache.withRasterizer((picture, width, height) {
      allocations++;
      return picture.toImage(width, height);
    })
      ..configure(paper, 2, 1, viewport: Offset.zero & paper);
    final layer = DrawingLayer(id: 'zoom-undo')..strokes.addAll(fixture(80));
    final entry = cache.forLayer(layer);
    final originalStrokes = fixture(80);
    const window = Rect.fromLTWH(60, 80, 10, 12);
    await tester.runAsync(() async {
      await flushFrames(tester, cache);
      await pixels((c) => reference(c, originalStrokes));
      cache.configure(paper, 2, 20, viewport: window);
      await flushFrames(tester, cache);
      final before = allocations;
      layer.strokes.removeLast();
      originalStrokes.removeLast();
      expectEquivalent(
          await windowPixels(
              window, 40, (c) => reference(c, originalStrokes, zoom: 20)),
          await windowPixels(
              window, 40, (c) => entry.paint(c, paper, zoomScale: 20)));
      await flushFrames(tester, cache);
      // One overview update, four bounded detail tiles and their final copy.
      // Replaying the 80-stroke history would require many more jobs.
      expect(allocations - before, lessThanOrEqualTo(6));
      expect(entry.isReady, isTrue);
      cache.configure(paper, 2, 1, viewport: Offset.zero & paper);
      final beforeZoomOut = allocations;
      await flushFrames(tester, cache);
      expect(allocations, beforeZoomOut);
      expectEquivalent(await pixels((c) => reference(c, originalStrokes)),
          await pixels((c) => entry.paint(c, paper)));
    });
    cache.dispose();
    await tester.pump();
  });

  testWidgets('a superseded in-flight zoom cannot publish or clear the preview',
      (tester) async {
    late Completer<void> entered;
    late Completer<void> release;
    var hold = false;
    final cache =
        DrawingRenderCache.withRasterizer((picture, width, height) async {
      if (hold) {
        hold = false;
        entered.complete();
        await release.future;
      }
      return picture.toImage(width, height);
    })
          ..configure(paper, 2, 1);
    final layer = DrawingLayer(id: 'race')..strokes.addAll(fixture(48));
    final entry = cache.forLayer(layer);
    await tester.runAsync(() async {
      entered = Completer<void>();
      release = Completer<void>();
      await flushFrames(tester, cache);
      final preview = entry.image;
      final publications = <ui.Image?>[];
      entry.addListener(() => publications.add(entry.image));
      hold = true;
      cache.configure(paper, 2, 4,
          viewport: const Rect.fromLTWH(60, 80, 30, 40));
      final work = cache.flush();
      await entered.future;
      cache.configure(paper, 2, 20,
          viewport: const Rect.fromLTWH(65, 85, 8, 10));
      expect(entry.image, same(preview));
      expect(publications, isEmpty);
      release.complete();
      await work;
      expect(entry.isReady, isTrue);
      expect(entry.scale, 40);
      expect(publications, hasLength(1));
      expect(publications.single, same(entry.image));
    });
    cache.dispose();
    await tester.pump();
  });

  testWidgets(
      'zoom replacements publish complete images atomically through 20x',
      (tester) async {
    late DrawingLayerCache entry;
    ui.Image? visibleBefore;
    var checking = false;
    var checkedBatches = 0;
    final cache = DrawingRenderCache.withRasterizer((picture, width, height) {
      if (checking) {
        expectSync(entry.image, same(visibleBefore));
        expectSync(width * height * 4,
            lessThanOrEqualTo(DrawingRenderCache.maxImageBytes));
        checkedBatches++;
      }
      return picture.toImage(width, height);
    })
      ..configure(paper, 2, 1);
    final layer = DrawingLayer(id: 'atomic')..strokes.addAll(fixture(48));
    final originalStrokes = fixture(48);
    entry = cache.forLayer(layer);
    await tester.runAsync(() async {
      await flushFrames(tester, cache);
      // Original perfect_freehand paths survive zoom changes as well. Warm
      // this independent reference at the same starting scale.
      await pixels((c) => reference(c, originalStrokes));
      for (final zoom in [2.0, 4.0, 8.0, 20.0, 0.5, 1.0]) {
        await tester.pump();
        final window = Rect.fromCenter(
            center: const Offset(80, 100),
            width: paper.width / math.max(zoom, 1),
            height: paper.height / math.max(zoom, 1));
        visibleBefore = entry.image;
        checking = true;
        cache.configure(paper, 2, zoom, viewport: window);
        expect(entry.image, same(visibleBefore));
        await flushFrames(tester, cache);
        checking = false;
        expect(entry.isReady, isTrue);
        final density = 2.0 * math.max(zoom, 1.0);
        expectEquivalent(
            await windowPixels(window, density,
                (c) => reference(c, originalStrokes, zoom: zoom)),
            await windowPixels(window, density,
                (c) => entry.paint(c, paper, zoomScale: zoom)));
      }
      expect(checkedBatches, greaterThan(6));
      expect(cache.allocatedBytes,
          lessThanOrEqualTo(DrawingRenderCache.maxTotalBytes));
    });
    cache.dispose();
    await tester.pump();
  });

  testWidgets('same-length edits cannot reuse stale prefix pixels',
      (tester) async {
    final cache = DrawingRenderCache()..configure(paper, 2, 1);
    final layer = DrawingLayer(id: 'replace')..strokes.addAll(fixture(48));
    final entry = cache.forLayer(layer);
    await tester.runAsync(() async {
      await flushFrames(tester, cache);
      layer.strokes.value = fixture(48).reversed.toList();
      await flushFrames(tester, cache);
      expectEquivalent(await pixels((c) => reference(c, fixture(48).reversed)),
          await pixels((c) => entry.paint(c, paper)));
    });
    cache.dispose();
    await tester.pump();
  });

  testWidgets(
      'high-zoom export covers the whole paper at the requested density',
      (tester) async {
    const window = Rect.fromLTWH(60, 80, 10, 12);
    final cache = DrawingRenderCache()
      ..configure(paper, 2, 20, viewport: window);
    final layer = DrawingLayer(id: 'export')..strokes.addAll(fixture(48));
    final originalStrokes = fixture(48);
    final entry = cache.forLayer(layer);
    await tester.runAsync(() async {
      await flushFrames(tester, cache);
      expect(entry.cachedRegion!.width, lessThan(paper.width));
      cache.configure(paper, 2, 20, fullResolutionExport: true);
      await flushFrames(tester, cache);
      expect(entry.cachedRegion, Offset.zero & paper);
      expect(entry.scale, 2);
      await pixels((c) => reference(c, originalStrokes));
      expectEquivalent(
          await pixels((c) => reference(c, originalStrokes, zoom: 20)),
          await pixels((c) => entry.paint(c, paper, zoomScale: 20)));
    });
    cache.dispose();
    await tester.pump();
  });

  testWidgets('bulk raster work is flattened between bounded native batches',
      (tester) async {
    var allocations = 0;
    final cache = DrawingRenderCache.withRasterizer((picture, width, height) {
      allocations++;
      return picture.toImage(width, height);
    })
      ..configure(paper, 2, 1);
    final layer = DrawingLayer(id: 'batch')..strokes.addAll(fixture(100));
    final entry = cache.forLayer(layer);
    await tester.runAsync(() async {
      await flushFrames(tester, cache);
      expect(allocations, (100 / DrawingRenderCache.maxBatchStrokes).ceil());
      expect(entry.bakedCount, 100);
      expectEquivalent(await pixels((c) => reference(c, fixture(100))),
          await pixels((c) => entry.paint(c, paper)));
      final completed = entry.image;
      cache.setGestureActive(true);
      for (final zoom in [1.1, 1.5, 1.8, 1.0]) {
        cache.configure(paper, 2, zoom);
        await flushFrames(tester, cache);
        expect(entry.image, same(completed));
      }
      cache.setGestureActive(false);
      await flushFrames(tester, cache);
      expect(allocations, (100 / DrawingRenderCache.maxBatchStrokes).ceil());
    });
    cache.dispose();
    await tester.pump();
  });

  testWidgets(
      'drawing and pinch pause background work independently while export can flush',
      (tester) async {
    var allocations = 0;
    final cache = DrawingRenderCache.withRasterizer((picture, width, height) {
      allocations++;
      return picture.toImage(width, height);
    })
      ..configure(paper, 2, 1);
    final layer = DrawingLayer(id: 'gesture')..strokes.addAll(fixture(8));
    final entry = cache.forLayer(layer);
    await tester.runAsync(() async {
      cache.setGestureActive(true);
      for (final zoom in [1.1, 1.2, 1.3, 1.4]) {
        cache.configure(paper, 2, zoom);
        await flushFrames(tester, cache);
      }
      expect(allocations, 0);
      expect(entry.image, isNull);
      cache.setGestureActive(false);
      await flushFrames(tester, cache);
      expect(allocations, 1);
      expect(entry.bakedCount, layer.strokes.length);
      cache.setDrawingActive(true);
      layer.strokes.add(fixture(1).first);
      await flushFrames(tester, cache);
      expect(allocations, 1);
      cache.setGestureActive(true);
      cache.setDrawingActive(false);
      await flushFrames(tester, cache);
      expect(allocations, 1);
      cache.setGestureActive(false);
      await flushFrames(tester, cache);
      expect(entry.isReady, isTrue);
      final beforeExport = allocations;
      cache.setDrawingActive(true);
      layer.strokes.add(fixture(2).last);
      cache.configure(paper, 2, 1.4, fullResolutionExport: true);
      await flushFrames(tester, cache);
      expect(entry.isReady, isTrue);
      expect(allocations, greaterThan(beforeExport));
    });
    cache.dispose();
    await tester.pump();
  });

  testWidgets('fractional device density retains detail through repeated bakes',
      (tester) async {
    final cache = DrawingRenderCache()..configure(paper, 2.625, 1);
    final layer = DrawingLayer(id: 'fractional');
    final entry = cache.forLayer(layer);
    final strokes = fixture(24);
    await tester.runAsync(() async {
      for (final stroke in strokes) {
        layer.strokes.add(stroke);
        await flushFrames(tester, cache);
      }
      expectEquivalent(
          await pixels((c) => reference(c, fixture(24)), density: 2.625),
          await pixels((c) => entry.paint(c, paper), density: 2.625));
    });
    cache.dispose();
    await tester.pump();
  });

  testWidgets(
    'shared renderer matches the frozen renderer at all zoom regimes',
    (tester) async {
      await tester.runAsync(() async {
        for (final zoom in [0.5, 1.0, 2.0, 5.0, 20.0]) {
          final expected = await pixels(
            (c) => reference(c, fixture(98), zoom: zoom),
          );
          final actual = await pixels((c) {
            c.saveLayer(Offset.zero & paper, Paint());
            for (final stroke in fixture(98)) {
              paintDrawingStroke(c, stroke, zoomScale: zoom);
            }
            c.restore();
          });
          expectEquivalent(expected, actual);
        }
      });
    },
  );

  testWidgets(
    'incremental smoothing retains the original curve at every sample',
    (tester) async {
      await tester.runAsync(() async {
        for (final type in [PencilType.pencil, PencilType.watercolor]) {
          final live = DrawingStroke(
            tool: DrawingTool.pencil,
            pencilType: type,
            points: [const Offset(10, 20)],
            color: Colors.blue,
            thickness: 12,
          );
          for (var i = 1; i < 35; i++) {
            live.points.add(Offset(10 + i * 4, 70 + math.sin(i / 3) * 30));
            live.cachedPath = null;
            final old = DrawingStroke.fromJson(live.toJson());
            final expected = await pixels((c) => reference(c, [old]));
            final actual = await pixels((c) {
              c.saveLayer(Offset.zero & paper, Paint());
              paintDrawingStroke(c, live, isLive: true);
              c.restore();
            });
            expectEquivalent(expected, actual);
          }
        }
      });
    },
  );

  testWidgets(
    'raster, pending eraser and multiply preserve layer composition',
    (tester) async {
      final cache = DrawingRenderCache()..configure(paper, 2, 1);
      final layer = DrawingLayer(id: 'one')..strokes.addAll(fixture());
      final entry = cache.forLayer(layer);
      await tester.runAsync(() async {
        await flushFrames(tester, cache);
        expect(entry.bakedCount, layer.strokes.length);
        expect(entry.image, isNotNull);
        expectEquivalent(
          await pixels((c) => reference(c, fixture())),
          await pixels((c) => entry.paint(c, paper)),
        );
        final eraser = DrawingStroke(
          tool: DrawingTool.eraser,
          points: [const Offset(10, 100), const Offset(150, 100)],
          color: Colors.transparent,
          thickness: 20,
        );
        layer.strokes.add(eraser);
        final pending = await pixels((c) => entry.paint(c, paper));
        final expected = await pixels(
          (c) => reference(c, [
            ...fixture(),
            DrawingStroke.fromJson(eraser.toJson()),
          ]),
        );
        expectEquivalent(expected, pending);
        await flushFrames(tester, cache);
        expectEquivalent(expected, await pixels((c) => entry.paint(c, paper)));
      });
      cache.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'undo invalidates immediately and redo restores the original order',
    (tester) async {
      final cache = DrawingRenderCache()..configure(paper, 2, 1);
      final layer = DrawingLayer(id: 'one')..strokes.addAll(fixture());
      final entry = cache.forLayer(layer);
      await tester.runAsync(() async {
        await flushFrames(tester, cache);
        final removed = layer.strokes.removeLast();
        expect(entry.image, isNotNull);
        expectEquivalent(
          await pixels((c) => reference(c, fixture(47))),
          await pixels((c) => entry.paint(c, paper)),
        );
        layer.strokes.add(removed);
        await flushFrames(tester, cache);
        expectEquivalent(
          await pixels((c) => reference(c, fixture())),
          await pixels((c) => entry.paint(c, paper)),
        );
      });
      cache.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'live eraser and watercolor composite over the cache without committing',
    (tester) async {
      final cache = DrawingRenderCache()..configure(paper, 2, 1);
      final layer = DrawingLayer(id: 'one')..strokes.addAll(fixture());
      final entry = cache.forLayer(layer);
      await tester.runAsync(() async {
        await flushFrames(tester, cache);
        final original = entry.image;
        for (final tool in [DrawingTool.eraser, DrawingTool.pencil]) {
          final live = DrawingStroke(
            tool: tool,
            pencilType: PencilType.watercolor,
            points: [const Offset(10, 50), const Offset(140, 140)],
            color: Colors.blue,
            thickness: 30,
            opacity: 0.5,
          );
          expectEquivalent(
            await pixels(
              (c) => reference(c, [
                ...fixture(),
                DrawingStroke.fromJson(live.toJson()),
              ]),
            ),
            await pixels((c) => entry.paint(c, paper, liveStroke: live)),
          );
          expect(entry.image, same(original));
          expect(layer.strokes.length, 48);
        }
      });
      cache.dispose();
      await tester.pump();
    },
  );

  testWidgets('rasterization failure leaves every vector stroke visible', (
    tester,
  ) async {
    final cache = DrawingRenderCache.withRasterizer((_, __, ___) async {
      throw StateError('simulated raster allocation failure');
    })
      ..configure(paper, 2, 1);
    final layer = DrawingLayer(id: 'one')..strokes.addAll(fixture());
    final entry = cache.forLayer(layer);
    await tester.runAsync(() async {
      await flushFrames(tester, cache);
      expect(entry.image, isNull);
      expect(entry.bakedCount, 0);
      expectEquivalent(
        await pixels((c) => reference(c, fixture())),
        await pixels((c) => entry.paint(c, paper)),
      );
    });
    cache.dispose();
    await tester.pump();
  });

  testWidgets('clear during a bake cannot resurrect deleted strokes', (
    tester,
  ) async {
    final cache = DrawingRenderCache()..configure(paper, 2, 1);
    final layer = DrawingLayer(id: 'one')..strokes.addAll(fixture(160));
    final entry = cache.forLayer(layer);
    await tester.runAsync(() async {
      final baking = cache.flush();
      layer.strokes.clear();
      await baking;
      expect(entry.image, isNull);
      expect(entry.bakedCount, 0);
      expectEquivalent(
        await pixels((_) {}),
        await pixels((c) => entry.paint(c, paper)),
      );
    });
    cache.dispose();
    await tester.pump();
  });

  testWidgets(
    'layer deletion and controller disposal cancel pending publication',
    (tester) async {
      final cache = DrawingRenderCache()..configure(paper, 2, 1);
      final layer = DrawingLayer(id: 'removed')..strokes.addAll(fixture(160));
      final entry = cache.forLayer(layer);
      await tester.runAsync(() async {
        final baking = cache.flush();
        cache.retainLayers([]);
        cache.dispose();
        await baking;
        expect(entry.image, isNull);
        expect(cache.allocatedBytes, 0);
      });
      await tester.pump();
    },
  );

  testWidgets(
    'standalone high-zoom output keeps its requested density without vector fallback',
    (tester) async {
      final cache = DrawingRenderCache()..configure(paper, 2, 1);
      final layer = DrawingLayer(id: 'one')..strokes.addAll(fixture());
      final entry = cache.forLayer(layer);
      await tester.runAsync(() async {
        await flushFrames(tester, cache);
        cache.configure(paper, 2, 20);
        await flushFrames(tester, cache);
        expect(entry.image, isNotNull);
        expectEquivalent(
          await pixels((c) => reference(c, layer.strokes, zoom: 20)),
          await pixels((c) => entry.paint(c, paper, zoomScale: 20)),
        );
        expect(
          cache.allocatedBytes,
          lessThanOrEqualTo(DrawingRenderCache.maxTotalBytes),
        );
      });
      cache.dispose();
      await tester.pump();
    },
  );

  testWidgets('capture bypass includes all cached and pending strokes', (
    tester,
  ) async {
    final cache = DrawingRenderCache()..configure(paper, 2, 1);
    final layer = DrawingLayer(id: 'one')..strokes.addAll(fixture());
    final entry = cache.forLayer(layer);
    await tester.runAsync(() async {
      await flushFrames(tester, cache);
      layer.strokes.addAll(fixture(3));
      expectEquivalent(
        await pixels((c) => reference(c, [...fixture(), ...fixture(3)])),
        await pixels((c) => entry.paint(c, paper, useRaster: false)),
      );
    });
    cache.dispose();
    await tester.pump();
  });

  testWidgets(
    'strokes appended during baking are coalesced without dropping order',
    (tester) async {
      final cache = DrawingRenderCache()..configure(paper, 2, 1);
      final layer = DrawingLayer(id: 'one')..strokes.addAll(fixture(80));
      final entry = cache.forLayer(layer);
      await tester.runAsync(() async {
        final baking = cache.flush();
        layer.strokes.addAll(fixture(5));
        await baking;
        expect(entry.bakedCount, 85);
        expectEquivalent(
          await pixels((c) => reference(c, [...fixture(80), ...fixture(5)])),
          await pixels((c) => entry.paint(c, paper)),
        );
      });
      cache.dispose();
      await tester.pump();
    },
  );

  testWidgets('eraser on an upper layer preserves the lower layer', (
    tester,
  ) async {
    final cache = DrawingRenderCache()..configure(paper, 2, 1);
    final lower = DrawingLayer(id: 'lower')..strokes.addAll(fixture(24));
    final upper = DrawingLayer(id: 'upper')..strokes.addAll(fixture(30));
    final lowerEntry = cache.forLayer(lower);
    final upperEntry = cache.forLayer(upper);
    await tester.runAsync(() async {
      await flushFrames(tester, cache);
      expectEquivalent(
        await pixels((c) {
          reference(c, fixture(24));
          reference(c, fixture(30));
        }),
        await pixels((c) {
          lowerEntry.paint(c, paper);
          upperEntry.paint(c, paper);
        }),
      );
      cache.releaseImages();
      expect(lowerEntry.image, isNotNull);
      expect(upperEntry.image, isNotNull);
      await flushFrames(tester, cache);
      expectEquivalent(
        await pixels((c) {
          reference(c, fixture(24));
          reference(c, fixture(30));
        }),
        await pixels((c) {
          lowerEntry.paint(c, paper);
          upperEntry.paint(c, paper);
        }),
      );
    });
    cache.dispose();
    await tester.pump();
  });

  for (final count in [1000, 3000, 5000]) {
    testWidgets(
      '$count mixed strokes across three layers retain complete caches',
      (tester) async {
        final cache = DrawingRenderCache()..configure(paper, 2, 1);
        final strokes = fixture(count);
        final layers = List.generate(3, (i) => DrawingLayer(id: 'stress-$i'));
        for (var i = 0; i < count; i++) {
          layers[i % layers.length].strokes.add(strokes[i]);
        }
        final entries = layers.map(cache.forLayer).toList();
        await tester.runAsync(() async {
          await flushFrames(tester, cache);
          for (var i = 0; i < entries.length; i++) {
            expect(entries[i].bakedCount, layers[i].strokes.length);
            expect(entries[i].image, isNotNull);
          }
          expect(
            cache.allocatedBytes,
            lessThanOrEqualTo(DrawingRenderCache.maxTotalBytes),
          );
          await pixels((c) {
            for (final entry in entries) {
              entry.paint(c, paper);
            }
          });
        });
        cache.dispose();
        await tester.pump();
      },
    );
  }

  test(
    'runtime caches do not enter draft JSON and old stroke defaults survive',
    () {
      final layer = DrawingLayer(id: 'draft')..strokes.addAll(fixture());
      final json = layer.toJson();
      expect(json.keys.toSet(), {
        'id',
        'name',
        'strokes',
        'stempels',
        'isVisible',
      });
      expect(DrawingLayer.fromJson(json).toJson(), json);
      expect(layer.toJson(encodeStroke: (stroke) => stroke.toJson()), json);
      final legacy = Map<String, dynamic>.of(fixture(1).first.toJson())
        ..remove('pencilType')
        ..remove('opacity');
      final stroke = DrawingStroke.fromJson(legacy);
      expect(stroke.pencilType, PencilType.ballpoint);
      expect(stroke.opacity, 1);
    },
  );
}
