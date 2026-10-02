import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:ai_workspace_client/features/canvas/engine/pressure_engine.dart';
import 'package:ai_workspace_client/features/canvas/engine/stroke_smoother.dart';
import 'package:ai_workspace_client/features/canvas/engine/stroke_interpolator.dart';
import 'package:ai_workspace_client/features/canvas/tools/shape_tool.dart';
import 'package:ai_workspace_client/features/canvas/tools/eraser_tool.dart';
import 'package:ai_workspace_client/features/canvas/tools/lasso_tool.dart';
import 'package:ai_workspace_client/features/canvas/widgets/color_picker.dart';
import 'package:ai_workspace_client/features/canvas/canvas_state.dart';
import 'package:ai_workspace_client/features/canvas/engine/stroke_renderer.dart';

void main() {
  group('Stroke Point & Serialization', () {
    test('StrokePoint roundtrips through JSON accurately', () {
      final pt = StrokePoint(x: 120.5, y: 340.25, pressure: 0.82, tilt: 0.15, velocity: 1.4);
      final json = pt.toJson();
      final restored = StrokePoint.fromJson(json);

      expect(restored.x, closeTo(120.5, 0.001));
      expect(restored.y, closeTo(340.25, 0.001));
      expect(restored.pressure, closeTo(0.82, 0.001));
      expect(restored.tilt, closeTo(0.15, 0.001));
      expect(restored.velocity, closeTo(1.4, 0.001));
    });
  });

  group('Pressure Engine & Fallbacks', () {
    test('Pressure curves scale correctly according to sensitivity', () {
      final off = PressureEngine.applyPressureCurve(0.9, PressureSensitivity.off);
      expect(off, 0.5);

      final low = PressureEngine.applyPressureCurve(0.8, PressureSensitivity.low);
      expect(low, closeTo(0.35 + 0.8 * 0.3, 0.01));

      final medium = PressureEngine.applyPressureCurve(0.5, PressureSensitivity.medium);
      expect(medium, closeTo(0.5, 0.01)); // S-curve inflection point at 0.5 is 0.5
    });

    test('Pressure fallback modulates with velocity when pressure is unavailable', () {
      final ptFast = StrokePoint(x: 10, y: 10, pressure: 0.5, velocity: 3.5);
      final ptSlow = StrokePoint(x: 10, y: 10, pressure: 0.5, velocity: 0.01);

      final widthFast = PressureEngine.computeWidth(
        baseWidth: 10.0,
        point: ptFast,
        penType: PenType.fountainPen,
        sensitivity: PressureSensitivity.medium,
        hasRealPressure: false,
      );

      final widthSlow = PressureEngine.computeWidth(
        baseWidth: 10.0,
        point: ptSlow,
        penType: PenType.fountainPen,
        sensitivity: PressureSensitivity.medium,
        hasRealPressure: false,
      );

      // Faster strokes with drag thin out naturally
      expect(widthFast, lessThan(widthSlow));
    });
  });

  group('Stroke Smoother & Interpolator', () {
    test('Smoother filters noisy high-frequency jitter', () {
      final smoother = StrokeSmoother(smoothingFactor: 0.5);
      final p1 = smoother.filter(StrokePoint(x: 0, y: 0));
      final p2 = smoother.filter(StrokePoint(x: 100, y: 0));

      expect(p1.x, 0.0);
      expect(p2.x, closeTo(50.0, 0.01)); // Filtered by EMA
    });

    test('Catmull-Rom interpolator generates continuous intermediate samples', () {
      final raw = [
        StrokePoint(x: 0, y: 0),
        StrokePoint(x: 100, y: 50),
        StrokePoint(x: 200, y: 0),
      ];

      final interpolated = StrokeInterpolator.interpolate(raw, defaultSegments: 4);
      expect(interpolated.length, greaterThan(raw.length));
      expect(interpolated.first.x, 0.0);
      expect(interpolated.last.x, 200.0);
    });
  });

  group('Shape Recognition', () {
    test('Recognizes straight line', () {
      final points = [
        StrokePoint(x: 10, y: 10),
        StrokePoint(x: 30, y: 30),
        StrokePoint(x: 60, y: 60),
        StrokePoint(x: 90, y: 90),
        StrokePoint(x: 120, y: 120),
        StrokePoint(x: 150, y: 150),
      ];

      final shape = ShapeTool.recognizeShape(
        id: 'test-shape',
        points: points,
        strokeColor: const Color(0xFF000000),
      );

      expect(shape, isNotNull);
      expect(shape!.shapeType, 'line');
    });
  });

  group('Eraser Tool', () {
    test('Stroke erasing removes intersecting strokes', () {
      const eraser = EraserTool();
      final stroke1 = CanvasStrokeItem(
        id: 's1',
        points: [StrokePoint(x: 10, y: 10), StrokePoint(x: 50, y: 50)],
        color: const Color(0xFF000000),
      );
      final stroke2 = CanvasStrokeItem(
        id: 's2',
        points: [StrokePoint(x: 200, y: 200), StrokePoint(x: 250, y: 250)],
        color: const Color(0xFF000000),
      );

      final objects = <CanvasObjectItem>[stroke1, stroke2];
      final updated = eraser.eraseAt(
        point: const Offset(30, 30),
        objects: objects,
        overrideRadius: 15.0,
      );

      expect(updated.length, 1);
      expect(updated.first.id, 's2');
    });

    test('Precision eraser splits stroke into two independent segments', () {
      const eraser = EraserTool();
      final longStroke = CanvasStrokeItem(
        id: 'long-stroke',
        points: [
          StrokePoint(x: 10, y: 10),
          StrokePoint(x: 20, y: 10),
          StrokePoint(x: 30, y: 10),
          StrokePoint(x: 40, y: 10),
          StrokePoint(x: 50, y: 10), // Erased middle
          StrokePoint(x: 60, y: 10),
          StrokePoint(x: 70, y: 10),
          StrokePoint(x: 80, y: 10),
        ],
        color: const Color(0xFFE11D48),
        strokeWidth: 4.0,
        penType: PenType.fountainPen,
      );

      final updated = eraser.eraseAt(
        point: const Offset(45, 10),
        objects: [longStroke],
        overrideRadius: 12.0,
        overrideMode: EraserMode.segment,
      );

      // Should be split into 2 sub-strokes
      expect(updated.length, 2);
      final seg1 = updated[0] as CanvasStrokeItem;
      final seg2 = updated[1] as CanvasStrokeItem;
      expect(seg1.points.length, greaterThanOrEqualTo(2));
      expect(seg2.points.length, greaterThanOrEqualTo(2));
      expect(seg1.color, const Color(0xFFE11D48));
      expect(seg2.color, const Color(0xFFE11D48));
      expect(seg1.penType, PenType.fountainPen);
      expect(seg2.penType, PenType.fountainPen);
    });
  });

  group('Vector Spline Stroke Renderer', () {
    test('Renders Fountain, Ballpoint, Brush, Pencil, and Highlighter without error', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final points = [
        StrokePoint(x: 10, y: 10, pressure: 0.3),
        StrokePoint(x: 30, y: 40, pressure: 0.6),
        StrokePoint(x: 60, y: 50, pressure: 0.8),
        StrokePoint(x: 90, y: 80, pressure: 0.4),
      ];

      for (final pen in [PenType.fountainPen, PenType.ballpoint, PenType.brushPen, PenType.pencil]) {
        StrokeRenderer.drawStroke(
          canvas: canvas,
          points: points,
          color: const Color(0xFFE11D48),
          baseWidth: 3.0,
          penType: pen,
          opacity: 1.0,
          sensitivity: PressureSensitivity.medium,
        );
      }

      // Highlighter test
      StrokeRenderer.drawStroke(
        canvas: canvas,
        points: points,
        color: const Color(0xFFFDE047),
        baseWidth: 20.0,
        penType: PenType.marker,
        opacity: 0.5,
        sensitivity: PressureSensitivity.medium,
        tool: 'highlighter',
      );

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });

  group('Lasso Selection Tool', () {
    test('Polygon containment correctly detects enclosed points', () {
      final box = [
        const Offset(0, 0),
        const Offset(100, 0),
        const Offset(100, 100),
        const Offset(0, 100),
      ];

      expect(LassoTool.isPointInsidePolygon(const Offset(50, 50), box), isTrue);
      expect(LassoTool.isPointInsidePolygon(const Offset(150, 50), box), isFalse);
    });

    test('Lasso selection respects category inclusion filters', () {
      final box = [
        const Offset(0, 0),
        const Offset(100, 0),
        const Offset(100, 100),
        const Offset(0, 100),
      ];

      final stroke = CanvasStrokeItem(
        id: 'stroke-1',
        points: [StrokePoint(x: 20, y: 20), StrokePoint(x: 40, y: 40)],
        color: const Color(0xFF000000),
      );

      final shape = CanvasShapeItem(
        id: 'shape-1',
        shapeType: 'rectangle',
        bounds: const Rect.fromLTWH(10, 10, 30, 30),
        strokeColor: const Color(0xFF000000),
      );

      final arrow = CanvasShapeItem(
        id: 'arrow-1',
        shapeType: 'arrow',
        bounds: const Rect.fromLTWH(15, 15, 20, 20),
        strokeColor: const Color(0xFF000000),
      );

      final text = CanvasTextItem(
        id: 'text-1',
        text: 'Hello world',
        position: const Offset(25, 25),
        color: const Color(0xFF000000),
      );

      final equation = CanvasTextItem(
        id: 'eq-1',
        text: r'$$E = mc^2$$',
        position: const Offset(30, 30),
        color: const Color(0xFF000000),
      );

      final image = CanvasImageItem(
        id: 'img-1',
        imageUrl: 'https://example.com/pic.png',
        bounds: const Rect.fromLTWH(5, 5, 25, 25),
      );

      final tape = CanvasTapeItem(
        id: 'tape-1',
        rect: const Rect.fromLTWH(10, 10, 40, 10),
      );

      final stickyNote = CanvasNoteCardItem(
        id: 'note-1',
        title: 'Memo',
        content: 'Notes here',
        position: const Offset(35, 35),
      );

      final objects = <CanvasObjectItem>[
        stroke, shape, arrow, text, equation, image, tape, stickyNote,
      ];

      final ds = CanvasDrawingState();

      // Case 1: All 8 filters enabled -> all 8 selected
      var selected = LassoTool.selectObjectsInLasso(
        lassoPoints: box,
        objects: objects,
        filter: ds.isObjectEligibleForLasso,
      );
      expect(selected.length, 8);

      // Case 2: Disable Handwriting -> stroke not selected
      ds.setLassoIncludeHandwriting(false);
      selected = LassoTool.selectObjectsInLasso(
        lassoPoints: box,
        objects: objects,
        filter: ds.isObjectEligibleForLasso,
      );
      expect(selected.length, 7);
      expect(selected.contains(stroke), isFalse);

      // Case 3: Disable Shapes -> shape not selected, arrow still selected
      ds.setLassoIncludeShapes(false);
      selected = LassoTool.selectObjectsInLasso(
        lassoPoints: box,
        objects: objects,
        filter: ds.isObjectEligibleForLasso,
      );
      expect(selected.length, 6);
      expect(selected.contains(shape), isFalse);
      expect(selected.contains(arrow), isTrue);

      // Case 4: Disable Arrows -> arrow not selected
      ds.setLassoIncludeArrows(false);
      selected = LassoTool.selectObjectsInLasso(
        lassoPoints: box,
        objects: objects,
        filter: ds.isObjectEligibleForLasso,
      );
      expect(selected.contains(arrow), isFalse);

      // Case 5: Rectangular selection mode with filter
      ds.setAllLassoFilters(false);
      ds.setLassoIncludeStickyNotes(true);
      final rectSelected = LassoTool.selectObjectsInRect(
        rect: const Rect.fromLTWH(0, 0, 100, 100),
        objects: objects,
        filter: ds.isObjectEligibleForLasso,
      );
      expect(rectSelected.length, 1);
      expect(rectSelected.first.id, 'note-1');
    });
  });

  group('Color Picker Presets', () {
    test('Provides curated Goodnotes color palette', () {
      expect(CanvasColorPicker.presetColors.length, greaterThanOrEqualTo(12));
      expect(CanvasColorPicker.presetColors, contains(const Color(0xFF0F172A)));
      expect(CanvasColorPicker.presetColors, contains(const Color(0xFFFDE047)));
    });
  });

  group('GoodNotes Pens — Ball Pen, Fountain Pen & Brush Pen Physics', () {
    test('Ball Pen produces uniform constant width without squiggly sausage pinching', () {
      final pSlow = StrokePoint(x: 10, y: 10, pressure: 0.5, velocity: 0.1);
      final pFast = StrokePoint(x: 50, y: 50, pressure: 0.5, velocity: 4.0);

      final wSlow = PressureEngine.computeWidth(
        baseWidth: 4.0,
        point: pSlow,
        penType: PenType.ballpoint,
        sensitivity: PressureSensitivity.medium,
      );
      final wFast = PressureEngine.computeWidth(
        baseWidth: 4.0,
        point: pFast,
        penType: PenType.ballpoint,
        sensitivity: PressureSensitivity.medium,
      );

      // Ball pen maintains uniform 4.0 width across velocities
      expect(wSlow, 4.0);
      expect(wFast, 4.0);
    });

    test('Fountain Pen flexes with pressure and attenuates on fast flicks', () {
      final pLight = StrokePoint(x: 10, y: 10, pressure: 0.1, velocity: 0.5);
      final pHeavy = StrokePoint(x: 20, y: 20, pressure: 0.9, velocity: 0.5);
      final pFlick = StrokePoint(x: 30, y: 30, pressure: 0.5, velocity: 5.0);

      final wLight = PressureEngine.computeWidth(
        baseWidth: 6.0,
        point: pLight,
        penType: PenType.fountainPen,
        sensitivity: PressureSensitivity.medium,
      );
      final wHeavy = PressureEngine.computeWidth(
        baseWidth: 6.0,
        point: pHeavy,
        penType: PenType.fountainPen,
        sensitivity: PressureSensitivity.medium,
      );
      final wFlick = PressureEngine.computeWidth(
        baseWidth: 6.0,
        point: pFlick,
        penType: PenType.fountainPen,
        sensitivity: PressureSensitivity.medium,
        hasRealPressure: false,
      );

      // Light upstroke is delicate (< baseWidth)
      expect(wLight, lessThan(6.0));
      // Heavy flex downstroke is bold (> baseWidth)
      expect(wHeavy, greaterThan(6.0));
      expect(wHeavy, greaterThan(wLight * 2.0));
      // Rapid flick thins out
      expect(wFlick, lessThan(5.0));
    });

    test('Brush Pen has wide dynamic range from hairline to broad stroke', () {
      final pHairline = StrokePoint(x: 10, y: 10, pressure: 0.05, velocity: 1.0);
      final pBroad = StrokePoint(x: 20, y: 20, pressure: 0.95, velocity: 0.5);

      final wHairline = PressureEngine.computeWidth(
        baseWidth: 8.0,
        point: pHairline,
        penType: PenType.brushPen,
        sensitivity: PressureSensitivity.medium,
      );
      final wBroad = PressureEngine.computeWidth(
        baseWidth: 8.0,
        point: pBroad,
        penType: PenType.brushPen,
        sensitivity: PressureSensitivity.medium,
      );

      // Dynamic range: hairline <= 0.25x baseWidth, broad >= 2.0x baseWidth
      expect(wHairline, lessThanOrEqualTo(8.0 * 0.25));
      expect(wBroad, greaterThanOrEqualTo(8.0 * 2.0));
    });

    test('StrokeRenderer renders Ballpoint, Fountain Pen, and Brush Pen with distance tapers', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // Multi-point stroke simulating handwriting
      final points = List.generate(
        30,
        (i) => StrokePoint(
          x: i * 5.0,
          y: math.sin(i * 0.3) * 20.0 + 50.0,
          pressure: (i / 30.0),
          velocity: 1.2,
        ),
      );

      for (final pen in [PenType.ballpoint, PenType.fountainPen, PenType.brushPen]) {
        expect(() {
          StrokeRenderer.drawStroke(
            canvas: canvas,
            points: points,
            color: const Color(0xFF2563EB),
            baseWidth: 4.0,
            penType: pen,
            opacity: 1.0,
            sensitivity: PressureSensitivity.medium,
            tipSharpness: 0.90,
            tipFlatness: 0.80,
          );
        }, returnsNormally);
      }
    });
  });
}
