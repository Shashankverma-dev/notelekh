import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_workspace_client/core/models/canvas_models.dart';
import 'package:ai_workspace_client/state/app_state.dart';
import 'package:ai_workspace_client/features/canvas/widgets/goodnotes_pdf_study_viewer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoodNotes PDF Document & Study Viewer Tests', () {
    test('PdfDocumentData creates default structure with formatted size', () {
      final doc = PdfDocumentData.createDefault('Advanced_Algorithms_Lecture.pdf', sizeBytes: 1540000);
      expect(doc.title, 'Advanced_Algorithms_Lecture.pdf');
      expect(doc.totalPages, 4);
      expect(doc.pages.length, 4);
      expect(doc.formattedSize, '1.5 MB');

      final page1 = doc.pages[0];
      expect(page1.pageNumber, 1);
      expect(page1.sectionTitle, contains('Chapter 1'));
      expect(page1.bulletPoints.isNotEmpty, true);
      expect(page1.keyTakeaway.isNotEmpty, true);
    });

    testWidgets('GoodNotesPdfCanvasCard renders PDF badge and page controls', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool studyOpened = false;
      bool importClicked = false;
      bool removeClicked = false;

      final card = CanvasNoteCardItem(
        id: 'pdf-test-123',
        position: const Offset(100, 100),
        width: 360,
        height: 250,
        title: '📄 Neural_Networks.pdf',
        content: 'PDF Document (345 KB, 4 pages)',
        backgroundColor: Colors.white,
        textColor: Colors.black,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoodNotesPdfCanvasCard(
              card: card,
              isDark: false,
              onOpenStudyReader: () => studyOpened = true,
              onImportToNotebook: () => importClicked = true,
              onRemove: () => removeClicked = true,
              onMove: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify PDF badge and title
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('Neural_Networks.pdf'), findsOneWidget);
      expect(find.text('1 / 4'), findsOneWidget);

      // Tap Study button
      final studyBtn = find.text('Study');
      expect(studyBtn, findsOneWidget);
      await tester.tap(studyBtn);
      await tester.pump();
      expect(studyOpened, true);

      // Tap Annotate button
      final annotateBtn = find.text('Annotate');
      expect(annotateBtn, findsOneWidget);
      await tester.tap(annotateBtn);
      await tester.pump();
      expect(importClicked, true);

      // Tap Close/Remove button
      final removeBtn = find.byTooltip('Remove Document Card');
      expect(removeBtn, findsOneWidget);
      await tester.tap(removeBtn);
      await tester.pump();
      expect(removeClicked, true);
    });

    testWidgets('GoodNotesPdfStudyPanel renders study reader and page navigation', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final doc = PdfDocumentData.createDefault('AI_Ethics_2026.pdf');
      bool closed = false;
      String? copiedText;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 700,
              child: GoodNotesPdfStudyPanel(
                document: doc,
                isDark: false,
                onClose: () => closed = true,
                onInsertPageToNotebook: (page, text) {},
                onCopyTextToCanvas: (text) => copiedText = text,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and reader elements
      expect(find.text('AI_Ethics_2026.pdf'), findsOneWidget);
      expect(find.textContaining('GoodNotes Study Mode'), findsOneWidget);
      expect(find.text('Page 1 of 4'), findsOneWidget);
      expect(find.text('Add to Notebook'), findsOneWidget);
      expect(find.text('Add as Note Card'), findsOneWidget);

      // Next page navigation
      final nextIcon = find.byIcon(Icons.arrow_forward_ios_rounded);
      expect(nextIcon, findsOneWidget);
      await tester.tap(nextIcon);
      await tester.pumpAndSettle();
      expect(find.text('Page 2 of 4'), findsOneWidget);

      // Tap Add as Note Card
      final addNoteCardBtn = find.text('Add as Note Card');
      await tester.tap(addNoteCardBtn);
      await tester.pump();
      expect(copiedText, isNotNull);

      // Tap Close
      final closeIcon = find.byIcon(Icons.close_rounded);
      await tester.tap(closeIcon.first);
      await tester.pump();
      expect(closed, true);
    });

    testWidgets('showGoodNotesPdfImportDialog shows notebook & study reader options', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final doc = PdfDocumentData.createDefault('Deep_Learning_Fundamentals.pdf');
      bool importedAsPages = false;
      bool selectedStudyCard = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showGoodNotesPdfImportDialog(
                      context: ctx,
                      state: AppState(),
                      fileName: doc.title,
                      sizeBytes: doc.fileSizeBytes,
                      onImportAsNotebookPages: (_) => importedAsPages = true,
                      onSelectStudyCard: (_) => selectedStudyCard = true,
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Import PDF Document'), findsOneWidget);
      expect(find.text('Import as Notebook Pages (Annotate Directly)'), findsOneWidget);
      expect(find.text('Side-by-Side Study Reader (Split Screen)'), findsOneWidget);

      // Tap Option 1: Import as Notebook Pages
      await tester.tap(find.text('Import as Notebook Pages (Annotate Directly)'));
      await tester.pumpAndSettle();
      expect(importedAsPages, true);

      // Re-open dialog to test Option 2
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Side-by-Side Study Reader (Split Screen)'));
      await tester.pumpAndSettle();
      expect(selectedStudyCard, true);
    });
  });
}
