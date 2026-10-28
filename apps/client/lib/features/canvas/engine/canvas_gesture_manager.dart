import 'package:flutter/gestures.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';
import 'package:ai_workspace_client/features/canvas/engine/input_processor.dart';

/// Single interaction state for the canvas input controller.
enum CanvasInputState {
  idle,
  pencilDrawing,
  fingerDrawing,
  oneFingerPanning,
  pinchAndPan,
  mouseDrawing,
  erasing,
  lassoing,
  shapeDragging,
}

enum PointerOwner {
  stylusDraw,
  touchGesture,
  mouse,
}

class ActivePointer {
  final int id;
  final PointerDeviceKind kind;
  Offset screenPosition;
  Offset worldPosition;

  ActivePointer({
    required this.id,
    required this.kind,
    required this.screenPosition,
    required this.worldPosition,
  });
}

class PointerTelemetry {
  final String deviceKind;
  final int pointerId;
  final double pressure;
  final double tilt;
  final int buttons;
  final Offset screenPosition;
  final Offset worldPosition;
  final String eventType;
  final int timestamp;

  PointerTelemetry({
    required this.deviceKind,
    required this.pointerId,
    required this.pressure,
    required this.tilt,
    required this.buttons,
    required this.screenPosition,
    required this.worldPosition,
    required this.eventType,
    required this.timestamp,
  });
}

class TouchGestureEngine {
  int? finger1Id;
  int? finger2Id;
  Offset? finger1ScreenPos;
  Offset? finger2ScreenPos;
  double startScale = 1.0;
  double startDistance = 1.0;
  Offset startPanOffset = Offset.zero;
  Offset focalPointWorld = Offset.zero;

  bool get isPinching => finger1Id != null && finger2Id != null;

  void startPinch({
    required int f1Id,
    required Offset f1Pos,
    required int f2Id,
    required Offset f2Pos,
    required double currentScale,
    required Offset currentPan,
  }) {
    finger1Id = f1Id;
    finger2Id = f2Id;
    finger1ScreenPos = f1Pos;
    finger2ScreenPos = f2Pos;
    startScale = currentScale;
    startPanOffset = currentPan;
    startDistance = (f1Pos - f2Pos).distance.clamp(1.0, 10000.0);
    focalPointWorld = ((f1Pos + f2Pos) / 2.0 - currentPan) / currentScale;
  }

  MapEntry<double, Offset>? updatePinch(int pointerId, Offset position) {
    if (!isPinching) return null;
    if (pointerId == finger1Id) {
      finger1ScreenPos = position;
    } else if (pointerId == finger2Id) {
      finger2ScreenPos = position;
    } else {
      return null;
    }
    final p1 = finger1ScreenPos!;
    final p2 = finger2ScreenPos!;
    final distance = (p1 - p2).distance.clamp(1.0, 10000.0);
    final scale = (startScale * distance / startDistance).clamp(0.5, 5.0);
    final focal = (p1 + p2) / 2.0;
    return MapEntry(scale, focal - focalPointWorld * scale);
  }

  void removePointer(int pointerId) {
    if (finger1Id == pointerId) {
      finger1Id = null;
      finger1ScreenPos = null;
    } else if (finger2Id == pointerId) {
      finger2Id = null;
      finger2ScreenPos = null;
    }
  }

  void endPinch() {
    finger1Id = null;
    finger2Id = null;
    finger1ScreenPos = null;
    finger2ScreenPos = null;
  }
}

/// The only pointer classifier and ownership controller for canvas input.
class CanvasGestureManager {
  final InputProcessor inputProcessor;
  final Offset Function(Offset screenPos) screenToWorld;
  final Map<int, ActivePointer> _activePointers = {};
  final Map<int, PointerOwner> pointerOwners = {};
  // Tool ownership is immutable for the lifetime of a pointer. Switching a
  // toolbar control must not redirect an in-progress pointer sequence.
  final Map<int, String> _pointerTools = {};
  final TouchGestureEngine touchGestureEngine = TouchGestureEngine();

  CanvasInputState _state = CanvasInputState.idle;
  int? _activeStylusPointerId;
  int? _activeTouchPointerId;
  double _pinchStartScale = 1.0;
  Offset _pinchStartPanOffset = Offset.zero;

  void Function(StrokePoint point, bool isStylus)? onStrokeStart;
  void Function(StrokePoint point)? onStrokeUpdate;
  void Function(StrokePoint point)? onStrokeEnd;
  void Function({bool discard})? onStrokeCancel;
  void Function(double newScale, Offset newPanOffset)? onTransformUpdate;
  void Function(Offset delta)? onPanDelta;
  void Function(Offset? hoverWorldPos, double tilt)? onStylusHover;
  void Function(Offset worldPos)? onEraseAt;
  void Function(Offset worldPos, bool isStart)? onLassoPoint;
  void Function(Offset worldPos, bool isStart)? onShapeDrag;
  void Function(Offset screenPos)? onTextTap;
  void Function(PointerTelemetry telemetry)? onPointerTelemetry;

  CanvasGestureManager({
    required this.screenToWorld,
    InputProcessor? inputProcessor,
    this.fingerDrawingEnabled = false,
  }) : inputProcessor = inputProcessor ?? InputProcessor();

  CanvasInputState get state => _state;
  bool get isPencilActive => _activeStylusPointerId != null;
  int? get activeStylusPointerId => _activeStylusPointerId;
  int get activePointersCount => _activePointers.length;
  int get rejectedPalmPointersCount => 0;
  bool get lastClassificationWasStylus => false;
  bool get isStylusActive => _activeStylusPointerId != null;
  bool fingerDrawingEnabled = false;
  bool enableTelemetry = false;

  void setStabilization(double value) => inputProcessor.setStabilization(value);

  void setPinchStartGeometry(double scale, Offset pan) {
    _pinchStartScale = scale;
    _pinchStartPanOffset = pan;
  }

  void onPointerDown(
    PointerDownEvent event,
    String currentTool, {
    double? currentZoom,
    Offset? currentPan,
  }) {
    final world = screenToWorld(event.localPosition);
    final isStylus = event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus;
    final isMouse = event.kind == PointerDeviceKind.mouse;
    final owner = isStylus
        ? PointerOwner.stylusDraw
        : (isMouse ? PointerOwner.mouse : PointerOwner.touchGesture);

    // WebKit may reuse pointer ids. Clear any stale bookkeeping first.
    pointerOwners.remove(event.pointer);
    _pointerTools.remove(event.pointer);
    pointerOwners[event.pointer] = owner;
    _pointerTools[event.pointer] = currentTool;
    _activePointers[event.pointer] = ActivePointer(
      id: event.pointer,
      kind: event.kind,
      screenPosition: event.localPosition,
      worldPosition: world,
    );
    _emitTelemetry(event, world, 'down');

    if (isStylus) {
      // A second down without a matching up/cancel is a new physical session;
      // finish the old one before reusing the single ink buffer.
      if (_activeStylusPointerId != null || _activeTouchPointerId != null) {
        _finishOrCancelActiveStroke();
        // _finishOrCancelActiveStroke clears the old owner; when WebKit has
        // reused the same id, restore this new event's bookkeeping.
        pointerOwners[event.pointer] = owner;
        _pointerTools[event.pointer] = currentTool;
        _activePointers[event.pointer] = ActivePointer(
          id: event.pointer,
          kind: event.kind,
          screenPosition: event.localPosition,
          worldPosition: world,
        );
      }
      _activeStylusPointerId = event.pointer;
      _endTouchGesture();
      _routeDrawingDown(event, world, currentTool, isStylus: true);
      return;
    }

    if (isMouse) {
      // InputProcessor has one active ink buffer. A mouse/trackpad event must
      // never replace Pencil input while the Pencil owns that buffer.
      if (_activeStylusPointerId != null) return;
      _routeDrawingDown(event, world, currentTool, isStylus: false, isMouse: true);
      return;
    }

    // A touch never becomes ink while a stylus is actively down.
    if (_activeStylusPointerId != null) return;

    final touches = _touchPointers;
    if (touches.length >= 2) {
      if (_state == CanvasInputState.fingerDrawing) {
        inputProcessor.forceReset();
        onStrokeCancel?.call(discard: true);
        _activeTouchPointerId = null;
      }
      _beginPinch(touches[0], touches[1], currentZoom, currentPan);
      return;
    }
    _routeTouchDown(event, world, currentTool);
  }

  void onPointerMoveFast(PointerMoveEvent event) {
    onPointerMove(
      event,
      currentZoom: _pinchStartScale,
      currentPan: _pinchStartPanOffset,
      currentTool: 'pen',
    );
  }

  void onPointerMove(
    PointerMoveEvent event, {
    required double currentZoom,
    required Offset currentPan,
    required String currentTool,
  }) {
    final owner = pointerOwners[event.pointer];
    final pointer = _activePointers[event.pointer];
    if (owner == null || pointer == null) return;
    pointer.screenPosition = event.localPosition;
    pointer.worldPosition = screenToWorld(event.localPosition);
    _emitTelemetry(event, pointer.worldPosition, 'move');

    if (owner == PointerOwner.stylusDraw) {
      if (event.pointer != _activeStylusPointerId || _state != CanvasInputState.pencilDrawing) return;
      final point = inputProcessor.onPointerMove(event, pointer.worldPosition);
      if (point != null) onStrokeUpdate?.call(point);
      return;
    }
    if (owner == PointerOwner.mouse) {
      if (_activeStylusPointerId != null) return;
      _handleMouseMove(
        event,
        pointer.worldPosition,
        _pointerTools[event.pointer] ?? currentTool,
      );
      return;
    }
    if (_activeStylusPointerId != null) return;

    if (owner == PointerOwner.touchGesture) {
      if (_state == CanvasInputState.fingerDrawing && event.pointer == _activeTouchPointerId) {
        final point = inputProcessor.onPointerMove(event, pointer.worldPosition);
        if (point != null) onStrokeUpdate?.call(point);
        return;
      }
      if (_state == CanvasInputState.pinchAndPan) {
        final update = touchGestureEngine.updatePinch(event.pointer, event.localPosition);
        if (update != null) onTransformUpdate?.call(update.key, update.value);
        return;
      }
      if (_state == CanvasInputState.oneFingerPanning) {
        onPanDelta?.call(event.delta);
        return;
      }
      if (_state == CanvasInputState.lassoing) {
        onLassoPoint?.call(pointer.worldPosition, false);
        return;
      }
      if (_state == CanvasInputState.shapeDragging) {
        onShapeDrag?.call(pointer.worldPosition, false);
        return;
      }
      if (_state == CanvasInputState.erasing) onEraseAt?.call(pointer.worldPosition);
    }
  }

  void onPointerUp(PointerUpEvent event) {
    final owner = pointerOwners.remove(event.pointer);
    _pointerTools.remove(event.pointer);
    _activePointers.remove(event.pointer);
    _emitTelemetry(event, screenToWorld(event.localPosition), 'up');
    if (owner == null) return;

    if (owner == PointerOwner.stylusDraw && event.pointer == _activeStylusPointerId) {
      final world = screenToWorld(event.localPosition);
      final point = inputProcessor.onPointerUp(event, world);
      if (point != null) onStrokeEnd?.call(point);
      _activeStylusPointerId = null;
      _state = CanvasInputState.idle;
      return;
    }

    if (owner == PointerOwner.touchGesture) {
      touchGestureEngine.removePointer(event.pointer);
      if (event.pointer == _activeTouchPointerId && _state == CanvasInputState.fingerDrawing) {
        final world = screenToWorld(event.localPosition);
        final point = inputProcessor.onPointerUp(event, world);
        if (point != null) onStrokeEnd?.call(point);
        _activeTouchPointerId = null;
        _state = CanvasInputState.idle;
        return;
      }
      if (_activeStylusPointerId != null) return;
      if (_state == CanvasInputState.pinchAndPan && !touchGestureEngine.isPinching) {
        _state = CanvasInputState.idle;
      } else if (_state != CanvasInputState.pinchAndPan) {
        _state = CanvasInputState.idle;
      }
    } else if (owner == PointerOwner.mouse) {
      if (_state == CanvasInputState.mouseDrawing) {
        final world = screenToWorld(event.localPosition);
        final point = inputProcessor.onPointerUp(event, world);
        if (point != null) onStrokeEnd?.call(point);
      }
      _state = CanvasInputState.idle;
    }
  }

  void onPointerCancel(PointerCancelEvent event) {
    final owner = pointerOwners.remove(event.pointer);
    _pointerTools.remove(event.pointer);
    _activePointers.remove(event.pointer);
    _emitTelemetry(event, screenToWorld(event.localPosition), 'cancel');
    if (owner == PointerOwner.stylusDraw && event.pointer == _activeStylusPointerId) {
      inputProcessor.onPointerCancel(event);
      onStrokeCancel?.call(discard: false);
      _activeStylusPointerId = null;
      _state = CanvasInputState.idle;
      return;
    }
    if (owner == PointerOwner.touchGesture) {
      touchGestureEngine.removePointer(event.pointer);
      if (event.pointer == _activeTouchPointerId && _state == CanvasInputState.fingerDrawing) {
        inputProcessor.onPointerCancel(event);
        onStrokeCancel?.call(discard: false);
        _activeTouchPointerId = null;
        _state = CanvasInputState.idle;
        return;
      }
      if (!touchGestureEngine.isPinching) _state = CanvasInputState.idle;
    } else if (owner == PointerOwner.mouse) {
      if (_state == CanvasInputState.mouseDrawing) {
        inputProcessor.onPointerCancel(event);
        onStrokeCancel?.call(discard: false);
      }
      _state = CanvasInputState.idle;
    } else if (owner != null) {
      _state = CanvasInputState.idle;
    }
  }

  void onPointerHover(PointerHoverEvent event, {String currentTool = 'pen'}) {
    if (event.kind == PointerDeviceKind.stylus || event.kind == PointerDeviceKind.invertedStylus) {
      onStylusHover?.call(screenToWorld(event.localPosition), event.tilt);
    } else {
      onStylusHover?.call(null, 0.0);
    }
  }

  List<ActivePointer> get _touchPointers => _activePointers.values
      .where((pointer) => pointer.kind == PointerDeviceKind.touch)
      .toList(growable: false);

  void _routeDrawingDown(
    PointerDownEvent event,
    Offset world,
    String tool, {
    required bool isStylus,
    bool isMouse = false,
  }) {
    if (_isDrawTool(tool)) {
      final point = inputProcessor.onPointerDown(event, world, isStylus: isStylus);
      _state = isMouse ? CanvasInputState.mouseDrawing : CanvasInputState.pencilDrawing;
      if (point != null) onStrokeStart?.call(point, isStylus);
    } else if (tool == 'eraser') {
      _state = CanvasInputState.erasing;
      onEraseAt?.call(world);
    } else if (tool == 'lasso') {
      _state = CanvasInputState.lassoing;
      onLassoPoint?.call(world, true);
    } else if (tool == 'text') {
      onTextTap?.call(event.localPosition);
    } else if (_isShapeTool(tool)) {
      _state = CanvasInputState.shapeDragging;
      onShapeDrag?.call(world, true);
    } else {
      _state = CanvasInputState.oneFingerPanning;
    }
  }

  void _routeTouchDown(PointerDownEvent event, Offset world, String tool) {
    if (fingerDrawingEnabled && _isDrawTool(tool)) {
      final point = inputProcessor.onPointerDown(event, world, isStylus: false);
      _state = CanvasInputState.fingerDrawing;
      _activeTouchPointerId = event.pointer;
      if (point != null) onStrokeStart?.call(point, false);
      return;
    }
    if (tool == 'eraser') {
      _state = CanvasInputState.erasing;
      onEraseAt?.call(world);
    } else if (tool == 'lasso') {
      _state = CanvasInputState.lassoing;
      onLassoPoint?.call(world, true);
    } else if (_isShapeTool(tool)) {
      _state = CanvasInputState.shapeDragging;
      onShapeDrag?.call(world, true);
    } else {
      _state = CanvasInputState.oneFingerPanning;
    }
  }

  void _handleMouseMove(PointerMoveEvent event, Offset world, String tool) {
    if (_state == CanvasInputState.mouseDrawing) {
      final point = inputProcessor.onPointerMove(event, world);
      if (point != null) onStrokeUpdate?.call(point);
    } else if (_state == CanvasInputState.oneFingerPanning) {
      onPanDelta?.call(event.delta);
    } else if (_state == CanvasInputState.erasing) {
      onEraseAt?.call(world);
    } else if (_state == CanvasInputState.shapeDragging) {
      onShapeDrag?.call(world, false);
    } else if (_state == CanvasInputState.lassoing) {
      onLassoPoint?.call(world, false);
    }
  }

  void _beginPinch(ActivePointer first, ActivePointer second, double? zoom, Offset? pan) {
    _state = CanvasInputState.pinchAndPan;
    _pinchStartScale = zoom ?? _pinchStartScale;
    _pinchStartPanOffset = pan ?? _pinchStartPanOffset;
    touchGestureEngine.startPinch(
      f1Id: first.id,
      f1Pos: first.screenPosition,
      f2Id: second.id,
      f2Pos: second.screenPosition,
      currentScale: _pinchStartScale,
      currentPan: _pinchStartPanOffset,
    );
  }

  void _endTouchGesture() {
    touchGestureEngine.endPinch();
    if (_state == CanvasInputState.pinchAndPan || _state == CanvasInputState.oneFingerPanning) {
      _state = CanvasInputState.idle;
    }
  }

  void _finishOrCancelActiveStroke() {
    final last = inputProcessor.lastPoint;
    if (last != null) {
      onStrokeEnd?.call(last);
    } else {
      onStrokeCancel?.call(discard: false);
    }
    inputProcessor.forceReset();
    if (_activeStylusPointerId != null) {
      pointerOwners.remove(_activeStylusPointerId);
      _pointerTools.remove(_activeStylusPointerId);
      _activePointers.remove(_activeStylusPointerId);
      _activeStylusPointerId = null;
    }
    if (_activeTouchPointerId != null) {
      pointerOwners.remove(_activeTouchPointerId);
      _pointerTools.remove(_activeTouchPointerId);
      _activePointers.remove(_activeTouchPointerId);
      _activeTouchPointerId = null;
    }
    _state = CanvasInputState.idle;
  }

  void _emitTelemetry(PointerEvent event, Offset world, String type) {
    if (!enableTelemetry || onPointerTelemetry == null) return;
    onPointerTelemetry!.call(PointerTelemetry(
      deviceKind: event.kind.name,
      pointerId: event.pointer,
      pressure: event.pressure,
      tilt: event.tilt,
      buttons: event.buttons,
      screenPosition: event.localPosition,
      worldPosition: world,
      eventType: type,
      timestamp: event.timeStamp.inMilliseconds,
    ));
  }

  bool _isDrawTool(String tool) =>
      tool == 'pen' || tool == 'pencil' || tool == 'highlighter' || tool == 'brush';

  bool _isShapeTool(String tool) =>
      tool == 'line' ||
      tool == 'rectangle' ||
      tool == 'circle' ||
      tool == 'triangle' ||
      tool == 'arrow';
}
