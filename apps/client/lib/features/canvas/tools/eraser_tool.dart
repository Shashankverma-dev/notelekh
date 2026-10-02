import 'dart:math' as math;
import 'dart:ui';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';

/// Handles advanced eraser interactions: full stroke erase, segment slicing, and area erase.
class EraserTool {
  final EraserMode mode;
  final double radius;

  const EraserTool({
    this.mode = EraserMode.stroke,
    this.radius = 18.0,
  });

  /// Erases objects intersecting [point] with [eraserRadius].
  /// Returns the updated list of canvas objects.
  List<CanvasObjectItem> eraseAt({
    required Offset point,
    required List<CanvasObjectItem> objects,
    double? overrideRadius,
    EraserMode? overrideMode,
    bool eraseHighlighterOnly = false,
  }) {
    if (objects.isEmpty) return objects;
    final r = overrideRadius ?? radius;
    final m = overrideMode ?? mode;

    if (m == EraserMode.stroke) {
      return _eraseStrokeMode(point, r, objects, eraseHighlighterOnly);
    } else if (m == EraserMode.segment) {
      return _eraseSegmentMode(point, r, objects, eraseHighlighterOnly);
    } else {
      return _eraseStrokeMode(point, r, objects, eraseHighlighterOnly);
    }
  }

  /// Single-pass stroke-level erase (deletes entire stroke if touched)
  List<CanvasObjectItem> _eraseStrokeMode(
    Offset point,
    double r,
    List<CanvasObjectItem> objects,
    bool eraseHighlighterOnly,
  ) {
    List<CanvasObjectItem>? result;
    for (int i = 0; i < objects.length; i++) {
      final obj = objects[i];
      if (eraseHighlighterOnly && (obj is! CanvasStrokeItem || obj.tool != 'highlighter')) {
        result?.add(obj);
        continue;
      }
      if (obj.hits(point, padding: r)) {
        // Lazily allocate result list on first collision
        result ??= objects.sublist(0, i);
      } else {
        result?.add(obj);
      }
    }
    return result ?? objects;
  }

  /// Single-pass precision erase (slices touched strokes into sub-strokes at circle boundary)
  List<CanvasObjectItem> _eraseSegmentMode(
    Offset point,
    double r,
    List<CanvasObjectItem> objects,
    bool eraseHighlighterOnly,
  ) {
    List<CanvasObjectItem>? result;
    for (int i = 0; i < objects.length; i++) {
      final obj = objects[i];
      if (eraseHighlighterOnly && (obj is! CanvasStrokeItem || obj.tool != 'highlighter')) {
        result?.add(obj);
        continue;
      }
      if (obj is CanvasStrokeItem) {
        if (!obj.hits(point, padding: r)) {
          result?.add(obj);
        } else {
          result ??= objects.sublist(0, i);
          final split = _sliceStroke(obj, point, r);
          result.addAll(split);
        }
      } else {
        // Non-stroke objects (shapes, text, stickers) are removed entirely if hit
        if (obj.hits(point, padding: r)) {
          result ??= objects.sublist(0, i);
        } else {
          result?.add(obj);
        }
      }
    }
    return result ?? objects;
  }

  /// Erases all objects completely or partially contained within [area].
  List<CanvasObjectItem> eraseInArea({
    required Rect area,
    required List<CanvasObjectItem> objects,
  }) {
    return objects.where((obj) => !area.overlaps(obj.getBoundingBox())).toList();
  }

  /// High-precision stroke slicing using exact line-circle intersections.
  /// Cuts the stroke cleanly at the boundary of [eraserPos] with [eraserRadius].
  List<CanvasStrokeItem> _sliceStroke(
    CanvasStrokeItem stroke,
    Offset eraserPos,
    double eraserRadius,
  ) {
    final pts = stroke.points;
    if (pts.isEmpty) return const [];

    final rSq = eraserRadius * eraserRadius;

    // Fast path: single-point dot stroke
    if (pts.length == 1) {
      final p0 = pts.first.toOffset();
      final dx = p0.dx - eraserPos.dx;
      final dy = p0.dy - eraserPos.dy;
      if (dx * dx + dy * dy <= rSq) {
        return const [];
      }
      return [stroke];
    }

    final result = <CanvasStrokeItem>[];
    List<StrokePoint> currentSegment = [];
    int subIndex = 0;
    final baseId = stroke.id;

    void commitSegment() {
      if (currentSegment.length >= 2) {
        result.add(CanvasStrokeItem(
          id: '$baseId-s${subIndex++}',
          points: List<StrokePoint>.from(currentSegment),
          color: stroke.color,
          strokeWidth: stroke.strokeWidth,
          opacity: stroke.opacity,
          tool: stroke.tool,
          penType: stroke.penType,
          zIndex: stroke.zIndex,
        ));
      }
      currentSegment.clear();
    }

    for (int i = 0; i < pts.length - 1; i++) {
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final o1 = p1.toOffset();
      final o2 = p2.toOffset();

      final d1Sq = (o1.dx - eraserPos.dx) * (o1.dx - eraserPos.dx) +
          (o1.dy - eraserPos.dy) * (o1.dy - eraserPos.dy);
      final in1 = d1Sq <= rSq;

      if (!in1) {
        if (currentSegment.isEmpty || currentSegment.last != p1) {
          currentSegment.add(p1);
        }
      }

      // Line-circle analytical intersection for segment (o1 -> o2)
      final d = o2 - o1;
      final f = o1 - eraserPos;
      final a = d.dx * d.dx + d.dy * d.dy;
      final b = 2.0 * (f.dx * d.dx + f.dy * d.dy);
      final c = (f.dx * f.dx + f.dy * f.dy) - rSq;
      final disc = b * b - 4.0 * a * c;

      if (a > 1e-6 && disc >= 0) {
        final sqrtDisc = math.sqrt(disc);
        final t1 = (-b - sqrtDisc) / (2.0 * a);
        final t2 = (-b + sqrtDisc) / (2.0 * a);

        // Entering circle
        if (t1 > 0.001 && t1 < 0.999) {
          final interPos = o1 + d * t1;
          final interPressure = p1.pressure + (p2.pressure - p1.pressure) * t1;
          currentSegment.add(StrokePoint(
            x: interPos.dx,
            y: interPos.dy,
            pressure: interPressure,
            timestamp: p1.timestamp + ((p2.timestamp - p1.timestamp) * t1).round(),
          ));
          commitSegment();
        }

        // Exiting circle
        if (t2 > 0.001 && t2 < 0.999) {
          final interPos = o1 + d * t2;
          final interPressure = p1.pressure + (p2.pressure - p1.pressure) * t2;
          currentSegment.add(StrokePoint(
            x: interPos.dx,
            y: interPos.dy,
            pressure: interPressure,
            timestamp: p1.timestamp + ((p2.timestamp - p1.timestamp) * t2).round(),
          ));
        }
      }
    }

    // Process last point
    final lastPt = pts.last;
    final lastOff = lastPt.toOffset();
    final dLastSq = (lastOff.dx - eraserPos.dx) * (lastOff.dx - eraserPos.dx) +
        (lastOff.dy - eraserPos.dy) * (lastOff.dy - eraserPos.dy);
    if (dLastSq > rSq) {
      if (currentSegment.isEmpty || currentSegment.last != lastPt) {
        currentSegment.add(lastPt);
      }
    }
    commitSegment();

    // If stroke wasn't sliced at all and has exact same points
    if (result.length == 1 && result.first.points.length == pts.length) {
      return [stroke];
    }
    return result;
  }
}
