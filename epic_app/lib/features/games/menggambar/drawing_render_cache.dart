import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import 'models/drawing_models.dart';
import 'widgets/stroke_renderer.dart';

/// Disposable acceleration; editable vector strokes remain authoritative.
class DrawingRenderCache extends ChangeNotifier {
  DrawingRenderCache() : _rasterize = _rasterizePicture;
  @visibleForTesting
  DrawingRenderCache.withRasterizer(this._rasterize);
  static int _jobsSinceFence = 0;
  static Future<ui.Image> _rasterizePicture(ui.Picture p, int w, int h) async {
    final image = await p.toImage(w, h);
    // Native texture creation can finish before queued GPU work. Bound that
    // queue without paying for a synchronous readback on every small tile.
    if (++_jobsSinceFence < 2) return image;
    _jobsSinceFence = 0;
    final recorder = ui.PictureRecorder();
    ui.Picture? picture;
    ui.Image? probe;
    try {
      ui.Canvas(recorder).drawImage(image, ui.Offset.zero, ui.Paint());
      picture = recorder.endRecording();
      probe = await picture.toImage(1, 1);
      await probe.toByteData(format: ui.ImageByteFormat.rawRgba);
      return image;
    } catch (_) {
      image.dispose();
      rethrow;
    } finally {
      if (recorder.isRecording) recorder.endRecording().dispose();
      picture?.dispose();
      probe?.dispose();
    }
  }

  final Future<ui.Image> Function(ui.Picture, int, int) _rasterize;
  static const maxImageBytes = 32 * 1024 * 1024;
  static const maxTotalBytes = 160 * 1024 * 1024;
  static const maxBatchStrokes = 16;
  static const maxImmediateStrokes = 16;
  static const maxImageSide = 4096;

  final _entries = <DrawingLayer, DrawingLayerCache>{};
  final _queue = <DrawingLayerCache>{};
  final _deferred = <DrawingLayerCache>{};
  final _retired = <ui.Image>{};
  int _retiredBytes = 0;
  int _reservedBytes = 0;
  Timer? _timer;
  bool _running = false;
  bool _gestureActive = false;
  bool _drawingActive = false;
  bool get _workPaused => _gestureActive || (_drawingActive && !_export);
  bool _disposed = false;
  ui.Size _size = ui.Size.zero;
  double _pixelRatio = 1;
  double _zoom = 1;
  ui.Rect? _viewport;
  bool _export = false;
  int _historySkips = 0;
  ui.Rect? get viewport => _viewport;
  Duration get _backgroundWorkGap {
    final views = ui.PlatformDispatcher.instance.views;
    final displayRate = views.isEmpty ? 60.0 : views.first.display.refreshRate;
    final refreshRate =
        displayRate.isFinite && displayRate > 0 ? displayRate : 60.0;
    // Leave three display intervals for interactive frames between native
    // raster jobs. Preparation is asynchronous and the complete preview stays
    // visible, so background cache throughput must not crowd out drawing.
    final microseconds =
        (3000000 / refreshRate).round().clamp(25000, 60000).toInt();
    return Duration(microseconds: microseconds);
  }

  @visibleForTesting
  int get skippedTileStrokeJobs => _historySkips;
  bool _sceneEnabled = false;
  List<DrawingLayer> _layerOrder = [];
  ui.Image? _scene;
  _RasterSpec? _sceneSpec;
  List<(DrawingLayer, int, int, bool)> _sceneContent = [];
  List<ui.Image?> _sceneFronts = [];

  void enableScene() {
    _sceneEnabled = true;
    for (final entry in _entries.values) {
      _enqueue(entry);
    }
  }

  List<DrawingLayer> get _ordered =>
      _layerOrder.isEmpty ? _entries.keys.toList() : _layerOrder;
  List<(DrawingLayer, int, int, bool)> get _content => [
        for (final layer in _ordered)
          (
            layer,
            forLayer(layer)._revision,
            forLayer(layer)._strokes.length,
            layer.isVisible.value
          )
      ];

  bool paintScene(ui.Canvas canvas) {
    final spec = _sceneSpec;
    if (_scene == null ||
        spec == null ||
        spec.size != _size ||
        _export ||
        !listEquals(_sceneContent, _content) ||
        _ordered.any((l) => l.stempels.isNotEmpty)) {
      return false;
    }
    final visible = (_viewport ?? (ui.Offset.zero & _size))
        .intersect(ui.Offset.zero & _size);
    if (!DrawingLayerCache._covers(spec.region, visible)) return false;
    canvas.save();
    canvas.clipRect(spec.region);
    canvas.translate(spec.region.left, spec.region.top);
    canvas.scale(1 / spec.scale);
    canvas.drawImage(_scene!, ui.Offset.zero,
        ui.Paint()..filterQuality = ui.FilterQuality.medium);
    canvas.restore();
    return true;
  }

  /// Paint a normal source-over live stroke over the cached layer stack.
  /// Callers must ensure the active layer is the top visible layer; erasers
  /// and multiply brushes stay on the isolated per-layer compositing path.
  bool paintSceneWithLiveStroke(
    ui.Canvas canvas,
    DrawingStroke stroke, {
    double zoomScale = 1,
  }) {
    if (!supportsLiveOverlay(stroke) || !paintScene(canvas)) {
      return false;
    }
    paintDrawingStroke(canvas, stroke,
        zoomScale: zoomScale,
        isLive: true,
        rasterClip: zoomScale > 1 ? _viewport : null);
    return true;
  }

  /// A source-over stroke can be painted in its own topmost canvas without
  /// changing the cached scene underneath it. Layer-local clear and blend
  /// operations still need the original isolated renderer.
  static bool supportsLiveOverlay(DrawingStroke stroke) =>
      (stroke.tool == DrawingTool.pencil ||
          stroke.tool == DrawingTool.straightLine ||
          stroke.tool == DrawingTool.shape ||
          stroke.tool == DrawingTool.symbol) &&
      stroke.pencilType.blendMode == ui.BlendMode.srcOver;

  Future<void> _composeScene() async {
    final layers = _ordered;
    if (!_sceneEnabled ||
        _export ||
        _workPaused ||
        layers.length < 2 ||
        layers.any((l) => l.stempels.isNotEmpty || !forLayer(l).isReady)) {
      return;
    }
    final fronts = [for (final l in layers) forLayer(l)._front?.image];
    final content = _content;
    if (listEquals(fronts, _sceneFronts) &&
        listEquals(content, _sceneContent)) {
      return;
    }
    final visible =
        layers.where((l) => l.isVisible.value && l.strokes.isNotEmpty).toList();
    if (visible.isEmpty) return;
    final first = forLayer(visible.first)._front!;
    var region = first.spec.region;
    for (final l in visible.skip(1)) {
      region = region.intersect(forLayer(l)._front!.spec.region);
    }
    final spec = _RasterSpec(_size, region, first.spec.scale, first.spec.zoom);
    if (region.isEmpty ||
        spec.bytes > maxImageBytes ||
        spec.width > maxImageSide ||
        spec.height > maxImageSide) {
      return;
    }
    if (allocatedBytes + spec.bytes > maxTotalBytes) {
      for (final entry in _entries.values) {
        final old = entry._images;
        entry._previous = null;
        entry._basePrevious = null;
        entry._retireUnused(old);
      }
      if (_retired.isNotEmpty) _afterRetirement(forLayer(visible.first));
      return;
    }
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..scale(spec.scale)
      ..translate(-region.left, -region.top)
      ..clipRect(region);
    for (final layer in visible) {
      forLayer(layer).paint(canvas, _size, zoomScale: _zoom);
    }
    final picture = recorder.endRecording();
    ui.Image? image;
    _reservedBytes = spec.bytes;
    try {
      image = await _rasterize(picture, spec.width, spec.height);
      if (_disposed ||
          !listEquals(content, _content) ||
          !listEquals(
              fronts, [for (final l in layers) forLayer(l)._front?.image])) {
        return;
      }
      final old = _scene;
      _scene = image;
      image = null;
      _sceneSpec = spec;
      _sceneContent = content;
      _sceneFronts = fronts;
      if (old != null) _retire(old);
      notifyListeners();
    } finally {
      _reservedBytes = 0;
      image?.dispose();
      picture.dispose();
    }
  }

  DrawingLayerCache forLayer(DrawingLayer layer) =>
      _entries.putIfAbsent(layer, () => DrawingLayerCache._(this, layer));

  void retainLayers(Iterable<DrawingLayer> layers) {
    _layerOrder = List.of(layers);
    final retained = layers.toSet();
    if (_sceneContent.any((s) => !retained.contains(s.$1)) ||
        _layerOrder.length < 2 ||
        _layerOrder.any((l) => l.stempels.isNotEmpty)) {
      final scene = _scene;
      _scene = null;
      _sceneSpec = null;
      _sceneContent = [];
      _sceneFronts = [];
      if (scene != null) _retire(scene);
    }
    for (final layer in _entries.keys.toList()) {
      if (!retained.contains(layer)) {
        final entry = _entries.remove(layer)!;
        _queue.remove(entry);
        entry.dispose();
      }
    }
    for (final layer in retained) {
      forLayer(layer);
    }
  }

  /// [viewport] is the visible screen rectangle transformed into paper space.
  /// Export uses full-paper [pixelRatio], independently of the current zoom.
  void configure(ui.Size size, double pixelRatio, double zoom,
      {ui.Rect? viewport, bool fullResolutionExport = false}) {
    if (_disposed ||
        !size.isFinite ||
        size.isEmpty ||
        !pixelRatio.isFinite ||
        pixelRatio <= 0 ||
        !zoom.isFinite ||
        zoom <= 0) {
      return;
    }
    if (_size == size &&
        _pixelRatio == pixelRatio &&
        (_zoom - zoom).abs() < 1e-9 &&
        _viewport == viewport &&
        _export == fullResolutionExport) {
      return;
    }
    _size = size;
    _pixelRatio = pixelRatio;
    _zoom = zoom;
    _viewport = viewport;
    _export = fullResolutionExport;
    for (final entry in _entries.values) {
      entry._configurationChanged();
      _queue.add(entry);
    }
    _timer?.cancel();
    _timer =
        _workPaused ? null : Timer(const Duration(milliseconds: 180), _drain);
  }

  void setGestureActive(bool active) {
    if (_disposed || _gestureActive == active) return;
    _gestureActive = active;
    _interactionChanged();
  }

  void setDrawingActive(bool active) {
    if (_disposed || _drawingActive == active) return;
    _drawingActive = active;
    _interactionChanged();
  }

  void _interactionChanged() {
    _timer?.cancel();
    _timer = null;
    if (!_workPaused && _queue.isNotEmpty) {
      _timer = Timer(_backgroundWorkGap, _drain);
    }
  }

  int get allocatedBytes =>
      _reservedBytes +
      (_scene == null ? 0 : _scene!.width * _scene!.height * 4) +
      _retiredBytes +
      _entries.values.fold<int>(0, (sum, entry) => sum + entry._imageBytes);

  @visibleForTesting
  Map<String, Object> get debugProgress => {
        'skippedTileStrokeJobs': _historySkips,
        'running': _running,
        'queued': _queue.length,
        'deferred': _deferred.length,
        'layers': _entries.values
            .map((e) => {
                  'source': e._strokes.length,
                  'building': e._build?.current?.count ?? 0,
                  'front': e.bakedCount,
                  'failed': e._failed,
                  'ready': e.isReady,
                })
            .toList(),
      };

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    while (!_disposed &&
        !_workPaused &&
        (_running || _queue.isNotEmpty || _deferred.isNotEmpty)) {
      if (_running) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      } else if (_queue.isEmpty && _deferred.isNotEmpty) {
        await SchedulerBinding.instance.endOfFrame;
      } else {
        await _drain();
        _timer?.cancel();
        _timer = null;
      }
    }
  }

  void _enqueue(DrawingLayerCache entry) {
    if (_disposed || entry._disposed) return;
    _queue.add(entry);
    if (!_workPaused && !_running) {
      _timer ??= Timer(_backgroundWorkGap, _drain);
    }
  }

  void _afterRetirement(DrawingLayerCache entry) {
    if (_disposed || !_deferred.add(entry)) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _deferred.remove(entry);
      _enqueue(entry);
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  Future<void> _drain() async {
    _timer = null;
    if (_disposed || _workPaused || _running || _queue.isEmpty) return;
    _running = true;
    // Finish one detail tile set before allocating another layer's tile set.
    final entry = _queue.firstWhere((e) => e._needsOverview,
        orElse: () => _queue.firstWhere((e) => e._build?.tiles != null,
            orElse: () => _queue.first));
    _queue.remove(entry);
    try {
      await entry._bake();
      if (_queue.isEmpty) await _composeScene();
    } catch (error, stack) {
      entry._failed = true;
      entry._cancelBuild();
      if (!entry._disposed) entry._changed();
      debugPrint('Drawing cache: $error\n$stack');
    } finally {
      _running = false;
      if (!_disposed && !_workPaused && _queue.isNotEmpty) {
        _timer ??= Timer(_backgroundWorkGap, _drain);
      }
    }
  }

  void _retire(ui.Image image) {
    if (_disposed) {
      image.dispose();
      return;
    }
    if (!_retired.add(image)) return;
    _retiredBytes += image.width * image.height * 4;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_retired.remove(image)) {
        _retiredBytes -= image.width * image.height * 4;
        image.dispose();
        // A scheduled but unchanged scene can skip rasterization. Repaint
        // existing coverage so native texture cleanup also advances while
        // the user holds still and only offscreen preparation is running.
        if (!_disposed && _entries.isNotEmpty) {
          _entries.values.first._changed();
        }
      }
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  void releaseImages() {
    if (_disposed) return;
    final scene = _scene;
    _scene = null;
    _sceneFronts = [];
    _sceneContent = [];
    if (scene != null) _retire(scene);
    notifyListeners();
    // Keep visible coverage; memory pressure must not flash the paper blank.
    for (final entry in _entries.values) {
      final old = entry._images;
      entry._previous = null;
      entry._basePrevious = null;
      // Native caches are purged by the engine too. Discarding our bounded
      // prefix here restarts a large restore and can cause repeated pressure.
      entry._build?.previous = null;
      if (entry._overview != null) entry._front = entry._overview;
      entry._retireUnused(old);
      entry._changed();
      _enqueue(entry);
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _queue.clear();
    _deferred.clear();
    for (final entry in _entries.values) {
      entry.dispose();
    }
    _entries.clear();
    _scene?.dispose();
    _scene = null;
    _sceneContent = [];
    _sceneFronts = [];
    _layerOrder = [];
    for (final image in _retired) {
      image.dispose();
    }
    _retired.clear();
    _retiredBytes = 0;
    super.dispose();
  }
}

class _RasterSpec {
  const _RasterSpec(this.size, this.region, this.scale, this.zoom);
  final ui.Size size;
  final ui.Rect region;
  final double scale;
  final double zoom;
  int get width => (region.width * scale).ceil();
  int get height => (region.height * scale).ceil();
  int get bytes => width * height * 4;
  bool matches(_RasterSpec other) =>
      size == other.size &&
      region == other.region &&
      (scale - other.scale).abs() < 1e-4 &&
      (zoom - other.zoom).abs() < 1e-4;
}

class _RasterFrame {
  const _RasterFrame(this.image, this.spec, this.count, this.revision);
  final ui.Image image;
  final _RasterSpec spec;
  final int count;
  final int revision;
}

class _RasterBuild {
  _RasterBuild(
      this.spec, this.strokes, this.isOverview, this.revision, this.current);
  final _RasterSpec spec;
  final List<DrawingStroke> strokes;
  final bool isOverview;
  final int revision;
  _RasterFrame? current;
  _RasterFrame? previous;
  List<_RasterTile>? tiles;
  bool initialCoverage = false;
}

class _RasterTile {
  _RasterTile(this.core, this.area, this.count);
  final ui.Rect core;
  final ui.Rect area;
  int count;
  ui.Image? image;
  bool initialized = false;
  bool discardBase = false;
}

class DrawingLayerCache extends ChangeNotifier {
  DrawingLayerCache._(this._owner, DrawingLayer layer) {
    _strokes = List.of(layer.strokes);
    _worker = ever(layer.strokes, (_) => _sync(layer.strokes));
    _owner._enqueue(this);
  }
  final DrawingRenderCache _owner;
  late final Worker _worker;
  late List<DrawingStroke> _strokes;
  _RasterFrame? _front;
  _RasterFrame? _overview;
  _RasterFrame? _previous;
  _RasterFrame? _basePrevious;
  _RasterBuild? _build;
  int _revision = 0;
  bool _failed = false;
  bool _disposed = false;

  bool get _needsOverview =>
      !_owner._export &&
      _owner._viewport != null &&
      (_overview?.revision != _revision ||
          _overview?.count != _strokes.length ||
          !(_overview?.spec.matches(_overviewSpec()) ?? false));

  void _changed() => notifyListeners();
  ui.Image? get image => (_front ?? _overview)?.image;
  double get scale => (_front ?? _overview)?.spec.scale ?? 1;
  int get bakedCount => (_front ?? _overview)?.count ?? 0;
  bool get isReady =>
      _strokes.isEmpty ||
      (_front != null &&
          _front!.revision == _revision &&
          _front!.count == _strokes.length &&
          _front!.spec.matches(_detailSpec()) &&
          (_owner._export ||
              _owner._viewport == null ||
              (_overview?.revision == _revision &&
                  _overview?.count == _strokes.length &&
                  (_overview?.spec.matches(_overviewSpec()) ?? false))));
  @visibleForTesting
  ui.Rect? get cachedRegion => _front?.spec.region;

  Set<ui.Image> get _images => {
        if (_front != null) _front!.image,
        if (_overview != null) _overview!.image,
        if (_previous != null) _previous!.image,
        if (_basePrevious != null) _basePrevious!.image,
        if (_build?.current != null) _build!.current!.image,
        if (_build?.previous != null) _build!.previous!.image,
        if (_build?.tiles != null)
          for (final tile in _build!.tiles!)
            if (tile.image != null) tile.image!,
      };
  int get _imageBytes => _images.fold<int>(
      0, (sum, image) => sum + image.width * image.height * 4);

  void _retireUnused(Set<ui.Image> old) {
    final retained = _images;
    for (final image in old.difference(retained)) {
      _owner._retire(image);
    }
  }

  _RasterSpec _overviewSpec() => _RasterSpec(
      _owner._size, ui.Offset.zero & _owner._size, _owner._pixelRatio, 1);

  _RasterSpec _detailSpec() {
    final paper = ui.Offset.zero & _owner._size;
    if (_owner._export || _owner._viewport == null || _owner._zoom <= 1) {
      return _RasterSpec(_owner._size, paper, _owner._pixelRatio, _owner._zoom);
    }
    final scale = _owner._pixelRatio * _owner._zoom;
    final visible = _owner._viewport!.intersect(paper);
    if (visible.isEmpty) return _overviewSpec();
    final front = _front;
    if (front != null &&
        front.spec.size == _owner._size &&
        (front.spec.scale - scale).abs() < 1e-4 &&
        (front.spec.zoom - _owner._zoom).abs() < 1e-4 &&
        _covers(front.spec.region, visible)) {
      return front.spec;
    }
    final step = 64 / scale;
    // Overscan keeps panning smooth and keeps blur clipping outside the screen.
    final padded = visible.inflate(192 / scale);
    final region = ui.Rect.fromLTRB(
      (padded.left / step).floor() * step,
      (padded.top / step).floor() * step,
      (padded.right / step).ceil() * step,
      (padded.bottom / step).ceil() * step,
    ).intersect(paper);
    return _RasterSpec(_owner._size, region, scale, _owner._zoom);
  }

  static bool _covers(ui.Rect outer, ui.Rect inner) =>
      outer.left <= inner.left &&
      outer.top <= inner.top &&
      outer.right >= inner.right &&
      outer.bottom >= inner.bottom;

  void _configurationChanged() {
    final build = _build;
    if (build != null &&
        !build.spec
            .matches(build.isOverview ? _overviewSpec() : _detailSpec())) {
      _cancelBuild();
    }
    // Never invalidate or notify the displayed image on each transform event.
  }

  void _cancelBuild() {
    final old = _images;
    _build = null;
    _retireUnused(old);
  }

  void _sync(List<DrawingStroke> strokes) {
    if (_disposed) return;
    var common = 0;
    while (common < strokes.length &&
        common < _strokes.length &&
        identical(strokes[common], _strokes[common])) {
      common++;
    }
    final append = common == _strokes.length;
    _strokes = List.of(strokes);
    _failed = false;
    if (!append) {
      final old = _images;
      final basePrefix =
          _basePrevious?.revision == _revision && _basePrevious!.count <= common
              ? _basePrevious
              : null;
      _revision++;
      _build = null;
      if (_strokes.isEmpty) {
        _front = null;
        _overview = null;
        _previous = null;
        _basePrevious = null;
      } else if (_previous != null && _previous!.count <= common) {
        _front = _RasterFrame(
            _previous!.image, _previous!.spec, _previous!.count, _revision);
        if (_front!.spec.region == (ui.Offset.zero & _owner._size)) {
          _overview = _front;
        } else if (basePrefix != null) {
          _overview = _RasterFrame(
              basePrefix.image, basePrefix.spec, basePrefix.count, _revision);
        }
        _previous = null;
        _basePrevious = null;
      } else if (basePrefix != null) {
        _front = _overview = _RasterFrame(
            basePrefix.image, basePrefix.spec, basePrefix.count, _revision);
        _previous = null;
        _basePrevious = null;
      } else {
        // Keep complete old coverage until replacement is ready, but mark it
        // invalid as a raster source: same-length edits must rebuild correctly.
        _previous = null;
        _basePrevious = null;
      }
      _retireUnused(old);
    }
    notifyListeners();
    _owner._enqueue(this);
  }

  void _paintFrame(ui.Canvas canvas, _RasterFrame frame, double zoom,
      {bool replace = false}) {
    final region = frame.spec.region;
    canvas.save();
    canvas.clipRect(region);
    if (replace) {
      canvas.drawRect(region, ui.Paint()..blendMode = ui.BlendMode.clear);
    }
    canvas.save();
    canvas.translate(region.left, region.top);
    canvas.scale(1 / frame.spec.scale);
    canvas.drawImage(frame.image, ui.Offset.zero,
        ui.Paint()..filterQuality = ui.FilterQuality.medium);
    canvas.restore();
    final pending = _strokes.length - frame.count;
    if (frame.revision == _revision &&
        pending > 0 &&
        pending <= DrawingRenderCache.maxImmediateStrokes) {
      for (var i = frame.count; i < _strokes.length; i++) {
        paintDrawingStroke(canvas, _strokes[i],
            zoomScale: zoom,
            rasterClip: _owner._zoom > 1 ? _owner._viewport : null);
      }
    }
    canvas.restore();
  }

  void paint(
    ui.Canvas canvas,
    ui.Size size, {
    DrawingStroke? liveStroke,
    bool lowCostLivePreview = false,
    double zoomScale = 1,
    bool useRaster = true,
  }) {
    if (_strokes.isEmpty && liveStroke == null) return;
    final front = useRaster && _front?.spec.size == size ? _front : null;
    final overview =
        useRaster && _overview?.spec.size == size ? _overview : null;
    final visible = (_owner._export ? null : _owner._viewport)
            ?.intersect(ui.Offset.zero & size) ??
        (ui.Offset.zero & size);
    if (front != null &&
        (front.count == _strokes.length ||
            (front.revision == _revision &&
                front.count < _strokes.length &&
                _strokes.length - front.count <=
                    DrawingRenderCache.maxImmediateStrokes)) &&
        _covers(front.spec.region, visible)) {
      bool needsIsolation(DrawingStroke stroke) =>
          stroke.tool == DrawingTool.eraser ||
          stroke.pencilType.blendMode != ui.BlendMode.srcOver;
      // SrcOver is associative: replaying it directly over the cached layer
      // preserves its pixels without a full viewport offscreen pass. Clear
      // and multiply still need their original layer-local destination.
      final isolate = (liveStroke != null && needsIsolation(liveStroke)) ||
          _strokes.skip(front.count).any(needsIsolation);
      if (isolate) {
        canvas.save();
        canvas.clipRect(visible);
        canvas.saveLayer(visible, ui.Paint());
      }
      _paintFrame(canvas, front, zoomScale);
      if (liveStroke != null) {
        paintDrawingStroke(canvas, liveStroke,
            zoomScale: zoomScale,
            isLive: true,
            lowCostLivePreview: lowCostLivePreview,
            rasterClip: visible);
      }
      if (isolate) {
        canvas.restore();
        canvas.restore();
      }
      return;
    }
    if (front != null &&
        front.count == _strokes.length &&
        liveStroke == null &&
        overview != null &&
        overview.count == _strokes.length) {
      // Finished images already contain layer-local clear/multiply. Paint
      // disjoint coverage directly, without a full-screen layer/clear pass.
      canvas.save();
      canvas.clipRect(visible);
      canvas.save();
      canvas.clipRect(front.spec.region, clipOp: ui.ClipOp.difference);
      _paintFrame(canvas, overview, zoomScale);
      canvas.restore();
      _paintFrame(canvas, front, zoomScale);
      canvas.restore();
      return;
    }
    canvas.save();
    if (useRaster && !_owner._export && _owner._viewport != null) {
      canvas.clipRect(_owner._viewport!.intersect(ui.Offset.zero & size));
    }
    canvas.saveLayer(ui.Offset.zero & size, ui.Paint());
    if (overview != null && !identical(overview, front)) {
      _paintFrame(canvas, overview, zoomScale);
    }
    if (front != null) {
      _paintFrame(canvas, front, zoomScale,
          replace: overview != null && !identical(overview, front));
    } else if (overview == null &&
        (!useRaster ||
            _strokes.length <= DrawingRenderCache.maxImmediateStrokes ||
            (_failed && _strokes.length <= 64))) {
      for (final stroke in _strokes) {
        paintDrawingStroke(canvas, stroke, zoomScale: zoomScale);
      }
    }
    if (liveStroke != null) {
      paintDrawingStroke(canvas, liveStroke,
          zoomScale: zoomScale,
          isLive: true,
          lowCostLivePreview: lowCostLivePreview,
          rasterClip: _owner._zoom > 1 ? _owner._viewport : null);
    }
    canvas.restore();
    canvas.restore();
  }

  Future<void> _bakeTiles(_RasterBuild build) async {
    final spec = build.spec;
    if (build.tiles == null) {
      final tiles = <_RasterTile>[];
      // Wide blur gutters are expensive relative to small cores below 5x.
      // Cores cut repeated history rasterization while remaining well
      // below the per-image limit with the maximum watercolor scratch gutter.
      final edge = spec.zoom < 5 ? 384 : 512;
      // Native mask filters need real offscreen pixels around each core.
      // Clipping their render target at the core truncates blur at tile seams.
      var gutter = 2.0;
      if (spec.zoom < 5) {
        for (final stroke in build.strokes) {
          if (stroke.tool == DrawingTool.eraser) continue;
          final sigma = stroke.pencilType == PencilType.watercolor
              ? (stroke.thickness * .4 / spec.zoom.clamp(.1, 10.0))
                  .clamp(.05, 8.0)
              : stroke.pencilType == PencilType.pencil
                  ? (1 / spec.zoom.clamp(.1, 10.0)).clamp(.05, 2.0)
                  : 0.0;
          final padding = (4 * sigma * spec.scale + 2).ceilToDouble();
          if (padding > gutter) gutter = padding;
        }
      }
      final bounds =
          ui.Rect.fromLTWH(0, 0, spec.width.toDouble(), spec.height.toDouble());
      for (var y = 0; y < spec.height; y += edge) {
        for (var x = 0; x < spec.width; x += edge) {
          final core = ui.Rect.fromLTWH(
                  x.toDouble(), y.toDouble(), edge.toDouble(), edge.toDouble())
              .intersect(bounds);
          tiles.add(_RasterTile(core, core.inflate(gutter).intersect(bounds),
              build.current?.count ?? 0));
        }
      }
      build.tiles = tiles;
    }
    // Keep the penultimate complete image as the immediate undo checkpoint.
    final target = (build.current?.count ?? 0) < build.strokes.length - 1
        ? build.strokes.length - 1
        : build.strokes.length;
    final pending = build.tiles!.where((t) => t.count < target);
    final tile = pending.isEmpty ? null : pending.first;
    if (tile != null && !tile.initialized) {
      if (target - tile.count > 32) {
        final region = ui.Rect.fromLTRB(
                spec.region.left + tile.core.left / spec.scale,
                spec.region.top + tile.core.top / spec.scale,
                spec.region.left + tile.core.right / spec.scale,
                spec.region.top + tile.core.bottom / spec.scale)
            .inflate(2 / spec.scale);
        // Earlier destination pixels are only needed in the retained core.
        // Each later stroke filters its own mask, never the layer backdrop;
        // its scratch gutter must not enlarge this history-coverage proof.
        var candidates = 0;
        final resetStrokes = <DrawingStroke>[];
        var resetStart = tile.count;
        for (var i = target - 1; i >= tile.count; i--) {
          final stroke = build.strokes[i];
          if (stroke.tool != DrawingTool.eraser &&
              !(stroke.tool == DrawingTool.pencil &&
                  stroke.color.a == 1 &&
                  stroke.opacity == 1 &&
                  stroke.pencilType.opacityFactor == 1)) {
            continue;
          }
          resetStrokes.add(stroke);
          resetStart = i;
          final resets = await drawingStrokeOverwritesRegion(stroke, region);
          if (_disposed || !identical(_build, build)) return;
          if (resets) {
            _owner._historySkips += i - tile.count;
            tile.count = i;
            tile.discardBase = true;
            break;
          }
          if (++candidates == 32) break;
        }
        if (!tile.discardBase &&
            resetStrokes.length > 1 &&
            await drawingStrokesOverwriteRegion(
                resetStrokes, region, 2 / spec.scale)) {
          if (_disposed || !identical(_build, build)) return;
          _owner._historySkips += resetStart - tile.count;
          tile.count = resetStart;
          tile.discardBase = true;
        }
      }
      tile.initialized = true;
      if (_disposed || !identical(_build, build)) return;
    }
    final bytes = tile == null
        ? spec.bytes
        : ((tile.area.width * tile.area.height +
                    tile.core.width * tile.core.height) *
                4)
            .round();
    if (_owner.allocatedBytes + bytes > DrawingRenderCache.maxTotalBytes) {
      for (final entry in _owner._entries.values) {
        final old = entry._images;
        entry._previous = null;
        entry._basePrevious = null;
        entry._build?.previous = null;
        entry._retireUnused(old);
      }
      if (_owner._retired.isNotEmpty) {
        _owner._afterRetirement(this);
      } else {
        _failed = true;
      }
      return;
    }
    final recorder = ui.PictureRecorder();
    ui.Picture? picture;
    ui.Image? image;
    _owner._reservedBytes = bytes;
    try {
      final canvas = ui.Canvas(recorder);
      var count = target;
      if (tile != null) {
        if (tile.image != null) {
          canvas.drawImage(
              tile.image!, tile.core.topLeft - tile.area.topLeft, ui.Paint());
        } else if (build.current != null && !tile.discardBase) {
          canvas.drawImage(
              build.current!.image, -tile.area.topLeft, ui.Paint());
        }
        canvas.translate(-tile.area.left, -tile.area.top);
        canvas.scale(spec.scale);
        canvas.translate(-spec.region.left, -spec.region.top);
        final region = ui.Rect.fromLTRB(
            spec.region.left + tile.core.left / spec.scale,
            spec.region.top + tile.core.top / spec.scale,
            spec.region.left + tile.core.right / spec.scale,
            spec.region.top + tile.core.bottom / spec.scale);
        count = tile.count;
        var draws = 0;
        var expensiveBlurs = 0;
        final cpu = Stopwatch()..start();
        for (var i = tile.count; i < target; i++) {
          final stroke = build.strokes[i];
          final hasBlur = spec.zoom < 5 &&
              stroke.tool != DrawingTool.eraser &&
              (stroke.pencilType == PencilType.pencil ||
                  stroke.pencilType == PencilType.watercolor);
          // The renderer expands this output core by the brush's own filter
          // support. The larger image target supplies real scratch pixels;
          // it is not another output region to expand/prove all over again.
          final work = paintDrawingStroke(canvas, stroke,
              zoomScale: spec.zoom, rasterClip: region);
          count = i + 1;
          if (work != DrawingPaintWork.empty) draws++;
          if (hasBlur && work != DrawingPaintWork.empty) expensiveBlurs++;
          if (draws >= 16 ||
              expensiveBlurs >= 1 ||
              cpu.elapsedMicroseconds >= 2000) {
            break;
          }
        }
        if (draws == 0) {
          tile.count = count;
          _owner._reservedBytes = 0;
          _owner._enqueue(this);
          await Future<void>.delayed(Duration.zero);
          return;
        }
      } else {
        for (final part in build.tiles!) {
          canvas.save();
          canvas.clipRect(part.core, doAntiAlias: false);
          if (part.image != null) {
            canvas.drawImage(part.image!, part.core.topLeft, ui.Paint());
          } else if (build.current != null && !part.discardBase) {
            canvas.drawImage(build.current!.image, ui.Offset.zero, ui.Paint());
          }
          canvas.restore();
        }
      }
      picture = recorder.endRecording();
      image = await _owner._rasterize(
          picture,
          tile?.area.width.round() ?? spec.width,
          tile?.area.height.round() ?? spec.height);
      if (_disposed || !identical(_build, build)) return;
      if (tile != null) {
        // Gutters are scratch input for this mask only. Retain disjoint cores
        // between jobs, so overlap cannot multiply persistent texture memory
        // or evict the complete undo checkpoint.
        final cropRecorder = ui.PictureRecorder();
        ui.Canvas(cropRecorder).drawImage(
            image, tile.area.topLeft - tile.core.topLeft, ui.Paint());
        final crop = cropRecorder.endRecording();
        try {
          final core = await _owner._rasterize(
              crop, tile.core.width.round(), tile.core.height.round());
          _owner._retire(image);
          image = core;
        } finally {
          crop.dispose();
        }
        if (_disposed || !identical(_build, build)) return;
      }
      final old = _images;
      final internal = <ui.Image>{
        if (tile?.image != null) tile!.image!,
        if (tile == null &&
            target == build.strokes.length &&
            !_owner._gestureActive)
          for (final part in build.tiles!)
            if (part.image != null) part.image!,
      };
      if (tile != null) {
        tile.image = image;
        tile.count = count;
      } else {
        build.previous = build.current;
        build.current = _RasterFrame(image, spec, target, build.revision);
        if (target == build.strokes.length && !_owner._gestureActive) {
          _previous = build.previous;
          _front = build.current;
          _build = null;
          _failed = false;
          notifyListeners();
        }
      }
      image = null;
      _owner._reservedBytes = 0;
      // Retire even private textures on a frame. Long offscreen-only runs
      // otherwise postpone the renderer's GPU resource cleanup indefinitely.
      for (final texture in internal) {
        _owner._retire(texture);
      }
      _retireUnused(old.difference(internal));
      if (!isReady) _owner._enqueue(this);
    } finally {
      _owner._reservedBytes = 0;
      if (recorder.isRecording) recorder.endRecording().dispose();
      picture?.dispose();
      image?.dispose();
    }
  }

  Future<void> _bake() async {
    if (_disposed ||
        _owner._disposed ||
        _owner._size.isEmpty ||
        _strokes.isEmpty ||
        isReady) {
      return;
    }
    final overviewSpec = _overviewSpec();
    if (_overview == null &&
        _front?.revision == _revision &&
        (_front?.spec.matches(overviewSpec) ?? false)) {
      _overview = _front;
    }
    if (_overview?.revision == _revision &&
        _overview?.count == _strokes.length &&
        (_overview?.spec.matches(_detailSpec()) ?? false)) {
      final old = _images;
      _front = _overview;
      _build = null;
      _retireUnused(old);
      notifyListeners();
      return;
    }
    final needsOverview = !_owner._export &&
        _owner._viewport != null &&
        (_overview?.revision != _revision ||
            _overview?.count != _strokes.length ||
            !(_overview?.spec.matches(overviewSpec) ?? false));
    final spec = needsOverview ? overviewSpec : _detailSpec();
    if (spec.width <= 0 ||
        spec.height <= 0 ||
        spec.width > DrawingRenderCache.maxImageSide ||
        spec.height > DrawingRenderCache.maxImageSide ||
        spec.bytes > DrawingRenderCache.maxImageBytes) {
      // Never replay the complete vector history because an image is too large.
      _failed = true;
      return;
    }
    var build = _build;
    if (build == null || !build.spec.matches(spec)) {
      _cancelBuild();
      final candidate = needsOverview ? _overview : _front;
      final base = candidate != null &&
              candidate.revision == _revision &&
              candidate.spec.matches(spec) &&
              candidate.count <= _strokes.length
          ? candidate
          : null;
      build = _RasterBuild(spec, _strokes, needsOverview, _revision, base);
      build.initialCoverage = needsOverview && _front == null;
      _build = build;
    }
    final tiled = spec.scale > _owner._pixelRatio * 1.1 &&
        (spec.width > 768 || spec.height > 768);
    if (tiled) {
      await _bakeTiles(build);
      return;
    }
    final workingBytes = spec.bytes;
    if (_owner.allocatedBytes + workingBytes >
        DrawingRenderCache.maxTotalBytes) {
      for (final entry in _owner._entries.values) {
        final old = entry._images;
        entry._previous = null;
        entry._basePrevious = null;
        entry._build?.previous = null;
        entry._retireUnused(old);
      }
      if (_owner._retired.isNotEmpty) {
        _owner._afterRetirement(this);
      } else {
        _failed = true;
      }
      return;
    }
    final start = build.current?.count ?? 0;
    final isDetail = spec.scale > _owner._pixelRatio * 1.1;
    var count =
        (start + (isDetail && !tiled ? 4 : DrawingRenderCache.maxBatchStrokes))
            .clamp(0, build.strokes.length);
    if (isDetail && !tiled && spec.zoom < 5) {
      var blurred = false;
      for (var i = start; i < count; i++) {
        final stroke = build.strokes[i];
        final hasBlur = stroke.tool != DrawingTool.eraser &&
            (stroke.pencilType == PencilType.pencil ||
                stroke.pencilType == PencilType.watercolor);
        if (hasBlur && blurred) {
          count = i;
          break;
        }
        blurred |= hasBlur;
      }
    }
    final recorder = ui.PictureRecorder();
    ui.Picture? picture;
    ui.Image? result;
    _owner._reservedBytes = workingBytes;
    final job = build;
    try {
      void draw(ui.Canvas canvas, ui.Rect region) {
        canvas.clipRect(region);
        if (job.current != null) {
          canvas.save();
          canvas.translate(spec.region.left, spec.region.top);
          canvas.scale(1 / spec.scale);
          canvas.drawImage(job.current!.image, ui.Offset.zero, ui.Paint());
          canvas.restore();
        }
        for (var i = start; i < count; i++) {
          paintDrawingStroke(canvas, job.strokes[i],
              zoomScale: spec.zoom,
              rasterClip: !tiled && spec.region == (ui.Offset.zero & spec.size)
                  ? null
                  : region);
        }
      }

      final canvas = ui.Canvas(recorder)
        ..scale(spec.scale)
        ..translate(-spec.region.left, -spec.region.top);
      draw(canvas, spec.region);
      picture = recorder.endRecording();
      result = await _owner._rasterize(picture, spec.width, spec.height);
      if (_disposed || _owner._disposed || !identical(_build, build)) return;
      final old = _images;
      build.previous = build.current;
      build.current = _RasterFrame(result, spec, count, build.revision);
      result = null;
      _owner._reservedBytes = 0;
      if (build.initialCoverage && count < build.strokes.length) {
        // An initial restore has no old complete preview to preserve. Reveal
        // its valid prefixes; subsequent zoom replacements remain atomic.
        _front = _overview = build.current;
        notifyListeners();
      }
      if (count == build.strokes.length &&
          (!_owner._gestureActive || build.isOverview)) {
        _previous = build.previous;
        if (build.isOverview) {
          _basePrevious = build.previous;
          _overview = build.current;
          if (_owner._gestureActive ||
              _front == null ||
              _front!.spec.matches(spec)) {
            _front = _overview;
          }
        } else {
          _front = build.current;
        }
        _build = null;
        _failed = false;
        notifyListeners();
      }
      _retireUnused(old);
      if (!isReady) _owner._enqueue(this);
    } finally {
      _owner._reservedBytes = 0;
      if (recorder.isRecording) recorder.endRecording().dispose();
      picture?.dispose();
      result?.dispose();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _worker.dispose();
    final old = _images;
    _front = null;
    _overview = null;
    _previous = null;
    _basePrevious = null;
    _build = null;
    _retireUnused(old);
    super.dispose();
  }
}
