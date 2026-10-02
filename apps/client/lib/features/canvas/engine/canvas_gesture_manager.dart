import 'package:flutter/gestures.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';
import 'package:ai_workspace_client/features/canvas/engine/input_processor.dart';

/// State of active canvas interaction
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

/// Tracks an active pointer on the screen
class ActivePointer {
  final int id;
  final PointerDeviceKind kind;
  Offset screenPosition;
  Offset worldPosition;
  double pressure;
  double tilt;
  int timestamp;

  ActivePointer({
    required this.id,
    required this.kind,
    required this.screenPosition,
    required this.worldPosition,
    required this.pressure,
    required this.tilt,
    required this.timestamp,
  });
}

/// Real-time pointer telemetry data for diagnostic display and iPad verification (Part 7)
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

/// Production-grade iPad + Apple Pencil Gesture & Input Manager.
///
/// Ensures:
/// 1. First-class Apple Pencil priority (stylus = drawing/writing, finger = navigation/gestures).
/// 2. Strict palm rejection (temporal cooldown + contact area suppression).
/// 3. Zero accidental ink strokes during pinch-to-zoom and two-finger pan.
/// 4. Invariant focal-point zoom (50% to 500%) with stable content under fingers.
/// 5. Apple Pencil hover preview reticle.
class CanvasGestureManager {
  final InputProcessor inputProcessor;
  final Offset Function(Offset screenPos) screenToWorld;

  // Active pointer tracking
  final Map<int, ActivePointer> _activePointers = {};
  final Set<int> _rejectedPalmPointers = {};

  // Stylus tracking
  int? _activeStylusPointerId;
  int _lastStylusLiftTimestamp = 0;

  // Known stylus pointer IDs and last seen timestamps — persists across events so we can recognize
  // a pencil even when pressure=0 on the very first contact frame, especially during fast writing.
  // WebKit sometimes sends PointerDown with pressure=0 before the digitizer
  // has measured actual pressure, so we remember pointer IDs for 10 seconds.
  final Map<int, int> _knownStylusPointerTimestamps = {};

  void _pruneStalePointers() {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Fix for permanent canvas freeze: If a PointerUp is dropped, the pointer stays here forever.
    // We MUST prune all pointers (including stylus) if they haven't moved in 2.5 seconds.
    _activePointers.removeWhere((id, p) {
      if (now - p.timestamp > 2500) {
        if (id == _activeStylusPointerId) {
           _activeStylusPointerId = null;
        }
        return true;
      }
      return false;
    });

    _knownStylusPointerTimestamps.removeWhere((id, time) => now - time > 10000);

    if (_activeStylusPointerId == null) {
      if (_state == CanvasInputState.pencilDrawing) {
        _state = CanvasInputState.idle;
      }
      inputProcessor.forceReset();
    }
  }

  // Gesture state
  CanvasInputState _state = CanvasInputState.idle;
  bool fingerDrawingEnabled = true; // Natural drawing: single touch/stylus draws immediately, two fingers pinch/pan

  // Pinch / Pan invariant geometry
  double _pinchStartScale = 1.0;
  double _pinchStartDistance = 1.0;
  Offset _pinchFocalPoint = Offset.zero;
  Offset _pinchStartPanOffset = Offset.zero;

  // Callbacks
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

  void _emitTelemetry(PointerEvent event, Offset worldPos, String type) {
    onPointerTelemetry?.call(PointerTelemetry(
      deviceKind: event.kind.name,
      pointerId: event.pointer,
      pressure: event.pressure,
      tilt: event.tilt,
      buttons: event.buttons,
      screenPosition: event.localPosition,
      worldPosition: worldPos,
      eventType: type,
      timestamp: event.timeStamp.inMilliseconds,
    ));
  }

  CanvasGestureManager({
    required this.screenToWorld,
    InputProcessor? inputProcessor,
    this.fingerDrawingEnabled = true,
  }) : inputProcessor = inputProcessor ?? InputProcessor();

  CanvasInputState get state => _state;
  bool get isPencilActive => _activeStylusPointerId != null;
  int? get activeStylusPointerId => _activeStylusPointerId;

  void setStabilization(double val) {
    inputProcessor.setStabilization(val);
  }

  /// Detects if a pointer event is from Apple Pencil / stylus.
  /// Uses multiple heuristics because Safari/WebKit sends pressure=0 on first contact.
  bool _detectIsStylus(PointerEvent event) {
    // Definitive: Flutter has classified this as stylus
    if (event.kind == PointerDeviceKind.stylus || event.kind == PointerDeviceKind.invertedStylus) {
      return true;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    // We have previously identified this pointer as a stylus in the current writing session
    final lastSeen = _knownStylusPointerTimestamps[event.pointer];
    if (lastSeen != null && (now - lastSeen) < 10000) {
      _knownStylusPointerTimestamps[event.pointer] = now;
      return true;
    }
    // Stylus pressure and tilt indicators (critical for Apple Pencil / active styluses on Safari and Web):
    // Apple Pencil or active stylus reporting real pressure or tilt is ALWAYS a stylus,
    // even if resting palm or fingers touched the glass first!
    final hasPressureData = event.pressure > 0.0 && event.pressure != 0.5 && event.pressure != 1.0;
    final hasTilt = event.tilt > 0.0;
    if (hasPressureData || hasTilt) {
      _knownStylusPointerTimestamps[event.pointer] = now;
      return true;
    }
    return false;
  }

  /// Handles PointerDownEvent with strict device differentiation & palm rejection
  void onPointerDown(PointerDownEvent event, String currentTool, {double? currentZoom, Offset? currentPan}) {
    _pruneStalePointers();
    final worldPos = screenToWorld(event.localPosition);
    _emitTelemetry(event, worldPos, 'down');
    final isStylus = _detectIsStylus(event);
    final isMouse = event.kind == PointerDeviceKind.mouse;
    final isTouch = !isStylus && !isMouse;

    if (currentZoom != null && currentPan != null) {
      _pinchStartScale = currentZoom;
      _pinchStartPanOffset = currentPan;
    }

    // If we're stuck in any drawing state with missed pointerUp,
    // commit the previous stroke immediately so new rapid handwriting can proceed with zero delay.
    final isStuckPencil = _state == CanvasInputState.pencilDrawing && _activeStylusPointerId == null;
    final isStuckFinger = _state == CanvasInputState.fingerDrawing && _activePointers.isEmpty;
    // Also catch: fingerDrawing but all remaining pointers are rejected palms
    final isStuckFingerAllPalm = _state == CanvasInputState.fingerDrawing &&
        _activePointers.isNotEmpty &&
        _activePointers.keys.every((id) => _rejectedPalmPointers.contains(id));
    if (isStuckPencil || isStuckFinger || isStuckFingerAllPalm) {
      onStrokeEnd?.call(StrokePoint(
        x: worldPos.dx,
        y: worldPos.dy,
        pressure: 0.5,
        isStylus: isStylus,
        timestamp: event.timeStamp.inMilliseconds,
      ));
      _state = CanvasInputState.idle;
    }

    // ── 1. APPLE PENCIL INPUT (Priority 1: Guaranteed immediate ink) ──────────────
    if (isStylus) {
      // If we already have an active stylus pointer that was only heuristically classified from kind == touch,
      // and now a second touch arrives, this is a two-finger pinch gesture ONLY if fingers are far apart (>35px)
      final prevStylus = _activeStylusPointerId != null ? _activePointers[_activeStylusPointerId] : null;
      final prevIsHeuristic = prevStylus != null && prevStylus.kind == PointerDeviceKind.touch;
      if (event.kind == PointerDeviceKind.touch && prevIsHeuristic && _activeStylusPointerId != event.pointer) {
        final dist = (event.localPosition - prevStylus.screenPosition).distance;
        if (dist > 20.0) {
          _knownStylusPointerTimestamps.remove(_activeStylusPointerId);
          _knownStylusPointerTimestamps.remove(event.pointer);
          _activeStylusPointerId = null;
          if (_state == CanvasInputState.pencilDrawing || _state == CanvasInputState.fingerDrawing) {
            onStrokeCancel?.call(discard: true);
          }
          _activePointers[event.pointer] = ActivePointer(
            id: event.pointer,
            kind: event.kind,
            screenPosition: event.localPosition,
            worldPosition: worldPos,
            pressure: event.pressure,
            tilt: event.tilt,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          );
          final touches = _activePointers.values.where((p) => p.kind != PointerDeviceKind.mouse).toList();
          if (touches.length >= 2) {
            _state = CanvasInputState.pinchAndPan;
            final p1 = touches[0].screenPosition;
            final p2 = touches[1].screenPosition;
            _pinchStartDistance = (p1 - p2).distance.clamp(10.0, 10000.0);
            _pinchFocalPoint = (p1 + p2) / 2.0;
            if (currentZoom != null) _pinchStartScale = currentZoom;
            if (currentPan != null) _pinchStartPanOffset = currentPan;
            return;
          }
        }
      }

      // If a previous stylus stroke was somehow not closed (missed pointerup), commit it immediately
      if (_state == CanvasInputState.pencilDrawing && _activeStylusPointerId != null && _activeStylusPointerId != event.pointer) {
        onStrokeEnd?.call(StrokePoint(
          x: worldPos.dx,
          y: worldPos.dy,
          pressure: 0.5,
          isStylus: true,
          timestamp: event.timeStamp.inMilliseconds,
        ));
      }

      // Any other touches on screen right now are resting palms! Mark them as rejected palm touches
      for (final p in _activePointers.values) {
        if (p.id != event.pointer) {
          _rejectedPalmPointers.add(p.id);
        }
      }

      // Stylus preempts and cancels any ongoing finger gesture (pan, pinch, finger drawing)
      if (_state == CanvasInputState.oneFingerPanning ||
          _state == CanvasInputState.fingerDrawing ||
          _state == CanvasInputState.pinchAndPan) {
        if (_state == CanvasInputState.fingerDrawing) {
          onStrokeCancel?.call(discard: true);
        }
        _state = CanvasInputState.idle;
      }

      _activeStylusPointerId = event.pointer;
      _knownStylusPointerTimestamps[event.pointer] = DateTime.now().millisecondsSinceEpoch; // remember this pointer as a stylus
      _activePointers[event.pointer] = ActivePointer(
        id: event.pointer,
        kind: event.kind,
        screenPosition: event.localPosition,
        worldPosition: worldPos,
        pressure: event.pressure,
        tilt: event.tilt,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      _routeStylusToolDown(event, worldPos, currentTool);
      return;
    }

    // ── 2. PALM REJECTION & TOUCH INPUT (Fingers) ──────────────────────────────
    if (isTouch) {
      // If our "active stylus" was only heuristically classified from kind == touch/unknown,
      // and now a second touch arrives, this is NOT a palm—this is a two-finger pinch!
      final activeStylus = _activeStylusPointerId != null ? _activePointers[_activeStylusPointerId] : null;
      final isRealHardwareStylus = activeStylus != null &&
          (activeStylus.kind == PointerDeviceKind.stylus || activeStylus.kind == PointerDeviceKind.invertedStylus || activeStylus.tilt > 0.0);

      if (_activeStylusPointerId != null && !isRealHardwareStylus) {
        // Demote heuristic stylus back to touch pointer so 2-finger pinch can activate if separated
        final prevStylusPos = activeStylus?.screenPosition;
        final sep = prevStylusPos != null ? (event.localPosition - prevStylusPos).distance : 0.0;
        if (sep > 20.0) {
          _knownStylusPointerTimestamps.remove(_activeStylusPointerId);
          _activeStylusPointerId = null;
          if (_state == CanvasInputState.pencilDrawing || _state == CanvasInputState.fingerDrawing) {
            onStrokeCancel?.call(discard: true);
            _state = CanvasInputState.idle;
          }
        }
      } else if (isRealHardwareStylus || _state == CanvasInputState.pencilDrawing) {
        // 2a. Reject touch if a REAL Apple Pencil is currently touching/drawing on screen
        _rejectedPalmPointers.add(event.pointer);
        return;
      }

      // 2b. Post-pencil temporal check: ONLY reject real massive resting palm patches (>45px major / >30px minor).
      // NEVER reject based on pressure == 0.0, because WebKit Apple Pencil has pressure == 0.0 on touchdown!
      final now = DateTime.now().millisecondsSinceEpoch;
      final isRecentPencilLift = _lastStylusLiftTimestamp > 0 && (now - _lastStylusLiftTimestamp) < 2500;
      final isRealPalm = (isRecentPencilLift && (event.radiusMajor > 35.0 || event.radiusMinor > 25.0)) ||
          (event.radiusMajor > 45.0 || event.radiusMinor > 30.0);
      if (isRealPalm) {
        _rejectedPalmPointers.add(event.pointer);
        return;
      }

      // 2c. Only reject extreme resting palm area (>60px radius) when no other touches are active
      if (_activePointers.isEmpty && inputProcessor.isPalmContact(event)) {
        _rejectedPalmPointers.add(event.pointer);
        return;
      }

      _activePointers[event.pointer] = ActivePointer(
        id: event.pointer,
        kind: event.kind,
        screenPosition: event.localPosition,
        worldPosition: worldPos,
        pressure: event.pressure,
        tilt: event.tilt,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      final touchPointers = _activePointers.values.where((p) => p.kind != PointerDeviceKind.mouse && p.id != _activeStylusPointerId).toList();

      if (touchPointers.length >= 2) {
        final p1 = touchPointers[0].screenPosition;
        final p2 = touchPointers[1].screenPosition;
        final touchSeparation = (p1 - p2).distance;

        // Two fingers triggers pinch-to-zoom ONLY if fingers are physically separated (> 15px)
        if (touchSeparation > 15.0) {
          if (_state == CanvasInputState.fingerDrawing) {
            onStrokeCancel?.call(discard: true);
          }

          _state = CanvasInputState.pinchAndPan;
          _pinchStartDistance = touchSeparation.clamp(10.0, 10000.0);
          _pinchFocalPoint = (p1 + p2) / 2.0;
          if (currentZoom != null) _pinchStartScale = currentZoom;
          if (currentPan != null) _pinchStartPanOffset = currentPan;
          return;
        }
      }

      // ONE FINGER TOUCH:
      if (touchPointers.length == 1) {
        if (fingerDrawingEnabled && _isDrawTool(currentTool)) {
          final processed = inputProcessor.onPointerDown(event, worldPos);
          if (processed != null) {
            _state = CanvasInputState.fingerDrawing;
            onStrokeStart?.call(processed, false);
          } else {
            _state = CanvasInputState.idle;
          }
        } else if (currentTool == 'line' || currentTool == 'rectangle' || currentTool == 'circle' || currentTool == 'arrow') {
          _state = CanvasInputState.shapeDragging;
          onShapeDrag?.call(worldPos, true);
        } else if (currentTool == 'eraser') {
          _state = CanvasInputState.erasing;
          onEraseAt?.call(worldPos);
        } else if (currentTool == 'lasso') {
          _state = CanvasInputState.lassoing;
          onLassoPoint?.call(worldPos, true);
        } else if (currentTool == 'text') {
          _state = CanvasInputState.idle;
          onTextTap?.call(event.localPosition);
        } else {
          _state = CanvasInputState.oneFingerPanning;
        }
        return;
      }
    }

    // ── 3. MOUSE INPUT (Desktop precision) ─────────────────────────────
    if (isMouse) {
      _activePointers[event.pointer] = ActivePointer(
        id: event.pointer,
        kind: event.kind,
        screenPosition: event.localPosition,
        worldPosition: worldPos,
        pressure: event.pressure,
        tilt: event.tilt,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      if (currentTool == 'hand') {
        _state = CanvasInputState.oneFingerPanning;
      } else {
        _routeStylusToolDown(event, worldPos, currentTool, isMouse: true);
      }
    }
  }

  /// Handles PointerMoveEvent
  void onPointerMove(
    PointerMoveEvent event, {
    required double currentZoom,
    required Offset currentPan,
    required String currentTool,
  }) {
    final isStylusMove = event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus ||
        _knownStylusPointerTimestamps.containsKey(event.pointer) ||
        (event.pressure > 0.0 && event.pressure != 0.5 && event.pressure != 1.0) ||
        event.tilt > 0.0;

    if (_rejectedPalmPointers.contains(event.pointer)) {
      if (isStylusMove) {
        // WebKit quirk: Apple Pencil had no pressure on frame 1, so it was rejected as a palm.
        // It now has pressure/tilt, proving it's a stylus. Resurrect it!
        _rejectedPalmPointers.remove(event.pointer);
      } else {
        return;
      }
    }

    _emitTelemetry(event, screenToWorld(event.localPosition), 'move');

    // Is this an active pointer that was previously assigned to panning/finger drawing, but is actually a stylus?
    final isPromotingToStylus = _activePointers.containsKey(event.pointer) &&
        isStylusMove &&
        (_state == CanvasInputState.oneFingerPanning || _state == CanvasInputState.fingerDrawing);

    // Resilient stroke start: ONLY for stylus events where pointerdown was skipped by Safari
    // or if the pointer was resurrected from a false palm-rejection
    // OR if we are promoting a late-pressure stroke from pan/finger to stylus!
    if ((!_activePointers.containsKey(event.pointer) || isPromotingToStylus) && isStylusMove && _isDrawTool(currentTool)) {
      if (isPromotingToStylus) {
        if (_state == CanvasInputState.fingerDrawing) {
          onStrokeCancel?.call(discard: true);
        }
        _activePointers.remove(event.pointer);
      }

      final downEvent = PointerDownEvent(
        pointer: event.pointer,
        position: event.position,
        kind: PointerDeviceKind.stylus,
        device: event.device,
        pressure: event.pressure > 0 ? event.pressure : 0.5,
        pressureMin: event.pressureMin,
        pressureMax: event.pressureMax,
        tilt: event.tilt,
        orientation: event.orientation,
        buttons: event.buttons,
        timeStamp: event.timeStamp,
      );
      onPointerDown(downEvent, currentTool, currentZoom: currentZoom, currentPan: currentPan);
      return;
    }

    final pointer = _activePointers[event.pointer];
    if (pointer != null) {
      pointer.screenPosition = event.localPosition;
      pointer.worldPosition = screenToWorld(event.localPosition);
      pointer.pressure = event.pressure;
      pointer.tilt = event.tilt;
      pointer.timestamp = DateTime.now().millisecondsSinceEpoch;
    }

    final touches = _activePointers.values.where((p) => p.kind != PointerDeviceKind.mouse && p.id != _activeStylusPointerId).toList();

    // Safety net: if 2+ touch contacts are moving and state is not pinchAndPan, transition immediately
    if (touches.length >= 2 && _state != CanvasInputState.pinchAndPan) {
      if (_state == CanvasInputState.fingerDrawing) {
        onStrokeCancel?.call(discard: true);
      }
      _state = CanvasInputState.pinchAndPan;
      final p1 = touches[0].screenPosition;
      final p2 = touches[1].screenPosition;
      _pinchStartDistance = (p1 - p2).distance.clamp(10.0, 10000.0);
      _pinchFocalPoint = (p1 + p2) / 2.0;
      _pinchStartScale = currentZoom;
      _pinchStartPanOffset = currentPan;
    }

    // ── TWO-FINGER PINCH & PAN (ZERO INK) ──────────────────────────────
    if (_state == CanvasInputState.pinchAndPan) {
      if (touches.length >= 2) {
        final p1 = touches[0].screenPosition;
        final p2 = touches[1].screenPosition;
        final currentDist = (p1 - p2).distance.clamp(1.0, 10000.0);
        final currentFocal = (p1 + p2) / 2.0;

        if (_pinchStartDistance > 0 && _pinchStartScale > 0) {
          // Invariant pinch-to-zoom calculation
          final scaleDelta = currentDist / _pinchStartDistance;
          final newScale = (_pinchStartScale * scaleDelta).clamp(0.50, 5.00); // 50% to 500%

          // The point under _pinchFocalPoint at start must remain under currentFocal
          final newPan = currentFocal - (_pinchFocalPoint - _pinchStartPanOffset) * (newScale / _pinchStartScale);

          onTransformUpdate?.call(newScale, newPan);
        }
      }
      return;
    }

    // ── ONE-FINGER PANNING ─────────────────────────────────────────────
    if (_state == CanvasInputState.oneFingerPanning) {
      onPanDelta?.call(event.delta);
      return;
    }

    // ── ACTIVE STROKE DRAWING (Apple Pencil / Mouse / Finger Draw) ──────
    if (_state == CanvasInputState.pencilDrawing ||
        _state == CanvasInputState.mouseDrawing ||
        _state == CanvasInputState.fingerDrawing) {
      // If Apple Pencil is drawing, only process events from the active stylus
      if (_state == CanvasInputState.pencilDrawing && event.pointer != _activeStylusPointerId) {
        return; // Ignore secondary palm movement
      }
      // If finger is drawing, only process events from the drawing touch pointer
      if (_state == CanvasInputState.fingerDrawing && event.pointer != inputProcessor.activePointerId) {
        return; // Ignore secondary touch movement
      }
      final worldPos = screenToWorld(event.localPosition);
      final processed = inputProcessor.onPointerMove(event, worldPos);
      if (processed != null) {
        onStrokeUpdate?.call(processed);
      }
      return;
    }

    // ── ERASER TOOL ───────────────────────────────────────────────────
    if (_state == CanvasInputState.erasing) {
      final worldPos = screenToWorld(event.localPosition);
      onEraseAt?.call(worldPos);
      return;
    }

    // ── LASSO TOOL ────────────────────────────────────────────────────
    if (_state == CanvasInputState.lassoing) {
      final worldPos = screenToWorld(event.localPosition);
      onLassoPoint?.call(worldPos, false);
      return;
    }

    // ── SHAPE TOOL ────────────────────────────────────────────────────
    if (_state == CanvasInputState.shapeDragging) {
      final worldPos = screenToWorld(event.localPosition);
      onShapeDrag?.call(worldPos, false);
      return;
    }
  }

  /// Handles PointerUpEvent
  void onPointerUp(PointerUpEvent event) {
    _emitTelemetry(event, screenToWorld(event.localPosition), 'up');
    if (_rejectedPalmPointers.remove(event.pointer)) return;
    _activePointers.remove(event.pointer);

    final isOurStylus = event.pointer == _activeStylusPointerId;

    if (isOurStylus) {
      _lastStylusLiftTimestamp = DateTime.now().millisecondsSinceEpoch;
      _knownStylusPointerTimestamps[event.pointer] = _lastStylusLiftTimestamp; // keep remembered for next stroke!
      _activeStylusPointerId = null;
    }

    if (_state == CanvasInputState.pinchAndPan) {
      final remainingTouches = _activePointers.values.where((p) => p.kind != PointerDeviceKind.mouse && p.id != _activeStylusPointerId).length;
      if (remainingTouches < 2) {
        _state = CanvasInputState.idle;
      }
      return;
    }

    // PENCIL DRAWING: Only end the stroke when the Apple Pencil itself lifts!
    if (_state == CanvasInputState.pencilDrawing) {
      if (!isOurStylus) {
        // A secondary palm touch lifted from the screen — Apple Pencil is STILL WRITING!
        return;
      }
      final worldPos = screenToWorld(event.localPosition);
      final processed = inputProcessor.onPointerUp(event, worldPos);
      if (processed != null) {
        onStrokeEnd?.call(processed);
      } else {
        onStrokeEnd?.call(StrokePoint(
          x: worldPos.dx,
          y: worldPos.dy,
          pressure: 0.5,
          isStylus: true,
          timestamp: event.timeStamp.inMilliseconds,
        ));
      }
      _state = CanvasInputState.idle;
      return;
    }

    // FINGER DRAWING: Only end when the active finger lifts
    if (_state == CanvasInputState.fingerDrawing) {
      if (event.pointer != inputProcessor.activePointerId) {
        return; // Secondary finger lifted — active drawing finger continues
      }
      final worldPos = screenToWorld(event.localPosition);
      final processed = inputProcessor.onPointerUp(event, worldPos);
      if (processed != null) {
        onStrokeEnd?.call(processed);
      } else {
        onStrokeEnd?.call(StrokePoint(
          x: worldPos.dx,
          y: worldPos.dy,
          pressure: 0.5,
          timestamp: event.timeStamp.inMilliseconds,
        ));
      }
      _state = CanvasInputState.idle;
      return;
    }

    // MOUSE DRAWING
    if (_state == CanvasInputState.mouseDrawing) {
      final worldPos = screenToWorld(event.localPosition);
      final processed = inputProcessor.onPointerUp(event, worldPos);
      if (processed != null) {
        onStrokeEnd?.call(processed);
      } else {
        onStrokeEnd?.call(StrokePoint(
          x: worldPos.dx,
          y: worldPos.dy,
          pressure: 0.5,
          timestamp: event.timeStamp.inMilliseconds,
        ));
      }
      _state = CanvasInputState.idle;
      return;
    }

    if (_state == CanvasInputState.erasing ||
        _state == CanvasInputState.lassoing ||
        _state == CanvasInputState.shapeDragging ||
        _state == CanvasInputState.oneFingerPanning) {
      _state = CanvasInputState.idle;
    }
  }

  /// Handles PointerCancelEvent — hardened for iPadOS Safari which aggressively
  /// cancels pointer events during system gestures (notification center, control
  /// center, app switcher). Must fully recover state to prevent "stuck" gestures.
  void onPointerCancel(PointerCancelEvent event) {
    _rejectedPalmPointers.remove(event.pointer);
    _activePointers.remove(event.pointer);

    // If Apple Pencil is actively drawing and iOS cancels a resting palm touch:
    if (_state == CanvasInputState.pencilDrawing && event.pointer != _activeStylusPointerId) {
      // Ignore secondary palm cancellation — Apple Pencil is still writing!
      return;
    }

    // If the cancelled pointer was our active stylus, fully clean up stylus state
    if (event.pointer == _activeStylusPointerId) {
      _lastStylusLiftTimestamp = DateTime.now().millisecondsSinceEpoch;
      _knownStylusPointerTimestamps[event.pointer] = _lastStylusLiftTimestamp;
      _activeStylusPointerId = null;
      inputProcessor.onPointerCancel(event);
      if (_state == CanvasInputState.pencilDrawing) {
        onStrokeCancel?.call(discard: false);
      }
      _state = CanvasInputState.idle;
      return;
    }

    // If finger drawing and the cancelled pointer isn't the active drawing finger:
    if (_state == CanvasInputState.fingerDrawing && event.pointer != inputProcessor.activePointerId) {
      // Secondary finger cancelled — primary drawing finger is still drawing!
      return;
    }

    // Full state reset for any other cancellation scenario
    inputProcessor.onPointerCancel(event);
    if (_state == CanvasInputState.fingerDrawing ||
        _state == CanvasInputState.mouseDrawing) {
      onStrokeCancel?.call(discard: false);
    }

    // If no pointers remain, force full idle reset to prevent stuck state
    if (_activePointers.isEmpty) {
      _activeStylusPointerId = null;
      _state = CanvasInputState.idle;
    } else if (_state == CanvasInputState.pinchAndPan) {
      final remainingTouches = _activePointers.values.where((p) => p.kind != PointerDeviceKind.mouse && p.id != _activeStylusPointerId).length;
      if (remainingTouches < 2) {
        _state = CanvasInputState.idle;
      }
    } else if (_state != CanvasInputState.pencilDrawing) {
      _state = CanvasInputState.idle;
    }
  }

  /// Handles Apple Pencil hover preview
  void onPointerHover(PointerHoverEvent event) {
    if (event.kind == PointerDeviceKind.stylus || event.kind == PointerDeviceKind.invertedStylus) {
      // If WebKit sends hover with active button contact while idle, start stroke immediately:
      if (event.buttons != 0 && _state == CanvasInputState.idle) {
        final downEvent = PointerDownEvent(
          pointer: event.pointer,
          position: event.position,
          kind: event.kind,
          device: event.device,
          tilt: event.tilt,
          buttons: event.buttons,
          timeStamp: event.timeStamp,
        );
        onPointerDown(downEvent, 'pen');
        return;
      }

      final worldPos = screenToWorld(event.localPosition);
      onStylusHover?.call(worldPos, event.tilt);
    } else {
      onStylusHover?.call(null, 0.0);
    }
  }

  /// Call this when pinch gesture begins to record initial scale and pan offset
  void setPinchStartGeometry(double initialScale, Offset initialPan) {
    _pinchStartScale = initialScale;
    _pinchStartPanOffset = initialPan;
  }

  void _routeStylusToolDown(PointerDownEvent event, Offset worldPos, String tool, {bool isMouse = false}) {
    if (tool == 'pen' || tool == 'pencil' || tool == 'highlighter' || tool == 'brush') {
      final processed = inputProcessor.onPointerDown(event, worldPos, isGuaranteedStylus: !isMouse);
      if (processed != null) {
        _state = isMouse ? CanvasInputState.mouseDrawing : CanvasInputState.pencilDrawing;
        onStrokeStart?.call(processed, !isMouse);
      } else {
        // Absolute fallback: NEVER let an Apple Pencil stroke fail to create ink
        final fallbackPoint = StrokePoint(
          x: worldPos.dx,
          y: worldPos.dy,
          pressure: 0.5,
          isStylus: !isMouse,
          timestamp: event.timeStamp.inMilliseconds,
        );
        _state = isMouse ? CanvasInputState.mouseDrawing : CanvasInputState.pencilDrawing;
        onStrokeStart?.call(fallbackPoint, !isMouse);
      }
    } else if (tool == 'eraser') {
      _state = CanvasInputState.erasing;
      onEraseAt?.call(worldPos);
    } else if (tool == 'lasso') {
      _state = CanvasInputState.lassoing;
      onLassoPoint?.call(worldPos, true);
    } else if (tool == 'text') {
      _state = CanvasInputState.idle;
      onTextTap?.call(event.localPosition);
    } else if (tool == 'rectangle' || tool == 'circle' || tool == 'line' || tool == 'arrow') {
      _state = CanvasInputState.shapeDragging;
      onShapeDrag?.call(worldPos, true);
    } else {
      _state = CanvasInputState.idle;
    }
  }

  bool _isDrawTool(String tool) =>
      tool == 'pen' || tool == 'pencil' || tool == 'highlighter' || tool == 'brush';
}
