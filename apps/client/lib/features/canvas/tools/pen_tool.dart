import 'dart:ui';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke.dart';
import 'package:ai_workspace_client/features/canvas/engine/stroke_engine.dart';

/// Handles standard pen and fountain pen drawing interactions.
class PenTool {
  final PenType penType;
  final double baseWidth;
  final Color color;
  final double opacity;

  const PenTool({
    this.penType = PenType.fountainPen,
    this.baseWidth = 2.5,
    this.color = const Color(0xFF0F172A),
    this.opacity = 1.0,
  });

  CanvasStrokeItem createStroke({
    required String id,
    required List<StrokePoint> points,
    Color? overrideColor,
    double? overrideWidth,
    double? overrideOpacity,
    PenType? overridePenType,
  }) {
    final processedPoints = StrokeEngine.injectVelocity(points);
    return CanvasStrokeItem(
      id: id,
      points: processedPoints,
      color: overrideColor ?? color,
      strokeWidth: overrideWidth ?? baseWidth,
      opacity: overrideOpacity ?? opacity,
      tool: 'pen',
      penType: overridePenType ?? penType,
    );
  }
}
