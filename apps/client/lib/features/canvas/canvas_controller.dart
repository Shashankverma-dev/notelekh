import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';
import 'package:ai_workspace_client/features/canvas/canvas_state.dart';
import 'package:ai_workspace_client/features/canvas/engine/input_processor.dart';
import 'package:ai_workspace_client/features/canvas/tools/eraser_tool.dart';
import 'package:ai_workspace_client/features/canvas/tools/shape_tool.dart';

/// Primary coordinator for drawing interactions, input processing, tool execution,
/// shape auto-recognition, and object transformations.
class CanvasController {
  final CanvasDrawingState state;
  final InputProcessor inputProcessor;
  final EraserTool eraserTool;

  // Active stroke buffer
  final List<StrokePoint> _rawPoints = [];
  bool autoRecognizeShapes = true;

  CanvasController({
    required this.state,
    InputProcessor? inputProcessor,
    EraserTool? eraserTool,
  })  : inputProcessor = inputProcessor ?? InputProcessor(),
        eraserTool = eraserTool ?? const EraserTool();

  /// Handles pointer down event
  void onPointerDown(PointerDownEvent event, Offset worldPosition, {List<CanvasObjectItem>? objects, void Function(List<CanvasObjectItem>)? onObjectsUpdated}) {
    final tool = state.currentTool;

    if (tool == CanvasTool.hand) return;

    if (tool == CanvasTool.eraser) {
      if (objects != null && onObjectsUpdated != null) {
        final updated = eraserTool.eraseAt(
          point: worldPosition,
          objects: objects,
          overrideMode: state.eraserMode,
          overrideRadius: state.strokeWidth * 2.5,
        );
        onObjectsUpdated(updated);
      }
      return;
    }

    if (tool == CanvasTool.lasso) {
      state.setDrag(worldPosition, worldPosition);
      return;
    }

    if (tool == CanvasTool.rectangle ||
        tool == CanvasTool.circle ||
        tool == CanvasTool.triangle ||
        tool == CanvasTool.line ||
        tool == CanvasTool.arrow) {
      state.setDrag(worldPosition, worldPosition);
      return;
    }

    // Drawing tools (pen, pencil, brush, highlighter)
    _rawPoints.clear();
    final point = inputProcessor.onPointerDown(event, worldPosition);
    if (point != null) {
      _rawPoints.add(point);
      state.updateLivePoints(List.from(_rawPoints));
    }
  }

  /// Handles pointer move event
  void onPointerMove(PointerMoveEvent event, Offset worldPosition, {List<CanvasObjectItem>? objects, void Function(List<CanvasObjectItem>)? onObjectsUpdated}) {
    final tool = state.currentTool;

    if (tool == CanvasTool.hand) return;

    if (tool == CanvasTool.eraser) {
      if (objects != null && onObjectsUpdated != null) {
        final updated = eraserTool.eraseAt(
          point: worldPosition,
          objects: objects,
          overrideMode: state.eraserMode,
          overrideRadius: state.strokeWidth * 2.5,
        );
        onObjectsUpdated(updated);
      }
      return;
    }

    if (tool == CanvasTool.lasso ||
        tool == CanvasTool.rectangle ||
        tool == CanvasTool.circle ||
        tool == CanvasTool.triangle ||
        tool == CanvasTool.line ||
        tool == CanvasTool.arrow) {
      state.setDrag(state.dragStart, worldPosition);
      return;
    }

    // Drawing tools
    final point = inputProcessor.onPointerMove(event, worldPosition);
    if (point != null) {
      _rawPoints.add(point);
      state.updateLivePoints(List.from(_rawPoints));
    }
  }

  /// Handles pointer up event and commits created strokes / shapes
  void onPointerUp({
    required PointerUpEvent event,
    required Offset worldPosition,
    required List<CanvasObjectItem> objects,
    required void Function(CanvasObjectItem) onCommitObject,
    required void Function(List<CanvasObjectItem>) onObjectsUpdated,
  }) {
    final tool = state.currentTool;

    if (tool == CanvasTool.hand) return;

    if (tool == CanvasTool.lasso) {
      if (state.dragStart != null && state.dragCurrent != null) {
        final rect = Rect.fromPoints(state.dragStart!, state.dragCurrent!);
        final selected = objects.where((o) => rect.overlaps(o.getBoundingBox())).toList();
        for (final o in objects) {
          o.isSelected = selected.contains(o);
        }
        state.setSelectedObjects(selected);
      }
      state.setDrag(null, null);
      return;
    }

    // Geometric shape drag commit
    if (tool == CanvasTool.rectangle ||
        tool == CanvasTool.circle ||
        tool == CanvasTool.triangle ||
        tool == CanvasTool.line ||
        tool == CanvasTool.arrow) {
      if (state.dragStart != null && state.dragCurrent != null) {
        final rect = Rect.fromPoints(state.dragStart!, state.dragCurrent!);
        if (rect.width > 3 || rect.height > 3) {
          final shape = ShapeTool.createShape(
            id: 'shape-${DateTime.now().microsecondsSinceEpoch}',
            shapeType: tool.name,
            bounds: rect,
            strokeColor: state.strokeColor,
            strokeWidth: state.strokeWidth,
            startPoint: state.dragStart,
            endPoint: state.dragCurrent,
          );
          onCommitObject(shape);
        }
      }
      state.setDrag(null, null);
      return;
    }

    // Conclude live stroke
    final finalPoint = inputProcessor.onPointerUp(event, worldPosition);
    if (finalPoint != null) {
      _rawPoints.add(finalPoint);
    }

    if (_rawPoints.isNotEmpty) {
      // 1. Shape recognition check
      if (autoRecognizeShapes && tool == CanvasTool.pen) {
        final recognized = ShapeTool.recognizeShape(
          id: 'shape-${DateTime.now().microsecondsSinceEpoch}',
          points: _rawPoints,
          strokeColor: state.strokeColor,
          strokeWidth: state.strokeWidth,
        );
        if (recognized != null) {
          _rawPoints.clear();
          state.clearLivePoints();
          onCommitObject(recognized);
          return;
        }
      }

      // 2. Commit standard stroke
      final isHighlighter = tool == CanvasTool.highlighter;
      final stroke = CanvasStrokeItem(
        id: 'stroke-${DateTime.now().microsecondsSinceEpoch}',
        points: List.from(_rawPoints),
        color: state.strokeColor,
        strokeWidth: isHighlighter ? state.strokeWidth * 3.0 : state.strokeWidth,
        opacity: isHighlighter ? (state.strokeOpacity * 0.40).clamp(0.1, 0.45) : state.strokeOpacity,
        tool: tool.name,
        penType: isHighlighter ? PenType.marker : state.currentPenType,
      );

      _rawPoints.clear();
      state.clearLivePoints();
      onCommitObject(stroke);
    }
  }

  void onPointerCancel(PointerCancelEvent event) {
    inputProcessor.onPointerCancel(event);
    _rawPoints.clear();
    state.clearLivePoints();
    state.setDrag(null, null);
  }
}
