import 'package:flutter/gestures.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';
import 'package:ai_workspace_client/features/canvas/engine/stroke_smoother.dart';

/// Processes raw Flutter pointer events into clean, digitizer-accurate [StrokePoint]s.
/// Handles Apple Pencil/stylus first-class input, palm rejection with resting cooldown,
/// continuous pressure extraction with EMA smoothing, and tilt/orientation.
class InputProcessor {
  final StrokeSmoother smoother;
  bool enablePalmRejection;

  int? _lastTimestamp;
  Offset? _lastPosition;
  double _filteredVelocity = 0.0;
  double _filteredPressure = 0.5;
  bool _isStylusActive = false;
  int? _lastStylusTimestamp;
  int? _activePointerId;
  bool _initialPressureWasFallback = false;

  InputProcessor({
    StrokeSmoother? smoother,
    this.enablePalmRejection = true,
  }) : smoother = smoother ?? StrokeSmoother();

  void setStabilization(double val) {
    smoother.stabilization = val;
  }

  bool get isStylusActive => _isStylusActive;
  int? get activePointerId => _activePointerId;
  int? get lastStylusTimestamp => _lastStylusTimestamp;

  /// Checks if palm rejection should suppress a touch pointer
  bool isPalmContact(PointerEvent event) {
    if (!enablePalmRejection) return false;

    // Stylus is NEVER a palm
    final isStylus = event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus ||
        ((event.kind == PointerDeviceKind.touch || event.kind == PointerDeviceKind.unknown) &&
            ((event.pressure > 0.0 && event.pressure != 0.5 && event.pressure != 1.0) || event.tilt > 0.0));

    if (isStylus) {
      return false;
    }

    // 1. If a stylus is currently actively down on screen, reject simultaneous secondary touches (palm while writing)
    if (_isStylusActive && _activePointerId != null && event.pointer != _activePointerId) {
      return true;
    }

    // 2. Physical palm contact patch filter: only suppress massive resting palm area (>60px major / >40px minor)
    if (event.kind == PointerDeviceKind.touch) {
      if (event.radiusMajor > 60.0 && event.radiusMinor > 40.0) {
        return true;
      }
    }

    return false;
  }

  /// Starts processing a new stroke gesture
  StrokePoint? onPointerDown(PointerDownEvent event, Offset worldPosition, {bool isGuaranteedStylus = false}) {
    // Cleanly reset any previous pointer when a new rapid stroke begins
    if (_activePointerId != null && _activePointerId != event.pointer) {
      forceReset();
    }

    if (!isGuaranteedStylus && isPalmContact(event)) {
      return null;
    }

    final isStylus = isGuaranteedStylus ||
        event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus ||
        ((event.kind == PointerDeviceKind.touch || event.kind == PointerDeviceKind.unknown) &&
            ((event.pressure > 0.0 && event.pressure != 0.5 && event.pressure != 1.0) || event.tilt > 0.0));
    if (isStylus) {
      _isStylusActive = true;
      _lastStylusTimestamp = DateTime.now().millisecondsSinceEpoch;
    } else {
      _isStylusActive = false;
    }

    _activePointerId = event.pointer;
    smoother.reset();
    _lastPosition = worldPosition;
    _lastTimestamp = event.timeStamp.inMilliseconds;
    _filteredVelocity = 0.0;

    final rawPressure = _extractPressure(event);
    _filteredPressure = rawPressure;
    // Track whether the initial pressure was a fallback sentinel (0.50) so we can
    // re-seed the EMA filter when real pressure data arrives in onPointerMove.
    _initialPressureWasFallback = isStylus && (rawPressure == 0.50);
    final tilt = _extractTilt(event);

    final rawPoint = StrokePoint(
      x: worldPosition.dx,
      y: worldPosition.dy,
      pressure: _filteredPressure,
      tilt: tilt,
      velocity: 0.0,
      isStylus: isStylus,
      timestamp: _lastTimestamp,
    );

    return smoother.filter(rawPoint);
  }

  /// Processes moving pointer event, updating velocity, smoothing position and pressure
  StrokePoint? onPointerMove(PointerMoveEvent event, Offset worldPosition) {
    if (_activePointerId != null && event.pointer != _activePointerId) {
      return null; // Ignore secondary pointers while drawing
    }

    final isStylus = event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus ||
        ((event.kind == PointerDeviceKind.touch || event.kind == PointerDeviceKind.unknown) &&
            ((event.pressure > 0.0 && event.pressure != 0.5 && event.pressure != 1.0) || event.tilt > 0.0));
    if (isStylus) {
      _isStylusActive = true;
      _lastStylusTimestamp = DateTime.now().millisecondsSinceEpoch;
    }

    final now = event.timeStamp.inMilliseconds;
    final dt = _lastTimestamp != null ? (now - _lastTimestamp!).clamp(1, 100) : 16;
    final prevPos = _lastPosition ?? worldPosition;

    final dx = worldPosition.dx - prevPos.dx;
    final dy = worldPosition.dy - prevPos.dy;
    final dist = Offset(dx, dy).distance;

    // Velocity in pixels / ms
    final instantVelocity = dist / dt;
    _filteredVelocity = (_filteredVelocity * 0.7) + (instantVelocity * 0.3);

    _lastPosition = worldPosition;
    _lastTimestamp = now;

    final rawPressure = _extractPressure(event);
    
    // If the stroke started with 0.50 fallback (because WebKit/Safari zeroes initial pressure)
    // and we now have a real pressure reading, re-seed the EMA completely instead of polluting
    // it with the 0.50 artificial start.
    if (_initialPressureWasFallback && rawPressure != 0.50 && rawPressure > 0.0) {
      _filteredPressure = rawPressure;
      _initialPressureWasFallback = false;
    } else {
      // Smooth pressure with responsive EMA (0.25 past + 0.75 current) for zero-lag 120Hz/240Hz iPad handwriting
      _filteredPressure = (_filteredPressure * 0.25) + (rawPressure * 0.75);
    }
    
    final tilt = _extractTilt(event);

    final rawPoint = StrokePoint(
      x: worldPosition.dx,
      y: worldPosition.dy,
      pressure: _filteredPressure,
      tilt: tilt,
      velocity: _filteredVelocity,
      isStylus: isStylus,
      timestamp: now,
    );

    return smoother.filter(rawPoint);
  }

  /// Concludes active stroke gesture
  StrokePoint? onPointerUp(PointerUpEvent event, Offset worldPosition) {
    if (_activePointerId != null && event.pointer != _activePointerId) {
      return null;
    }

    final isStylus = _isStylusActive ||
        event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus;

    final now = event.timeStamp.inMilliseconds;
    final rawPressure = _extractPressure(event);
    _filteredPressure = (_filteredPressure * 0.35) + (rawPressure * 0.65);
    final tilt = _extractTilt(event);

    final rawPoint = StrokePoint(
      x: worldPosition.dx,
      y: worldPosition.dy,
      pressure: _filteredPressure,
      tilt: tilt,
      velocity: _filteredVelocity,
      isStylus: isStylus,
      timestamp: now,
    );

    final finalPoint = smoother.filter(rawPoint);

    _activePointerId = null;
    _lastPosition = null;
    _lastTimestamp = null;
    _isStylusActive = false;
    _lastStylusTimestamp = DateTime.now().millisecondsSinceEpoch;

    return finalPoint;
  }

  /// Resets input processor state when gesture is cancelled
  void onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _activePointerId) {
      _activePointerId = null;
      _lastPosition = null;
      _lastTimestamp = null;
      _isStylusActive = false;
      _lastStylusTimestamp = DateTime.now().millisecondsSinceEpoch;
      smoother.reset();
    }
  }

  /// Forcefully clears any active pointers to resolve ghost touches / frozen canvas state
  void forceReset() {
    _activePointerId = null;
    _lastPosition = null;
    _lastTimestamp = null;
    _isStylusActive = false;
    smoother.reset();
  }

  /// Extracts smooth normalized pressure from pointer event (0.04 - 1.0)
  double _extractPressure(PointerEvent event) {
    final isStylus = _isStylusActive ||
        event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus ||
        ((event.kind == PointerDeviceKind.touch || event.kind == PointerDeviceKind.unknown) &&
            ((event.pressure > 0.0 && event.pressure != 0.5 && event.pressure != 1.0) || event.tilt > 0.0));

    if (isStylus) {
      if (event.pressureMax > event.pressureMin) {
        final norm = (event.pressure - event.pressureMin) / (event.pressureMax - event.pressureMin);
        if (norm.isNaN) return 0.50;
        if (norm <= 0.001) {
          return event.pressure > 0.0 ? 0.08 : 0.50;
        }
        return norm.clamp(0.04, 1.0);
      }
      if (event.pressure > 0.0 && !event.pressure.isNaN) {
        return event.pressure.clamp(0.04, 1.0);
      }
      return 0.50;
    }

    // Touch or mouse input
    if (event.pressureMax > event.pressureMin && event.pressure > 0.0 && event.pressure != 0.5) {
      final p = ((event.pressure - event.pressureMin) / (event.pressureMax - event.pressureMin)).clamp(0.04, 1.0);
      if (!p.isNaN) return p;
    }

    return 0.50; // Neutral constant for non-pressure devices
  }

  /// Extracts tilt angle normalized to 0.0 - 1.0 (where 1.0 = pi/2 horizontal shading)
  double _extractTilt(PointerEvent event) {
    final tilt = event.tilt;
    if (tilt.isNaN || tilt <= 0.0) return 0.0;
    return (tilt / 1.5707963).clamp(0.0, 1.0); // pi / 2 max tilt
  }
}
