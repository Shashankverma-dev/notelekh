import 'package:flutter/gestures.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';

/// O(1) raw pointer-to-stroke adapter. Device classification happens upstream.
class InputProcessor {
  int? _activePointerId;
  bool _activeStrokeIsStylus = false;
  Offset? _lastPosition;
  int? _lastTimestamp;
  double _velocity = 0.0;
  StrokePoint? _lastPoint;

  bool get isStylusActive => _activeStrokeIsStylus;
  int? get activePointerId => _activePointerId;
  StrokePoint? get lastPoint => _lastPoint;

  void setStabilization(double value) {}

  StrokePoint? onPointerDown(
    PointerDownEvent event,
    Offset worldPosition, {
    bool isGuaranteedStylus = false,
    bool? isStylus,
  }) {
    final stylus = isStylus ?? isGuaranteedStylus;
    _activePointerId = event.pointer;
    _activeStrokeIsStylus = stylus;
    _lastPosition = worldPosition;
    _lastTimestamp = event.timeStamp.inMilliseconds;
    _velocity = 0.0;
    final point = _point(
      worldPosition,
      _pressure(event.pressure),
      event.tilt,
      0.0,
      stylus,
      _lastTimestamp!,
    );
    _lastPoint = point;
    return point;
  }

  StrokePoint? onPointerMove(PointerMoveEvent event, Offset worldPosition) {
    if (_activePointerId != event.pointer) return null;
    return _append(event, worldPosition);
  }

  StrokePoint? onPointerMoveFast(PointerMoveEvent event, Offset worldPosition) {
    return onPointerMove(event, worldPosition);
  }

  StrokePoint? _append(PointerMoveEvent event, Offset worldPosition) {
    final now = event.timeStamp.inMilliseconds;
    final previousTime = _lastTimestamp ?? now - 16;
    final dt = (now - previousTime).clamp(1, 100);
    final previous = _lastPosition ?? worldPosition;
    final distance = (worldPosition - previous).distance;
    final instantVelocity = distance / dt;
    _velocity = (_velocity * 0.7) + (instantVelocity * 0.3);
    _lastPosition = worldPosition;
    _lastTimestamp = now;
    final point = _point(
      worldPosition,
      _pressure(event.pressure),
      event.tilt,
      _velocity,
      _activeStrokeIsStylus,
      now,
    );
    _lastPoint = point;
    return point;
  }

  StrokePoint? onPointerUp(PointerUpEvent event, Offset worldPosition) {
    if (_activePointerId != event.pointer) return null;
    final point = _point(
      worldPosition,
      _pressure(event.pressure),
      event.tilt,
      _velocity,
      _activeStrokeIsStylus,
      event.timeStamp.inMilliseconds,
    );
    _clear();
    return point;
  }

  void onPointerCancel(PointerCancelEvent event) {
    if (_activePointerId == event.pointer) _clear();
  }

  void forceReset() => _clear();

  StrokePoint _point(
    Offset position,
    double pressure,
    double tilt,
    double velocity,
    bool isStylus,
    int timestamp,
  ) {
    return StrokePoint(
      x: position.dx,
      y: position.dy,
      pressure: pressure,
      tilt: tilt,
      velocity: velocity,
      isStylus: isStylus,
      timestamp: timestamp,
    );
  }

  double _pressure(double value) {
    if (value.isNaN || value <= 0.0) return 0.5;
    return value.clamp(0.0, 1.0);
  }

  void _clear() {
    _activePointerId = null;
    _activeStrokeIsStylus = false;
    _lastPosition = null;
    _lastTimestamp = null;
    _lastPoint = null;
    _velocity = 0.0;
  }
}
