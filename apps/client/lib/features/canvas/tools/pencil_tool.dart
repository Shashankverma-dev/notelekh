import 'dart:ui';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke.dart';
import 'package:ai_workspace_client/features/canvas/engine/stroke_engine.dart';

/// Handles realistic pencil sketching interactions with tilt and texture sensitivity.
class PencilTool {
  final double baseWidth;
  final Color color;
  final double opacity;

  const PencilTool({
    this.baseWidth = 2.0,
    this.color = const Color(0xFF475569),
    this.opacity = 0.85,
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
      tool: 'pencil',
      penType: PenType.pencil,
    );
  }
}
