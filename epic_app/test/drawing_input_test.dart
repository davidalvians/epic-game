import 'dart:ui' as ui;

import 'package:epic_app/features/games/menggambar/drawing_controller.dart';
import 'package:epic_app/features/games/menggambar/drawing_screen.dart';
import 'package:epic_app/features/games/menggambar/models/stempel_model.dart';
import 'package:epic_app/features/games/menggambar/stempel_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _InputController extends DrawingController {
  _InputController() : super(kategori: 'batik', level: 1);

  @override
  void onReady() {} // Exercise drawing without creating a Firebase session.
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DrawingController controller;
  var closed = false;

  setUp(() {
    closed = false;
    controller = _InputController();
    controller.onInit();
    controller.layers.add(DrawingLayer(id: 'test'));
    controller.setDefaultCanvasSize(400, 600, 320, 450);
  });

  tearDown(() {
    if (!closed) controller.onClose();
  });

  test(
    'long freehand input keeps one stroke and leaves Rx widget state alone',
    () {
      controller.onPanStart(const Offset(10, 10));
      final live = controller.currentStroke.value!;
      final startTick = controller.liveTick.value;
      var replacements = 0;
      final worker = ever(controller.currentStroke, (_) => replacements++);
      for (var i = 1; i <= 1000; i++) {
        controller.onPanUpdate(Offset(10 + i * 3, 10));
      }
      expect(identical(controller.currentStroke.value, live), isTrue);
      expect(live.points.length, 1001);
      expect(replacements, 0);
      expect(controller.liveTick.value - startTick, 1000);
      worker.dispose();
      controller.onPanEnd();
      final committed = controller.activeLayer.strokes.single;
      final snapshot = List<Offset>.of(committed.points);
      controller.onPanStart(const Offset(30, 30));
      controller.onPanUpdate(const Offset(60, 60));
      expect(committed.points, snapshot);
    },
  );

  test('distance threshold and tap conversion remain unchanged', () {
    controller.onPanStart(const Offset(10, 10));
    controller.onPanUpdate(const Offset(10.5, 10));
    expect(controller.currentStroke.value!.points.length, 1);
    controller.onPanEnd();
    expect(controller.currentStroke.value, isNull);
    expect(controller.activeLayer.strokes.single.isDot, isTrue);
    expect(controller.activeLayer.strokes.single.points, [
      const Offset(10, 10),
    ]);
  });

  test('straight lines and legacy shapes retain two endpoint behavior', () {
    for (final tool in [
      DrawingTool.straightLine,
      DrawingTool.shape,
      DrawingTool.symbol,
    ]) {
      controller.setTool(tool);
      controller.activeShape.value = 'bintang';
      controller.onPanStart(const Offset(10, 10));
      controller.onPanUpdate(const Offset(30, 30));
      controller.onPanUpdate(const Offset(70, 60));
      expect(controller.currentStroke.value!.points, [
        const Offset(10, 10),
        const Offset(70, 60),
      ]);
      controller.onPanEnd();
      expect(controller.activeLayer.strokes.last.tool, tool);
    }
  });

  test('undo and redo stay local to a layer and new input clears redo', () {
    controller.onTap(const Offset(20, 20));
    final first = controller.activeLayer.strokes.single;
    controller.layers.add(DrawingLayer(id: 'other'));
    controller.activeLayerIndex.value = 1;
    controller.onTap(const Offset(30, 30));
    controller.undo();
    expect(controller.activeLayer.strokes, isEmpty);
    expect(controller.layers.first.strokes.single, same(first));
    controller.redo();
    expect(controller.activeLayer.strokes.length, 1);
    controller.undo();
    controller.onTap(const Offset(40, 40));
    expect(controller.activeLayer.undoStack, isEmpty);
  });

  test('pause and time-up guards still block drawing', () {
    controller.isPaused.value = true;
    controller.onPanStart(const Offset(10, 10));
    controller.onTap(const Offset(10, 10));
    expect(controller.currentStroke.value, isNull);
    expect(controller.activeLayer.strokes, isEmpty);
    controller.isPaused.value = false;
    controller.isTimeUp.value = true;
    controller.onPanStart(const Offset(10, 10));
    controller.onTap(const Offset(10, 10));
    expect(controller.currentStroke.value, isNull);
    expect(controller.activeLayer.strokes, isEmpty);
  });

  testWidgets('live points and translation reuse the canvas painter delegate',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: buildDrawingCanvasForTesting(controller))));
    await tester.pump();
    final paints = find.byType(CustomPaint);
    final original = tester.widget<CustomPaint>(paints.first).painter;
    controller.onPanStart(const Offset(10, 10));
    for (var i = 1; i <= 1000; i++) {
      controller.onPanUpdate(Offset(10 + i * 3, 20));
    }
    await tester.pump();
    expect(tester.widget<CustomPaint>(paints.first).painter, same(original));
    controller.canvasMatrix.value = controller.canvasMatrix.value.clone()
      ..translateByDouble(20.0, 30.0, 0.0, 1.0);
    await tester.pump();
    expect(tester.widget<CustomPaint>(paints.first).painter, same(original));
    await tester.pumpWidget(const SizedBox.shrink());
    controller.onClose();
    closed = true;
    await tester.pump();
  });

  testWidgets(
      'upper stroke layers do not block stamp selection, drag or resize',
      (tester) async {
    final stamp = StempelModel(
        id: 'lower-stamp',
        shape: StempelShape.persegi,
        initialPosition: const Offset(70, 70),
        initialColor: Colors.blue,
        initialStrokeWidth: 4);
    controller.layers.first.stempels.add(stamp);
    controller.layers.add(DrawingLayer(id: 'upper'));
    controller.activeLayerIndex.value = 1;
    controller.setTool(DrawingTool.cursor);
    try {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: buildDrawingCanvasForTesting(controller))));
      await tester.pump();
      final box =
          controller.canvasKey.currentContext!.findRenderObject() as RenderBox;
      final center =
          box.localToGlobal(stamp.position.value + const Offset(32, 32));
      await tester.tapAt(center);
      await tester.pump();
      expect(controller.activeStempelId.value, stamp.id);
      expect(controller.activeLayerIndex.value, 0);
      final before = stamp.position.value;
      await tester.dragFrom(center, const Offset(20, 15));
      await tester.pump();
      expect((stamp.position.value - before - const Offset(20, 15)).distance,
          lessThan(0.01));
      final scaleX = stamp.scaleX.value;
      final scaleY = stamp.scaleY.value;
      await tester.drag(find.byKey(const ValueKey('stempel_corner_br')),
          const Offset(12, 12));
      await tester.pump();
      expect(stamp.scaleX.value, greaterThan(scaleX));
      expect(stamp.scaleY.value, greaterThan(scaleY));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.onClose();
      closed = true;
      await tester.pump();
    }
  });

  testWidgets(
      'PNG capture includes a just-committed stroke before its bake finishes',
      (tester) async {
    try {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: buildDrawingCanvasForTesting(controller))));
      await tester.pump();
      controller.setColor(Colors.blue);
      controller.setThickness(40);
      controller.onTap(const Offset(100, 100));
      await tester.runAsync(() async {
        final capture = controller.captureCanvas();
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
        final png = await capture;
        expect(png, isNotNull);
        expect(png!.length, greaterThan(100));
        final codec = await ui.instantiateImageCodec(png);
        final frame = await codec.getNextFrame();
        try {
          final data =
              await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
          final offset = (200 * frame.image.width + 200) * 4;
          expect(data!.getUint8(offset), 33);
          expect(data.getUint8(offset + 1), 150);
          expect(data.getUint8(offset + 2), 243);
          expect(data.getUint8(offset + 3), 255);
          expect(controller.isCapturing.value, isFalse);
        } finally {
          frame.image.dispose();
          codec.dispose();
        }
      });
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.onClose();
      closed = true;
      await tester.pump();
    }
  });
}
