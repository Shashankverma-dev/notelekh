import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:ai_workspace_client/features/canvas/engine/pressure_engine.dart';

/// Static reusable flat buffers for zero-allocation vector spline ribbon rendering.
/// Eliminates thousands of heap object allocations (Offset, List) per second at 120Hz/240Hz,
/// completely removing GC pauses during fast iPad/stylus handwriting.
class _StrokeBuffer {
  static Float64List distances = Float64List(256);
  static Float64List widths = Float64List(256);
  static Float64List nx = Float64List(256);
  static Float64List ny = Float64List(256);
  static Float64List cleanNx = Float64List(256);
  static Float64List cleanNy = Float64List(256);
  static Float64List leftX = Float64List(256);
  static Float64List leftY = Float64List(256);
  static Float64List rightX = Float64List(256);
  static Float64List rightY = Float64List(256);

  static void ensureCapacity(int count) {
    if (distances.length < count) {
      final newCap = math.max(count * 2, 512);
      distances = Float64List(newCap);
      widths = Float64List(newCap);
      nx = Float64List(newCap);
      ny = Float64List(newCap);
      cleanNx = Float64List(newCap);
      cleanNy = Float64List(newCap);
      leftX = Float64List(newCap);
      leftY = Float64List(newCap);
      rightX = Float64List(newCap);
      rightY = Float64List(newCap);
    }
  }
}

/// Professional, native-grade vector stroke renderer.
///
/// Uses G1-continuous quadratic Bézier spline outlines, tangent-averaged normal
/// vectors, and pen-specific physical models (Fountain, Ballpoint, Brush, Pencil, Highlighter).
///
/// Produces razor-sharp, anti-aliased vector ink at all zoom scales (100% to 800%)
/// with ZERO overlapping disc artifacts ("beads on a string").
class StrokeRenderer {
  /// Draws a committed or live stroke with full variable-width physics and styling.
  static void drawStroke({
    required Canvas canvas,
    required List<StrokePoint> points,
    required Color color,
    required double baseWidth,
    required PenType penType,
    required double opacity,
    required PressureSensitivity sensitivity,
    String tool = 'pen',
    Rect? viewport,
    double tipSharpness = 0.75,
    double tipFlatness = 0.66,
    bool isLive = false,
  }) {
    if (points.isEmpty) return;

    // Viewport culling check if viewport is supplied
    if (viewport != null && points.length > 1) {
      double minX = points.first.x;
      double maxX = points.first.x;
      double minY = points.first.y;
      double maxY = points.first.y;
      for (final p in points) {
        if (p.x < minX) minX = p.x;
        if (p.x > maxX) maxX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.y > maxY) maxY = p.y;
      }
      final bbox = Rect.fromLTRB(
        minX - baseWidth * 3,
        minY - baseWidth * 3,
        maxX + baseWidth * 3,
        maxY + baseWidth * 3,
      );
      if (!viewport.overlaps(bbox)) {
        return; // Cull stroke outside viewport
      }
    }

    // Special single dot/tap rendering
    if (points.length == 1) {
      _drawSingleDot(canvas, points.first, color, baseWidth, opacity, penType, sensitivity);
      return;
    }

    // Highlighter path
    if (tool == 'highlighter') {
      _drawHighlighter(canvas, points, color, baseWidth, opacity);
      return;
    }

    // Pencil textured rendering
    if (penType == PenType.pencil || tool == 'pencil') {
      _drawPencilStroke(canvas, points, color, baseWidth, opacity, sensitivity, isLive: isLive);
      return;
    }

    // Dedicated Ballpoint renderer: uniform crisp stroke width, zero distortion or sausage pinching
    // If user configured Tip Sharpness or Pressure Sensitivity on Ball Pen, render with spline ribbon
    if (penType == PenType.ballpoint && tipSharpness <= 0.02 && sensitivity == PressureSensitivity.off) {
      _drawBallpointStroke(
        canvas: canvas,
        points: points,
        color: color,
        baseWidth: baseWidth,
        opacity: opacity,
        sensitivity: sensitivity,
      );
      return;
    }

    // Standard smooth vector spline ribbon for Fountain Pen and Brush Pen
    _drawSplineRibbon(
      canvas: canvas,
      points: points,
      color: color,
      baseWidth: baseWidth,
      opacity: opacity,
      penType: penType,
      sensitivity: sensitivity,
      tipSharpness: tipSharpness,
      tipFlatness: tipFlatness,
    );
  }

  /// Dedicated native vector renderer for GoodNotes Ballpoint Pen.
  /// Produces uniform, crisp line width, zero spline distortion or pinching,
  /// and perfectly rounded caps and joins.
  static void _drawBallpointStroke({
    required Canvas canvas,
    required List<StrokePoint> points,
    required Color color,
    required double baseWidth,
    required double opacity,
    required PressureSensitivity sensitivity,
  }) {
    final count = points.length;
    if (count < 2) return;

    final paint = Paint()
      ..color = color.withValues(alpha: opacity.clamp(0.0, 1.0))
      ..strokeWidth = baseWidth.clamp(0.6, 120.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final path = Path();
    path.moveTo(points[0].x, points[0].y);

    if (count == 2) {
      path.lineTo(points[1].x, points[1].y);
    } else {
      for (int i = 0; i < count - 1; i++) {
        final p0 = points[i].toOffset();
        final p1 = points[i + 1].toOffset();
        final mid = Offset((p0.dx + p1.dx) / 2.0, (p0.dy + p1.dy) / 2.0);
        if (i == 0) {
          path.lineTo(mid.dx, mid.dy);
        } else {
          path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
        }
      }
      path.lineTo(points.last.x, points.last.y);
    }

    canvas.drawPath(path, paint);
  }

  /// Draws single tap dot with clean anti-aliased round cap or textured graphite mark
  static void _drawSingleDot(
    Canvas canvas,
    StrokePoint point,
    Color color,
    double baseWidth,
    double opacity,
    PenType penType,
    PressureSensitivity sensitivity,
  ) {
    final width = PressureEngine.computeWidth(
      baseWidth: baseWidth,
      point: point,
      penType: penType,
      sensitivity: sensitivity,
    );
    final offset = point.toOffset();
    final r = (width / 2).clamp(0.6, 60.0);

    if (penType == PenType.pencil) {
      // Soft feathered graphite halo (lead contact on paper tooth)
      final haloPaint = Paint()
        ..color = color.withValues(alpha: (opacity * 0.25).clamp(0.04, 0.40))
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawCircle(offset, r * 1.35, haloPaint);

      // Core graphite dot
      final corePaint = Paint()
        ..color = color.withValues(alpha: (opacity * 0.72).clamp(0.12, 0.95))
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawCircle(offset, r, corePaint);

      // Micro-texture grain on dot
      final grainPaint = Paint()
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      for (int k = 0; k < 6; k++) {
        final angle = (k * 1.047) + 0.25;
        final dist = r * (0.35 + 0.45 * math.sin(k * 2.71));
        final gx = offset.dx + math.cos(angle) * dist;
        final gy = offset.dy + math.sin(angle) * dist;
        final h = _stochasticHash(gx * 3.1, gy * 3.1);
        grainPaint.color = color.withValues(alpha: (opacity * (0.20 + h * 0.40)).clamp(0.05, 0.85));
        canvas.drawCircle(Offset(gx, gy), 0.50 + h * 0.40, grainPaint);
      }
      return;
    }

    final paint = Paint()
      ..color = color.withValues(alpha: opacity.clamp(0.0, 1.0))
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawCircle(offset, r, paint);
  }

  /// Silky-smooth vector ribbon outline using G1 quadratic Bézier curve interpolation
  /// between boundary vertices with tangent-averaged normals.
  /// Uses distance-based arc-length tapering for authentic GoodNotes Tip Sharpness
  /// and 45-degree chisel angle modulation for authentic GoodNotes Tip Flatness.
  static void _drawSplineRibbon({
    required Canvas canvas,
    required List<StrokePoint> points,
    required Color color,
    required double baseWidth,
    required double opacity,
    required PenType penType,
    required PressureSensitivity sensitivity,
    double tipSharpness = 0.75,
    double tipFlatness = 0.66,
  }) {
    final count = points.length;
    if (count < 2) return;

    _StrokeBuffer.ensureCapacity(count);
    final distances = _StrokeBuffer.distances;
    final widths = _StrokeBuffer.widths;
    final nx = _StrokeBuffer.nx;
    final ny = _StrokeBuffer.ny;
    final cleanNx = _StrokeBuffer.cleanNx;
    final cleanNy = _StrokeBuffer.cleanNy;
    final leftX = _StrokeBuffer.leftX;
    final leftY = _StrokeBuffer.leftY;
    final rightX = _StrokeBuffer.rightX;
    final rightY = _StrokeBuffer.rightY;

    // 1. Calculate cumulative arc-length distances along the spine
    distances[0] = 0.0;
    for (int i = 1; i < count; i++) {
      final dx = points[i].x - points[i - 1].x;
      final dy = points[i].y - points[i - 1].y;
      distances[i] = distances[i - 1] + math.sqrt(dx * dx + dy * dy);
    }
    final totalLength = distances[count - 1];

    // 2. Calculate per-point stroke widths with GoodNotes physical pen models
    for (int i = 0; i < count; i++) {
      double w = PressureEngine.computeWidth(
        baseWidth: baseWidth,
        point: points[i],
        penType: penType,
        sensitivity: sensitivity,
      );

      // Distance-based Entrance & Exit Tapering (Tip Sharpness)
      if (penType == PenType.fountainPen) {
        if (tipSharpness > 0.02 && totalLength > 4.0) {
          final inTaperDist = (baseWidth * 2.2 + 25.0 * tipSharpness).clamp(4.0, totalLength * 0.42);
          final outTaperDist = (baseWidth * 3.2 + 38.0 * tipSharpness).clamp(6.0, totalLength * 0.48);
          final minScale = (0.10 + (1.0 - tipSharpness) * 0.78).clamp(0.10, 1.0);

          if (distances[i] < inTaperDist) {
            final t = distances[i] / inTaperDist;
            final ease = t * (2.0 - t);
            w *= (minScale + (1.0 - minScale) * ease);
          }
          final distFromEnd = totalLength - distances[i];
          if (distFromEnd < outTaperDist) {
            final t = distFromEnd / outTaperDist;
            final ease = t * (2.0 - t);
            w *= (minScale + (1.0 - minScale) * ease);
          }
        }
      } else if (penType == PenType.brushPen) {
        if (tipSharpness > 0.02 && totalLength > 4.0) {
          final inTaperDist = (baseWidth * 2.0 + 20.0 * tipSharpness).clamp(4.0, totalLength * 0.38);
          final outTaperDist = (baseWidth * 4.5 + 55.0 * tipSharpness).clamp(10.0, totalLength * 0.50);
          final minScale = (0.06 + (1.0 - tipSharpness) * 0.74).clamp(0.06, 0.95);

          if (distances[i] < inTaperDist) {
            final t = distances[i] / inTaperDist;
            final ease = t * (2.0 - t);
            w *= (minScale + (1.0 - minScale) * ease);
          }
          final distFromEnd = totalLength - distances[i];
          if (distFromEnd < outTaperDist) {
            final t = distFromEnd / outTaperDist;
            final ease = t * (2.0 - t);
            w *= (minScale + (1.0 - minScale) * ease);
          }
        }
      } else if (penType == PenType.ballpoint) {
        if (tipSharpness > 0.02 && totalLength > 4.0) {
          final inTaperDist = (baseWidth * 1.8 + 18.0 * tipSharpness).clamp(3.0, totalLength * 0.35);
          final outTaperDist = (baseWidth * 2.5 + 24.0 * tipSharpness).clamp(4.0, totalLength * 0.40);
          final minScale = (0.20 + (1.0 - tipSharpness) * 0.70).clamp(0.20, 1.0);

          if (distances[i] < inTaperDist) {
            final t = distances[i] / inTaperDist;
            final ease = t * (2.0 - t);
            w *= (minScale + (1.0 - minScale) * ease);
          }
          final distFromEnd = totalLength - distances[i];
          if (distFromEnd < outTaperDist) {
            final t = distFromEnd / outTaperDist;
            final ease = t * (2.0 - t);
            w *= (minScale + (1.0 - minScale) * ease);
          }
        }
      }

      // Tip Flatness (chisel angle modulation)
      if (tipFlatness > 0.02 && (penType == PenType.fountainPen || penType == PenType.brushPen)) {
        final double dirX, dirY;
        if (i == 0) {
          dirX = points[1].x - points[0].x;
          dirY = points[1].y - points[0].y;
        } else if (i == count - 1) {
          dirX = points[count - 1].x - points[count - 2].x;
          dirY = points[count - 1].y - points[count - 2].y;
        } else {
          dirX = points[i + 1].x - points[i - 1].x;
          dirY = points[i + 1].y - points[i - 1].y;
        }
        final dSq = dirX * dirX + dirY * dirY;
        if (dSq > 0.0001) {
          final angle = math.atan2(dirY, dirX);
          final angleDiff = angle - (math.pi / 4.0);
          final chiselFactor = 1.0 - (tipFlatness * 0.55 * math.pow(math.cos(angleDiff), 2).toDouble());
          w *= chiselFactor;
        }
      }

      widths[i] = w.clamp(0.4, 150.0);
    }

    // 3. Compute smooth unit normal vectors along the spine (Zero Heap Allocations)
    for (int i = 0; i < count; i++) {
      final double dirX, dirY;
      if (i == 0) {
        dirX = points[1].x - points[0].x;
        dirY = points[1].y - points[0].y;
      } else if (i == count - 1) {
        dirX = points[count - 1].x - points[count - 2].x;
        dirY = points[count - 1].y - points[count - 2].y;
      } else {
        dirX = points[i + 1].x - points[i - 1].x;
        dirY = points[i + 1].y - points[i - 1].y;
      }
      final d = math.sqrt(dirX * dirX + dirY * dirY);
      if (d > 0.0001) {
        nx[i] = -dirY / d;
        ny[i] = dirX / d;
      } else {
        nx[i] = (i > 0) ? nx[i - 1] : 0.0;
        ny[i] = (i > 0) ? ny[i - 1] : 1.0;
      }
    }

    // Moving average smoothing on normal vectors to eliminate angular jitter
    for (int i = 0; i < count; i++) {
      if (i == 0 || i == count - 1) {
        cleanNx[i] = nx[i];
        cleanNy[i] = ny[i];
      } else {
        final avgX = nx[i - 1] * 0.25 + nx[i] * 0.50 + nx[i + 1] * 0.25;
        final avgY = ny[i - 1] * 0.25 + ny[i] * 0.50 + ny[i + 1] * 0.25;
        final d = math.sqrt(avgX * avgX + avgY * avgY);
        if (d > 0.0001) {
          cleanNx[i] = avgX / d;
          cleanNy[i] = avgY / d;
        } else {
          cleanNx[i] = nx[i];
          cleanNy[i] = ny[i];
        }
      }
    }

    // 4. Compute left and right boundary curves
    for (int i = 0; i < count; i++) {
      final cx = points[i].x;
      final cy = points[i].y;
      final halfW = widths[i] / 2.0;
      leftX[i] = cx + cleanNx[i] * halfW;
      leftY[i] = cy + cleanNy[i] * halfW;
      rightX[i] = cx - cleanNx[i] * halfW;
      rightY[i] = cy - cleanNy[i] * halfW;
    }

    // 5. Build continuous anti-aliased closed spline vector path directly
    final path = Path();
    path.moveTo(leftX[0], leftY[0]);

    if (count == 2) {
      path.lineTo(leftX[1], leftY[1]);
    } else {
      for (int i = 0; i < count - 1; i++) {
        final midX = (leftX[i] + leftX[i + 1]) / 2.0;
        final midY = (leftY[i] + leftY[i + 1]) / 2.0;
        if (i == 0) {
          path.lineTo(midX, midY);
        } else {
          path.quadraticBezierTo(leftX[i], leftY[i], midX, midY);
        }
      }
      path.lineTo(leftX[count - 1], leftY[count - 1]);
    }

    // End cap
    final endRadius = widths[count - 1] / 2.0;
    if (endRadius < 1.2) {
      path.lineTo(rightX[count - 1], rightY[count - 1]);
    } else {
      final endX = points[count - 1].x;
      final endY = points[count - 1].y;
      final dirX = count > 1 ? points[count - 1].x - points[count - 2].x : 1.0;
      final dirY = count > 1 ? points[count - 1].y - points[count - 2].y : 0.0;
      final d = math.sqrt(dirX * dirX + dirY * dirY);
      final tanX = d > 0.0001 ? dirX / d : 1.0;
      final tanY = d > 0.0001 ? dirY / d : 0.0;
      final tipX = endX + tanX * endRadius;
      final tipY = endY + tanY * endRadius;
      path.quadraticBezierTo(tipX, tipY, rightX[count - 1], rightY[count - 1]);
    }

    // Backward along right boundary
    if (count == 2) {
      path.lineTo(rightX[0], rightY[0]);
    } else {
      for (int i = count - 1; i > 0; i--) {
        final midX = (rightX[i] + rightX[i - 1]) / 2.0;
        final midY = (rightY[i] + rightY[i - 1]) / 2.0;
        path.quadraticBezierTo(rightX[i], rightY[i], midX, midY);
      }
      path.lineTo(rightX[0], rightY[0]);
    }

    // Start cap
    final startRadius = widths[0] / 2.0;
    if (startRadius < 1.2) {
      path.lineTo(leftX[0], leftY[0]);
    } else {
      final startX = points[0].x;
      final startY = points[0].y;
      final dirX = count > 1 ? points[0].x - points[1].x : -1.0;
      final dirY = count > 1 ? points[0].y - points[1].y : 0.0;
      final d = math.sqrt(dirX * dirX + dirY * dirY);
      final tanX = d > 0.0001 ? dirX / d : -1.0;
      final tanY = d > 0.0001 ? dirY / d : 0.0;
      final tipX = startX + tanX * startRadius;
      final tipY = startY + tanY * startRadius;
      path.quadraticBezierTo(tipX, tipY, leftX[0], leftY[0]);
    }
    path.close();

    final paint = Paint()
      ..color = color.withValues(alpha: opacity.clamp(0.0, 1.0))
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(path, paint);
  }

  /// Highlighter with semi-transparent flat tint, multiply blend effect, and smooth rounded joints
  static void _drawHighlighter(
    Canvas canvas,
    List<StrokePoint> points,
    Color color,
    double baseWidth,
    double opacity,
  ) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = color.withValues(alpha: (opacity * 0.38).clamp(0.12, 0.55))
      ..strokeWidth = math.max(4.0, baseWidth)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final path = Path();
    path.moveTo(points.first.x, points.first.y);

    if (points.length == 2) {
      path.lineTo(points[1].x, points[1].y);
    } else {
      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i].toOffset();
        final p1 = points[i + 1].toOffset();
        final mid = Offset((p0.dx + p1.dx) / 2.0, (p0.dy + p1.dy) / 2.0);
        if (i == 0) {
          path.lineTo(mid.dx, mid.dy);
        } else {
          path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
        }
      }
      path.lineTo(points.last.x, points.last.y);
    }

    canvas.drawPath(path, paint);
  }

  /// Fast, deterministic pseudo-random hash in [0.0, 1.0) based on 2D coordinates.
  /// Eliminates frame-to-frame redraw flicker while giving real organic paper-tooth stippling.
  static double _stochasticHash(double x, double y) {
    final v = math.sin(x * 12.9898 + y * 78.233) * 43758.5453123;
    return v - v.floor();
  }

  /// Authentic GoodNotes iPad Pencil model with realistic graphite deposition,
  /// pressure-modulated paper-tooth grain, soft feathered lead edge, and Apple Pencil tilt shading.
  static void _drawPencilStroke(
    Canvas canvas,
    List<StrokePoint> points,
    Color color,
    double baseWidth,
    double opacity,
    PressureSensitivity sensitivity, {
    bool isLive = false,
  }) {
    final count = points.length;
    if (count < 2) return;

    final hasPressure = sensitivity != PressureSensitivity.off;
    final safeWidth = (baseWidth.isNaN || baseWidth <= 0.1) ? 2.5 : baseWidth;
    final safeOpacity = opacity.isNaN ? 0.85 : opacity.clamp(0.0, 1.0);

    // 1. Calculate per-point physical width, alpha, and tilt
    final widths = List<double>.filled(count, safeWidth, growable: false);
    final alphas = List<double>.filled(count, safeOpacity, growable: false);
    final tilts  = List<double>.filled(count, 0.0, growable: false);

    for (int i = 0; i < count; i++) {
      final pt = points[i];
      final rawP = pt.pressure;
      final hasRealPressure = hasPressure &&
          (pt.isStylus ? rawP > 0.0 : (rawP > 0.0 && rawP != 0.50 && rawP != 1.00));

      final double effPressure;
      if (hasRealPressure) {
        effPressure = PressureEngine.applyPressureCurve(rawP, sensitivity);
      } else {
        // Natural handwriting velocity response for mouse/touch
        final vel = pt.velocity.clamp(0.0, 5.0);
        effPressure = (0.32 + 0.68 * math.exp(-vel * 0.35)).clamp(0.12, 1.0);
      }

      final t = pt.tilt.clamp(0.0, 1.4);
      tilts[i] = t;

      // GoodNotes Apple Pencil tilt shading: expands into broad lead contact
      final tiltMult = t > 0.28 ? (1.0 + (t - 0.28) * 3.4).clamp(1.0, 4.2) : 1.0;
      widths[i] = (safeWidth * (0.62 + 0.72 * effPressure) * tiltMult).clamp(0.8, 52.0);

      final pAlpha = safeOpacity * (0.32 + 0.58 * effPressure);
      alphas[i] = (t > 0.28 ? pAlpha / math.sqrt(tiltMult) : pAlpha).clamp(0.10, 0.95);
    }

    // Natural tip entrance and exit tapers (light lead touch on touchdown and liftoff)
    if (count > 3) {
      widths[0] *= 0.65;
      alphas[0] *= 0.70;
      widths[1] *= 0.85;
      alphas[1] *= 0.88;
      widths[count - 1] *= 0.60;
      alphas[count - 1] *= 0.65;
    }

    // 2. LAYER 1: Broad Soft Graphite Feathering (The "Matte Paper Contact" Layer)
    // Slightly wider with soft alpha — immediately removes vector plastic edge
    final avgAlpha = alphas.reduce((a, b) => a + b) / count;
    final featherPaint = Paint()
      ..color = color.withValues(alpha: (avgAlpha * 0.22).clamp(0.03, 0.32))
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    for (int i = 0; i < count - 1; i++) {
      final p0 = points[i].toOffset();
      final p1 = points[i + 1].toOffset();
      if (p0.dx.isNaN || p0.dy.isNaN || p1.dx.isNaN || p1.dy.isNaN) continue;
      final segW = (widths[i] + widths[i + 1]) * 0.65; // ~1.3x width
      featherPaint.strokeWidth = segW;
      canvas.drawLine(p0, p1, featherPaint);
    }

    // 3. LAYER 2: Core Graphite Mark (Segmented variable-width & dynamic pressure)
    final corePaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    for (int i = 0; i < count - 1; i++) {
      final p0 = points[i].toOffset();
      final p1 = points[i + 1].toOffset();
      if (p0.dx.isNaN || p0.dy.isNaN || p1.dx.isNaN || p1.dy.isNaN) continue;
      final segW = (widths[i] + widths[i + 1]) / 2.0;
      final segAlpha = (alphas[i] + alphas[i + 1]) / 2.0;

      corePaint.color = color.withValues(alpha: segAlpha.clamp(0.0, 1.0));
      corePaint.strokeWidth = segW;
      canvas.drawLine(p0, p1, corePaint);
    }

    // 4. LAYER 3: Procedural Paper-Tooth Graphite Grain & Micro-Stippling
    // Simulates graphite particles catching on microscopic paper tooth fibers.
    // During fast live drawing, Layer 1 + Layer 2 provide complete authentic feathered graphite body.
    // We bypass procedural stippling during live stroke updates to guarantee 120Hz/240Hz zero-lag responsiveness.
    if (isLive) return;

    final grainPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (int i = 0; i < count - 1; i++) {
      final p0 = points[i].toOffset();
      final p1 = points[i + 1].toOffset();
      if (p0.dx.isNaN || p0.dy.isNaN || p1.dx.isNaN || p1.dy.isNaN) continue;
      final dx = p1.dx - p0.dx;
      final dy = p1.dy - p0.dy;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist < 0.6) continue;

      final nx = -dy / dist;
      final ny = dx / dist;

      final segW = (widths[i] + widths[i + 1]) / 2.0;
      final segAlpha = (alphas[i] + alphas[i + 1]) / 2.0;
      final segTilt = (tilts[i] + tilts[i + 1]) / 2.0;

      // Step along segment every ~2.6 px
      const stepSize = 2.6;
      final numSteps = (dist / stepSize).clamp(1, 40).toInt();

      for (int s = 0; s < numSteps; s++) {
        final frac = (s + 0.5) / numSteps;
        final cx = p0.dx + dx * frac;
        final cy = p0.dy + dy * frac;

        final h1 = _stochasticHash(cx * 1.37, cy * 1.37);
        final h2 = _stochasticHash(cx * 2.81 + 17.3, cy * 2.81 + 31.7);
        final h3 = _stochasticHash(cx * 4.19 + 73.1, cy * 4.19 + 11.9);

        // Lateral grain offset across the lead contact width
        final lateralOffset = (h1 - 0.5) * segW * 0.85;
        final grainX = cx + nx * lateralOffset;
        final grainY = cy + ny * lateralOffset;

        final grainR = (0.42 + h2 * 0.55).clamp(0.35, 1.25);
        final grainA = (segAlpha * (0.20 + h3 * 0.45)).clamp(0.04, 0.80);

        grainPaint.color = color.withValues(alpha: grainA);
        canvas.drawCircle(Offset(grainX, grainY), grainR, grainPaint);

        // GoodNotes Apple Pencil tilt shading: when tilted, deposit broad side-shading graphite swath
        if (segTilt > 0.28) {
          final extraH = _stochasticHash(cx * 0.73 + 5.1, cy * 0.73 + 89.4);
          final extraOffset = (extraH - 0.5) * segW * 1.35;
          final extraX = cx + nx * extraOffset;
          final extraY = cy + ny * extraOffset;
          final extraA = (segAlpha * (0.12 + h1 * 0.28)).clamp(0.02, 0.50);

          grainPaint.color = color.withValues(alpha: extraA);
          canvas.drawCircle(Offset(extraX, extraY), grainR * 1.15, grainPaint);
        }
      }
    }
  }
}
