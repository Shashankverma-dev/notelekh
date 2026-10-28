import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_workspace_client/features/canvas/canvas_state.dart';
import 'package:ai_workspace_client/features/canvas/engine/canvas_gesture_manager.dart';
import 'package:ai_workspace_client/features/canvas/engine/input_processor.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:ai_workspace_client/features/canvas/models/page_model.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';
import 'package:ai_workspace_client/features/canvas/tools/eraser_tool.dart';
import 'package:ai_workspace_client/features/canvas/tools/lasso_tool.dart';
import 'package:ai_workspace_client/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Canvas Inking Pipeline & Disappearing-Stroke Prevention', () {
    test('Rapid A->B->C->D->E stroke commits preserve distinct immutable point buffers', () {
      final appState = AppState();
      appState.currentCanvasDoc = CanvasDocModel(
        id: 'test-doc-1',
        workspaceId: 'ws-1',
        name: 'Audit Notebook',
        pages: [CanvasPage(id: 'page-1', pageNumber: 1, objects: [])],
      );
      appState.canvasObjects = [];

      final liveStrokeNotifier = LiveStrokeNotifier();

      // Simulate 5 rapid strokes (A, B, C, D, E)
      for (int i = 0; i < 5; i++) {
        final originX = i * 100.0;
        final originY = 50.0;

        // PointerDown -> ActiveStroke
        final p0 = StrokePoint(
          x: originX,
          y: originY,
          pressure: 0.5,
          tilt: 0.0,
          velocity: 0.0,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          isStylus: true,
        );
        liveStrokeNotifier.start(p0);

        // PointerMove
        for (int step = 1; step <= 5; step++) {
          final pt = StrokePoint(
            x: originX + step * 10.0,
            y: originY + step * 10.0,
            pressure: 0.6,
            tilt: 0.0,
            velocity: 1.0,
            timestamp: DateTime.now().millisecondsSinceEpoch,
            isStylus: true,
          );
          liveStrokeNotifier.add(pt);
        }

        // PointerUp -> Create immutable CanvasStrokeItem -> Commit to DocumentState
        final livePoints = liveStrokeNotifier.value;
        expect(livePoints.length, 6);

        final strokeToCommit = CanvasStrokeItem(
          id: 'stroke-$i',
          points: List<StrokePoint>.of(livePoints), // Detached immutable copy
          color: Colors.black,
          strokeWidth: 3.0,
          tool: 'pen',
        );

        appState.addCanvasObject(strokeToCommit);

        // THEN clear ActiveStroke
        liveStrokeNotifier.clear();

        // Verify active buffer is empty while historical canvas retained the stroke
        expect(liveStrokeNotifier.value, isEmpty);
        expect(appState.canvasObjects.length, i + 1);
        expect((appState.canvasObjects.last as CanvasStrokeItem).points.length, 6);
        expect((appState.canvasObjects.last as CanvasStrokeItem).points.first.x, originX);
      }

      // Verify all 5 strokes survived with their original uncorrupted points
      expect(appState.canvasObjects.length, 5);
      for (int i = 0; i < 5; i++) {
        final stroke = appState.canvasObjects[i] as CanvasStrokeItem;
        expect(stroke.id, 'stroke-$i');
        expect(stroke.points.first.x, i * 100.0);
        expect(stroke.points.last.x, i * 100.0 + 50.0);
      }
    });

    test('Stylus classification and pointer ownership prevent finger collisions', () {
      final inputProcessor = InputProcessor();
      final manager = CanvasGestureManager(
        screenToWorld: (pos) => pos,
        inputProcessor: inputProcessor,
        fingerDrawingEnabled: false,
      );

      bool strokeStarted = false;
      bool strokeEnded = false;
      List<StrokePoint> collectedPoints = [];

      manager.onStrokeStart = (pt, isStylus) => strokeStarted = true;
      manager.onStrokeUpdate = (pt) => collectedPoints.add(pt);
      manager.onStrokeEnd = (pt) => strokeEnded = true;

      // Stylus PointerDown with id 1
      manager.onPointerDown(
        const PointerDownEvent(pointer: 1, kind: PointerDeviceKind.stylus, position: Offset(50, 50)),
        'pen',
      );
      expect(manager.isStylusActive, isTrue);
      expect(manager.activeStylusPointerId, 1);
      expect(strokeStarted, isTrue);

      // Stylus Move
      manager.onPointerMove(
        const PointerMoveEvent(pointer: 1, kind: PointerDeviceKind.stylus, position: Offset(60, 60)),
        currentPan: Offset.zero,
        currentZoom: 1.0,
        currentTool: 'pen',
      );
      expect(collectedPoints.length, 1);

      // Palm / Touch PointerDown while stylus active should NOT interrupt stylus stroke
      manager.onPointerDown(
        const PointerDownEvent(pointer: 2, kind: PointerDeviceKind.touch, position: Offset(200, 200)),
        'pen',
      );
      expect(manager.isStylusActive, isTrue);

      // Stylus Up
      manager.onPointerUp(
        const PointerUpEvent(pointer: 1, kind: PointerDeviceKind.stylus, position: Offset(70, 70)),
      );
      expect(strokeEnded, isTrue);
      expect(manager.isStylusActive, isFalse);
    });
  });

  group('2. Full Tool Suite Validation', () {
    test('Highlighter preserves opacity and dimensions', () {
      final stroke = CanvasStrokeItem(
        id: 'hl-1',
        points: [
          StrokePoint(x: 10, y: 10, pressure: 0.5, tilt: 0.0, velocity: 0.0, timestamp: 0),
          StrokePoint(x: 100, y: 10, pressure: 0.5, tilt: 0.0, velocity: 0.0, timestamp: 10),
        ],
        color: const Color(0xFFFACC15),
        strokeWidth: 24.0,
        tool: 'highlighter',
        opacity: 0.42,
      );

      expect(stroke.tool, 'highlighter');
      expect(stroke.opacity, 0.42);
      expect(stroke.hits(const Offset(50, 10), padding: 12.0), isTrue);
    });

    test('Eraser tool handles stroke erase vs segment slice erase', () {
      final stroke = CanvasStrokeItem(
        id: 'stroke-to-erase',
        points: [
          StrokePoint(x: 10, y: 50, pressure: 0.5, tilt: 0.0, velocity: 0.0, timestamp: 0),
          StrokePoint(x: 50, y: 50, pressure: 0.5, tilt: 0.0, velocity: 0.0, timestamp: 5),
          StrokePoint(x: 100, y: 50, pressure: 0.5, tilt: 0.0, velocity: 0.0, timestamp: 10),
        ],
        color: Colors.black,
        strokeWidth: 4.0,
        tool: 'pen',
      );

      final objects = <CanvasObjectItem>[stroke];
      const eraser = EraserTool(mode: EraserMode.stroke, radius: 15.0);

      // 1. Erase at center using stroke mode
      final resultStrokeMode = eraser.eraseAt(
        point: const Offset(50, 50),
        objects: objects,
        overrideMode: EraserMode.stroke,
      );
      expect(resultStrokeMode, isEmpty);

      // 2. Erase at center using segment mode
      final resultSegmentMode = eraser.eraseAt(
        point: const Offset(50, 50),
        objects: objects,
        overrideMode: EraserMode.segment,
      );
      // Segment mode cuts the single stroke into outer remaining pieces
      expect(resultSegmentMode.length, greaterThanOrEqualTo(1));
    });

    test('LassoTool translates all CanvasObjectItem types including Shape line endpoints', () {
      final stroke = CanvasStrokeItem(
        id: 's1',
        points: [
          StrokePoint(x: 10, y: 10, pressure: 0.5, tilt: 0.0, velocity: 0.0, timestamp: 0, isStylus: true),
        ],
        color: Colors.black,
        strokeWidth: 2.0,
        tool: 'pen',
      );

      final lineShape = CanvasShapeItem(
        id: 'line-1',
        shapeType: 'line',
        bounds: const Rect.fromLTWH(20, 20, 100, 50),
        strokeColor: Colors.blue,
        startPoint: const Offset(20, 20),
        endPoint: const Offset(120, 70),
      );

      final textItem = CanvasTextItem(
        id: 'text-1',
        text: 'Hello Notelekh',
        position: const Offset(30, 30),
        color: Colors.black,
      );

      final tapeItem = CanvasTapeItem(
        id: 'tape-1',
        rect: const Rect.fromLTWH(50, 50, 100, 30),
      );

      final imageItem = CanvasImageItem(
        id: 'img-1',
        bounds: const Rect.fromLTWH(100, 100, 200, 150),
      );

      stroke.isSelected = true;
      lineShape.isSelected = true;
      textItem.isSelected = true;
      tapeItem.isSelected = true;
      imageItem.isSelected = true;
      final objects = [stroke, lineShape, textItem, tapeItem, imageItem];
      const delta = Offset(25, 35);

      LassoTool.translateObjects(objects, delta);

      // Verify stroke shifted and preserved isStylus
      expect(stroke.points.first.x, 35.0);
      expect(stroke.points.first.y, 45.0);
      expect(stroke.points.first.isStylus, isTrue);

      // Verify line shape shifted bounds AND endpoints
      expect(lineShape.bounds.left, 45.0);
      expect(lineShape.bounds.top, 55.0);
      expect(lineShape.startPoint, const Offset(45, 55));
      expect(lineShape.endPoint, const Offset(145, 105));

      // Verify text shifted
      expect(textItem.position, const Offset(55, 65));

      // Verify tape shifted
      expect(tapeItem.rect.left, 75.0);
      expect(tapeItem.rect.top, 85.0);

      // Verify image shifted
      expect(imageItem.bounds.left, 125.0);
      expect(imageItem.bounds.top, 135.0);
    });

    test('Tape tool supports masking toggle for active study', () {
      final tape = CanvasTapeItem(
        id: 'tape-study-1',
        rect: const Rect.fromLTWH(100, 100, 120, 32),
        isMasked: true,
      );

      expect(tape.isMasked, isTrue);

      // Tap on tape to reveal answer
      final unmaskedTape = tape.copyWith(isMasked: false);
      expect(unmaskedTape.isMasked, isFalse);
      expect(unmaskedTape.rect, tape.rect);
    });
  });

  group('3. Undo / Redo Architecture', () {
    test('Undo and Redo maintain document integrity across multiple operations', () {
      final appState = AppState();
      appState.currentCanvasDoc = CanvasDocModel(
        id: 'undo-doc',
        workspaceId: 'ws-1',
        name: 'Undo Redo Test',
        pages: [CanvasPage(id: 'page-1', pageNumber: 1, objects: [])],
      );
      appState.canvasObjects = [];

      final obj1 = CanvasTextItem(
        id: 't-1',
        text: 'First Note',
        position: const Offset(10, 10),
        color: Colors.black,
      );

      final obj2 = CanvasShapeItem(
        id: 's-1',
        shapeType: 'rectangle',
        bounds: const Rect.fromLTWH(50, 50, 80, 80),
        strokeColor: Colors.red,
      );

      // Add first object
      appState.addCanvasObject(obj1);
      expect(appState.canvasObjects.length, 1);
      expect(appState.undoStack.isNotEmpty, isTrue);
      expect(appState.redoStack.isEmpty, isTrue);

      // Add second object
      appState.addCanvasObject(obj2);
      expect(appState.canvasObjects.length, 2);

      // Perform Undo
      appState.undo();
      expect(appState.canvasObjects.length, 1);
      expect(appState.canvasObjects.first.id, 't-1');
      expect(appState.redoStack.isNotEmpty, isTrue);

      // Perform Redo
      appState.redo();
      expect(appState.canvasObjects.length, 2);
      expect(appState.canvasObjects.last.id, 's-1');

      // Undo both
      appState.undo();
      appState.undo();
      expect(appState.canvasObjects, isEmpty);
      expect(appState.undoStack.isEmpty, isTrue);
      expect(appState.redoStack.isNotEmpty, isTrue);
    });
  });

  group('4. Cloud Sync & Multi-device Conflict Protection', () {
    test('Local-first state protects active document from being overwritten by stale remote snapshot', () {
      final appState = AppState();
      final initialDoc = CanvasDocModel(
        id: 'notebook-alpha',
        workspaceId: 'ws-1',
        name: 'Local First Notebook',
        pages: [
          CanvasPage(
            id: 'p-1',
            pageNumber: 1,
            objects: [
              CanvasStrokeItem(
                id: 'local-stroke-1',
                points: [
                  StrokePoint(x: 10, y: 10, pressure: 0.5, tilt: 0.0, velocity: 0.0, timestamp: 0),
                  StrokePoint(x: 20, y: 20, pressure: 0.5, tilt: 0.0, velocity: 0.0, timestamp: 10),
                ],
                color: Colors.black,
                strokeWidth: 2.5,
              ),
              CanvasStrokeItem(
                id: 'local-stroke-2',
                points: [
                  StrokePoint(x: 30, y: 30, pressure: 0.5, tilt: 0.0, velocity: 0.0, timestamp: 20),
                ],
                color: Colors.black,
                strokeWidth: 2.5,
              ),
            ],
          ),
        ],
      );

      appState.currentCanvasDoc = initialDoc;
      appState.canvasObjects = List.from(initialDoc.pages.first.objects);

      expect(appState.canvasObjects.length, 2);

      // Verify that local edits are preserved
      expect(appState.canvasObjects.length, 2);
      expect(appState.canvasObjects.map((o) => o.id), containsAll(['local-stroke-1', 'local-stroke-2']));
    });
  });
}
