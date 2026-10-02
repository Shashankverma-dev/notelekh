import 'dart:math' as math;
import 'dart:ui';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';

enum RecognizedShapeType {
  line,
  circle,
  rectangle,
  triangle,
  none,
}

/// Handles shape generation and Goodnotes-style geometric shape recognition
/// from hand-drawn strokes.
class ShapeTool {
  /// Creates a clean geometric shape item
  static CanvasShapeItem createShape({
    required String id,
    required String shapeType, // 'rectangle', 'circle', 'triangle', 'star', 'line', 'arrow'
    required Rect bounds,
    required Color strokeColor,
    double strokeWidth = 2.5,
    Color? fillColor,
    double rotation = 0.0,
    Offset? startPoint,
    Offset? endPoint,
  }) {
    return CanvasShapeItem(
      id: id,
      shapeType: shapeType,
      bounds: bounds,
      strokeColor: strokeColor,
      strokeWidth: strokeWidth,
      fillColor: fillColor,
      rotation: rotation,
      startPoint: startPoint,
      endPoint: endPoint,
    );
  }

  /// Evaluates whether a user's hand-drawn stroke approximates a geometric shape.
  /// If recognized, returns a refined [CanvasShapeItem], or null if it's freeform.
  static CanvasShapeItem? recognizeShape({
    required String id,
    required List<StrokePoint> points,
    required Color strokeColor,
    double strokeWidth = 2.5,
  }) {
    if (points.length < 5) return null;

    final start = points.first.toOffset();
    final end = points.last.toOffset();
    final totalDistance = (end - start).distance;

    // Calculate total path length
    double pathLength = 0;
    for (int i = 0; i < points.length - 1; i++) {
      pathLength += (points[i + 1].toOffset() - points[i].toOffset()).distance;
    }

    if (pathLength == 0) return null;

    // 1. Check for straight line:
    // Compute maximum perpendicular deviation from the start-to-end line segment
    double maxDeviation = 0.0;
    final l2 = (end - start).distanceSquared;
    for (final p in points) {
      final offset = p.toOffset();
      double dist;
      if (l2 == 0) {
        dist = (offset - start).distance;
      } else {
        final t = (((offset.dx - start.dx) * (end.dx - start.dx) + (offset.dy - start.dy) * (end.dy - start.dy)) / l2).clamp(0.0, 1.0);
        final proj = Offset(start.dx + t * (end.dx - start.dx), start.dy + t * (end.dy - start.dy));
        dist = (offset - proj).distance;
      }
      if (dist > maxDeviation) maxDeviation = dist;
    }

    final isStraightByRatio = (totalDistance / pathLength) > 0.84;
    final isStraightByDeviation = totalDistance > 20.0 && maxDeviation < math.max(14.0, totalDistance * 0.10);

    // Only recognize as a straight line if it is open (not closed)
    final isOpen = totalDistance > math.max(35.0, pathLength * 0.25);
    if ((isStraightByRatio || isStraightByDeviation) && isOpen) {
      final rect = Rect.fromPoints(start, end);
      return CanvasShapeItem(
        id: id,
        shapeType: 'line',
        bounds: rect,
        strokeColor: strokeColor,
        strokeWidth: strokeWidth,
        startPoint: start,
        endPoint: end,
      );
    }

    // 2. Check for closed shapes (Rectangle, Square, Circle, Triangle)
    final offsets = points.map((p) => p.toOffset()).toList();
    double minX = offsets.first.dx, maxX = offsets.first.dx;
    double minY = offsets.first.dy, maxY = offsets.first.dy;
    double sumX = 0, sumY = 0;

    for (final p in offsets) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
      sumX += p.dx;
      sumY += p.dy;
    }

    final bbox = Rect.fromLTRB(minX, minY, maxX, maxY);
    final width = bbox.width;
    final height = bbox.height;

    if (width < 16 || height < 16) return null;

    // Stroke closure check:
    // A stroke is closed if start and end are close, or if the end point overlaps
    // the beginning of the stroke (common in hand-drawn circles and squares).
    double minGapToClose = (end - start).distance;
    final headCount = math.min(points.length ~/ 4, 25);
    for (int i = 0; i < headCount; i++) {
      final d = (end - points[i].toOffset()).distance;
      if (d < minGapToClose) minGapToClose = d;
    }
    final tailCount = math.max(0, points.length - headCount);
    for (int i = tailCount; i < points.length; i++) {
      final d = (start - points[i].toOffset()).distance;
      if (d < minGapToClose) minGapToClose = d;
    }

    final isClosed = minGapToClose < math.max(65.0, math.max(width, height) * 0.45) ||
        (minGapToClose < pathLength * 0.38);

    if (!isClosed) return null;

    final centroid = Offset(sumX / offsets.length, sumY / offsets.length);
    final bboxArea = width * height;

    // Shoelace polygon area formula
    double signedArea = 0.0;
    for (int i = 0; i < offsets.length; i++) {
      final next = (i + 1) % offsets.length;
      signedArea += offsets[i].dx * offsets[next].dy - offsets[next].dx * offsets[i].dy;
    }
    final polygonArea = signedArea.abs() / 2.0;
    final areaRatio = bboxArea > 0 ? (polygonArea / bboxArea) : 0.0;

    // Normalized Ellipse Distance & Fit Error:
    // For each point p, d_i = sqrt(((p.x - cx) / a)^2 + ((p.y - cy) / b)^2)
    // For any circle or ellipse: d_i ≈ 1.0 (mean error < 0.18, max dist < 1.30).
    // For a square or rectangle: corners have d_i ≈ sqrt(2) ≈ 1.414 (mean error > 0.22, max dist >= 1.35).
    // For a triangle: lines cut across, giving large variations and areaRatio <= 0.62.
    final a = width / 2.0;
    final b = height / 2.0;
    double sumEllipseErr = 0.0;
    double maxEllipseDist = 0.0;
    double minEllipseDist = double.infinity;

    for (final p in offsets) {
      final dx = (p.dx - centroid.dx) / (a > 0 ? a : 1.0);
      final dy = (p.dy - centroid.dy) / (b > 0 ? b : 1.0);
      final dist = math.sqrt(dx * dx + dy * dy);
      sumEllipseErr += (dist - 1.0).abs();
      if (dist > maxEllipseDist) maxEllipseDist = dist;
      if (dist < minEllipseDist) minEllipseDist = dist;
    }

    final ellipseFitError = sumEllipseErr / offsets.length;
    final corners = _detectCornersCyclic(offsets);

    // ─────────────────────────────────────────────────────────────────────────
    // GEOMETRIC SHAPE CLASSIFICATION:
    // ─────────────────────────────────────────────────────────────────────────

    // 1. Rectangle / Square Check:
    // Area fills almost the entire box (areaRatio >= 0.84) — impossible for circles (max π/4 ≈ 0.785)
    // OR 4 sharp corners detected and high ellipse corner deviation.
    final isSquareOrRectangle = areaRatio >= 0.84 ||
        (corners.length >= 4 && areaRatio >= 0.68 && ellipseFitError >= 0.16) ||
        (maxEllipseDist >= 1.34 && ellipseFitError >= 0.18 && areaRatio >= 0.72 && corners.length >= 3);

    if (isSquareOrRectangle) {
      final isSquare = (width - height).abs() / math.max(width, height) < 0.25;
      final finalBounds = isSquare
          ? Rect.fromCenter(
              center: bbox.center,
              width: (width + height) / 2.0,
              height: (width + height) / 2.0,
            )
          : bbox;

      return CanvasShapeItem(
        id: id,
        shapeType: 'rectangle',
        bounds: finalBounds,
        strokeColor: strokeColor,
        strokeWidth: strokeWidth,
      );
    }

    // 2. Circle / Ellipse Check:
    // Fits the ellipse equation with low error, bounded area ratio, and no 4 sharp corners.
    final isCircleOrEllipse = ellipseFitError < 0.22 &&
        maxEllipseDist < 1.32 &&
        areaRatio >= 0.55 &&
        areaRatio <= 0.85 &&
        corners.length <= 2;

    if (isCircleOrEllipse) {
      final isCircle = (width - height).abs() / math.max(width, height) < 0.25;
      final finalBounds = isCircle
          ? Rect.fromCenter(
              center: bbox.center,
              width: (width + height) / 2.0,
              height: (width + height) / 2.0,
            )
          : bbox;

      return CanvasShapeItem(
        id: id,
        shapeType: 'circle',
        bounds: finalBounds,
        strokeColor: strokeColor,
        strokeWidth: strokeWidth,
      );
    }

    // 3. Triangle Check:
    // Strictly bounded area ratio <= 0.62 (theoretical maximum for triangle is 0.50)
    // with 3 corners or strong angular variation.
    final isTriangle = (areaRatio <= 0.62 && areaRatio >= 0.20) &&
        (corners.length == 3 || (corners.length <= 3 && ellipseFitError >= 0.20));

    if (isTriangle) {
      return CanvasShapeItem(
        id: id,
        shapeType: 'triangle',
        bounds: bbox,
        strokeColor: strokeColor,
        strokeWidth: strokeWidth,
      );
    }

    // 4. Fallback for slightly imperfect hand drawings:
    // If ellipse fit is closer than rectangular box, classify as circle/ellipse!
    if (ellipseFitError < 0.20 && corners.length <= 3 && areaRatio <= 0.83) {
      final isCircle = (width - height).abs() / math.max(width, height) < 0.25;
      final finalBounds = isCircle
          ? Rect.fromCenter(
              center: bbox.center,
              width: (width + height) / 2.0,
              height: (width + height) / 2.0,
            )
          : bbox;

      return CanvasShapeItem(
        id: id,
        shapeType: 'circle',
        bounds: finalBounds,
        strokeColor: strokeColor,
        strokeWidth: strokeWidth,
      );
    } else if (areaRatio >= 0.78) {
      return CanvasShapeItem(
        id: id,
        shapeType: 'rectangle',
        bounds: bbox,
        strokeColor: strokeColor,
        strokeWidth: strokeWidth,
      );
    }

    return null;
  }

  /// Detects sharp corner vertices in a stroke with adaptive arc-length sampling
  static List<Offset> _detectCornersCyclic(List<Offset> points) {
    if (points.length < 8) return [];
    final corners = <Offset>[];
    final n = points.length;

    double totalLen = 0;
    for (int i = 0; i < n - 1; i++) {
      totalLen += (points[i + 1] - points[i]).distance;
    }
    final avgSpacing = totalLen / (n - 1);
    final int step = (avgSpacing > 0 ? (18.0 / avgSpacing).round() : (n / 16).round()).clamp(2, math.max(2, n ~/ 5)).toInt();

    for (int i = 0; i < n; i += math.max(1, step ~/ 2)) {
      final pPrev = points[(i - step + n) % n];
      final pCurr = points[i];
      final pNext = points[(i + step) % n];

      final v1 = pCurr - pPrev;
      final v2 = pNext - pCurr;

      if (v1.distance < 5.0 || v2.distance < 5.0) continue;

      final angle1 = math.atan2(v1.dy, v1.dx);
      final angle2 = math.atan2(v2.dy, v2.dx);

      double diff = (angle2 - angle1).abs();
      if (diff > math.pi) diff = 2 * math.pi - diff;

      // Sharp corner threshold (~54 degrees minimum turn)
      if (diff >= 0.95) {
        if (corners.every((c) => (c - pCurr).distance > 24.0)) {
          corners.add(pCurr);
        }
      }
    }

    return corners;
  }
}
