import 'package:flutter_test/flutter_test.dart';
import 'package:ai_workspace_client/state/app_state.dart';
import 'package:ai_workspace_client/core/models/canvas_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Template and Style Verification Tests', () {
    late AppState state;

    setUp(() {
      state = AppState();
    });

    test('Notebook templates initialize with correct paperStyle', () {
      state.createNotebook('Ruled Notebook', defaultPaperStyle: CanvasPaperStyle.ruledLines);
      expect(state.currentCanvasDoc?.docType, CanvasDocType.notebook);
      expect(state.currentCanvasDoc?.activePage.paperStyle, CanvasPaperStyle.ruledLines);
      expect(state.isPageViewMode, isTrue);

      state.createNotebook('Cornell Notebook', defaultPaperStyle: CanvasPaperStyle.cornell);
      expect(state.currentCanvasDoc?.activePage.paperStyle, CanvasPaperStyle.cornell);

      state.createNotebook('Dot Notebook', defaultPaperStyle: CanvasPaperStyle.dotGrid);
      expect(state.currentCanvasDoc?.activePage.paperStyle, CanvasPaperStyle.dotGrid);

      state.createNotebook('Graph Notebook', defaultPaperStyle: CanvasPaperStyle.graphGrid);
      expect(state.currentCanvasDoc?.activePage.paperStyle, CanvasPaperStyle.graphGrid);

      state.createNotebook('Blank Notebook', defaultPaperStyle: CanvasPaperStyle.blankSlate);
      expect(state.currentCanvasDoc?.activePage.paperStyle, CanvasPaperStyle.blankSlate);
    });

    test('Whiteboard templates initialize with proper infinite paperStyle and objects', () {
      // 1. Blank whiteboard
      state.createInfiniteCanvas('Blank Board', template: 'blank');
      expect(state.currentCanvasDoc?.docType, CanvasDocType.canvas);
      expect(state.currentCanvasDoc?.activePage.paperStyle, CanvasPaperStyle.blankSlate);
      expect(state.isPageViewMode, isFalse);

      // 2. Dot Matrix whiteboard
      state.createInfiniteCanvas('Dots Board', template: 'dots');
      expect(state.currentCanvasDoc?.activePage.paperStyle, CanvasPaperStyle.dotGrid);
      expect(state.isPageViewMode, isFalse);

      // 3. Mind Map whiteboard
      state.createInfiniteCanvas('Product Mindmap', template: 'mindmap');
      expect(state.currentCanvasDoc?.activePage.paperStyle, CanvasPaperStyle.dotGrid);
      expect(state.isPageViewMode, isFalse);
      final mindCards = state.canvasObjects.whereType<CanvasNoteCardItem>().toList();
      final mindArrows = state.canvasObjects.whereType<CanvasShapeItem>().where((s) => s.shapeType == 'arrow').toList();
      expect(mindCards.length, 4); // Root + 3 branches
      expect(mindArrows.length, 3); // 3 connecting arrows

      // 4. Flowchart whiteboard
      state.createInfiniteCanvas('App Flowchart', template: 'flowchart');
      expect(state.currentCanvasDoc?.activePage.paperStyle, CanvasPaperStyle.dotGrid);
      expect(state.isPageViewMode, isFalse);
      final flowCards = state.canvasObjects.whereType<CanvasNoteCardItem>().toList();
      final flowArrows = state.canvasObjects.whereType<CanvasShapeItem>().where((s) => s.shapeType == 'arrow').toList();
      expect(flowCards.length, 4); // 4 sequential stages
      expect(flowArrows.length, 3); // 3 connecting step arrows
    });

    test('Text Document templates initialize on A4 blank slate with centered CanvasTextItem', () async {
      await state.createTextDocument('Chemistry Lecture', template: 'lecture');
      expect(state.currentCanvasDoc?.docType, CanvasDocType.textDocument);
      expect(state.currentCanvasDoc?.activePage.paperStyle, CanvasPaperStyle.blankSlate);
      expect(state.isPageViewMode, isTrue);

      final textItems = state.canvasObjects.whereType<CanvasTextItem>().toList();
      expect(textItems.length, 1);
      final item = textItems.first;
      expect(item.position.dx, -360.0); // Centered on A4 page
      expect(item.boxWidth, 720.0);
      expect(item.text, contains('Lecture Overview'));

      // Project Spec
      await state.createTextDocument('Alpha Project', template: 'project');
      final projectItem = state.canvasObjects.whereType<CanvasTextItem>().first;
      expect(projectItem.text, contains('Executive Summary'));

      // Meeting Minutes
      await state.createTextDocument('Sprint Sync', template: 'meeting');
      final meetingItem = state.canvasObjects.whereType<CanvasTextItem>().first;
      expect(meetingItem.text, contains('Agenda & Discussion'));

      // Blank Document
      await state.createTextDocument('Freeform Doc', template: 'blank');
      final blankItem = state.canvasObjects.whereType<CanvasTextItem>().first;
      expect(blankItem.text, contains('Start typing your notes'));
    });
  });
}
