import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:ai_workspace_client/features/canvas/tools/eraser_tool.dart';
import 'package:ai_workspace_client/features/canvas/tools/lasso_tool.dart';
import 'package:ai_workspace_client/features/canvas/tools/highlighter_tool.dart';
import 'package:ai_workspace_client/features/canvas/canvas_state.dart';
import 'package:ai_workspace_client/state/app_state.dart';

void main() {
  group('Canvas Drawing Tools Fixes & Optimizations', () {
    test('Single-dot strokes can be hit-tested and erased', () {
      final dot = CanvasStrokeItem(
        id: 'dot-1',
        points: [StrokePoint(x: 100, y: 100, pressure: 0.5)],
        color: Colors.black,
        strokeWidth: 4.0,
      );

      expect(dot.hits(const Offset(100, 100)), isTrue);
      expect(dot.hits(const Offset(105, 105)), isTrue);
      expect(dot.hits(const Offset(200, 200)), isFalse);

      const eraser = EraserTool();
      final result = eraser.eraseAt(
        point: const Offset(100, 100),
        objects: [dot],
        overrideRadius: 20.0,
      );

      expect(result, isEmpty);
    });

    test('EraserTool returns identical list reference when no objects hit (zero GC allocation)', () {
      final stroke = CanvasStrokeItem(
        id: 's-1',
        points: [
          StrokePoint(x: 10, y: 10),
          StrokePoint(x: 50, y: 50),
        ],
        color: Colors.blue,
      );
      final objects = <CanvasObjectItem>[stroke];

      const eraser = EraserTool();
      final result = eraser.eraseAt(
        point: const Offset(500, 500),
        objects: objects,
        overrideRadius: 20.0,
      );

      expect(identical(result, objects), isTrue);
    });

    test('Lasso dragging mutates stroke points in-place without breaking reference identity', () {
      final stroke = CanvasStrokeItem(
        id: 's-move',
        points: [
          StrokePoint(x: 10, y: 10),
          StrokePoint(x: 20, y: 20),
        ],
        color: Colors.black,
        isSelected: true,
      );
      final objects = <CanvasObjectItem>[stroke];

      // Translate by delta (5, 10)
      LassoTool.translateObjects(objects, const Offset(5, 10));

      expect(stroke.points[0].x, closeTo(15.0, 0.001));
      expect(stroke.points[0].y, closeTo(20.0, 0.001));
      expect(stroke.points[1].x, closeTo(25.0, 0.001));
      expect(stroke.points[1].y, closeTo(30.0, 0.001));
      // Instance is unchanged
      expect(identical(objects[0], stroke), isTrue);
    });

    test('CanvasDrawingState setTool switches stroke width presets appropriately', () {
      final state = CanvasDrawingState();
      expect(state.currentTool, CanvasTool.pen);
      expect(state.strokeWidth, state.penWidthPresets[state.selectedPresetIndex]);

      // Switch to highlighter
      state.setTool(CanvasTool.highlighter);
      expect(state.currentTool, CanvasTool.highlighter);
      expect(state.strokeWidth, state.highlighterWidthPresets[state.selectedPresetIndex]);

      // Switch back to pen
      state.setTool(CanvasTool.pen);
      expect(state.currentTool, CanvasTool.pen);
      expect(state.strokeWidth, state.penWidthPresets[state.selectedPresetIndex]);
    });

    test('AppState setCanvasObjects with pushUndo: false does not flood undoStack', () {
      final appState = AppState();
      final initialStackLen = appState.undoStack.length;

      final s1 = CanvasStrokeItem(
        id: 's1',
        points: [StrokePoint(x: 0, y: 0)],
        color: Colors.black,
      );

      // First erase tick pushes undo
      appState.setCanvasObjects([s1], pushUndo: true);
      expect(appState.undoStack.length, initialStackLen + 1);

      // Subsequent erase ticks in same sweep do not push undo
      appState.setCanvasObjects([], pushUndo: false);
      expect(appState.undoStack.length, initialStackLen + 1);
    });

    test('HighlighterTool.straightenPoints snaps wobbly horizontal stroke to perfectly horizontal text line', () {
      final wobblyPoints = [
        StrokePoint(x: 100, y: 200),
        StrokePoint(x: 150, y: 204),
        StrokePoint(x: 200, y: 198),
        StrokePoint(x: 250, y: 203),
        StrokePoint(x: 300, y: 201),
      ];

      final straight = HighlighterTool.straightenPoints(wobblyPoints);

      expect(straight.length, greaterThanOrEqualTo(5));
      // All points should have the exact same Y coordinate (200.0)
      for (final p in straight) {
        expect(p.y, closeTo(200.0, 0.001));
      }
      expect(straight.first.x, closeTo(100.0, 0.001));
      expect(straight.last.x, closeTo(300.0, 0.001));
    });

    test('HighlighterTool.straightenPoints snaps vertical margin stroke to perfectly vertical line', () {
      final verticalPoints = [
        StrokePoint(x: 80, y: 100),
        StrokePoint(x: 82, y: 200),
        StrokePoint(x: 79, y: 300),
        StrokePoint(x: 81, y: 400),
      ];

      final straight = HighlighterTool.straightenPoints(verticalPoints);

      // All points should have the exact same X coordinate (80.0)
      for (final p in straight) {
        expect(p.x, closeTo(80.0, 0.001));
      }
      expect(straight.first.y, closeTo(100.0, 0.001));
      expect(straight.last.y, closeTo(400.0, 0.001));
    });

    test('CanvasDrawingState highlighterStraightLine defaults to true and toggles properly', () {
      final state = CanvasDrawingState();
      expect(state.highlighterStraightLine, isTrue);

      state.setHighlighterStraightLine(false);
      expect(state.highlighterStraightLine, isFalse);

      state.setHighlighterStraightLine(true);
      expect(state.highlighterStraightLine, isTrue);
    });
  });
}
