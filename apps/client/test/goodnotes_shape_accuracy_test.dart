import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';
import 'package:ai_workspace_client/features/canvas/tools/shape_tool.dart';

void main() {
  group('GoodNotes Geometric Shape Recognition Accuracy Tests', () {
    test('Hand-drawn square is accurately recognized as rectangle (square), NEVER circle or triangle', () {
      // Hand-drawn square around (100, 100) to (300, 300) with slight hand jitter
      final points = <StrokePoint>[];
      // Top edge: (100, 100) -> (300, 102)
      for (int i = 0; i <= 10; i++) {
        final t = i / 10.0;
        points.add(StrokePoint(x: 100.0 + 200.0 * t, y: 100.0 + (i.isEven ? 2.0 : -1.0)));
      }
      // Right edge: (300, 100) -> (302, 300)
      for (int i = 1; i <= 10; i++) {
        final t = i / 10.0;
        points.add(StrokePoint(x: 300.0 + (i.isOdd ? 2.0 : -1.0), y: 100.0 + 200.0 * t));
      }
      // Bottom edge: (300, 300) -> (100, 298)
      for (int i = 1; i <= 10; i++) {
        final t = i / 10.0;
        points.add(StrokePoint(x: 300.0 - 200.0 * t, y: 300.0 + (i.isEven ? -2.0 : 1.0)));
      }
      // Left edge: (100, 300) -> (102, 102) (closing back near start)
      for (int i = 1; i <= 10; i++) {
        final t = i / 10.0;
        points.add(StrokePoint(x: 100.0 + (i.isOdd ? -1.0 : 2.0), y: 300.0 - 200.0 * t));
      }

      final shape = ShapeTool.recognizeShape(
        id: 'test-square-accuracy',
        points: points,
        strokeColor: const Color(0xFF2563EB),
      );

      expect(shape, isNotNull);
      // Crucial test: MUST BE 'rectangle', NOT 'circle', NOT 'triangle'!
      expect(shape!.shapeType, equals('rectangle'));
      expect(shape.shapeType, isNot(equals('circle')));
      expect(shape.shapeType, isNot(equals('triangle')));

      // Bounds should be approximately 200x200 square
      expect(shape.bounds.width, closeTo(200.0, 15.0));
      expect(shape.bounds.height, closeTo(200.0, 15.0));
    });

    test('Hand-drawn elongated rectangle is recognized as rectangle and preserves aspect ratio', () {
      // 300x100 rectangle
      final points = <StrokePoint>[];
      for (int i = 0; i <= 10; i++) {
        points.add(StrokePoint(x: 100.0 + 300.0 * (i / 10.0), y: 100.0));
      }
      for (int i = 1; i <= 10; i++) {
        points.add(StrokePoint(x: 400.0, y: 100.0 + 100.0 * (i / 10.0)));
      }
      for (int i = 1; i <= 10; i++) {
        points.add(StrokePoint(x: 400.0 - 300.0 * (i / 10.0), y: 200.0));
      }
      for (int i = 1; i <= 10; i++) {
        points.add(StrokePoint(x: 100.0, y: 200.0 - 100.0 * (i / 10.0)));
      }

      final shape = ShapeTool.recognizeShape(
        id: 'test-rect-accuracy',
        points: points,
        strokeColor: const Color(0xFF0F172A),
      );

      expect(shape, isNotNull);
      expect(shape!.shapeType, equals('rectangle'));
      expect(shape.bounds.width, closeTo(300.0, 15.0));
      expect(shape.bounds.height, closeTo(100.0, 15.0));
    });

    test('Hand-drawn circle is accurately recognized as circle, NOT rectangle or triangle', () {
      final points = <StrokePoint>[];
      const int steps = 40;
      const double radius = 100.0;
      const Offset center = Offset(250.0, 250.0);

      for (int i = 0; i <= steps; i++) {
        final angle = (i / steps) * 2 * math.pi;
        // Add tiny realistic hand jitter (+/- 2px)
        final r = radius + (i.isEven ? 1.5 : -1.5);
        points.add(StrokePoint(
          x: center.dx + r * math.cos(angle),
          y: center.dy + r * math.sin(angle),
        ));
      }

      final shape = ShapeTool.recognizeShape(
        id: 'test-circle-accuracy',
        points: points,
        strokeColor: const Color(0xFFE11D48),
      );

      expect(shape, isNotNull);
      expect(shape!.shapeType, equals('circle'));
      expect(shape.shapeType, isNot(equals('rectangle')));
      expect(shape.shapeType, isNot(equals('triangle')));
      expect(shape.bounds.width, closeTo(200.0, 15.0));
      expect(shape.bounds.height, closeTo(200.0, 15.0));
    });

    test('Fast-drawn circle with few points is accurately recognized as circle', () {
      final points = <StrokePoint>[];
      const int steps = 16;
      const double radius = 80.0;
      const Offset center = Offset(200.0, 200.0);

      for (int i = 0; i <= steps; i++) {
        final angle = (i / steps) * 2 * math.pi;
        points.add(StrokePoint(
          x: center.dx + radius * math.cos(angle),
          y: center.dy + radius * math.sin(angle),
        ));
      }

      final shape = ShapeTool.recognizeShape(
        id: 'test-fast-circle',
        points: points,
        strokeColor: const Color(0xFFE11D48),
      );

      expect(shape, isNotNull);
      expect(shape!.shapeType, equals('circle'));
    });

    test('Circle with hand-drawn overlap (crossing past start) is recognized as circle', () {
      final points = <StrokePoint>[];
      const int steps = 36;
      const double radius = 90.0;
      const Offset center = Offset(200.0, 200.0);

      // Loop around 360 deg + 40 deg overlap
      for (int i = 0; i <= steps + 4; i++) {
        final angle = (i / steps) * 2 * math.pi;
        points.add(StrokePoint(
          x: center.dx + radius * math.cos(angle),
          y: center.dy + radius * math.sin(angle),
        ));
      }

      final shape = ShapeTool.recognizeShape(
        id: 'test-overlap-circle',
        points: points,
        strokeColor: const Color(0xFFE11D48),
      );

      expect(shape, isNotNull);
      expect(shape!.shapeType, equals('circle'));
    });

    test('Hand-drawn slightly oval circle is recognized as circle', () {
      final points = <StrokePoint>[];
      const int steps = 32;
      const double rx = 100.0;
      const double ry = 80.0;
      const Offset center = Offset(200.0, 200.0);

      for (int i = 0; i <= steps; i++) {
        final angle = (i / steps) * 2 * math.pi;
        points.add(StrokePoint(
          x: center.dx + rx * math.cos(angle),
          y: center.dy + ry * math.sin(angle),
        ));
      }

      final shape = ShapeTool.recognizeShape(
        id: 'test-oval-circle',
        points: points,
        strokeColor: const Color(0xFFE11D48),
      );

      expect(shape, isNotNull);
      expect(shape!.shapeType, equals('circle'));
    });

    test('Hand-drawn triangle is accurately recognized as triangle, NOT circle or rectangle', () {
      final points = <StrokePoint>[];
      // Vertex A: (200, 100) -> Vertex B: (320, 300) -> Vertex C: (80, 300) -> back to A
      const a = Offset(200.0, 100.0);
      const b = Offset(320.0, 300.0);
      const c = Offset(80.0, 300.0);

      // Side A -> B
      for (int i = 0; i <= 10; i++) {
        final t = i / 10.0;
        points.add(StrokePoint(x: a.dx + (b.dx - a.dx) * t, y: a.dy + (b.dy - a.dy) * t));
      }
      // Side B -> C
      for (int i = 1; i <= 10; i++) {
        final t = i / 10.0;
        points.add(StrokePoint(x: b.dx + (c.dx - b.dx) * t, y: b.dy + (c.dy - b.dy) * t));
      }
      // Side C -> A
      for (int i = 1; i <= 10; i++) {
        final t = i / 10.0;
        points.add(StrokePoint(x: c.dx + (a.dx - c.dx) * t, y: c.dy + (a.dy - c.dy) * t));
      }

      final shape = ShapeTool.recognizeShape(
        id: 'test-triangle-accuracy',
        points: points,
        strokeColor: const Color(0xFF10B981),
      );

      expect(shape, isNotNull);
      expect(shape!.shapeType, equals('triangle'));
      expect(shape.shapeType, isNot(equals('circle')));
      expect(shape.shapeType, isNot(equals('rectangle')));
    });

    test('Small handwritten letters (e.g. 20x20px letter "o") are NOT recognized as shapes', () {
      final points = <StrokePoint>[];
      const int steps = 16;
      const double radius = 10.0; // 20px wide/tall letter 'o'
      const Offset center = Offset(100.0, 100.0);

      for (int i = 0; i <= steps; i++) {
        final angle = (i / steps) * 2 * math.pi;
        points.add(StrokePoint(
          x: center.dx + radius * math.cos(angle),
          y: center.dy + radius * math.sin(angle),
        ));
      }

      final shape = ShapeTool.recognizeShape(
        id: 'handwriting-letter-o',
        points: points,
        strokeColor: const Color(0xFF0F172A),
      );

      // Must be null! Normal handwriting letters must NEVER snap to shapes
      expect(shape, isNull);
    });

    test('Handwritten open cursive curves (e.g. letter "c" or "s") are NOT recognized as closed shapes', () {
      final points = <StrokePoint>[];
      // Arc of 220 degrees representing letter 'c'
      for (int i = 0; i <= 20; i++) {
        final angle = math.pi * 0.2 + (i / 20.0) * (math.pi * 1.5);
        points.add(StrokePoint(
          x: 100.0 + 35.0 * math.cos(angle),
          y: 100.0 + 35.0 * math.sin(angle),
        ));
      }

      final shape = ShapeTool.recognizeShape(
        id: 'handwriting-letter-c',
        points: points,
        strokeColor: const Color(0xFF0F172A),
      );

      expect(shape, isNull);
    });

    test('Handwritten short dashes or accents (< 50px) are NOT recognized as straight lines', () {
      final points = <StrokePoint>[];
      // 30px short dash (e.g. hyphen or t-cross)
      for (int i = 0; i <= 8; i++) {
        points.add(StrokePoint(x: 100.0 + 30.0 * (i / 8.0), y: 100.0));
      }

      final shape = ShapeTool.recognizeShape(
        id: 'handwriting-dash',
        points: points,
        strokeColor: const Color(0xFF0F172A),
      );

      expect(shape, isNull);
    });

    test('Irregular freehand scribble/cursive word is NOT coerced into a rectangle', () {
      final points = <StrokePoint>[];
      // Zig-zag scribble covering an area
      for (int i = 0; i < 30; i++) {
        final x = 100.0 + (i % 6) * 15.0;
        final y = 100.0 + (i ~/ 6) * 15.0;
        points.add(StrokePoint(x: x, y: y));
      }

      final shape = ShapeTool.recognizeShape(
        id: 'handwriting-scribble',
        points: points,
        strokeColor: const Color(0xFF0F172A),
      );

      // Must not be coerced into rectangle
      expect(shape, isNull);
    });
  });
}
