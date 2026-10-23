import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'models/drawing_models.dart';

String _encodeSnapshot(List<Map<String, dynamic>> layers) => jsonEncode(layers);

/// Reuse immutable completed-stroke snapshots and keep background saves ordered.
/// Cache keys are weak: removed strokes are not kept alive by draft encoding.
class DrawingDraftStore {
  final _strokeSnapshots = Expando<Map<String, dynamic>>();
  Future<void> _saveChain = Future<void>.value();

  Future<String> encode(Iterable<DrawingLayer> layers) {
    final snapshot = layers
        .map((layer) => layer.toJson(encodeStroke: (stroke) {
              return _strokeSnapshots[stroke] ??= stroke.toJson();
            }))
        .toList();
    return compute(_encodeSnapshot, snapshot);
  }

  Future<void> enqueue(Future<void> Function() save) {
    final next = _saveChain.then((_) => save());
    _saveChain =
        next.then<void>((_) {}, onError: (Object error, StackTrace stack) {
      debugPrint('Drawing draft: $error\n$stack');
    });
    return next;
  }
}
