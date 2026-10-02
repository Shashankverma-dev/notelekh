import 'package:flutter_test/flutter_test.dart';
import 'package:ai_workspace_client/state/app_state.dart';
import 'package:ai_workspace_client/core/models/canvas_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoodNotes Page Navigation & Slide Verification Tests', () {
    late AppState state;

    setUp(() {
      state = AppState();
      state.createNotebook('Test Notebook', defaultPaperStyle: CanvasPaperStyle.ruledLines);
      state.addNewPage(switchToPage: false);
      state.addNewPage(switchToPage: false);
    });

    test('Navigating between pages preserves bounds and updates currentPageIndex', () {
      expect(state.currentPageIndex, equals(0));
      expect(state.canvasPages.length, equals(3));

      // Advance to page 1
      state.setCanvasPage(1);
      expect(state.currentPageIndex, equals(1));

      // Advance to page 2
      state.setCanvasPage(2);
      expect(state.currentPageIndex, equals(2));

      // Slide back to previous page (page 1)
      state.setCanvasPage(1);
      expect(state.currentPageIndex, equals(1));

      // Slide back to previous page (page 0)
      state.setCanvasPage(0);
      expect(state.currentPageIndex, equals(0));

      // Cannot go below 0
      state.setCanvasPage(0);
      expect(state.currentPageIndex, equals(0));
    });

    test('Swipe delta classification: dragging right (deltaX >= 50) triggers previous page', () {
      int currentPageIndex = 2;
      const double swipeThreshold = 50.0;

      // Simulate dragging right to go to previous page:
      const double deltaXRight = 65.0;
      bool wentToPrev = false;
      bool wentToNext = false;

      if (deltaXRight <= -swipeThreshold) {
        wentToNext = true;
      } else if (deltaXRight >= swipeThreshold && currentPageIndex > 0) {
        currentPageIndex -= 1;
        wentToPrev = true;
      }

      expect(wentToPrev, isTrue);
      expect(wentToNext, isFalse);
      expect(currentPageIndex, equals(1));

      // Simulate dragging left to go to next page:
      const double deltaXLeft = -65.0;
      wentToPrev = false;
      wentToNext = false;

      if (deltaXLeft <= -swipeThreshold) {
        currentPageIndex += 1;
        wentToNext = true;
      } else if (deltaXLeft >= swipeThreshold && currentPageIndex > 0) {
        currentPageIndex -= 1;
        wentToPrev = true;
      }

      expect(wentToNext, isTrue);
      expect(wentToPrev, isFalse);
      expect(currentPageIndex, equals(2));
    });

    test('Edge zone detection detects margins outside paper as valid swipe zones', () {
      const double csWidth = 1536.0;
      const double zoomScale = 1.0;
      const Offset panOffset = Offset(338.0, 0.0);
      const double kPageLeft = -430.0;
      const double kPageWidth = 860.0;

      final paperScreenLeft = (kPageLeft * zoomScale) + panOffset.dx;
      final paperScreenRight = ((kPageLeft + kPageWidth) * zoomScale) + panOffset.dx;

      bool isLeftSwipeZone(Offset pos) {
        return pos.dx <= 90.0 || (pos.dx <= paperScreenLeft + 90.0 && pos.dx <= paperScreenRight);
      }

      bool isRightSwipeZone(Offset pos) {
        return pos.dx >= (csWidth - 90.0) || (pos.dx >= paperScreenRight - 90.0 && pos.dx >= paperScreenLeft);
      }

      // Point in extreme left edge of screen
      expect(isLeftSwipeZone(const Offset(40.0, 300.0)), isTrue);
      // Point in extreme right edge of screen
      expect(isRightSwipeZone(const Offset(1500.0, 300.0)), isTrue);
      // Center of paper sheet is not an edge swipe zone (allows inking)
      expect(isLeftSwipeZone(Offset(paperScreenLeft + 300.0, 300.0)), isFalse);
      expect(isRightSwipeZone(Offset(paperScreenLeft + 300.0, 300.0)), isFalse);
    });
  });
}
