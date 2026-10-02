import 'dart:math' as math;
import 'dart:ui';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke.dart';

/// Handles highlighter strokes with multiply blend simulation, wide widths,
/// and straight line snap assist.
class HighlighterTool {
  final double baseWidth;
  final Color color;
  final double opacity;

  const HighlighterTool({
    this.baseWidth = 24.0,
    this.color = const Color(0xFFFFEB3B),
    this.opacity = 0.40,
  });

  /// Snaps a sequence of highlighter points to a laser-straight line,
  /// with automatic horizontal text-alignment and vertical margin snapping.
  static List<StrokePoint> straightenPoints(List<StrokePoint> points) {
    if (points.length < 2) return points;
    final start = points.first;
    final end = points.last;

    final dx = (end.x - start.x).abs();
    final dy = (end.y - start.y).abs();

    double targetEndX = end.x;
    double targetEndY = end.y;

    // Horizontal text snapping (if angle is within ~22 degrees, snap to perfectly horizontal)
    if (dx > 12.0 && dy < dx * 0.40) {
      targetEndY = start.y;
    } else if (dy > 12.0 && dx < dy * 0.40) {
      // Vertical margin snapping
      targetEndX = start.x;
    }

    final count = math.max(6, points.length);
    final result = <StrokePoint>[];
    for (int i = 0; i < count; i++) {
      final t = i / (count - 1);
      result.add(StrokePoint(
        x: start.x + (targetEndX - start.x) * t,
        y: start.y + (targetEndY - start.y) * t,
        pressure: 0.5,
        velocity: 0.0,
        tilt: 0.0,
        timestamp: start.timestamp + ((end.timestamp - start.timestamp) * t).toInt(),
      ));
    }
    return result;
  }

  CanvasStrokeItem createStroke({
    required String id,
    required List<StrokePoint> points,
    Color? overrideColor,
    double? overrideWidth,
    double? overrideOpacity,
    bool snapStraight = false,
  }) {
    final finalPoints = snapStraight ? straightenPoints(points) : points;

    return CanvasStrokeItem(
      id: id,
      points: finalPoints,
      color: overrideColor ?? color,
      strokeWidth: overrideWidth ?? baseWidth,
      opacity: (overrideOpacity ?? opacity).clamp(0.1, 0.5),
      tool: 'highlighter',
      penType: PenType.marker,
    );
  }
}
