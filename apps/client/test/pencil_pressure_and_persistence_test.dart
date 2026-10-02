import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:ai_workspace_client/features/canvas/models/page_model.dart';
import 'package:ai_workspace_client/features/canvas/engine/stroke_engine.dart';
import 'package:ai_workspace_client/features/canvas/engine/canvas_gesture_manager.dart';
import 'package:ai_workspace_client/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pencil Pressure Sensitivity & Zero Disappearing Word Tests', () {
    test('StrokeInterpolator.interpolate preserves isStylus: true on ALL intermediate points', () {
      final p1 = StrokePoint(x: 10, y: 10, pressure: 0.3, isStylus: true, timestamp: 1000);
      final p2 = StrokePoint(x: 50, y: 50, pressure: 0.7, isStylus: true, timestamp: 1050);

      final interpolated = StrokeInterpolator.interpolate([p1, p2], defaultSegments: 4);
      expect(interpolated.length, greaterThan(2));

      for (final pt in interpolated) {
        expect(pt.isStylus, isTrue, reason: 'Interpolated point at (${pt.x}, ${pt.y}) must preserve isStylus = true');
        expect(pt.pressure, greaterThanOrEqualTo(0.3));
        expect(pt.pressure, lessThanOrEqualTo(0.7));
      }
    });

    test('StrokeEngine.drawVariableWidthStroke renders directly to canvas without blanking', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final stroke = CanvasStrokeItem(
        id: 'test-stroke-1',
        points: [
          StrokePoint(x: 100, y: 100, pressure: 0.2, isStylus: true, timestamp: 100),
          StrokePoint(x: 150, y: 120, pressure: 0.5, isStylus: true, timestamp: 120),
          StrokePoint(x: 200, y: 140, pressure: 0.8, isStylus: true, timestamp: 140),
        ],
        color: const Color(0xFF1E293B),
        strokeWidth: 4.0,
        penType: PenType.fountainPen,
        pressureSensitivity: PressureSensitivity.medium,
      );

      // Must draw directly to canvas without throwing or requiring fragile Picture caching
      expect(() {
        StrokeEngine.drawVariableWidthStroke(canvas, stroke, PressureSensitivity.medium);
      }, returnsNormally);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });

    test('Pencil tool with analog pressure computes distinct variable widths across stroke', () {
      final lightPoint = StrokePoint(x: 50, y: 50, pressure: 0.15, isStylus: true);
      final heavyPoint = StrokePoint(x: 100, y: 100, pressure: 0.85, isStylus: true);

      final lightWidth = PressureEngine.computeWidth(
        baseWidth: 4.0,
        point: lightPoint,
        penType: PenType.pencil,
        sensitivity: PressureSensitivity.medium,
      );

      final heavyWidth = PressureEngine.computeWidth(
        baseWidth: 4.0,
        point: heavyPoint,
        penType: PenType.pencil,
        sensitivity: PressureSensitivity.medium,
      );

      expect(heavyWidth, greaterThan(lightWidth), reason: 'Heavy pressure must produce thicker pencil width than light pressure');
    });

    test('Adding a stroke replaces canvasObjects list reference so painters detect new content', () {
      final appState = AppState();
      final initialDoc = CanvasDocModel(id: 'doc-test-1', workspaceId: 'ws-1', name: 'Test Doc');
      appState.canvasDocs = [initialDoc];
      appState.currentCanvasDoc = initialDoc;
      appState.currentPageIndex = 0;
      appState.canvasObjects = [];

      final initialList = appState.canvasObjects;

      final stroke = CanvasStrokeItem(
        id: 'stroke-1',
        points: [StrokePoint(x: 10, y: 10)],
        color: const Color(0xFF000000),
      );

      appState.addCanvasObject(stroke);

      expect(appState.canvasObjects.length, equals(1));
      expect(identical(appState.canvasObjects, initialList), isFalse,
          reason: 'canvasObjects list instance must be replaced so CustomPainter.shouldRepaint detects the change');
    });

    test('Stylus with resting palm on screen is immediately recognized as stylus', () {
      final manager = CanvasGestureManager(screenToWorld: (pos) => pos);
      bool isStrokeStarted = false;
      bool isStylusIdentified = false;

      manager.onStrokeStart = (pt, isStylus) {
        isStrokeStarted = true;
        isStylusIdentified = isStylus;
      };

      // 1. Palm touches down first
      manager.onPointerDown(
        const PointerDownEvent(
          pointer: 801,
          kind: PointerDeviceKind.touch,
          position: Offset(500, 600),
          radiusMajor: 70.0,
          radiusMinor: 50.0,
        ),
        'pen',
      );

      // 2. Apple Pencil touches down while palm is already resting on glass
      manager.onPointerDown(
        const PointerDownEvent(
          pointer: 802,
          kind: PointerDeviceKind.stylus,
          position: Offset(200, 200),
          pressure: 0.65,
          tilt: 0.15,
        ),
        'pen',
      );

      expect(isStrokeStarted, isTrue, reason: 'Stylus must begin drawing immediately even if palm is on screen');
      expect(isStylusIdentified, isTrue, reason: 'Apple Pencil must be classified as isStylus: true');
      expect(manager.state, equals(CanvasInputState.pencilDrawing));
    });

    test('Stylus reporting touch kind but non-standard pressure is classified as stylus even with palm', () {
      final manager = CanvasGestureManager(screenToWorld: (pos) => pos);
      bool isStylusIdentified = false;

      manager.onStrokeStart = (pt, isStylus) {
        isStylusIdentified = isStylus;
      };

      // Apple Pencil on Safari/Web sending kind: touch but analog pressure
      manager.onPointerDown(
        const PointerDownEvent(
          pointer: 901,
          kind: PointerDeviceKind.touch,
          position: Offset(300, 300),
          pressure: 0.72,
          tilt: 0.22,
        ),
        'pencil',
      );

      expect(isStylusIdentified, isTrue, reason: 'Web Apple Pencil with pressure must be classified as stylus');
      expect(manager.state, equals(CanvasInputState.pencilDrawing));
    });
  });
}
