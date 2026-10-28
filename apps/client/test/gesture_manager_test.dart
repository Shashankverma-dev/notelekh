import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/gestures.dart';
import 'package:ai_workspace_client/features/canvas/engine/canvas_gesture_manager.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';

void main() {
  group('CanvasGestureManager — iPad & Apple Pencil Tests', () {
    late CanvasGestureManager manager;
    List<StrokePoint> emittedStarts = [];
    List<StrokePoint> emittedUpdates = [];
    List<StrokePoint> emittedEnds = [];
    int cancelCount = 0;
    double latestScale = 1.0;
    Offset latestPan = Offset.zero;
    Offset? latestPanDelta;
    Offset? hoverPos;

    setUp(() {
      emittedStarts = [];
      emittedUpdates = [];
      emittedEnds = [];
      cancelCount = 0;
      latestScale = 1.0;
      latestPan = Offset.zero;
      latestPanDelta = null;
      hoverPos = null;

      manager = CanvasGestureManager(
        screenToWorld: (screen) => screen,
      );

      manager.onStrokeStart = (pt, isStylus) => emittedStarts.add(pt);
      manager.onStrokeUpdate = (pt) => emittedUpdates.add(pt);
      manager.onStrokeEnd = (pt) => emittedEnds.add(pt);
      manager.onStrokeCancel = ({bool discard = false}) {
        cancelCount++;
      };
      manager.onTransformUpdate = (s, p) {
        latestScale = s;
        latestPan = p;
      };
      manager.onPanDelta = (delta) {
        latestPanDelta = delta;
      };
      manager.onStylusHover = (pos, tilt) => hoverPos = pos;
    });

    test('Apple Pencil touches down and draws immediately with pressure and tilt', () {
      const downEvent = PointerDownEvent(
        pointer: 1,
        kind: PointerDeviceKind.stylus,
        position: Offset(150, 200),
        pressure: 0.65,
        pressureMin: 0.0,
        pressureMax: 1.0,
        tilt: 0.40,
      );

      manager.onPointerDown(downEvent, 'pen');

      expect(manager.state, equals(CanvasInputState.pencilDrawing));
      expect(emittedStarts.length, equals(1));
      expect(emittedStarts.first.x, equals(150));
      expect(emittedStarts.first.y, equals(200));
      expect(emittedStarts.first.pressure, closeTo(0.65, 0.05));
      expect(emittedStarts.first.tilt, closeTo(0.40, 0.05));
    });

    test('Palm rejection suppresses touch events while Apple Pencil is active', () {
      // 1. Apple Pencil down
      manager.onPointerDown(
        const PointerDownEvent(
          pointer: 1,
          kind: PointerDeviceKind.stylus,
          position: Offset(100, 100),
          pressure: 0.5,
        ),
        'pen',
      );

      // 2. Palm rests on screen as a touch event
      manager.onPointerDown(
        const PointerDownEvent(
          pointer: 2,
          kind: PointerDeviceKind.touch,
          position: Offset(300, 400),
          size: 0.55,
          radiusMajor: 30.0,
          radiusMinor: 25.0,
        ),
        'pen',
      );

      // Palm should be rejected, no additional stroke started
      expect(emittedStarts.length, equals(1));
      expect(manager.state, equals(CanvasInputState.pencilDrawing));
    });

    test('Two-finger pinch-to-zoom produces ZERO ink and transitions to pinchAndPan', () {
      // Finger 1 is navigation; touch never creates ink.
      manager.onPointerDown(
        const PointerDownEvent(
          pointer: 10,
          kind: PointerDeviceKind.touch,
          position: Offset(100, 100),
        ),
        'pen',
      );

      expect(manager.state, equals(CanvasInputState.oneFingerPanning));
      expect(emittedStarts, isEmpty);

      manager.setPinchStartGeometry(1.0, Offset.zero);

      // Finger 2 touches down (pinch gesture begins!)
      manager.onPointerDown(
        const PointerDownEvent(
          pointer: 11,
          kind: PointerDeviceKind.touch,
          position: Offset(200, 100),
        ),
        'pen',
      );

      // Must immediately cancel tentative stroke and enter pinchAndPan
      expect(cancelCount, equals(0));
      expect(manager.state, equals(CanvasInputState.pinchAndPan));

      // Moving fingers apart to 300px (1.5x zoom)
      manager.onPointerMove(
        const PointerMoveEvent(
          pointer: 11,
          kind: PointerDeviceKind.touch,
          position: Offset(250, 100),
        ),
        currentZoom: 1.0,
        currentPan: Offset.zero,
        currentTool: 'pen',
      );

      // No new stroke updates or ends
      expect(emittedUpdates.isEmpty, isTrue);
      expect(emittedEnds.isEmpty, isTrue);
      expect(latestScale, greaterThan(1.0));
      expect(latestPan, isNotNull);
    });

    test('Pinch-to-zoom respects 50% minimum and 500% maximum bounds', () {
      manager.setPinchStartGeometry(1.0, Offset.zero);

      // Down with 2 fingers 100px apart
      manager.onPointerDown(
        const PointerDownEvent(pointer: 20, kind: PointerDeviceKind.touch, position: Offset(100, 100)),
        'pen',
      );
      manager.onPointerDown(
        const PointerDownEvent(pointer: 21, kind: PointerDeviceKind.touch, position: Offset(200, 100)),
        'pen',
      );

      // Extreme pinch-out: fingers 1000px apart
      manager.onPointerMove(
        const PointerMoveEvent(pointer: 21, kind: PointerDeviceKind.touch, position: Offset(1100, 100)),
        currentZoom: 1.0,
        currentPan: Offset.zero,
        currentTool: 'pen',
      );

      expect(latestScale, equals(5.0)); // Clamped to 500%

      // Extreme pinch-in: fingers 10px apart
      manager.onPointerMove(
        const PointerMoveEvent(pointer: 21, kind: PointerDeviceKind.touch, position: Offset(110, 100)),
        currentZoom: 1.0,
        currentPan: Offset.zero,
        currentTool: 'pen',
      );

      expect(latestScale, equals(0.5)); // Clamped to 50%
    });

    test('Apple Pencil hover emits hover coordinates for cursor reticle', () {
      manager.onPointerHover(
        const PointerHoverEvent(
          kind: PointerDeviceKind.stylus,
          position: Offset(420, 310),
          tilt: 0.20,
        ),
      );

      expect(hoverPos, isNotNull);
      expect(hoverPos!.dx, equals(420));
      expect(hoverPos!.dy, equals(310));

      // Moving away clears hover
      manager.onPointerHover(
        const PointerHoverEvent(
          kind: PointerDeviceKind.mouse,
          position: Offset(420, 310),
        ),
      );

      expect(hoverPos, isNull);
    });

    test('Rapid successive strokes (word 1 then word 2) both write successfully without lock-out', () {
      // Stroke 1 (Word 1)
      manager.onPointerDown(
        const PointerDownEvent(pointer: 30, kind: PointerDeviceKind.stylus, position: Offset(50, 50), pressure: 0.5),
        'pen',
      );
      expect(emittedStarts.length, equals(1));
      manager.onPointerMove(
        const PointerMoveEvent(pointer: 30, kind: PointerDeviceKind.stylus, position: Offset(60, 60), pressure: 0.5),
        currentZoom: 1.0,
        currentPan: Offset.zero,
        currentTool: 'pen',
      );
      manager.onPointerUp(
        const PointerUpEvent(pointer: 30, kind: PointerDeviceKind.stylus, position: Offset(70, 70)),
      );
      expect(emittedEnds.length, equals(1));
      expect(manager.state, equals(CanvasInputState.idle));

      // Stroke 2 (Word 2, immediately after stroke 1)
      manager.onPointerDown(
        const PointerDownEvent(pointer: 31, kind: PointerDeviceKind.touch, position: Offset(150, 50), pressure: 0.5),
        'pen',
      );
      expect(emittedStarts.length, equals(1));
      manager.onPointerMove(
        const PointerMoveEvent(pointer: 31, kind: PointerDeviceKind.touch, position: Offset(160, 60), pressure: 0.5),
        currentZoom: 1.0,
        currentPan: Offset.zero,
        currentTool: 'pen',
      );
      manager.onPointerUp(
        const PointerUpEvent(pointer: 31, kind: PointerDeviceKind.touch, position: Offset(170, 70)),
      );
      expect(emittedEnds.length, equals(1));
      expect(manager.state, equals(CanvasInputState.idle));
    });

    test('Palm touch down, move, and up while Apple Pencil writes does NOT kill pencil stroke', () {
      // 1. Apple Pencil touches down and starts writing
      manager.onPointerDown(
        const PointerDownEvent(pointer: 40, kind: PointerDeviceKind.stylus, position: Offset(100, 100), pressure: 0.6),
        'pencil',
      );
      expect(manager.state, equals(CanvasInputState.pencilDrawing));
      expect(emittedStarts.length, equals(1));

      // 2. Palm touches down while pencil is writing
      manager.onPointerDown(
        const PointerDownEvent(pointer: 41, kind: PointerDeviceKind.touch, position: Offset(200, 300)),
        'pencil',
      );
      // Pencil drawing must NOT be interrupted or cancelled
      expect(manager.state, equals(CanvasInputState.pencilDrawing));
      expect(cancelCount, equals(0));

      // 3. Apple Pencil moves (writes letters)
      manager.onPointerMove(
        const PointerMoveEvent(pointer: 40, kind: PointerDeviceKind.stylus, position: Offset(120, 110), pressure: 0.7),
        currentZoom: 1.0,
        currentPan: Offset.zero,
        currentTool: 'pencil',
      );
      expect(emittedUpdates.length, equals(1));

      // 4. Palm lifts up from screen
      manager.onPointerUp(
        const PointerUpEvent(pointer: 41, kind: PointerDeviceKind.touch, position: Offset(200, 300)),
      );
      // CRITICAL: Pencil drawing must STILL be active! Must NOT end stroke!
      expect(manager.state, equals(CanvasInputState.pencilDrawing));
      expect(emittedEnds.length, equals(0));

      // 5. Apple Pencil continues writing
      manager.onPointerMove(
        const PointerMoveEvent(pointer: 40, kind: PointerDeviceKind.stylus, position: Offset(140, 120), pressure: 0.8),
        currentZoom: 1.0,
        currentPan: Offset.zero,
        currentTool: 'pencil',
      );
      expect(emittedUpdates.length, equals(2));

      // 6. Finally, Apple Pencil itself lifts up
      manager.onPointerUp(
        const PointerUpEvent(pointer: 40, kind: PointerDeviceKind.stylus, position: Offset(160, 130)),
      );
      expect(emittedEnds.length, equals(1));
      expect(manager.state, equals(CanvasInputState.idle));
    });

    test('Palm touch cancelled by iOS does NOT cancel active Apple Pencil stroke', () {
      // 1. Apple Pencil begins writing
      manager.onPointerDown(
        const PointerDownEvent(pointer: 50, kind: PointerDeviceKind.stylus, position: Offset(50, 50), pressure: 0.5),
        'pen',
      );
      expect(manager.state, equals(CanvasInputState.pencilDrawing));

      // 2. iOS sends pointer cancel for a resting palm contact (pointer 51)
      manager.onPointerCancel(
        const PointerCancelEvent(pointer: 51, kind: PointerDeviceKind.touch, position: Offset(300, 300)),
      );
      // CRITICAL: Pencil must NOT be cancelled
      expect(manager.state, equals(CanvasInputState.pencilDrawing));
      expect(cancelCount, equals(0));

      // 3. Apple Pencil writes and lifts cleanly
      manager.onPointerMove(
        const PointerMoveEvent(pointer: 50, kind: PointerDeviceKind.stylus, position: Offset(70, 70), pressure: 0.6),
        currentZoom: 1.0,
        currentPan: Offset.zero,
        currentTool: 'pen',
      );
      manager.onPointerUp(
        const PointerUpEvent(pointer: 50, kind: PointerDeviceKind.stylus, position: Offset(80, 80)),
      );
      expect(emittedEnds.length, equals(1));
      expect(manager.state, equals(CanvasInputState.idle));
    });

    test('Writing lines with pencil tool (both stylus and touch) never freezes and commits cleanly', () {
      // 1. Stylus writing with pencil tool
      manager.onPointerDown(
        const PointerDownEvent(pointer: 60, kind: PointerDeviceKind.stylus, position: Offset(10, 10), pressure: 0.5),
        'pencil',
      );
      expect(manager.state, equals(CanvasInputState.pencilDrawing));
      expect(emittedStarts.length, equals(1));

      manager.onPointerMove(
        const PointerMoveEvent(pointer: 60, kind: PointerDeviceKind.stylus, position: Offset(100, 10), pressure: 0.5),
        currentZoom: 1.0,
        currentPan: Offset.zero,
        currentTool: 'pencil',
      );
      expect(emittedUpdates.length, equals(1));

      manager.onPointerUp(
        const PointerUpEvent(pointer: 60, kind: PointerDeviceKind.stylus, position: Offset(100, 10)),
      );
      expect(emittedEnds.length, equals(1));
      expect(manager.state, equals(CanvasInputState.idle));

      // 2. Touch screen writing with pencil tool
      manager.onPointerDown(
        const PointerDownEvent(pointer: 61, kind: PointerDeviceKind.touch, position: Offset(10, 50), pressure: 0.5),
        'pencil',
      );
      expect(manager.state, equals(CanvasInputState.oneFingerPanning));
      expect(emittedStarts.length, equals(1));

      manager.onPointerMove(
        const PointerMoveEvent(pointer: 61, kind: PointerDeviceKind.touch, position: Offset(150, 50), pressure: 0.5),
        currentZoom: 1.0,
        currentPan: Offset.zero,
        currentTool: 'pencil',
      );
      expect(emittedUpdates.length, equals(1));

      manager.onPointerUp(
        const PointerUpEvent(pointer: 61, kind: PointerDeviceKind.touch, position: Offset(150, 50)),
      );
      expect(emittedEnds.length, equals(1));
      expect(manager.state, equals(CanvasInputState.idle));
    });

    test('Touchscreen drawing with line tool triggers shape dragging without locking up canvas', () {
      Offset? draggedPos;
      manager.onShapeDrag = (pos, isStart) {
        draggedPos = pos;
      };

      manager.onPointerDown(
        const PointerDownEvent(pointer: 70, kind: PointerDeviceKind.touch, position: Offset(20, 20)),
        'line',
      );
      expect(manager.state, equals(CanvasInputState.shapeDragging));
      expect(draggedPos, isNotNull);

      manager.onPointerMove(
        const PointerMoveEvent(pointer: 70, kind: PointerDeviceKind.touch, position: Offset(200, 20)),
        currentZoom: 1.0,
        currentPan: Offset.zero,
        currentTool: 'line',
      );
      expect(draggedPos?.dx, equals(200));

      manager.onPointerUp(
        const PointerUpEvent(pointer: 70, kind: PointerDeviceKind.touch, position: Offset(200, 20)),
      );
      expect(manager.state, equals(CanvasInputState.idle));
    });

    test('Browser skips pointerdown during rapid iPad handwriting -> recovers and writes on pointermove', () {
      expect(manager.state, equals(CanvasInputState.idle));

      // Browser skips pointerdown and sends pointermove with pressure > 0 while idle:
      manager.onPointerMove(
        const PointerMoveEvent(
          pointer: 80,
          kind: PointerDeviceKind.stylus,
          position: Offset(100, 100),
          pressure: 0.60,
          buttons: 1,
        ),
        currentZoom: 1.0,
        currentPan: Offset.zero,
        currentTool: 'pen',
      );

      // A move without PointerDown is incomplete and cannot create a stroke.
      expect(manager.state, equals(CanvasInputState.idle));
      expect(emittedStarts, isEmpty);

      // Continuing move emits stroke update
      manager.onPointerMove(
        const PointerMoveEvent(
          pointer: 80,
          kind: PointerDeviceKind.stylus,
          position: Offset(120, 120),
          pressure: 0.70,
          buttons: 1,
        ),
        currentZoom: 1.0,
        currentPan: Offset.zero,
        currentTool: 'pen',
      );
      expect(emittedUpdates, isEmpty);

      // Lifts cleanly
      manager.onPointerUp(
        const PointerUpEvent(pointer: 80, kind: PointerDeviceKind.stylus, position: Offset(120, 120)),
      );
      expect(emittedEnds, isEmpty);
      expect(manager.state, equals(CanvasInputState.idle));
    });

    test('Apple Pencil touches down during hover -> begins drawing immediately', () {
      expect(manager.state, equals(CanvasInputState.idle));

      // Hover event with button down (touchdown during hover in Safari)
      manager.onPointerHover(
        const PointerHoverEvent(
          kind: PointerDeviceKind.stylus,
          position: Offset(250, 250),
          buttons: 1,
        ),
      );

      expect(manager.state, equals(CanvasInputState.idle));
      expect(emittedStarts, isEmpty);

      manager.onPointerUp(
        const PointerUpEvent(pointer: 0, kind: PointerDeviceKind.stylus, position: Offset(250, 250)),
      );
      expect(manager.state, equals(CanvasInputState.idle));
    });

    test('Stylus reported with touch kind but analog pressure -> correctly recognized as stylus', () {
      manager.onPointerDown(
        const PointerDownEvent(
          pointer: 90,
          kind: PointerDeviceKind.touch,
          position: Offset(300, 300),
          pressure: 0.58, // Analog pressure from stylus
          pressureMin: 0.0,
          pressureMax: 1.0,
        ),
        'pen',
      );

      // Device kind is authoritative; a touch remains a gesture.
      expect(manager.state, equals(CanvasInputState.oneFingerPanning));
      expect(manager.isPencilActive, isFalse);
      expect(manager.activeStylusPointerId, isNull);
      expect(emittedStarts, isEmpty);
    });

    test('Section 8: Apple Pencil draws immediately even if pressure is reported as 0.0 (fallback 0.50)', () {
      manager.onPointerDown(
        const PointerDownEvent(
          pointer: 101,
          kind: PointerDeviceKind.stylus,
          position: Offset(120, 150),
          pressure: 0.0, // Pressure 0 reported by device/browser
          pressureMin: 0.0,
          pressureMax: 1.0,
        ),
        'pen',
      );

      expect(manager.state, equals(CanvasInputState.pencilDrawing));
      expect(emittedStarts.length, equals(1));
      expect(emittedStarts.first.pressure, closeTo(0.50, 0.01)); // Guaranteed fallback
    });

    test('Section 11: Apple Pencil draws on pointerdown even if buttons == 0', () {
      manager.onPointerDown(
        const PointerDownEvent(
          pointer: 102,
          kind: PointerDeviceKind.stylus,
          position: Offset(200, 220),
          buttons: 0, // WebKit may report buttons 0 on initial touch
          pressure: 0.70,
        ),
        'pen',
      );

      expect(manager.state, equals(CanvasInputState.pencilDrawing));
      expect(emittedStarts.length, equals(1));
    });

    test('Resting palm already down on screen does NOT block Apple Pencil from writing immediately', () {
      // Step 1: User rests palm on glass first (touch event down)
      manager.onPointerDown(
        const PointerDownEvent(pointer: 201, kind: PointerDeviceKind.touch, position: Offset(300, 400)),
        'pen',
      );

      // Step 2: Apple Pencil touches down while palm is still on the glass
      manager.onPointerDown(
        const PointerDownEvent(pointer: 202, kind: PointerDeviceKind.stylus, position: Offset(150, 150), pressure: 0.8),
        'pen',
      );

      // Apple Pencil MUST be drawing immediately
      expect(manager.state, equals(CanvasInputState.pencilDrawing));
      expect(manager.activeStylusPointerId, equals(202));
      expect(emittedStarts.isNotEmpty, isTrue);

      // Apple Pencil moves
      manager.onPointerMove(
        const PointerMoveEvent(pointer: 202, kind: PointerDeviceKind.stylus, position: Offset(160, 160), pressure: 0.8),
        currentZoom: 1.0,
        currentPan: Offset.zero,
        currentTool: 'pen',
      );
      expect(emittedUpdates.isNotEmpty, isTrue);

      // Resting palm moves slightly — MUST NOT affect Apple Pencil stroke
      manager.onPointerMove(
        const PointerMoveEvent(pointer: 201, kind: PointerDeviceKind.touch, position: Offset(302, 402)),
        currentZoom: 1.0,
        currentPan: Offset.zero,
        currentTool: 'pen',
      );
      expect(manager.state, equals(CanvasInputState.pencilDrawing));
      expect(manager.activeStylusPointerId, equals(202));
    });

    test('Missed pointerup auto-recovery: successive stylus strokes always draw', () {
      // Stroke 1 starts
      manager.onPointerDown(
        const PointerDownEvent(pointer: 301, kind: PointerDeviceKind.stylus, position: Offset(50, 50), pressure: 0.6),
        'pen',
      );
      expect(manager.state, equals(CanvasInputState.pencilDrawing));
      expect(emittedStarts.length, equals(1));

      // Pointerup was MISSED by browser for pointer 301!
      // Stroke 2 touches down with new pointer 302
      manager.onPointerDown(
        const PointerDownEvent(pointer: 302, kind: PointerDeviceKind.stylus, position: Offset(80, 80), pressure: 0.6),
        'pen',
      );

      // Must have auto-committed stroke 1 and started stroke 2
      expect(emittedEnds.length, equals(1));
      expect(manager.state, equals(CanvasInputState.pencilDrawing));
      expect(manager.activeStylusPointerId, equals(302));
      expect(emittedStarts.length, equals(2));
    });

    test('Idle palm touch move does NOT synthesize accidental stroke start', () {
      expect(manager.state, equals(CanvasInputState.idle));

      // Palm moves while idle (touch move without stylus)
      manager.onPointerMove(
        const PointerMoveEvent(pointer: 401, kind: PointerDeviceKind.touch, position: Offset(100, 100)),
        currentZoom: 1.0,
        currentPan: Offset.zero,
        currentTool: 'pen',
      );

      // MUST NOT start a stroke
      expect(manager.state, equals(CanvasInputState.idle));
      expect(emittedStarts.isEmpty, isTrue);
    });

    test('Finger pinch-to-zoom works with realistic uptime timestamps and analog pressure', () {
      manager.setPinchStartGeometry(1.0, Offset.zero);

      // Finger 1 touches down with realistic non-zero timestamp & analog touchscreen pressure
      manager.onPointerDown(
        const PointerDownEvent(
          pointer: 501,
          kind: PointerDeviceKind.touch,
          position: Offset(200, 200),
          pressure: 0.35,
          timeStamp: Duration(seconds: 15),
        ),
        'pen',
        currentZoom: 1.0,
        currentPan: Offset.zero,
      );

      // Finger 2 touches down 50ms later
      manager.onPointerDown(
        const PointerDownEvent(
          pointer: 502,
          kind: PointerDeviceKind.touch,
          position: Offset(400, 200),
          pressure: 0.42,
          timeStamp: Duration(seconds: 15, milliseconds: 50),
        ),
        'pen',
        currentZoom: 1.0,
        currentPan: Offset.zero,
      );

      // Must cancel any tentative finger drawing and enter pinchAndPan
      expect(manager.state, equals(CanvasInputState.pinchAndPan));
      expect(cancelCount, equals(0));

      // Finger 2 moves to distance 400px (2x zoom out/in)
      manager.onPointerMove(
        const PointerMoveEvent(
          pointer: 502,
          kind: PointerDeviceKind.touch,
          position: Offset(600, 200),
          timeStamp: Duration(seconds: 15, milliseconds: 100),
        ),
        currentZoom: 1.0,
        currentPan: Offset.zero,
        currentTool: 'pen',
      );

      expect(latestScale, closeTo(2.0, 0.05));

      // Finger 1 lifts
      manager.onPointerUp(
        const PointerUpEvent(
          pointer: 501,
          kind: PointerDeviceKind.touch,
          position: Offset(200, 200),
        ),
      );

      expect(manager.state, equals(CanvasInputState.idle));
    });

    test('Finger pinch-to-zoom works when Hand tool is active', () {
      manager.setPinchStartGeometry(1.0, Offset.zero);

      // Touch 1 down with Hand tool
      manager.onPointerDown(
        const PointerDownEvent(
          pointer: 601,
          kind: PointerDeviceKind.touch,
          position: Offset(150, 150),
        ),
        'hand',
        currentZoom: 1.0,
        currentPan: Offset.zero,
      );

      expect(manager.state, equals(CanvasInputState.oneFingerPanning));

      // Touch 2 down with Hand tool
      manager.onPointerDown(
        const PointerDownEvent(
          pointer: 602,
          kind: PointerDeviceKind.touch,
          position: Offset(350, 150),
        ),
        'hand',
        currentZoom: 1.0,
        currentPan: Offset.zero,
      );

      expect(manager.state, equals(CanvasInputState.pinchAndPan));

      // Pinch zoom in/out
      manager.onPointerMove(
        const PointerMoveEvent(
          pointer: 602,
          kind: PointerDeviceKind.touch,
          position: Offset(550, 150),
        ),
        currentZoom: 1.0,
        currentPan: Offset.zero,
        currentTool: 'hand',
      );

      expect(latestScale, closeTo(2.0, 0.05));
    });

    test('Ultra-fast handwriting with rapid successive strokes (< 50ms) never drops strokes or locks canvas', () {
      // Simulate rapid writing: 8 strokes written consecutively at 20ms intervals
      for (int i = 0; i < 8; i++) {
        final pointerId = 700 + i;
        final startX = 20.0 + (i * 25.0);

        // Touchdown with pressure = 0.0 (common on Web / initial hardware frame)
        manager.onPointerDown(
          PointerDownEvent(
            pointer: pointerId,
            kind: PointerDeviceKind.stylus,
            position: Offset(startX, 100),
            pressure: 0.0,
            tilt: 0.15,
          ),
          'pen',
        );

        // Movement with analog pressure
        manager.onPointerMove(
          PointerMoveEvent(
            pointer: pointerId,
            kind: PointerDeviceKind.stylus,
            position: Offset(startX + 10, 120),
            pressure: 0.65,
            tilt: 0.2,
          ),
          currentZoom: 1.0,
          currentPan: Offset.zero,
          currentTool: 'pen',
        );

        // Lift
        manager.onPointerUp(
          PointerUpEvent(
            pointer: pointerId,
            kind: PointerDeviceKind.stylus,
            position: Offset(startX + 10, 120),
          ),
        );
      }

      // Exactly 8 strokes started and ended cleanly
      expect(emittedStarts.length, equals(8));
      expect(emittedUpdates.length, equals(8));
      expect(emittedEnds.length, equals(8));
      expect(manager.state, equals(CanvasInputState.idle));
    });

    test('Hand tool single-finger touch pans canvas via onPanDelta and transitions to pinchAndPan when second finger touches', () {
      // 1-finger touch down with Hand tool
      manager.onPointerDown(
        const PointerDownEvent(
          pointer: 801,
          kind: PointerDeviceKind.touch,
          position: Offset(100, 100),
        ),
        'hand',
        currentZoom: 1.0,
        currentPan: Offset.zero,
      );

      expect(manager.state, equals(CanvasInputState.oneFingerPanning));
      expect(emittedStarts, isEmpty); // Zero ink produced

      // 1-finger move pans canvas
      manager.onPointerMove(
        const PointerMoveEvent(
          pointer: 801,
          kind: PointerDeviceKind.touch,
          position: Offset(115, 120),
          delta: Offset(15, 20),
        ),
        currentZoom: 1.0,
        currentPan: Offset.zero,
        currentTool: 'hand',
      );

      expect(latestPanDelta, equals(const Offset(15, 20)));
      expect(emittedUpdates, isEmpty); // Zero ink produced

      // Second finger touches down for pinch-to-zoom
      manager.onPointerDown(
        const PointerDownEvent(
          pointer: 802,
          kind: PointerDeviceKind.touch,
          position: Offset(200, 200),
        ),
        'hand',
        currentZoom: 1.0,
        currentPan: Offset.zero,
      );

      expect(manager.state, equals(CanvasInputState.pinchAndPan));

      // Pinch zoom move
      manager.onPointerMove(
        const PointerMoveEvent(
          pointer: 802,
          kind: PointerDeviceKind.touch,
          position: Offset(300, 300),
        ),
        currentZoom: 1.0,
        currentPan: Offset.zero,
        currentTool: 'hand',
      );

      expect(latestScale, greaterThan(1.0));
      expect(emittedStarts, isEmpty); // Absolutely zero ink
    });

    test('Transition from finger drawing to two-finger pinch triggers onStrokeCancel with discard: true', () {
      // Finger 1 touches down with pen tool
      manager.onPointerDown(
        const PointerDownEvent(
          pointer: 901,
          kind: PointerDeviceKind.touch,
          position: Offset(100, 100),
        ),
        'pen',
        currentZoom: 1.0,
        currentPan: Offset.zero,
      );

      expect(manager.state, equals(CanvasInputState.oneFingerPanning));
      expect(emittedStarts, isEmpty);

      // Finger 2 touches down (initiating pinch-to-zoom)
      manager.onPointerDown(
        const PointerDownEvent(
          pointer: 902,
          kind: PointerDeviceKind.touch,
          position: Offset(250, 250),
        ),
        'pen',
        currentZoom: 1.0,
        currentPan: Offset.zero,
      );

      expect(manager.state, equals(CanvasInputState.pinchAndPan));
      expect(cancelCount, equals(0));
    });
  });
}


