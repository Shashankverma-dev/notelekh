import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_workspace_client/state/app_state.dart';
import 'package:ai_workspace_client/features/canvas/models/page_model.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';
import 'package:ai_workspace_client/features/canvas/engine/canvas_gesture_manager.dart';

void main() {
  group('Zero Data Loss & Safe Deserialization Tests', () {
    test('StrokePoint.fromJson handles missing or null numeric fields safely', () {
      final point = StrokePoint.fromJson({
        'x': null,
        'y': null,
        'pressure': null,
      });
      expect(point.x, equals(0.0));
      expect(point.y, equals(0.0));
      expect(point.pressure, equals(0.5));
    });

    test('CanvasStrokeItem.fromJson safely parses malformed or hex colors', () {
      final stroke = CanvasStrokeItem.fromJson({
        'id': 'test-stroke-1',
        'points': [
          {'x': 100.0, 'y': 150.0, 'pressure': 0.6},
          {'x': 120.0, 'y': 160.0, 'pressure': 0.7},
        ],
        'color': '#ff3366', // hex with #
        'width': 2.5,
        'opacity': 1.0,
        'tool': 'pen',
      });
      expect(stroke.id, equals('test-stroke-1'));
      expect(stroke.points.length, equals(2));
      expect(stroke.color, isNotNull);
    });

    test('CanvasStrokeItem.fromJson falls back gracefully when color is completely invalid', () {
      final stroke = CanvasStrokeItem.fromJson({
        'id': 'test-stroke-2',
        'points': [
          {'x': 50.0, 'y': 50.0},
        ],
        'color': 'not-a-color',
        'width': 2.0,
      });
      expect(stroke.id, equals('test-stroke-2'));
      expect(stroke.color.toARGB32(), equals(0xFF1E293B));
    });
  });

  group('CanvasGestureManager Pointer Cancellation Safeguard Tests', () {
    test('onPointerCancel invokes onStrokeCancel with discard: false to prevent stroke loss', () {
      bool cancelInvoked = false;
      bool wasDiscarded = true;

      final manager = CanvasGestureManager(
        screenToWorld: (pos) => pos,
      );
      manager.onStrokeCancel = ({bool discard = false}) {
        cancelInvoked = true;
        wasDiscarded = discard;
      };

      manager.onPointerDown(
        const PointerDownEvent(
          pointer: 1,
          position: Offset(100, 100),
          kind: ui.PointerDeviceKind.touch,
        ),
        'pen',
      );

      manager.onPointerCancel(
        const PointerCancelEvent(
          pointer: 1,
          position: Offset(105, 105),
          kind: ui.PointerDeviceKind.touch,
        ),
      );

      expect(cancelInvoked, isTrue);
      expect(wasDiscarded, isFalse, reason: 'In-progress stroke points must never be discarded on cancellation');
    });
  });

  group('Notebook Page Synchronization Tests', () {
    test('AppState maintains and commits strokes across multiple notebook pages', () {
      final appState = AppState();
      
      final page1 = CanvasPage(
        id: 'page-1',
        pageNumber: 1,
        title: 'Page 1',
        objects: [],
      );
      final page2 = CanvasPage(
        id: 'page-2',
        pageNumber: 2,
        title: 'Page 2',
        objects: [],
      );
      final doc = CanvasDocModel(
        id: 'notebook-1',
        name: 'Test Notebook',
        workspaceId: 'ws-1',
        pages: [page1, page2],
      );

      appState.canvasDocs = [doc];
      appState.currentCanvasDoc = doc;
      appState.setCanvasPage(0);
      expect(appState.currentPageIndex, equals(0));

      final stroke1 = CanvasStrokeItem(
        id: 'stroke-p1',
        points: [StrokePoint(x: 10, y: 10), StrokePoint(x: 20, y: 20)],
        color: const Color(0xFF000000),
        strokeWidth: 2.0,
      );
      appState.addCanvasObject(stroke1);
      expect(appState.canvasObjects.length, equals(1));

      appState.setCanvasPage(1);
      expect(appState.currentPageIndex, equals(1));
      expect(appState.canvasObjects.isEmpty, isTrue, reason: 'Page 2 starts blank');

      final stroke2 = CanvasStrokeItem(
        id: 'stroke-p2',
        points: [StrokePoint(x: 30, y: 30), StrokePoint(x: 40, y: 40)],
        color: const Color(0xFF2563EB),
        strokeWidth: 3.0,
      );
      appState.addCanvasObject(stroke2);
      expect(appState.canvasObjects.length, equals(1));

      appState.setCanvasPage(0);
      expect(appState.currentPageIndex, equals(0));
      expect(appState.canvasObjects.length, equals(1), reason: 'Page 1 stroke must still be intact');
      expect((appState.canvasObjects.first as CanvasStrokeItem).id, equals('stroke-p1'));

      expect(appState.canvasPages[1].objects.length, equals(1));
      expect((appState.canvasPages[1].objects.first as CanvasStrokeItem).id, equals('stroke-p2'));
    });

    test('addNewPage adds page without dropping active strokes', () {
      final appState = AppState();
      final page1 = CanvasPage(
        id: 'p-1',
        pageNumber: 1,
        title: 'Page 1',
        objects: [],
      );
      final doc = CanvasDocModel(
        id: 'notebook-2',
        name: 'Test Notebook 2',
        workspaceId: 'ws-1',
        pages: [page1],
      );
      appState.canvasDocs = [doc];
      appState.currentCanvasDoc = doc;
      appState.setCanvasPage(0);

      final stroke = CanvasStrokeItem(
        id: 'stroke-1',
        points: [StrokePoint(x: 5, y: 5), StrokePoint(x: 15, y: 15)],
        color: const Color(0xFF000000),
        strokeWidth: 2.0,
      );
      appState.addCanvasObject(stroke);

      appState.addNewPage(switchToPage: false);
      expect(appState.canvasPages.length, equals(2));
      expect(appState.canvasPages[0].objects.length, equals(1));

      appState.setCanvasPage(1);
      expect(appState.currentPageIndex, equals(1));
      expect(appState.canvasObjects.isEmpty, isTrue);

      appState.setCanvasPage(0);
      expect(appState.canvasObjects.length, equals(1));
    });
  });
}
