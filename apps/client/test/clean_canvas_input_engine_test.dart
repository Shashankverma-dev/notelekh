import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_workspace_client/features/canvas/engine/canvas_gesture_manager.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CanvasGestureManager manager;
  late List<StrokePoint> starts;
  late List<StrokePoint> updates;
  late List<StrokePoint> ends;
  late int cancels;

  setUp(() {
    starts = [];
    updates = [];
    ends = [];
    cancels = 0;
    manager = CanvasGestureManager(screenToWorld: (position) => position);
    manager.onStrokeStart = (point, _) => starts.add(point);
    manager.onStrokeUpdate = updates.add;
    manager.onStrokeEnd = ends.add;
    manager.onStrokeCancel = ({bool discard = false}) => cancels++;
  });

  PointerDownEvent stylusDown(int id, Offset position) => PointerDownEvent(
    pointer: id,
    position: position,
    kind: PointerDeviceKind.stylus,
    pressure: 0.42,
    tilt: 0.25,
    timeStamp: const Duration(milliseconds: 1),
  );

  test('stylus owns one complete raw stroke and preserves digitizer data', () {
    manager.onPointerDown(stylusDown(5, const Offset(10, 10)), 'pen');
    manager.onPointerMove(
      const PointerMoveEvent(
        pointer: 5,
        position: Offset(20, 20),
        kind: PointerDeviceKind.stylus,
        pressure: 0.72,
        tilt: 0.35,
        timeStamp: Duration(milliseconds: 9),
      ),
      currentZoom: 1.0,
      currentPan: Offset.zero,
      currentTool: 'pen',
    );
    manager.onPointerUp(
      const PointerUpEvent(
        pointer: 5,
        position: Offset(30, 30),
        kind: PointerDeviceKind.stylus,
        timeStamp: Duration(milliseconds: 17),
      ),
    );

    expect(starts.single.isStylus, isTrue);
    expect(starts.single.pressure, closeTo(0.42, 0.001));
    expect(starts.single.tilt, closeTo(0.25, 0.001));
    expect(updates.single.pressure, closeTo(0.72, 0.001));
    expect(updates.single.tilt, closeTo(0.35, 0.001));
    expect(ends.single.x, 30.0);
    expect(manager.state, CanvasInputState.idle);
  });

  test('touch never creates ink and two touches become pinch', () {
    manager.onPointerDown(
      const PointerDownEvent(
        pointer: 1,
        position: Offset(10, 10),
        kind: PointerDeviceKind.touch,
      ),
      'pen',
      currentZoom: 1.0,
      currentPan: Offset.zero,
    );
    manager.onPointerDown(
      const PointerDownEvent(
        pointer: 2,
        position: Offset(110, 10),
        kind: PointerDeviceKind.touch,
      ),
      'pen',
      currentZoom: 1.0,
      currentPan: Offset.zero,
    );

    expect(starts, isEmpty);
    expect(manager.state, CanvasInputState.pinchAndPan);
    expect(manager.touchGestureEngine.isPinching, isTrue);
  });

  test('touch and palm pointers cannot steal an active stylus stroke', () {
    manager.onPointerDown(stylusDown(5, const Offset(10, 10)), 'pen');
    manager.onPointerDown(
      const PointerDownEvent(
        pointer: 8,
        position: Offset(200, 200),
        kind: PointerDeviceKind.touch,
      ),
      'pen',
    );
    manager.onPointerMove(
      const PointerMoveEvent(
        pointer: 8,
        position: Offset(210, 210),
        kind: PointerDeviceKind.touch,
      ),
      currentZoom: 1.0,
      currentPan: Offset.zero,
      currentTool: 'pen',
    );
    manager.onPointerMove(
      const PointerMoveEvent(
        pointer: 5,
        position: Offset(20, 20),
        kind: PointerDeviceKind.stylus,
        pressure: 0.5,
      ),
      currentZoom: 1.0,
      currentPan: Offset.zero,
      currentTool: 'pen',
    );
    manager.onPointerUp(
      const PointerUpEvent(
        pointer: 8,
        position: Offset(210, 210),
        kind: PointerDeviceKind.touch,
      ),
    );

    expect(manager.state, CanvasInputState.pencilDrawing);
    expect(updates.length, 1);
    expect(cancels, 0);
  });

  test('pointer ID reuse creates a fresh stroke session', () {
    manager.onPointerDown(stylusDown(5, const Offset(10, 10)), 'pen');
    manager.onPointerUp(
      const PointerUpEvent(
        pointer: 5,
        position: Offset(20, 20),
        kind: PointerDeviceKind.stylus,
      ),
    );
    manager.onPointerDown(stylusDown(5, const Offset(100, 100)), 'pen');
    manager.onPointerMove(
      const PointerMoveEvent(
        pointer: 5,
        position: Offset(110, 110),
        kind: PointerDeviceKind.stylus,
        pressure: 0.6,
      ),
      currentZoom: 1.0,
      currentPan: Offset.zero,
      currentTool: 'pen',
    );

    expect(starts.length, 2);
    expect(starts.last.x, 100.0);
    expect(updates.length, 1);
  });

  test('cancel releases stylus and the next stroke starts immediately', () {
    manager.onPointerDown(stylusDown(5, const Offset(10, 10)), 'pen');
    manager.onPointerMove(
      const PointerMoveEvent(
        pointer: 5,
        position: Offset(20, 20),
        kind: PointerDeviceKind.stylus,
      ),
      currentZoom: 1.0,
      currentPan: Offset.zero,
      currentTool: 'pen',
    );
    manager.onPointerCancel(
      const PointerCancelEvent(
        pointer: 5,
        position: Offset(20, 20),
        kind: PointerDeviceKind.stylus,
      ),
    );
    manager.onPointerDown(stylusDown(5, const Offset(100, 100)), 'pen');

    expect(cancels, 1);
    expect(starts.length, 2);
    expect(manager.isPencilActive, isTrue);
  });

  test(
    'one thousand moves are accepted without copying or reclassification',
    () {
      manager.onPointerDown(stylusDown(5, Offset.zero), 'pen');
      for (var i = 1; i <= 1000; i++) {
        manager.onPointerMove(
          PointerMoveEvent(
            pointer: 5,
            position: Offset(i.toDouble(), i.toDouble()),
            kind: PointerDeviceKind.stylus,
            pressure: 0.4,
            timeStamp: Duration(milliseconds: i + 1),
          ),
          currentZoom: 1.0,
          currentPan: Offset.zero,
          currentTool: 'pen',
        );
      }

      expect(updates.length, 1000);
      expect(manager.isPencilActive, isTrue);
    },
  );

  test('mouse input cannot replace the active Pencil buffer', () {
    manager.onPointerDown(stylusDown(5, const Offset(10, 10)), 'pen');
    manager.onPointerDown(
      const PointerDownEvent(
        pointer: 8,
        position: Offset(100, 100),
        kind: PointerDeviceKind.mouse,
      ),
      'pen',
    );
    manager.onPointerMove(
      const PointerMoveEvent(
        pointer: 5,
        position: Offset(20, 20),
        kind: PointerDeviceKind.stylus,
        timeStamp: Duration(milliseconds: 9),
      ),
      currentZoom: 1.0,
      currentPan: Offset.zero,
      currentTool: 'pen',
    );
    manager.onPointerUp(
      const PointerUpEvent(
        pointer: 5,
        position: Offset(30, 30),
        kind: PointerDeviceKind.stylus,
        timeStamp: Duration(milliseconds: 17),
      ),
    );

    expect(updates, hasLength(1));
    expect(ends, hasLength(1));
    expect(ends.single.x, 30.0);
  });

  test(
    'a pointer remains with its original drawing tool after a toolbar change',
    () {
      manager.onPointerDown(stylusDown(5, const Offset(10, 10)), 'pen');
      manager.onPointerMove(
        const PointerMoveEvent(
          pointer: 5,
          position: Offset(20, 20),
          kind: PointerDeviceKind.stylus,
          timeStamp: Duration(milliseconds: 9),
        ),
        currentZoom: 1.0,
        currentPan: Offset.zero,
        currentTool: 'eraser',
      );

      expect(updates, hasLength(1));
      expect(manager.state, CanvasInputState.pencilDrawing);
    },
  );
}
