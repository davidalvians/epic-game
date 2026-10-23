import 'dart:async';
import 'dart:convert';

import 'package:epic_app/features/games/menggambar/drawing_draft_store.dart';
import 'package:epic_app/features/games/menggambar/models/drawing_models.dart';
import 'package:epic_app/features/games/menggambar/models/stempel_model.dart';
import 'package:epic_app/features/games/menggambar/stempel_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('background encoding preserves JSON and snapshots before later edits',
      () async {
    final store = DrawingDraftStore();
    final layer = DrawingLayer(id: 'draft');
    final stroke = DrawingStroke(
        tool: DrawingTool.pencil,
        points: [const Offset(10, 20), const Offset(30, 40)],
        color: Colors.blue,
        thickness: 10);
    layer.strokes.add(stroke);
    final stamp = StempelModel(
        id: 'stamp',
        shape: StempelShape.bintang,
        initialPosition: const Offset(20, 30),
        initialColor: Colors.red,
        initialStrokeWidth: 4);
    layer.stempels.add(stamp);
    final expected = jsonEncode([layer.toJson()]);
    final encoding = store.encode([layer]);
    layer.strokes.clear();
    stamp.position.value = const Offset(80, 90);
    expect(await encoding, expected);
    expect(await store.encode([layer]), jsonEncode([layer.toJson()]));
    layer.strokes.add(stroke); // Redo reuses the immutable stroke snapshot.
    expect(await store.encode([layer]), jsonEncode([layer.toJson()]));
  });

  test('a newer save cannot overtake older background work', () async {
    final store = DrawingDraftStore();
    final gate = Completer<void>();
    final events = <String>[];
    final first = store.enqueue(() async {
      events.add('first-start');
      await gate.future;
      events.add('first-end');
    });
    final second = store.enqueue(() async => events.add('second'));
    await Future<void>.delayed(Duration.zero);
    expect(events, ['first-start']);
    gate.complete();
    await Future.wait([first, second]);
    expect(events, ['first-start', 'first-end', 'second']);
  });

  test('a failed save does not block future exit or autosave requests',
      () async {
    final store = DrawingDraftStore();
    var saved = false;
    await expectLater(store.enqueue(() async {
      throw StateError('simulated disk failure');
    }), throwsStateError);
    await store.enqueue(() async {
      saved = true;
    });
    expect(saved, isTrue);
  });
}
