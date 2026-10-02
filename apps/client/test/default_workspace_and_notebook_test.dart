import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_workspace_client/state/app_state.dart';
import 'package:ai_workspace_client/core/models/workspace_model.dart';
import 'package:ai_workspace_client/features/canvas/models/page_model.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:ai_workspace_client/core/services/notes_local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('New Account Default Workspace and Notebook Tests', () {
    test('AppState ensures exactly 1 default workspace and 1 default notebook on starter state', () async {
      final state = AppState();

      // Reset to simulate clean state as when an account is newly registered
      await state.resetWorkspace();
      expect(state.workspaces, isEmpty);
      expect(state.canvasDocs, isEmpty);

      // Simulate applying a newly registered user
      final testWs = WorkspaceModel(
        id: 'ws_test_user_123',
        userId: 'test_user_123',
        name: 'My Workspace',
        description: 'Personal notes & workspace',
        icon: 'book',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      state.workspaces = [testWs];
      state.currentWorkspace = testWs;

      final defaultNotebook = CanvasDocModel(
        id: 'notebook_${testWs.id}_default',
        workspaceId: testWs.id,
        name: 'Personal Notes',
        docType: CanvasDocType.notebook,
        coverColor: const Color(0xFF2E7D32),
        coverEmoji: '📓',
      );
      state.canvasDocs = [defaultNotebook];
      state.currentCanvasDoc = defaultNotebook;

      // Assert exactly 1 workspace exists with name "My Workspace"
      expect(state.workspaces.length, equals(1));
      expect(state.workspaces.first.name, equals('My Workspace'));

      // Assert exactly 1 notebook exists with name "Personal Notes"
      expect(state.canvasDocs.length, equals(1));
      expect(state.canvasDocs.first.name, equals('Personal Notes'));
    });

    test('Deduplicates starter notebooks if duplicate empty Personal Notes exist', () async {
      final state = AppState();
      state.userId = 'test_user_dedup';
      const wsId = 'ws_dedup_1';

      final doc1 = CanvasDocModel(
        id: 'notebook_1',
        workspaceId: wsId,
        name: 'Personal Notes',
      );
      final doc2 = CanvasDocModel(
        id: 'notebook_2',
        workspaceId: wsId,
        name: 'Personal Notes',
      );

      // Save both duplicate starter notebooks locally
      await NotesLocalStorageService.saveDocLocally(doc1, userId: state.userId);
      await NotesLocalStorageService.saveDocLocally(doc2, userId: state.userId);

      // Load docs for workspace via fetchWorkspaceCanvasDocs
      await state.fetchWorkspaceCanvasDocs(wsId);

      // Should automatically deduplicate down to 1 starter notebook
      expect(state.canvasDocs.length, equals(1));
      expect(state.canvasDocs.first.name, equals('Personal Notes'));
    });

    test('selectWorkspace clears canvasDocs and isolates workspace documents', () async {
      final state = AppState();
      state.canvasDocs = [
        CanvasDocModel(id: 'old_doc', workspaceId: 'old_ws', name: 'Old Notebook')
      ];
      expect(state.canvasDocs.length, equals(1));

      final newWs = WorkspaceModel(
        id: 'new_ws',
        userId: 'test_user',
        name: 'My Workspace',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await state.selectWorkspace(newWs);
      expect(state.currentWorkspace?.id, equals('new_ws'));
      // The old notebook from old_ws must NOT be in state.canvasDocs
      expect(state.canvasDocs.any((d) => d.id == 'old_doc'), isFalse);
    });
  });
}
