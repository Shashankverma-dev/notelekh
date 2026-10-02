import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:ai_workspace_client/features/canvas/engine/pressure_engine.dart';
import 'package:ai_workspace_client/features/canvas/engine/stroke_interpolator.dart';
import 'package:ai_workspace_client/features/canvas/engine/stroke_renderer.dart';

export 'package:ai_workspace_client/features/canvas/engine/pressure_engine.dart';
export 'package:ai_workspace_client/features/canvas/engine/stroke_interpolator.dart';
export 'package:ai_workspace_client/features/canvas/engine/stroke_smoother.dart';
export 'package:ai_workspace_client/features/canvas/engine/stroke_renderer.dart';
export 'package:ai_workspace_client/features/canvas/engine/input_processor.dart';

/// Facade for the modular stroke engine, providing convenient backward-compatible entrypoints.
class StrokeEngine {
  static double applyPressureCurve(double rawPressure, PressureSensitivity sensitivity) {
    return PressureEngine.applyPressureCurve(rawPressure, sensitivity);
  }

  static List<StrokePoint> interpolate(List<StrokePoint> raw, {int segments = 6}) {
    return StrokeInterpolator.interpolate(raw, defaultSegments: segments);
  }

  /// Calculates velocities between consecutive stroke points
  static List<StrokePoint> injectVelocity(List<StrokePoint> points) {
    if (points.length < 2) return points;

    final result = <StrokePoint>[];
    double runningVelocity = 0.0;

    for (int i = 0; i < points.length; i++) {
      if (i == 0) {
        result.add(points[0]);
        continue;
      }

      final prev = points[i - 1];
      final curr = points[i];

      final dt = (curr.timestamp - prev.timestamp).clamp(1, 100);
      final dx = curr.x - prev.x;
      final dy = curr.y - prev.y;
      final dist = Offset(dx, dy).distance;

      final instantVelocity = dist / dt;
      runningVelocity = (runningVelocity * 0.6) + (instantVelocity * 0.4);

      result.add(curr.copyWith(velocity: runningVelocity));
    }

    return result;
  }

  static double computeWidth(
    double baseWidth,
    StrokePoint point,
    PenType penType,
    PressureSensitivity sensitivity,
  ) {
    return PressureEngine.computeWidth(
      baseWidth: baseWidth,
      point: point,
      penType: penType,
      sensitivity: sensitivity,
    );
  }

  static void drawVariableWidthStroke(
    Canvas canvas,
    CanvasStrokeItem stroke,
    PressureSensitivity sensitivity, {
    Rect? viewport,
    bool isLive = false,
    double tipSharpness = 0.75,
    double tipFlatness = 0.66,
  }) {
    final pointsToDraw = stroke.points.length > 2
        ? (stroke.cachedInterpolatedPoints ??=
            StrokeInterpolator.interpolate(stroke.points, defaultSegments: 4))
        : stroke.points;

    StrokeRenderer.drawStroke(
      canvas: canvas,
      points: pointsToDraw,
      color: stroke.color,
      baseWidth: stroke.strokeWidth,
      penType: stroke.penType,
      opacity: stroke.opacity,
      sensitivity: sensitivity,
      tool: stroke.tool,
      viewport: viewport,
      tipSharpness: tipSharpness,
      tipFlatness: tipFlatness,
      isLive: isLive,
    );
  }

  static void drawLiveStroke(
    Canvas canvas,
    List<StrokePoint> points,
    Color color,
    double baseWidth,
    PenType penType,
    double opacity,
    PressureSensitivity sensitivity, {
    String tool = 'pen',
    double tipSharpness = 0.75,
    double tipFlatness = 0.66,
  }) {
    final smoothPoints = points.length > 2
        ? StrokeInterpolator.interpolate(points, defaultSegments: 4)
        : points;
    StrokeRenderer.drawStroke(
      canvas: canvas,
      points: smoothPoints,
      color: color,
      baseWidth: baseWidth,
      penType: penType,
      opacity: opacity,
      sensitivity: sensitivity,
      tool: tool,
      tipSharpness: tipSharpness,
      tipFlatness: tipFlatness,
    );
  }
}
