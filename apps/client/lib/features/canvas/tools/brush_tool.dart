import 'dart:ui';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke.dart';
import 'package:ai_workspace_client/features/canvas/engine/stroke_engine.dart';

/// Handles calligraphy and artistic brush pen strokes with extreme dynamic range.
class BrushTool {
  final double baseWidth;
  final Color color;
  final double opacity;

  const BrushTool({
    this.baseWidth = 5.0,
    this.color = const Color(0xFF0F172A),
    this.opacity = 1.0,
  });

  CanvasStrokeItem createStroke({
    required String id,
    required List<StrokePoint> points,
    Color? overrideColor,
    double? overrideWidth,
    double? overrideOpacity,
  }) {
    final processedPoints = StrokeEngine.injectVelocity(points);
    return CanvasStrokeItem(
      id: id,
      points: processedPoints,
      color: overrideColor ?? color,
      strokeWidth: overrideWidth ?? baseWidth,
      opacity: overrideOpacity ?? opacity,
      tool: 'brush',
      penType: PenType.brushPen,
    );
  }
}
