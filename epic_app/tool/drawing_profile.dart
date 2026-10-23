// Development-only entry point. This does not initialize Firebase or persist
// draft/session data. It benchmarks the actual drawing canvas and layer panel.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:epic_app/features/games/menggambar/debug/drawing_stress_fixture.dart';
import 'package:epic_app/features/games/menggambar/drawing_controller.dart';
import 'package:epic_app/features/games/menggambar/drawing_screen.dart';
import 'package:epic_app/features/games/menggambar/widgets/stroke_renderer.dart'
    show debugCoverageFastPathHits;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'drawing_device_quality.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GetMaterialApp(home: _DrawingProfile()));
}

void mainZoomStress() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GetMaterialApp(home: _DrawingProfile(zoomStress: true)));
}

void mainHighZoomStress() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GetMaterialApp(
      home: _DrawingProfile(zoomStress: true, stressZooms: [20])));
}

void mainFourZoomStress() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GetMaterialApp(
      home: _DrawingProfile(zoomStress: true, stressZooms: [4])));
}

class _ProfileController extends DrawingController {
  _ProfileController() : super(kategori: 'batik', level: 1);

  @override
  void onReady() {} // Never start a session or save drafts in the harness.
}

class _DrawingProfile extends StatefulWidget {
  const _DrawingProfile({
    this.zoomStress = false,
    this.stressZooms = const [4, 8, 20, 2, 0.5, 1],
  });
  final bool zoomStress;
  final List<double> stressZooms;
  @override
  State<_DrawingProfile> createState() => _DrawingProfileState();
}

class _DrawingProfileState extends State<_DrawingProfile>
    with TickerProviderStateMixin {
  late final DrawingController controller;
  String status = 'Preparing';
  bool panel = false;
  final frameProbe = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    controller = _ProfileController()..onInit();
    controller.layers.add(DrawingLayer(id: 'initial'));
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.zoomStress ? _runZoomStress() : _run());
  }

  int get rss {
    try {
      return ProcessInfo.currentRss;
    } catch (_) {
      return 0;
    }
  }

  double percentile(List<double> values, double fraction) {
    if (values.isEmpty) return 0;
    values.sort();
    return values[((values.length - 1) * fraction).round()];
  }

  void report(Map<String, Object> values) {
    debugPrint(
      'DRAWING_BENCHMARK ${jsonEncode({
            ...values,
            'rssMiB': rss / 1048576,
            'cacheMiB': controller.renderCache.allocatedBytes / 1048576,
            if (widget.zoomStress)
              'certifiedCoverageHits': debugCoverageFastPathHits,
            'cacheComplete': controller.layers.every(
                (layer) => controller.renderCache.forLayer(layer).isReady),
          })}',
    );
  }

  Future<void> waitForRasterFrame() async {
    final binding = WidgetsBinding.instance;
    final after = binding.currentSystemFrameTimeStamp.inMicroseconds;
    final done = Completer<void>();
    void collect(List<ui.FrameTiming> batch) {
      if (!done.isCompleted &&
          batch.any((frame) =>
              frame.timestampInMicroseconds(ui.FramePhase.buildStart) >
              after)) {
        done.complete();
      }
    }

    binding.addTimingsCallback(collect);
    // A scheduled frame with an unchanged scene can skip rasterization and
    // produce no FrameTiming. Dirty the benchmark label to create a real probe.
    if (mounted) setState(() => status = '$status .');
    binding.scheduleFrame();
    try {
      await done.future.timeout(const Duration(seconds: 30));
    } finally {
      binding.removeTimingsCallback(collect);
    }
  }

  Future<double> settleCaches() async {
    final watch = Stopwatch()..start();
    var nextProgress = 10;
    while (watch.elapsed < const Duration(minutes: 10)) {
      final ready = controller.layers.every(
        (layer) => controller.renderCache.forLayer(layer).isReady,
      );
      if (ready) break;
      if (watch.elapsed.inSeconds >= nextProgress) {
        report({
          'phase': 'cache-progress',
          'elapsedMs': watch.elapsedMilliseconds,
          ...controller.renderCache.debugProgress
        });
        nextProgress += 10;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final readyMs = watch.elapsedMicroseconds / 1000;
    if (!controller.layers
        .every((layer) => controller.renderCache.forLayer(layer).isReady)) {
      throw StateError('Cache did not finish preparing within ten minutes');
    }
    await waitForRasterFrame();
    return readyMs;
  }

  Future<void> measure(int count, String phase, void Function(double) action,
      {bool forceFrames = false}) async {
    if (!mounted) return;
    setState(() => status = '$count strokes: $phase');
    final frameBudgetMs = 1000 / View.of(context).display.refreshRate;
    final timings = <ui.FrameTiming>[];
    final first =
        WidgetsBinding.instance.currentSystemFrameTimeStamp.inMicroseconds;
    var last = first;
    var drained = false;
    void collect(List<ui.FrameTiming> batch) => timings.addAll(batch);
    final animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    animation.addListener(() {
      action(animation.value);
      if (forceFrames && mounted) frameProbe.value++;
    });
    WidgetsBinding.instance.addTimingsCallback(collect);
    try {
      await animation.forward();
      last = WidgetsBinding.instance.currentSystemFrameTimeStamp.inMicroseconds;
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) setState(() => status = '$count strokes: $phase sampled');
      final drain = Stopwatch()..start();
      while (drain.elapsed < const Duration(seconds: 30)) {
        drained = timings.any((frame) =>
            frame.timestampInMicroseconds(ui.FramePhase.buildStart) >= last);
        if (drained) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    } finally {
      WidgetsBinding.instance.removeTimingsCallback(collect);
      animation.dispose();
    }
    timings.removeWhere((frame) {
      final start = frame.timestampInMicroseconds(ui.FramePhase.buildStart);
      return start <= first || start > last;
    });
    timings.sort((a, b) => a.frameNumber.compareTo(b.frameNumber));
    var longestSlowRun = 0;
    var slowRun = 0;
    for (final frame in timings) {
      slowRun = frame.buildDuration.inMicroseconds > 16667 ||
              frame.rasterDuration.inMicroseconds > 16667
          ? slowRun + 1
          : 0;
      longestSlowRun = math.max(longestSlowRun, slowRun);
    }
    report({
      'count': count,
      'phase': phase,
      'frameBudgetMs': frameBudgetMs,
      'overDisplayBudget': timings
          .where((f) =>
              f.buildDuration.inMicroseconds / 1000 > frameBudgetMs ||
              f.rasterDuration.inMicroseconds / 1000 > frameBudgetMs)
          .length,
      'frames': timings.length,
      'rasterDrained': drained,
      'longestSlowRun': longestSlowRun,
      'maxBuildMs': percentile(
          timings.map((f) => f.buildDuration.inMicroseconds / 1000).toList(),
          1),
      'maxRasterMs': percentile(
          timings.map((f) => f.rasterDuration.inMicroseconds / 1000).toList(),
          1),
      'spanP95Ms': percentile(
          timings.map((f) => f.totalSpan.inMicroseconds / 1000).toList(), 0.95),
      'buildP95Ms': percentile(
        timings.map((f) => f.buildDuration.inMicroseconds / 1000).toList(),
        0.95,
      ),
      'rasterP95Ms': percentile(
        timings.map((f) => f.rasterDuration.inMicroseconds / 1000).toList(),
        0.95,
      ),
      'over16ms': timings
          .where(
            (f) =>
                f.buildDuration.inMicroseconds > 16667 ||
                f.rasterDuration.inMicroseconds > 16667,
          )
          .length,
    });
  }

  Matrix4 _zoomMatrix(Matrix4 base, Size size, double zoom,
          [double panX = 0, double panY = 0]) =>
      base.clone()
        ..translateByDouble(size.width / 2 + panX, size.height / 2 + panY, 0, 1)
        ..scaleByDouble(zoom, zoom, 1, 1)
        ..translateByDouble(-size.width / 2, -size.height / 2, 0, 1);

  Future<void> _waitForPaper() async {
    final watch = Stopwatch()..start();
    while (watch.elapsed < const Duration(seconds: 30)) {
      if (!mounted) return;
      final view = View.of(context);
      if (controller.paperWidth > 0 &&
          controller.paperHeight > 0 &&
          view.physicalSize.width > 32 &&
          view.physicalSize.height > 220) {
        await waitForRasterFrame();
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    throw StateError('Android view did not provide a valid paper size');
  }

  Future<void> _checkRasterContent(int count, Size size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(32 / size.width);
    for (final layer in controller.layers) {
      controller.renderCache.forLayer(layer).paint(canvas, size);
    }
    final picture = recorder.endRecording();
    final height = (32 * size.height / size.width).ceil();
    final image = await picture.toImage(32, height);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final data = bytes!.buffer.asUint8List();
      var painted = 0;
      for (var i = 3; i < data.length; i += 4) {
        if (data[i] > 0) painted++;
      }
      final centerAlpha = data[((height ~/ 2) * 32 + 16) * 4 + 3];
      if (centerAlpha == 0 || painted < 32 * height * .2) {
        throw StateError('Invalid benchmark: generated drawing is not visible');
      }
      report({
        'count': count,
        'phase': 'raster-content-check',
        'paintedFraction': painted / (32 * height),
        'centerAlpha': centerAlpha
      });
    } finally {
      image.dispose();
      picture.dispose();
    }
  }

  Future<void> _runZoomStress() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      await _waitForPaper();
      if (!mounted) return;
      setState(() => status = 'Validating native brush pixels');
      await verifyDrawingDeviceQuality(report);
      if (!mounted) return;
      final defaultConfig =
          File('${Directory.systemTemp.path}/drawing-zoom-count.txt');
      final appConfig = File(
          '/data/data/com.epic.epic_app.drawing_benchmark/cache/drawing-zoom-count.txt');
      final config = defaultConfig.existsSync() ? defaultConfig : appConfig;
      final requested = config.existsSync()
          ? int.tryParse(config.readAsStringSync().trim())
          : null;
      final count = [1000, 3000, 5000].contains(requested) ? requested! : 5000;
      final size = Size(controller.paperWidth, controller.paperHeight);
      report({
        'phase': 'zoom-stress-configuration',
        'paperWidth': size.width,
        'paperHeight': size.height,
        'pixelRatio': MediaQuery.devicePixelRatioOf(context),
        'longStrokePoints': 512,
        'initialStrokes': count,
        'refreshRateHz': View.of(context).display.refreshRate
      });
      final fixture = buildDrawingStressFixture(count, size, longStrokes: true);
      final denseLayer = DrawingLayer(id: 'stress-dense');
      denseLayer.strokes.addAll(fixture.expand((layer) => layer.strokes));
      controller.layers.assignAll([denseLayer]);
      controller.activeLayerIndex.value = 0;
      final initialMs = await settleCaches();
      report({'count': count, 'phase': 'initial-ready', 'readyMs': initialMs});
      await _checkRasterContent(count, size);
      final base = controller.canvasMatrix.value.clone();
      var previousZoom = 1.0;
      for (final zoom in widget.stressZooms) {
        controller.renderCache.setGestureActive(true);
        await measure(count, 'pinch-to-${zoom}x', (t) {
          controller.canvasMatrix.value =
              _zoomMatrix(base, size, previousZoom + (zoom - previousZoom) * t);
        }, forceFrames: true);
        controller.canvasMatrix.value = _zoomMatrix(base, size, zoom);
        controller.renderCache.setGestureActive(false);
        await measure(count, 'prepare-at-${zoom}x', (_) {}, forceFrames: true);
        final readyMs = await settleCaches();
        report({
          'count': count,
          'phase': 'ready-at-${zoom}x',
          'remainingReadyMs': readyMs
        });
        controller.renderCache.setGestureActive(true);
        await measure(count, 'pan-at-${zoom}x', (t) {
          controller.canvasMatrix.value = _zoomMatrix(
              base, size, zoom, math.sin(t * 12) * 18, math.cos(t * 12) * 18);
        }, forceFrames: true);
        controller.canvasMatrix.value = _zoomMatrix(base, size, zoom);
        controller.renderCache.setGestureActive(false);
        await settleCaches();
        if (zoom == 4 || zoom == 20) {
          for (final type in [PencilType.ballpoint, PencilType.watercolor]) {
            controller.setPencilType(type);
            controller.setThickness(40);
            controller.onPanStart(Offset(size.width / 2, size.height / 2));
            await measure(count, 'draw-${type.name}-at-${zoom}x', (t) {
              controller.onPanUpdate(Offset(
                  size.width * (.5 + .45 / zoom * math.sin(t * 48)),
                  size.height * (.5 + .45 / zoom * math.cos(t * 37))));
            }, forceFrames: true);
            controller.onPanEnd();
            await settleCaches();
            controller.undo();
            await settleCaches();
          }
        }
        previousZoom = zoom;
      }
      // Repeated real pinch pointer events validate gesture gating, rather than
      // relying solely on the benchmark's explicit setGestureActive calls.
      if (!mounted) return;
      final viewportCenter = Offset(MediaQuery.sizeOf(context).width / 2,
          MediaQuery.sizeOf(context).height / 2);
      controller.onPointerDown(PointerDownEvent(
          pointer: 91, position: viewportCenter - const Offset(30, 0)));
      controller.onPointerDown(PointerDownEvent(
          pointer: 92, position: viewportCenter + const Offset(30, 0)));
      await measure(count, 'repeated-real-pointer-pinch', (t) {
        final spread = 30 + 220 * (0.5 - 0.5 * math.cos(t * math.pi * 8));
        controller.onPointerMove(PointerMoveEvent(
            pointer: 91, position: viewportCenter - Offset(spread, 0)));
        controller.onPointerMove(PointerMoveEvent(
            pointer: 92, position: viewportCenter + Offset(spread, 0)));
      }, forceFrames: true);
      controller
          .onPointerUp(PointerUpEvent(pointer: 91, position: viewportCenter));
      controller
          .onPointerUp(PointerUpEvent(pointer: 92, position: viewportCenter));
      await settleCaches();
      report({'phase': 'zoom-stress-complete'});
      if (mounted) setState(() => status = 'Zoom stress complete');
    } catch (error, stack) {
      debugPrint('DRAWING_BENCHMARK_ERROR $error\n$stack');
      if (mounted) setState(() => status = 'Failed: $error');
    }
  }

  Future<void> _run() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      report({
        'phase': 'configuration',
        'paperWidth': controller.paperWidth,
        'paperHeight': controller.paperHeight,
        'pixelRatio': MediaQuery.devicePixelRatioOf(context)
      });
      for (final count in [1000, 3000, 5000]) {
        final size = Size(controller.paperWidth, controller.paperHeight);
        controller.layers.assignAll(buildDrawingStressFixture(count, size));
        controller.activeLayerIndex.value = 0;
        await settleCaches();
        final base = controller.canvasMatrix.value.clone();
        for (final type in [PencilType.ballpoint, PencilType.watercolor]) {
          controller.setPencilType(type);
          controller.setThickness(40);
          controller.onPanStart(Offset(size.width / 2, size.height / 2));
          await measure(count, 'draw-${type.name}', (t) {
            controller.onPanUpdate(
              Offset(
                size.width * (0.5 + 0.45 * math.sin(t * 30)),
                size.height * (0.5 + 0.45 * math.cos(t * 21)),
              ),
            );
          });
          controller.onPanEnd();
          await settleCaches();
        }
        await measure(count, 'pan-rotate', (t) {
          controller.canvasMatrix.value = base.clone()
            ..translateByDouble(
                math.sin(t * 8) * 30, math.cos(t * 8) * 30, 0.0, 1.0)
            ..rotateZ(math.sin(t * 6) * 0.15);
        });
        controller.canvasMatrix.value = base.clone();
        controller.renderCache.setGestureActive(true);
        await measure(count, 'zoom', (t) {
          controller.canvasMatrix.value = base.clone()
            ..scaleByDouble(1 + 0.8 * math.sin(t * math.pi),
                1 + 0.8 * math.sin(t * math.pi), 1.0, 1.0);
        });
        controller.canvasMatrix.value = base.clone();
        controller.renderCache.setGestureActive(false);
        await settleCaches();
        final undo = Stopwatch()..start();
        controller.undo();
        await WidgetsBinding.instance.endOfFrame;
        final uiFrameMs = undo.elapsedMicroseconds / 1000;
        final cacheWaitMs = await settleCaches();
        report({
          'count': count,
          'phase': 'undo',
          'uiFrameMs': uiFrameMs,
          'cacheReadyMs': uiFrameMs + cacheWaitMs,
        });
        setState(() => panel = true);
        await measure(count, 'layer-panel', (_) {});
        setState(() => panel = false);
        controller.clearCanvas();
        await waitForRasterFrame();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        report({'count': count, 'phase': 'clear'});
      }
      setState(() => status = 'Completed; results in Flutter logs');
      report({'phase': 'complete'});
    } catch (error, stack) {
      debugPrint('DRAWING_BENCHMARK_ERROR $error\n$stack');
      if (mounted) setState(() => status = 'Failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(status, style: const TextStyle(fontSize: 14)),
          actions: [
            ValueListenableBuilder<int>(
                valueListenable: frameProbe,
                builder: (_, value, child) => SizedBox(
                    width: 40,
                    child: Center(
                        child: Text('${value % 100}',
                            style: const TextStyle(fontSize: 10)))))
          ],
        ),
        // Physical touches must not modify the deterministic fixture while
        // this entry point drives controller input programmatically.
        body: IgnorePointer(
            child: Stack(
          children: [
            Positioned.fill(child: buildDrawingCanvasForTesting(controller)),
            if (panel)
              Center(
                child: SizedBox(
                  width: 340,
                  child: buildDrawingLayerPanelForTesting(controller),
                ),
              ),
          ],
        )),
      );

  @override
  void dispose() {
    controller.onClose();
    frameProbe.dispose();
    super.dispose();
  }
}
