import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_workspace_client/core/services/notes_local_storage_service.dart';
import 'package:ai_workspace_client/features/canvas/models/page_model.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke.dart';

void main() {
  group('NotesLocalStorageService — Offline-First Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Saves and restores notebook with pages and strokes locally', () async {
      final stroke = CanvasStrokeItem(
        id: 'stroke-1',
        color: const Color(0xFFE11D48),
        points: [
          StrokePoint(x: 100, y: 150, pressure: 0.6, timestamp: 1000),
          StrokePoint(x: 105, y: 155, pressure: 0.7, timestamp: 1016),
        ],
        strokeWidth: 3.5,
      );

      final notebook = CanvasDocModel(
        id: 'nb-test-1',
        workspaceId: 'ws-1',
        name: 'Calculus Notes',
        pages: [
          CanvasPage(
            id: 'page-1',
            pageNumber: 1,
            title: 'Derivatives',
            objects: [stroke],
            paperStyle: CanvasPaperStyle.graphGrid,
          ),
        ],
      );

      await NotesLocalStorageService.saveDocLocally(notebook, userId: 'test_user');
      await NotesLocalStorageService.saveActiveDocId(notebook.id, userId: 'test_user');

      final loadedDoc = await NotesLocalStorageService.loadDocLocally('nb-test-1', userId: 'test_user');
      expect(loadedDoc, isNotNull);
      expect(loadedDoc!.name, equals('Calculus Notes'));
      expect(loadedDoc.pages.length, equals(1));
      expect(loadedDoc.pages.first.title, equals('Derivatives'));
      expect(loadedDoc.pages.first.paperStyle, equals(CanvasPaperStyle.graphGrid));
      expect(loadedDoc.pages.first.objects.length, equals(1));

      final loadedStroke = loadedDoc.pages.first.objects.first as CanvasStrokeItem;
      expect(loadedStroke.points.length, equals(2));
      expect(loadedStroke.points.first.x, equals(100));
      expect(loadedStroke.points.first.pressure, equals(0.6));

      final activeId = await NotesLocalStorageService.getActiveDocId(userId: 'test_user');
      expect(activeId, equals('nb-test-1'));

      final allDocs = await NotesLocalStorageService.loadAllDocsLocally(userId: 'test_user');
      expect(allDocs.length, equals(1));
      expect(allDocs.first.id, equals('nb-test-1'));
    });
  });
}
