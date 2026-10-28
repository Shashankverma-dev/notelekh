import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:ai_workspace_client/features/canvas/canvas_state.dart';
import 'package:ai_workspace_client/features/canvas/widgets/contextual_toolbar.dart';
import 'package:ai_workspace_client/features/canvas/widgets/canvas_toolbar.dart';
import 'package:ai_workspace_client/features/canvas/widgets/floating_secondary_toolbar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContextualToolbar (ctool) Tests', () {
    testWidgets('Returns SizedBox.shrink when no objects are selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContextualToolbar(
              selectedObjects: const [],
              onDuplicate: () {},
              onDelete: () {},
              onRecolor: (_) {},
              onBringToFront: () {},
              onSendToBack: () {},
              onDeselect: () {},
            ),
          ),
        ),
      );

      expect(find.byType(ContextualToolbar), findsOneWidget);
      expect(find.text('selected'), findsNothing);
    });

    testWidgets('Renders selected count and triggers all actions correctly', (tester) async {
      bool duplicated = false;
      bool deleted = false;
      Color? recolored;
      bool broughtToFront = false;
      bool sentToBack = false;
      bool deselected = false;

      final shape = CanvasShapeItem(
        id: 'shape-1',
        shapeType: 'rectangle',
        bounds: const Rect.fromLTWH(10, 10, 100, 100),
        strokeColor: Colors.black,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContextualToolbar(
              selectedObjects: [shape],
              onDuplicate: () => duplicated = true,
              onDelete: () => deleted = true,
              onRecolor: (c) => recolored = c,
              onBringToFront: () => broughtToFront = true,
              onSendToBack: () => sentToBack = true,
              onDeselect: () => deselected = true,
            ),
          ),
        ),
      );

      // Verify badge text
      expect(find.text('1 selected'), findsOneWidget);

      // Verify action buttons exist via tooltips
      expect(find.byTooltip('Duplicate'), findsOneWidget);
      expect(find.byTooltip('Bring to Front'), findsOneWidget);
      expect(find.byTooltip('Send to Back'), findsOneWidget);
      expect(find.byTooltip('Delete'), findsOneWidget);
      expect(find.byTooltip('Deselect'), findsOneWidget);

      // Tap Duplicate
      await tester.tap(find.byTooltip('Duplicate'));
      await tester.pump();
      expect(duplicated, isTrue);

      // Tap Bring to Front
      await tester.tap(find.byTooltip('Bring to Front'));
      await tester.pump();
      expect(broughtToFront, isTrue);

      // Tap Send to Back
      await tester.tap(find.byTooltip('Send to Back'));
      await tester.pump();
      expect(sentToBack, isTrue);

      // Tap Delete
      await tester.tap(find.byTooltip('Delete'));
      await tester.pump();
      expect(deleted, isTrue);

      // Tap Deselect
      await tester.tap(find.byTooltip('Deselect'));
      await tester.pump();
      expect(deselected, isTrue);

      // Tap one of the recolor swatches
      final gestureDetectors = find.byType(GestureDetector);
      expect(gestureDetectors, findsWidgets);
      await tester.tap(gestureDetectors.first);
      await tester.pump();
      expect(recolored, isNotNull);
    });

    testWidgets('Adapts to narrow screen (< 360px) without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final shape = CanvasShapeItem(
        id: 'shape-1',
        shapeType: 'rectangle',
        bounds: const Rect.fromLTWH(10, 10, 50, 50),
        strokeColor: Colors.black,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ContextualToolbar(
                selectedObjects: [shape],
                onDuplicate: () {},
                onDelete: () {},
                onRecolor: (_) {},
                onBringToFront: () {},
                onSendToBack: () {},
                onDeselect: () {},
              ),
            ),
          ),
        ),
      );

      // No overflow exceptions thrown
      expect(tester.takeException(), isNull);
      expect(find.text('1 selected'), findsOneWidget);
    });
  });

  group('CanvasToolbar (tool bar) Tests', () {
    testWidgets('Renders in desktop mode with all primary tools and actions', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      CanvasTool activeTool = CanvasTool.pen;
      bool toolSettingsOpened = false;
      bool undoCalled = false;
      bool redoCalled = false;
      bool addPageCalled = false;
      bool shareCalled = false;
      int pageChangedTo = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CanvasToolbar(
              currentTool: activeTool,
              onToolSelected: (t) => activeTool = t,
              onOpenToolSettings: () => toolSettingsOpened = true,
              canUndo: true,
              canRedo: true,
              onUndo: () => undoCalled = true,
              onRedo: () => redoCalled = true,
              currentPageIndex: 0,
              totalPages: 3,
              onPageChanged: (p) => pageChangedTo = p,
              onAddPage: () => addPageCalled = true,
              onShareExport: () => shareCalled = true,
              onOpenMoreMenu: () {},
              documentTitle: 'Mathematics Lecture',
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Mathematics Lecture'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);

      // Undo / Redo
      await tester.tap(find.byTooltip('Undo (Ctrl+Z)'));
      await tester.pump();
      expect(undoCalled, isTrue);

      await tester.tap(find.byTooltip('Redo (Ctrl+Y)'));
      await tester.pump();
      expect(redoCalled, isTrue);

      // Add Page
      await tester.tap(find.byTooltip('Add Page'));
      await tester.pump();
      expect(addPageCalled, isTrue);

      // Share & Export
      await tester.tap(find.byTooltip('Share & Export'));
      await tester.pump();
      expect(shareCalled, isTrue);

      // Page change (next page chevron)
      final chevronRight = find.byIcon(Icons.chevron_right_rounded);
      expect(chevronRight, findsOneWidget);
      await tester.tap(chevronRight);
      await tester.pump();
      expect(pageChangedTo, equals(1));

      // Tool selection: tap Lasso
      await tester.tap(find.byTooltip('Lasso Selection [L]'));
      await tester.pump();
      expect(activeTool, equals(CanvasTool.lasso));

      // Re-tap active Pen to trigger tool settings
      activeTool = CanvasTool.pen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CanvasToolbar(
              currentTool: activeTool,
              onToolSelected: (t) => activeTool = t,
              onOpenToolSettings: () => toolSettingsOpened = true,
              canUndo: true,
              canRedo: true,
              onUndo: () {},
              onRedo: () {},
              currentPageIndex: 0,
              totalPages: 1,
              onPageChanged: (_) {},
              onAddPage: () {},
              onShareExport: () {},
              onOpenMoreMenu: () {},
              documentTitle: 'Notes',
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Pen Tool (Fountain / Ball / Brush) [P]'));
      await tester.pump();
      expect(toolSettingsOpened, isTrue);
    });

    testWidgets('Renders two-tier mobile layout (< 680px) without overflow', (tester) async {
      tester.view.physicalSize = const Size(375, 667); // iPhone screen size
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CanvasToolbar(
              currentTool: CanvasTool.pen,
              onToolSelected: (_) {},
              onOpenToolSettings: () {},
              canUndo: false,
              canRedo: false,
              onUndo: () {},
              onRedo: () {},
              currentPageIndex: 0,
              totalPages: 2,
              onPageChanged: (_) {},
              onAddPage: () {},
              onShareExport: () {},
              onOpenMoreMenu: () {},
              documentTitle: 'Mobile Document',
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Mobile Document'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
    });
  });

  group('FloatingSecondaryToolbar Tests', () {
    testWidgets('Adapts to Pen, Highlighter, Eraser, Lasso, Laser, Shapes tools', (tester) async {
      tester.view.physicalSize = const Size(900, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final state = CanvasDrawingState();
      bool penOptionsOpened = false;
      bool lassoOptionsOpened = false;
      bool clearPageCalled = false;

      // 1. Pen tool
      state.setTool(CanvasTool.pen);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingSecondaryToolbar(
              state: state,
              onOpenPenOptions: () => penOptionsOpened = true,
              onOpenLassoOptions: () => lassoOptionsOpened = true,
              onClearPage: () => clearPageCalled = true,
            ),
          ),
        ),
      );

      expect(find.byTooltip('Pen Options (Tap for settings)'), findsOneWidget);
      await tester.tap(find.byTooltip('Pen Options (Tap for settings)'));
      await tester.pump();
      expect(penOptionsOpened, isTrue);

      // 2. Eraser tool
      state.setTool(CanvasTool.eraser);
      await tester.pump();

      expect(find.text('Precision'), findsOneWidget);
      expect(find.text('Stroke'), findsOneWidget);
      expect(find.text('Area'), findsOneWidget);
      expect(find.text('Highlighter Only'), findsOneWidget);
      expect(find.text('Clear Page'), findsOneWidget);

      await tester.tap(find.text('Clear Page'));
      await tester.pump();
      expect(clearPageCalled, isTrue);

      // 3. Highlighter tool (default straight line is true)
      state.setTool(CanvasTool.highlighter);
      await tester.pump();

      expect(state.highlighterStraightLine, isTrue);
      expect(find.text('Straight Line'), findsOneWidget);

      // Tap to toggle off
      await tester.tap(find.text('Straight Line'));
      await tester.pump();
      expect(state.highlighterStraightLine, isFalse);

      // Tap to toggle on
      await tester.tap(find.text('Straight Line'));
      await tester.pump();
      expect(state.highlighterStraightLine, isTrue);

      // 4. Lasso tool
      state.setTool(CanvasTool.lasso);
      await tester.pump();

      expect(find.text('Freehand'), findsOneWidget);
      expect(find.text('Rectangular'), findsOneWidget);
      expect(find.byTooltip('Lasso Includes & Settings (8 Categories)'), findsOneWidget);

      await tester.tap(find.byTooltip('Lasso Includes & Settings (8 Categories)'));
      await tester.pump();
      expect(lassoOptionsOpened, isTrue);

      // 5. Laser tool
      state.setTool(CanvasTool.laser);
      await tester.pump();

      expect(find.text('Trail'), findsOneWidget);
      expect(find.text('Dot'), findsOneWidget);

      // 6. Shapes tool (Rectangle)
      state.setTool(CanvasTool.rectangle);
      await tester.pump();

      expect(find.byTooltip('Circle'), findsOneWidget);
      expect(find.byTooltip('Triangle'), findsOneWidget);
      expect(find.byTooltip('Line'), findsOneWidget);
      expect(find.byTooltip('Arrow'), findsOneWidget);

      // Switch to Triangle
      await tester.tap(find.byTooltip('Triangle'));
      await tester.pump();
      expect(state.currentTool, equals(CanvasTool.triangle));

      state.dispose();
    });
  });
}
