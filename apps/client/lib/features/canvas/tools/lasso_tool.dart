import 'dart:ui';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';

/// Handles freehand lasso selection, polygon containment tests, and object transformations.
class LassoTool {
  /// Ray-casting algorithm to determine if a 2D point is inside an arbitrary closed polygon
  static bool isPointInsidePolygon(Offset point, List<Offset> polygon) {
    if (polygon.length < 3) return false;

    bool inside = false;
    final n = polygon.length;

    for (int i = 0, j = n - 1; i < n; j = i++) {
      final xi = polygon[i].dx, yi = polygon[i].dy;
      final xj = polygon[j].dx, yj = polygon[j].dy;

      final intersect = ((yi > point.dy) != (yj > point.dy)) &&
          (point.dx < (xj - xi) * (point.dy - yi) / (yj - yi) + xi);

      if (intersect) inside = !inside;
    }

    return inside;
  }

  /// Selects all canvas objects whose centers or bounding boxes intersect the lasso polygon
  static List<CanvasObjectItem> selectObjectsInLasso({
    required List<Offset> lassoPoints,
    required List<CanvasObjectItem> objects,
    bool Function(CanvasObjectItem)? filter,
  }) {
    if (lassoPoints.length < 3) return [];

    final selected = <CanvasObjectItem>[];

    for (final obj in objects) {
      if (filter != null && !filter(obj)) {
        continue;
      }
      final bbox = obj.getBoundingBox();
      final center = bbox.center;

      // Check center point or corners
      if (isPointInsidePolygon(center, lassoPoints) ||
          isPointInsidePolygon(bbox.topLeft, lassoPoints) ||
          isPointInsidePolygon(bbox.bottomRight, lassoPoints) ||
          isPointInsidePolygon(bbox.topRight, lassoPoints) ||
          isPointInsidePolygon(bbox.bottomLeft, lassoPoints)) {
        obj.isSelected = true;
        selected.add(obj);
      } else if (obj is CanvasStrokeItem) {
        // If any point in stroke is enclosed
        bool hit = false;
        for (final pt in obj.points) {
          if (isPointInsidePolygon(pt.toOffset(), lassoPoints)) {
            hit = true;
            break;
          }
        }
        if (hit) {
          obj.isSelected = true;
          selected.add(obj);
        }
      }
    }

    return selected;
  }

  /// Selects all canvas objects intersecting the selection rectangle, honoring [filter]
  static List<CanvasObjectItem> selectObjectsInRect({
    required Rect rect,
    required List<CanvasObjectItem> objects,
    bool Function(CanvasObjectItem)? filter,
  }) {
    final selected = <CanvasObjectItem>[];

    for (final obj in objects) {
      if (filter != null && !filter(obj)) {
        continue;
      }
      if (rect.overlaps(obj.getBoundingBox())) {
        obj.isSelected = true;
        selected.add(obj);
      }
    }

    return selected;
  }

  /// Moves selected objects by [delta]
  static void translateObjects(List<CanvasObjectItem> objects, Offset delta) {
    for (final obj in objects) {
      if (!obj.isSelected) continue;

      if (obj is CanvasStrokeItem) {
        for (int i = 0; i < obj.points.length; i++) {
          final pt = obj.points[i];
          obj.points[i] = StrokePoint(
            x: pt.x + delta.dx,
            y: pt.y + delta.dy,
            pressure: pt.pressure,
            tilt: pt.tilt,
            velocity: pt.velocity,
            timestamp: pt.timestamp,
          );
        }
      } else if (obj is CanvasTextItem) {
        obj.position = obj.position + delta;
      } else if (obj is CanvasNoteCardItem) {
        obj.position = obj.position + delta;
      }
    }
  }
}
