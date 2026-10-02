import 'dart:math' as math;
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';

/// Handles digitizer pressure calculation, curve transformations, and fallback logic.
///
/// Designed so pressure is strictly optional:
/// - If device provides real pressure -> applied through S-curve/power curve.
/// - If pressure is unavailable (mouse/finger) -> velocity modulation or steady base width.
class PressureEngine {
  /// Normalize raw digitizer pressure (0.0 to 1.0).
  static double applyPressureCurve(double rawPressure, PressureSensitivity sensitivity) {
    final p = rawPressure.clamp(0.0, 1.0);
    switch (sensitivity) {
      case PressureSensitivity.off:
        return 0.5; // Neutral constant
      case PressureSensitivity.low:
        // Gentle response (0.35 -> 0.65)
        return 0.35 + p * 0.30;
      case PressureSensitivity.medium:
        // Natural ergonomic S-curve
        return _sCurve(p);
      case PressureSensitivity.high:
        // Highly dynamic power curve (0.60 exponent)
        return math.pow(p, 0.60).toDouble();
      case PressureSensitivity.custom:
        return _sCurve(p);
    }
  }

  /// Hermite / smoothstep Goodnotes ergonomic hybrid curve: passes through (0,0), (0.5, 0.5), (1,1)
  /// with linear core slope (0.60 * t + 0.40 * S(t)) so natural light-medium handwriting [0.08, 0.65] is responsive
  static double _sCurve(double t) {
    final s = t * t * (3.0 - 2.0 * t);
    return (0.60 * t + 0.40 * s).clamp(0.0, 1.0);
  }

  /// Calculates dynamic stroke width for a specific point along a stroke.
  /// Handles digitizer pressure, velocity fallback for touch/mouse, and GoodNotes pen physics.
  static double computeWidth({
    required double baseWidth,
    required StrokePoint point,
    required PenType penType,
    required PressureSensitivity sensitivity,
    bool hasRealPressure = true,
  }) {
    if (sensitivity == PressureSensitivity.off) {
      return baseWidth;
    }

    // Velocity factor (px/ms): fast handwriting flicks naturally attenuate ink
    final vel = point.velocity.clamp(0.0, 6.0);
    final velDamp = math.exp(-vel * 0.35); // 1.0 at 0 vel, 0.70 at 1.0, 0.50 at 2.0, 0.35 at 3.0

    // Detect if device provides true analog digitizer pressure (Apple Pencil, S-Pen, Surface Pen, Wacom)
    final isAnalogPressure = hasRealPressure &&
        (point.isStylus ||
            (point.pressure > 0.0 && point.pressure != 0.50));

    // Effective pressure: S-curve for analog digitizer, or natural velocity modulation for mouse/touch
    final double effectivePressure;
    if (isAnalogPressure) {
      effectivePressure = applyPressureCurve(point.pressure, sensitivity) * (0.90 + 0.10 * velDamp);
    } else {
      // Natural handwriting velocity response for passive pencils & touch:
      // slow deliberate writing deposits rich ink (1.0), while rapid cursive flicks taper down gracefully (0.22).
      effectivePressure = (0.22 + 0.78 * velDamp).clamp(0.12, 1.0);
    }

    switch (penType) {
      case PenType.ballpoint:
        // GoodNotes Ballpoint: consistent crisp stroke with subtle pressure response on Apple Pencil & styluses
        if (isAnalogPressure) {
          final varianceScale = switch (sensitivity) {
            PressureSensitivity.off => 0.0,
            PressureSensitivity.low => 0.12,
            PressureSensitivity.medium => 0.24,
            PressureSensitivity.high => 0.38,
            PressureSensitivity.custom => 0.24,
          };
          if (varianceScale > 0.0) {
            final subtleVariance = (1.0 - varianceScale / 2.0) + effectivePressure * varianceScale;
            return (baseWidth * subtleVariance).clamp(baseWidth * 0.75, baseWidth * 1.35);
          }
        }
        return baseWidth;

      case PenType.fountainPen:
        // GoodNotes Fountain Pen: authentic split flexible metal nib.
        // Dynamic range: light upward flicks (0.35x) to heavy flex downstrokes (1.85x).
        if (isAnalogPressure) {
          final capFlow = 0.88 + 0.12 * velDamp;
          final factor = (0.35 + effectivePressure * 1.45) * capFlow;
          return (baseWidth * factor).clamp(math.max(1.0, baseWidth * 0.32), baseWidth * 2.0);
        } else {
          final factor = 0.32 + effectivePressure * 0.95;
          return (baseWidth * factor).clamp(math.max(1.0, baseWidth * 0.35), baseWidth * 1.75);
        }

      case PenType.brushPen:
        // GoodNotes Brush Pen: supple calligraphy bristles with high dynamic range.
        // Expressive hairlines (0.18x) expanding into broad strokes (2.85x).
        if (isAnalogPressure) {
          final factor = 0.18 + math.pow(effectivePressure, 1.55) * 2.67;
          return (baseWidth * factor).clamp(math.max(0.8, baseWidth * 0.16), baseWidth * 2.85);
        } else {
          final factor = 0.20 + math.pow(effectivePressure, 1.65) * 2.45;
          return (baseWidth * factor).clamp(math.max(0.8, baseWidth * 0.18), baseWidth * 2.65);
        }

      case PenType.pencil:
        // Graphite core with tilt shading variance
        final tiltFactor = 1.0 + (point.tilt * 0.40);
        final pFactor = 0.55 + (effectivePressure * 0.75);
        return (baseWidth * pFactor * tiltFactor).clamp(math.max(1.4, baseWidth * 0.40), baseWidth * 1.75);

      case PenType.marker:
        // Flat, uniform chisel marker width
        return baseWidth;
    }
  }
}
