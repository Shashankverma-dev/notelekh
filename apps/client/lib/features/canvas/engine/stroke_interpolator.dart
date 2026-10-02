import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';

/// Catmull-Rom spline interpolator for generating smooth, continuous curves
/// from discrete pointer samples.
class StrokeInterpolator {
  /// Interpolates smooth curve points between raw sampled points.
  /// Uses adaptive segment calculation based on point-to-point distance.
  static List<StrokePoint> interpolate(List<StrokePoint> points, {int defaultSegments = 6}) {
    if (points.length < 2) return points;

    final result = <StrokePoint>[];

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : points[i + 1];

      if (i == 0) result.add(p1);

      // Adaptive segment density based on Euclidean distance
      final dx = p2.x - p1.x;
      final dy = p2.y - p1.y;
      final dist = dx * dx + dy * dy; // squared distance

      int segments = defaultSegments;
      if (dist < 16) {
        segments = 2; // Very short movement
      } else if (dist > 400) {
        segments = 10; // Large fast jump
      }

      for (int j = 1; j <= segments; j++) {
        final t = j / segments;
        final t2 = t * t;
        final t3 = t2 * t;

        // Catmull-Rom matrix calculation
        final x = 0.5 * (
          (2 * p1.x) +
          (-p0.x + p2.x) * t +
          (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 +
          (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3
        );

        final y = 0.5 * (
          (2 * p1.y) +
          (-p0.y + p2.y) * t +
          (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 +
          (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3
        );

        final pressure = _lerp(p1.pressure, p2.pressure, t);
        final velocity = _lerp(p1.velocity, p2.velocity, t);
        final tilt = _lerp(p1.tilt, p2.tilt, t);
        final timestamp = (p1.timestamp + (p2.timestamp - p1.timestamp) * t).round();

        result.add(StrokePoint(
          x: x,
          y: y,
          pressure: pressure,
          velocity: velocity,
          tilt: tilt,
          timestamp: timestamp,
          isStylus: p1.isStylus,
        ));
      }
    }

    return result;
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
