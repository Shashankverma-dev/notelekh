import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:ai_workspace_client/features/canvas/widgets/floating_text_toolbar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoodNotes Professional Text Box Tests', () {
    test('CanvasTextItem supports GoodNotes card backgrounds and border styling', () {
      final item = CanvasTextItem(
        id: 'text-card-1',
        text: 'Meeting Summary & Tasks',
        position: const Offset(150, 250),
        color: const Color(0xFF0F172A),
        fontSize: 18.0,
        backgroundColor: const Color(0xFFFEF3C7), // Sticky note yellow
        borderColor: const Color(0xFFF59E0B),
        borderWidth: 1.5,
        borderRadius: 12.0,
        padding: 12.0,
        isBold: true,
        isUnderline: true,
        isStrikethrough: false,
        alignment: TextAlign.center,
        boxWidth: 320.0,
      );

      expect(item.id, 'text-card-1');
      expect(item.backgroundColor, const Color(0xFFFEF3C7));
      expect(item.borderColor, const Color(0xFFF59E0B));
      expect(item.borderWidth, 1.5);
      expect(item.borderRadius, 12.0);
      expect(item.padding, 12.0);
      expect(item.boxWidth, 320.0);

      // JSON roundtrip test
      final json = item.toJson();
      expect(json['object_type'], 'text');
      expect(json['data']['background_color'], isNotNull);
      expect(json['data']['border_color'], isNotNull);
      expect(json['data']['border_width'], 1.5);
      expect(json['data']['border_radius'], 12.0);
      expect(json['data']['padding'], 12.0);
      expect(json['data']['alignment'], 'center');

      final fromJson = CanvasTextItem.fromJson(json);
      expect(fromJson.id, item.id);
      expect(fromJson.text, item.text);
      expect(fromJson.backgroundColor?.toARGB32(), item.backgroundColor?.toARGB32());
      expect(fromJson.borderColor?.toARGB32(), item.borderColor?.toARGB32());
      expect(fromJson.borderWidth, 1.5);
      expect(fromJson.borderRadius, 12.0);
      expect(fromJson.padding, 12.0);
      expect(fromJson.alignment, TextAlign.center);
    });

    test('CanvasTextItem getBoundingBox calculates accurate bounds with padding', () {
      final item = CanvasTextItem(
        id: 'text-bounds-1',
        text: 'Short text',
        position: const Offset(100, 100),
        color: Colors.black,
        fontSize: 16.0,
        padding: 10.0,
        boxWidth: 200.0,
      );

      final bbox = item.getBoundingBox();
      expect(bbox.left, 90.0); // 100 - 10
      expect(bbox.top, 90.0);  // 100 - 10
      expect(bbox.width >= 220.0, true); // 200 + 2*10
      expect(bbox.height > 20.0, true);
    });

    test('CanvasTextItem copyWith allows clearing background and border colors', () {
      final item = CanvasTextItem(
        id: 'text-copy-1',
        text: 'Styling Test',
        position: const Offset(50, 50),
        color: Colors.black,
        backgroundColor: Colors.yellow,
        borderColor: Colors.amber,
      );

      final cleared = item.copyWith(
        clearBackgroundColor: true,
        clearBorderColor: true,
      );

      expect(cleared.backgroundColor, isNull);
      expect(cleared.borderColor, isNull);
    });

    testWidgets('FloatingTextToolbar renders professional controls', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      CanvasTextItem currentItem = CanvasTextItem(
        id: 'text-widget-1',
        text: 'My Professional Note',
        position: const Offset(50, 50),
        color: const Color(0xFF0F172A),
        fontSize: 18.0,
      );

      bool editTriggered = false;
      bool duplicateTriggered = false;
      bool deleteTriggered = false;
      bool closeTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingTextToolbar(
              textItem: currentItem,
              isDark: false,
              onUpdate: (updated) => currentItem = updated,
              onEditText: () => editTriggered = true,
              onDuplicate: () => duplicateTriggered = true,
              onDelete: () => deleteTriggered = true,
              onClose: () => closeTriggered = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Edit button exists and triggers callback
      expect(find.text('Edit'), findsOneWidget);
      await tester.tap(find.text('Edit'));
      expect(editTriggered, true);

      // Check Box Style preset button exists
      expect(find.text('Box Style'), findsOneWidget);

      // Check Bold button toggle
      final boldFinder = find.byTooltip('Bold');
      expect(boldFinder, findsOneWidget);
      await tester.tap(boldFinder);
      expect(currentItem.isBold, true);

      // Check Duplicate icon button
      final dupFinder = find.byTooltip('Duplicate text box');
      expect(dupFinder, findsOneWidget);
      await tester.tap(dupFinder);
      expect(duplicateTriggered, true);

      // Check Done icon button
      final doneFinder = find.byTooltip('Done');
      expect(doneFinder, findsOneWidget);
      await tester.tap(doneFinder);
      expect(closeTriggered, true);
      expect(deleteTriggered, false);
    });
  });
}
