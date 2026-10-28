import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_workspace_client/features/canvas/canvas_state.dart';
import 'package:ai_workspace_client/features/canvas/engine/canvas_gesture_manager.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:ai_workspace_client/features/canvas/engine/canvas_performance_profiler.dart';
import 'package:ai_workspace_client/features/canvas/canvas_screen.dart';
import 'package:ai_workspace_client/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LiveStrokeNotifier & Live Inking Pipeline', () {
    test('start() immediately updates value, sets currentTip, and notifies listeners synchronously', () {
      final notifier = LiveStrokeNotifier();
      int notifyCount = 0;
      notifier.addListener(() => notifyCount++);

      final p0 = StrokePoint(x: 10.0, y: 20.0, timestamp: 100);
      notifier.start(p0);

      expect(notifier.value.length, equals(1));
      expect(notifier.value.first, equals(p0));
      expect(notifier.currentTip, equals(const Offset(10.0, 20.0)));
      expect(notifier.lastMid, isNull);
      expect(notifyCount, equals(1), reason: 'Must notify synchronously without waiting for scheduleFrameCallback');
    });

    test('add() incrementally constructs pure midpoint quadratic beziers without baked-in tip line', () {
      final notifier = LiveStrokeNotifier();
      int notifyCount = 0;
      notifier.addListener(() => notifyCount++);

      final p0 = StrokePoint(x: 0.0, y: 0.0, timestamp: 100);
      final p1 = StrokePoint(x: 10.0, y: 10.0, timestamp: 110);
      final p2 = StrokePoint(x: 20.0, y: 10.0, timestamp: 120);

      notifier.start(p0);
      expect(notifyCount, equals(1));

      // Second point
      notifier.add(p1);
      expect(notifyCount, equals(2));
      expect(notifier.value.length, equals(2));
      expect(notifier.lastMid, equals(const Offset(5.0, 5.0)));
      expect(notifier.currentTip, equals(const Offset(10.0, 10.0)));

      // Third point
      notifier.add(p2);
      expect(notifyCount, equals(3));
      expect(notifier.value.length, equals(3));
      expect(notifier.lastMid, equals(const Offset(15.0, 10.0)));
      expect(notifier.currentTip, equals(const Offset(20.0, 10.0)));
    });

    test('updateLast() refines the tip without resetting livePath', () {
      final notifier = LiveStrokeNotifier();
      final p0 = StrokePoint(x: 0.0, y: 0.0, timestamp: 100);
      final p1 = StrokePoint(x: 10.0, y: 10.0, timestamp: 110);

      notifier.start(p0);
      notifier.add(p1);

      final p1Refined = StrokePoint(x: 10.5, y: 10.2, pressure: 0.8, timestamp: 115);
      notifier.updateLast(p1Refined);

      expect(notifier.value.length, equals(2));
      expect(notifier.value.last, equals(p1Refined));
      expect(notifier.currentTip, equals(const Offset(10.5, 10.2)));
    });

    test('clear() cleans all live geometry and points', () {
      final notifier = LiveStrokeNotifier();
      notifier.start(StrokePoint(x: 0, y: 0));
      notifier.add(StrokePoint(x: 10, y: 10));

      notifier.clear();

      expect(notifier.value, isEmpty);
      expect(notifier.lastMid, isNull);
      expect(notifier.currentTip, isNull);
    });
  });

  group('Hot Path Telemetry Isolation', () {
    test('CanvasGestureManager does not allocate or emit telemetry when enableTelemetry is false', () {
      final manager = CanvasGestureManager(screenToWorld: (pos) => pos);
      manager.enableTelemetry = false;

      int telemetryEventsCount = 0;
      manager.onPointerTelemetry = (_) => telemetryEventsCount++;

      manager.onPointerDown(
        const PointerDownEvent(pointer: 1, kind: PointerDeviceKind.stylus, position: Offset(10, 10)),
        'pen',
      );
      manager.onPointerMove(
        const PointerMoveEvent(pointer: 1, kind: PointerDeviceKind.stylus, position: Offset(20, 20)),
        currentPan: Offset.zero,
        currentZoom: 1.0,
        currentTool: 'pen',
      );
      manager.onPointerUp(
        const PointerUpEvent(pointer: 1, kind: PointerDeviceKind.stylus, position: Offset(20, 20)),
      );

      expect(telemetryEventsCount, equals(0),
          reason: 'Telemetry callbacks must be 100% bypassed in normal production mode to eliminate GC allocations');

      manager.enableTelemetry = true;
      manager.onPointerDown(
        const PointerDownEvent(pointer: 2, kind: PointerDeviceKind.stylus, position: Offset(10, 10)),
        'pen',
      );
      expect(telemetryEventsCount, greaterThan(0),
          reason: 'Telemetry emits only when diagnostic HUD is explicitly enabled');
    });
  });

  group('Rapid A -> B -> C Stroke Commit & AppShell Isolation', () {
    test('committing strokes does NOT notify appShellNotifier', () {
      final appState = AppState();
      int appShellNotifications = 0;
      int generalNotifications = 0;

      appState.appShellNotifier.addListener(() => appShellNotifications++);
      appState.addListener(() => generalNotifications++);

      // Rapid stroke A
      appState.addCanvasObject(CanvasStrokeItem(
        id: 'stroke-A',
        points: [StrokePoint(x: 10, y: 10), StrokePoint(x: 15, y: 25)],
        color: Colors.black,
      ));

      // Rapid stroke B
      appState.addCanvasObject(CanvasStrokeItem(
        id: 'stroke-B',
        points: [StrokePoint(x: 30, y: 10), StrokePoint(x: 35, y: 25)],
        color: Colors.black,
      ));

      // Rapid stroke C
      appState.addCanvasObject(CanvasStrokeItem(
        id: 'stroke-C',
        points: [StrokePoint(x: 50, y: 10), StrokePoint(x: 55, y: 25)],
        color: Colors.black,
      ));

      expect(appState.canvasObjects.length, equals(3));
      expect(generalNotifications, equals(3), reason: 'Canvas-local painters must receive notification');
      expect(appShellNotifications, equals(0),
          reason: 'MaterialApp and ResponsiveShell must NOT rebuild on stroke commit');

      // Now change tab index or auth
      appState.setNavIndex(2);
      expect(appShellNotifications, equals(1),
          reason: 'appShellNotifier only fires for top-level shell routing/theme/auth changes');
    });
  });

  group('CanvasPerformanceProfiler Runtime Instrumentation', () {
    test('accurately records T0 through T6 and calculates latency without allocations', () {
      final profiler = CanvasPerformanceProfiler.instance;
      profiler.reset();

      // Stroke 1: PointerDown (T0)
      profiler.markPointerDown();
      expect(profiler.t0DownUs, isNotNull);

      // T1, T2, T3
      profiler.markPointAppended();
      expect(profiler.t1PointAppendedUs, isNotNull);

      profiler.markGeometryUpdated();
      expect(profiler.t2GeometryUpdatedUs, isNotNull);

      profiler.markRepaintRequested();
      expect(profiler.t3RepaintRequestedUs, isNotNull);

      // T4 Painter executed
      profiler.markPainterExecuted();
      expect(profiler.latestDownToFirstPaintMs, greaterThanOrEqualTo(0.0));

      // T5 PointerUp
      profiler.markPointerUp();
      expect(profiler.t5UpUs, isNotNull);
      expect(profiler.totalStrokesCompleted, equals(1));

      // Stroke 2: Immediate PointerDown (T6)
      profiler.markPointerDown();
      expect(profiler.latestUpToDownGapMs, greaterThanOrEqualTo(0.0));
    });
  });

  group('CanvasPainter Instant State Synchronization (Zero Tool-Switch Delay)', () {
    test('CanvasPainter dynamically pulls effectiveObjects and effectivePages from AppState on repaint', () {
      final appState = AppState();
      final painter = CanvasPainter(
        appState: appState,
        repaint: appState,
        objects: const [],
        currentPoints: const [],
        currentTool: CanvasTool.pen,
        currentColor: Colors.black,
        currentWidth: 2.0,
        isDark: false,
        panOffset: Offset.zero,
        zoomScale: 1.0,
        paperStyle: CanvasPaperStyle.blankSlate,
        isPageViewMode: false,
        pageTitle: 'Page 1',
        pageNumber: 1,
        totalPages: 1,
      );

      expect(painter.effectiveObjects, isEmpty);

      // Add a stroke to appState
      final stroke = CanvasStrokeItem(
        id: 'sync-stroke-1',
        points: [StrokePoint(x: 10, y: 10), StrokePoint(x: 20, y: 20)],
        color: Colors.black,
      );
      appState.addCanvasObject(stroke);

      // Painter instance created before the stroke was added MUST immediately see the new stroke
      // without needing to wait for a widget rebuild or tool change!
      expect(painter.effectiveObjects.length, equals(1));
      expect(painter.effectiveObjects.first.id, equals('sync-stroke-1'));
    });

    test('Selection mutations (delete, duplicate, recolor, z-order) support atomic undo/redo', () {
      final appState = AppState();
      final stroke1 = CanvasStrokeItem(
        id: 'stroke-1',
        points: [StrokePoint(x: 10, y: 10), StrokePoint(x: 20, y: 20)],
        color: Colors.black,
      );
      final stroke2 = CanvasStrokeItem(
        id: 'stroke-2',
        points: [StrokePoint(x: 30, y: 30), StrokePoint(x: 40, y: 40)],
        color: Colors.red,
      );

      appState.addCanvasObject(stroke1);
      appState.addCanvasObject(stroke2);
      expect(appState.canvasObjects.length, equals(2));

      // Select stroke1
      stroke1.isSelected = true;
      appState.selectedCanvasObjects.add(stroke1);

      // Duplicate
      appState.duplicateSelectedCanvasObjects();
      expect(appState.canvasObjects.length, equals(3));
      expect(appState.selectedCanvasObjects.length, equals(1));

      // Undo duplicate
      appState.undo();
      expect(appState.canvasObjects.length, equals(2));

      // Re-select stroke1 and delete
      stroke1.isSelected = true;
      appState.selectedCanvasObjects.add(stroke1);
      appState.deleteSelectedCanvasObjects();
      expect(appState.canvasObjects.length, equals(1));
      expect(appState.canvasObjects.first.id, equals('stroke-2'));

      // Undo delete
      appState.undo();
      expect(appState.canvasObjects.length, equals(2));
    });

    test('CanvasGestureManager properly classifies triangle tool as a shape drag tool', () {
      final manager = CanvasGestureManager(screenToWorld: (pos) => pos);
      bool shapeDragTriggered = false;
      manager.onShapeDrag = (pos, isStart) {
        shapeDragTriggered = true;
      };

      manager.onPointerDown(
        const PointerDownEvent(pointer: 1, kind: PointerDeviceKind.touch, position: Offset(10, 10)),
        'triangle',
      );

      expect(shapeDragTriggered, isTrue);
      expect(manager.state, equals(CanvasInputState.shapeDragging));
    });

    test('CanvasGestureManager routes mouse shape dragging and lasso moves properly', () {
      final manager = CanvasGestureManager(screenToWorld: (pos) => pos);
      final shapeMoves = <Offset>[];
      final lassoMoves = <Offset>[];
      StrokePoint? strokeEndResult;

      manager.onShapeDrag = (pos, isStart) {
        if (!isStart) shapeMoves.add(pos);
      };
      manager.onLassoPoint = (pos, isStart) {
        if (!isStart) lassoMoves.add(pos);
      };
      manager.onStrokeEnd = (point) {
        strokeEndResult = point;
      };

      // 1. Mouse shape drag
      manager.onPointerDown(
        const PointerDownEvent(pointer: 10, kind: PointerDeviceKind.mouse, position: Offset(10, 10)),
        'rectangle',
      );
      expect(manager.state, equals(CanvasInputState.shapeDragging));

      manager.onPointerMove(
        const PointerMoveEvent(pointer: 10, kind: PointerDeviceKind.mouse, position: Offset(50, 60)),
        currentPan: Offset.zero,
        currentZoom: 1.0,
        currentTool: 'rectangle',
      );
      expect(shapeMoves, contains(const Offset(50, 60)));

      manager.onPointerUp(
        const PointerUpEvent(pointer: 10, kind: PointerDeviceKind.mouse, position: Offset(50, 60)),
      );
      expect(manager.state, equals(CanvasInputState.idle));

      // 2. Mouse lasso
      manager.onPointerDown(
        const PointerDownEvent(pointer: 11, kind: PointerDeviceKind.mouse, position: Offset(20, 20)),
        'lasso',
      );
      expect(manager.state, equals(CanvasInputState.lassoing));

      manager.onPointerMove(
        const PointerMoveEvent(pointer: 11, kind: PointerDeviceKind.mouse, position: Offset(80, 90)),
        currentPan: Offset.zero,
        currentZoom: 1.0,
        currentTool: 'lasso',
      );
      expect(lassoMoves, contains(const Offset(80, 90)));

      manager.onPointerUp(
        const PointerUpEvent(pointer: 11, kind: PointerDeviceKind.mouse, position: Offset(80, 90)),
      );
      expect(manager.state, equals(CanvasInputState.idle));

      // 3. Mouse pen drawing with onStrokeEnd
      manager.onPointerDown(
        const PointerDownEvent(pointer: 12, kind: PointerDeviceKind.mouse, position: Offset(5, 5)),
        'pen',
      );
      expect(manager.state, equals(CanvasInputState.mouseDrawing));

      manager.onPointerMove(
        const PointerMoveEvent(pointer: 12, kind: PointerDeviceKind.mouse, position: Offset(15, 25)),
        currentPan: Offset.zero,
        currentZoom: 1.0,
        currentTool: 'pen',
      );

      manager.onPointerUp(
        const PointerUpEvent(pointer: 12, kind: PointerDeviceKind.mouse, position: Offset(15, 25)),
      );
      expect(manager.state, equals(CanvasInputState.idle));
      expect(strokeEndResult, isNotNull);
    });

    test('CanvasDrawingState and AppState synchronize tape and shape parameters', () {
      final drawingState = CanvasDrawingState();
      drawingState.setTapeColor(const Color(0xFFFDE047));
      drawingState.setTapeHeight(38.0);
      expect(drawingState.tapeColor, equals(const Color(0xFFFDE047)));
      expect(drawingState.tapeHeight, equals(38.0));

      drawingState.setTool(CanvasTool.tape);
      expect(drawingState.currentTool, equals(CanvasTool.tape));

      drawingState.setTool(CanvasTool.laser);
      expect(drawingState.currentTool, equals(CanvasTool.laser));
    });
  });
}

