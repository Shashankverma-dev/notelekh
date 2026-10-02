import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';
import 'package:ai_workspace_client/features/canvas/tools/shape_tool.dart';

void main() {
  group('GoodNotes Draw and Hold & Tilt Line Tests', () {
    test('Recognizes right-to-left tilt line (positive slope /) and preserves startPoint & endPoint', () {
      // User's exact case: diagonal stroke rising from bottom-left (100, 400) to top-right (400, 100)
      final start = const Offset(100, 400);
      final end = const Offset(400, 100);

      final points = <StrokePoint>[];
      const int steps = 20;
      for (int i = 0; i <= steps; i++) {
        final t = i / steps;
        final x = start.dx + (end.dx - start.dx) * t;
        final y = start.dy + (end.dy - start.dy) * t;
        points.add(StrokePoint(x: x, y: y, pressure: 0.5));
      }

      final shape = ShapeTool.recognizeShape(
        id: 'test-tilt-line-1',
        points: points,
        strokeColor: const Color(0xFF15803D), // Green line as in screenshot
        strokeWidth: 3.0,
      );

      expect(shape, isNotNull);
      expect(shape!.shapeType, equals('line'));
      expect(shape.startPoint, equals(start));
      expect(shape.endPoint, equals(end));

      // Ensure startPoint != bounds.topLeft (startPoint is bottom-left, while bounds.topLeft is top-left)
      expect(shape.startPoint, isNot(equals(shape.bounds.topLeft)));
      expect(shape.startPoint!.dx, equals(100));
      expect(shape.startPoint!.dy, equals(400));
      expect(shape.endPoint!.dx, equals(400));
      expect(shape.endPoint!.dy, equals(100));
    });

    test('Hit test works along tilted line segment, not entire bounding box', () {
      final line = CanvasShapeItem(
        id: 'line-hit-test',
        shapeType: 'line',
        bounds: const Rect.fromLTRB(100, 100, 400, 400),
        strokeColor: const Color(0xFF15803D),
        strokeWidth: 4.0,
        startPoint: const Offset(100, 400),
        endPoint: const Offset(400, 100),
      );

      // Point right on the midpoint of the line: (250, 250)
      expect(line.hits(const Offset(250, 250)), isTrue);

      // Point in the corner of bounding box (100, 100): far from line segment
      expect(line.hits(const Offset(100, 100)), isFalse);
      expect(line.hits(const Offset(400, 400)), isFalse);
    });

    test('Serializes and deserializes startPoint and endPoint correctly', () {
      final line = CanvasShapeItem(
        id: 'line-json',
        shapeType: 'line',
        bounds: const Rect.fromLTRB(50, 120, 300, 450),
        strokeColor: const Color(0xFF2563EB),
        strokeWidth: 3.5,
        startPoint: const Offset(50, 450),
        endPoint: const Offset(300, 120),
      );

      final json = line.toJson();
      final restored = CanvasShapeItem.fromJson(json);

      expect(restored.shapeType, equals('line'));
      expect(restored.startPoint, equals(const Offset(50, 450)));
      expect(restored.endPoint, equals(const Offset(300, 120)));
    });

    test('ShapeTool.createShape attaches startPoint and endPoint', () {
      final shape = ShapeTool.createShape(
        id: 'shape-tool-arrow',
        shapeType: 'arrow',
        bounds: const Rect.fromLTRB(50, 50, 250, 250),
        strokeColor: const Color(0xFFEF4444),
        startPoint: const Offset(250, 50),
        endPoint: const Offset(50, 250),
      );

      expect(shape.shapeType, equals('arrow'));
      expect(shape.startPoint, equals(const Offset(250, 50)));
      expect(shape.endPoint, equals(const Offset(50, 250)));
    });
  });
}
