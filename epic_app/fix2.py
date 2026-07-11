import sys
import re

path = r'c:\Users\ASUS\project-epic-app\epic_app\lib\features\games\menggambar\drawing_controller.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Insert `bool _isDraggingStempel = false;`
if 'bool _isDraggingStempel = false;' not in content:
    content = content.replace('bool _isDrawing = false;', 'bool _isDrawing = false;\n  bool _isDraggingStempel = false;')

# 2. Replace onPointerDown to _updateTransform block
start_str = '  void onPointerDown(PointerDownEvent event) {'
end_str = '  void _loadTimerState() {'

start_idx = content.find(start_str)
end_idx = content.find(end_str)

if start_idx != -1 and end_idx != -1:
    new_gestures = '''  void onPointerDown(PointerDownEvent event) {
    final position = event.localPosition;
    
    // Eyedropper logic
    if (activeTool.value == DrawingTool.eyedropper) {
      eyedropperPosition.value = position;
      _initEyedropper(position);
      return;
    }
    
    activePointersMap[event.pointer] = position;
    
    // Stempel cursor logic
    if (activeTool.value == DrawingTool.cursor && activePointersMap.length == 1) {
      final canvasPos = _screenToCanvas(position);
      if (_isPositionOnAnyStempel(canvasPos)) {
        // User clicked on a stempel. Do nothing, let the stempel gesture detector handle it.
        _isDraggingStempel = true;
      } else {
        activeStempelId.value = '';
        if (activeStempelShape.value != null) {
          placeNewStempel(canvasPos);
          _isDraggingStempel = true; // prevent panning while placing
        } else {
          _isDraggingStempel = false;
        }
      }
    } else {
      activeStempelId.value = '';
      _isDraggingStempel = false;
    }

    if (activePointersMap.length == 1) {
      if (activeTool.value == DrawingTool.cursor) {
         if (!_isDraggingStempel) {
            _setupTransform();
         }
      } else {
         _isDrawing = true;
         onPanStart(_screenToCanvas(position));
      }
    } else if (activePointersMap.length >= 2) {
      if (_isDrawing) {
        onPanCancel();
        _isDrawing = false;
      }
      _isDraggingStempel = false; // 2 fingers overrides stempel drag -> zooms canvas
      _setupTransform();
    }
  }

  void onPointerMove(PointerMoveEvent event) {
    final position = event.localPosition;
    
    if (activeTool.value == DrawingTool.eyedropper) {
      eyedropperPosition.value = position;
      _sampleColorAt(position);
      return;
    }
    
    if (activePointersMap.containsKey(event.pointer)) {
      activePointersMap[event.pointer] = position;
    }
    
    if (activePointersMap.length == 1) {
      if (_isDrawing) {
        onPanUpdate(_screenToCanvas(position));
      } else if (activeTool.value == DrawingTool.cursor && !_isDraggingStempel) {
        _updateTransform();
      }
    } else if (activePointersMap.length >= 2) {
      _updateTransform();
    }
  }

  void onPointerUp(PointerEvent event) {
    if (activeTool.value == DrawingTool.eyedropper) {
      eyedropperPosition.value = null;
      _eyedropperBytes = null;
      
      final color = activeColor.value;
      Get.snackbar(
        'Warna Disalin',
        'Berhasil mengambil warna dari kanvas.',
        backgroundColor: color.withValues(alpha: 0.9),
        colorText: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 1),
        margin: const EdgeInsets.all(12),
        borderRadius: 12,
      );
      
      activeTool.value = _toolBeforeEyedropper;
      return;
    }
    
    activePointersMap.remove(event.pointer);
    
    if (activePointersMap.isEmpty) {
      if (_isDrawing) {
        onPanEnd();
        _isDrawing = false;
      }
      _isDraggingStempel = false;
    } else if (activePointersMap.length == 1) {
      _isDrawing = false; // Do not resume drawing if dropping to 1 finger
      _setupTransform(); // Reset pivot points for 1 finger pan
    } else if (activePointersMap.length >= 2) {
      _setupTransform();
    }
  }

  void onPointerCancel(PointerEvent event) {
    if (activeTool.value == DrawingTool.eyedropper) {
      eyedropperPosition.value = null;
      _eyedropperBytes = null;
      activeTool.value = _toolBeforeEyedropper;
      return;
    }
    
    activePointersMap.remove(event.pointer);
    
    if (activePointersMap.isEmpty) {
      if (_isDrawing) {
        onPanCancel();
        _isDrawing = false;
      }
      _isDraggingStempel = false;
    } else {
      if (_isDrawing) {
        onPanCancel();
        _isDrawing = false;
      }
      _setupTransform();
    }
  }

  void _setupTransform() {
    if (activePointersMap.isEmpty) return;
    
    final points = activePointersMap.values.toList();
    if (points.length == 1) {
      _prevFocalPoint = points[0];
      _prevDistance = 0.0;
      _prevAngle = 0.0;
    } else {
      final p1 = points[0];
      final p2 = points[1];
      _prevFocalPoint = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      _prevDistance = (p1 - p2).distance;
      _prevAngle = math.atan2(p1.dy - p2.dy, p1.dx - p2.dx);
    }
  }

  void _updateTransform() {
    if (activePointersMap.isEmpty || _prevFocalPoint == null) return;
    
    final points = activePointersMap.values.toList();
    Offset currentFocalPoint;
    double currentDistance = 0.0;
    double currentAngle = 0.0;
    
    if (points.length == 1) {
      currentFocalPoint = points[0];
    } else {
      final p1 = points[0];
      final p2 = points[1];
      currentFocalPoint = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      currentDistance = (p1 - p2).distance;
      currentAngle = math.atan2(p1.dy - p2.dy, p1.dx - p2.dx);
    }
    
    // Scale limit check
    double deltaScale = 1.0;
    if (points.length >= 2 && _prevDistance != null && _prevDistance! > 0 && currentDistance > 0) {
        deltaScale = currentDistance / _prevDistance!;
    }
    
    double deltaAngle = 0.0;
    if (points.length >= 2 && _prevAngle != null) {
        deltaAngle = currentAngle - _prevAngle!;
    }
    
    final currentScale = canvasMatrix.value.getMaxScaleOnAxis();
    final projectedScale = currentScale * deltaScale;
    
    // Sangat dekat: No limit for zoom in. Lower limit slightly to 0.05 for zooming out
    final actualScaleDelta = projectedScale < 0.05 ? (0.05 / currentScale) : deltaScale;

    final deltaMatrix = Matrix4.identity()
      ..translate(currentFocalPoint.dx, currentFocalPoint.dy)
      ..scale(actualScaleDelta, actualScaleDelta)
      ..rotateZ(deltaAngle)
      ..translate(-_prevFocalPoint!.dx, -_prevFocalPoint!.dy);

    canvasMatrix.value = deltaMatrix.multiplied(canvasMatrix.value);
    
    _prevFocalPoint = currentFocalPoint;
    _prevDistance = currentDistance;
    _prevAngle = currentAngle;
  }

'''
    
    new_content = content[:start_idx] + new_gestures + content[end_idx:]
    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print('Replaced successfully')
else:
    print('Failed to find start or end index')

