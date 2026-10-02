import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_workspace_client/state/app_state.dart';
import 'package:ai_workspace_client/core/models/canvas_models.dart';
import 'package:ai_workspace_client/features/search/search_screen.dart';
import 'package:ai_workspace_client/features/files/files_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Files & Media Feature Tests', () {
    test('AppState initializes default workspace files and allows document creation', () async {
      final state = AppState();

      // Ensure default files are loaded
      expect(state.workspaceFiles, isNotEmpty);
      expect(state.workspaceFiles.any((f) => f.name.contains('GoodNotes')), isTrue);

      final initialCount = state.workspaceFiles.length;

      // Create a new markdown document
      final newDoc = await state.createDocumentFile(
        filename: 'My_Calculus_Notes.md',
        content: '# Calculus\n\n- Derivative rules\n- Integrals',
      );

      expect(newDoc, isNotNull);
      expect(state.workspaceFiles.length, equals(initialCount + 1));
      expect(state.workspaceFiles.first.name, equals('My_Calculus_Notes.md'));
      expect(state.workspaceFiles.first.content, contains('Integrals'));

      // Delete the document
      await state.deleteFile(newDoc!.id);
      expect(state.workspaceFiles.length, equals(initialCount));
      expect(state.workspaceFiles.any((f) => f.id == newDoc.id), isFalse);
    });
  });

  group('Global Search Feature Tests', () {
    test('AppState performs instant client-side search across notebooks, pages, and files', () async {
      final state = AppState();
      state.createNotebook('Personal Notes');

      // Ensure canvas docs and files exist
      expect(state.canvasDocs, isNotEmpty);
      expect(state.workspaceFiles, isNotEmpty);

      // Search for "Personal" (should match "Personal Notes" notebook)
      await state.performSearch('Personal');
      expect(state.searchResults, isNotEmpty);
      expect(state.searchResults.any((r) => r.entityType == 'canvas' && r.title.contains('Personal')), isTrue);

      // Search for "GoodNotes" (should match GoodNotes specification file)
      await state.performSearch('GoodNotes');
      expect(state.searchResults, isNotEmpty);
      expect(state.searchResults.any((r) => r.title.contains('GoodNotes')), isTrue);

      // Add a custom note card with unique text to active notebook
      final card = CanvasNoteCardItem(
        id: 'card-quantum-1',
        title: 'Quantum Entanglement',
        content: 'Superposition and Einstein-Podolsky-Rosen paradox',
        position: const Offset(100, 100),
      );
      state.canvasObjects.add(card);
      state.currentCanvasDoc?.activePage.objects.add(card);

      // Search for "Einstein"
      await state.performSearch('Einstein');
      expect(state.searchResults, isNotEmpty);
      expect(state.searchResults.any((r) => r.snippet.contains('Einstein')), isTrue);

      // Clear search
      await state.performSearch('');
      expect(state.searchResults, isEmpty);
    });
  });

  group('UI Screens Rendering Tests', () {
    testWidgets('SearchScreen renders header, search bar, and suggestions', (tester) async {
      final state = AppState();
      await tester.pumpWidget(
        MaterialApp(
          home: SearchScreen(state: state),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Global Search'), findsOneWidget);
      expect(find.text('SUGGESTED SEARCHES'), findsOneWidget);
      expect(find.text('GoodNotes Engine'), findsOneWidget);

      // Tap on a suggested query
      await tester.tap(find.text('GoodNotes Engine'));
      await tester.pumpAndSettle();

      // Results should be displayed
      expect(find.textContaining('All ('), findsOneWidget);
    });

    testWidgets('FilesScreen renders header, file rows, and supports tab switching', (tester) async {
      final state = AppState();
      await tester.pumpWidget(
        MaterialApp(
          home: FilesScreen(state: state),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Files & Media'), findsOneWidget);
      expect(find.text('New Document'), findsOneWidget);
      expect(find.text('Upload File'), findsOneWidget);

      // Verify files are listed
      expect(find.textContaining('GoodNotes_Vector_Engine'), findsOneWidget);

      // Switch to PDFs filter tab
      await tester.tap(find.textContaining('PDFs ('));
      await tester.pumpAndSettle();

      expect(find.textContaining('Project_Architecture_Overview'), findsOneWidget);
    });
  });
}
