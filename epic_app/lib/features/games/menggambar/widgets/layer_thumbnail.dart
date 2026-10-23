part of '../drawing_screen.dart';

/// Render the existing thumbnail painter once per content change, including
/// stamps. Keep its original coordinate system and clipping behavior.
class _LayerThumbnail extends StatefulWidget {
  const _LayerThumbnail({required this.layer, required this.logicalWidth});
  final DrawingLayer layer;
  final double logicalWidth;

  @override
  State<_LayerThumbnail> createState() => _LayerThumbnailState();
}

class _LayerThumbnailState extends State<_LayerThumbnail> {
  final _cache = DrawingRenderCache();
  ui.Image? _image;
  List<DrawingStroke> _strokes = [];
  String? _stamps;
  Size? _size;
  double? _ratio;
  bool? _visible;
  int _revision = 0;
  int _imageRevision = -1;

  Future<void> _render(int revision, Size size, double ratio) async {
    if (!mounted || revision != _revision) return;
    _cache.configure(size, ratio, 1);
    final entry = _cache.forLayer(widget.layer);
    await _cache.flush();
    if (!mounted || revision != _revision) return;
    final recorder = ui.PictureRecorder();
    ui.Picture? picture;
    ui.Image? image;
    try {
      final canvas = Canvas(recorder)..scale(ratio);
      _DrawingPainter(
        layers: [widget.layer],
        activeLayerIndex: -1,
        cache: entry,
      ).paint(canvas, size);
      picture = recorder.endRecording();
      image = await picture.toImage(
        (size.width * ratio).ceil(),
        (size.height * ratio).ceil(),
      );
      if (!mounted || revision != _revision) return;
      final old = _image;
      setState(() {
        _image = image;
        _imageRevision = revision;
      });
      image = null;
      if (old != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
    } catch (error) {
      // Leave the original vector thumbnail visible when rasterization fails.
      debugPrint('Drawing thumbnail: $error');
    } finally {
      if (recorder.isRecording) recorder.endRecording().dispose();
      picture?.dispose();
      image?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        final layer = widget.layer;
        final strokes = List<DrawingStroke>.of(layer.strokes);
        final stamps =
            jsonEncode(layer.stempels.map((s) => s.toJson()).toList());
        final visible = layer.isVisible.value;
        final size = Size(widget.logicalWidth, widget.logicalWidth * 1.414);
        final ratio = 32 * MediaQuery.devicePixelRatioOf(context) / size.width;
        if (!listEquals(strokes, _strokes) ||
            stamps != _stamps ||
            visible != _visible ||
            size != _size ||
            ratio != _ratio) {
          _strokes = strokes;
          _stamps = stamps;
          _visible = visible;
          _size = size;
          _ratio = ratio;
          final revision = ++_revision;
          Future<void>.microtask(() => _render(revision, size, ratio));
        }
        return RepaintBoundary(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: _imageRevision == _revision && _image != null
                  ? RawImage(image: _image, fit: BoxFit.fill)
                  : CustomPaint(
                      painter: _DrawingPainter(
                        layers: [layer],
                        activeLayerIndex: -1,
                        cache: _cache.forLayer(layer),
                        repaint: _cache.forLayer(layer),
                        contentRevision: _revision,
                      ),
                    ),
            ),
          ),
        );
      });

  @override
  void dispose() {
    _revision++;
    _cache.dispose();
    _image?.dispose();
    super.dispose();
  }
}
