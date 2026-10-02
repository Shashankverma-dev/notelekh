import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';

/// Real-time adaptive smoothing and stabilization filter to eliminate digitizer jitter,
/// touch quantization noise, and hand tremor without adding perceived input lag.
class StrokeSmoother {
  double _stabilization = 0.0;

  /// Stabilization level from 0.0 (0% / raw) to 1.0 (100% / max stabilization).
  double get stabilization => _stabilization;
  set stabilization(double val) {
    _stabilization = val.clamp(0.0, 1.0);
  }

  StrokePoint? _lastFilteredPoint;

  StrokeSmoother({double? stabilization, double? smoothingFactor}) {
    _stabilization = (stabilization ?? smoothingFactor ?? 0.0).clamp(0.0, 1.0);
  }

  /// Resets smoother state at the start of a new stroke gesture.
  void reset() {
    _lastFilteredPoint = null;
  }

  /// Processes a new raw point through an adaptive EMA filter.
  StrokePoint filter(StrokePoint raw) {
    if (_lastFilteredPoint == null) {
      _lastFilteredPoint = raw;
      return raw;
    }

    // At 0% stabilization, preserve raw handwriting immediately with zero lag
    if (_stabilization <= 0.01) {
      _lastFilteredPoint = raw;
      return raw;
    }

    final prev = _lastFilteredPoint!;
    final dx = raw.x - prev.x;
    final dy = raw.y - prev.y;
    final distSquared = dx * dx + dy * dy;

    // Sub-pixel deadband: ignore tiny micro-jitter (< 0.25 px) when holding steady
    if (distSquared < 0.0625) {
      return prev.copyWith(timestamp: raw.timestamp);
    }

    // Map stabilization [0.0, 1.0] to base EMA alpha [1.0, 0.08]
    final baseAlpha = (1.0 - _stabilization).clamp(0.08, 1.0);

    // Adaptive velocity compensation: When writing fast (cursive, flourishes, letters),
    // dynamically boost alpha towards 1.0 so fast strokes NEVER lag behind the pencil tip!
    final speed = raw.velocity.clamp(0.0, 5.0);
    final speedBoost = (speed / 1.6).clamp(0.0, 1.0);
    final effectiveAlpha = (baseAlpha + (1.0 - baseAlpha) * speedBoost).clamp(0.08, 1.0);

    final filteredX = prev.x + effectiveAlpha * dx;
    final filteredY = prev.y + effectiveAlpha * dy;
    final filteredPressure = prev.pressure + effectiveAlpha * (raw.pressure - prev.pressure);
    final filteredVelocity = prev.velocity + effectiveAlpha * (raw.velocity - prev.velocity);

    final filtered = StrokePoint(
      x: filteredX,
      y: filteredY,
      pressure: filteredPressure,
      velocity: filteredVelocity,
      tilt: raw.tilt,
      isStylus: raw.isStylus,
      timestamp: raw.timestamp,
    );

    _lastFilteredPoint = filtered;
    return filtered;
  }

  /// Batch smooths a completed list of points using a weighted moving window.
  static List<StrokePoint> smoothList(List<StrokePoint> points, {double stabilization = 0.0}) {
    if (points.length < 3 || stabilization <= 0.02) return points;

    final passes = stabilization > 0.55 ? 2 : 1;
    List<StrokePoint> current = points;

    for (int pass = 0; pass < passes; pass++) {
      final weight = (stabilization * 0.32).clamp(0.05, 0.32);
      final centerWeight = 1.0 - 2 * weight;

      final smoothed = <StrokePoint>[current.first];
      for (int i = 1; i < current.length - 1; i++) {
        final pPrev = current[i - 1];
        final pCurr = current[i];
        final pNext = current[i + 1];

        final x = weight * pPrev.x + centerWeight * pCurr.x + weight * pNext.x;
        final y = weight * pPrev.y + centerWeight * pCurr.y + weight * pNext.y;
        final pressure = weight * pPrev.pressure + centerWeight * pCurr.pressure + weight * pNext.pressure;
        final velocity = weight * pPrev.velocity + centerWeight * pCurr.velocity + weight * pNext.velocity;

        smoothed.add(StrokePoint(
          x: x,
          y: y,
          pressure: pressure,
          velocity: velocity,
          tilt: pCurr.tilt,
          isStylus: pCurr.isStylus,
          timestamp: pCurr.timestamp,
        ));
      }
      smoothed.add(current.last);
      current = smoothed;
    }
    return current;
  }
}
