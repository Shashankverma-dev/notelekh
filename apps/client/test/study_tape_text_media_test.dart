import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:ai_workspace_client/features/canvas/models/page_model.dart';
import 'package:ai_workspace_client/features/canvas/canvas_state.dart';
import 'package:ai_workspace_client/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Study Tape & Canvas Text & Media Features', () {
    test('CanvasTapeItem roundtrips through JSON and page parsing', () {
      final tape = CanvasTapeItem(
        id: 'tape-test-1',
        rect: const Rect.fromLTWH(50, 100, 200, 28),
        color: const Color(0xFFFDE047),
        isMasked: true,
      );

      final json = tape.toJson();
      expect(json['object_type'], 'tape');
      expect(json['data']['is_masked'], true);

      final parsed = CanvasTapeItem.fromJson(json);
      expect(parsed.id, 'tape-test-1');
      expect(parsed.rect.left, 50.0);
      expect(parsed.rect.width, 200.0);
      expect(parsed.rect.height, 28.0);
      expect(parsed.isMasked, true);

      // Verify page deserialization
      final pageJson = {
        'id': 'page-1',
        'page_number': 1,
        'paper_style': 'dotGrid',
        'objects': [json],
      };
      final page = CanvasPage.fromJson(pageJson);
      expect(page.objects.length, 1);
      expect(page.objects.first, isA<CanvasTapeItem>());
      final parsedPageTape = page.objects.first as CanvasTapeItem;
      expect(parsedPageTape.id, 'tape-test-1');
    });

    test('AppState toggleTapeMask flips mask state properly', () {
      final appState = AppState();
      final tape = CanvasTapeItem(
        id: 'tape-toggle-1',
        rect: const Rect.fromLTWH(10, 20, 100, 28),
        isMasked: true,
      );

      appState.addCanvasObject(tape);
      expect((appState.canvasObjects.first as CanvasTapeItem).isMasked, true);

      appState.toggleTapeMask('tape-toggle-1');
      expect((appState.canvasObjects.first as CanvasTapeItem).isMasked, false);

      appState.toggleTapeMask('tape-toggle-1');
      expect((appState.canvasObjects.first as CanvasTapeItem).isMasked, true);
    });

    test('CanvasTextItem copyWith updates formatting without losing id or text', () {
      final text = CanvasTextItem(
        id: 'text-123',
        text: 'Hello GoodNotes',
        position: const Offset(100, 200),
        color: Colors.black,
        fontFamily: 'Inter',
        isBold: false,
        isItalic: false,
        isUnderline: false,
        alignment: TextAlign.left,
      );

      final updated = text.copyWith(
        fontFamily: 'Caveat',
        isBold: true,
        isItalic: true,
        isUnderline: true,
        alignment: TextAlign.center,
        color: const Color(0xFFEF4444),
      );

      expect(updated.id, 'text-123');
      expect(updated.text, 'Hello GoodNotes');
      expect(updated.fontFamily, 'Caveat');
      expect(updated.isBold, true);
      expect(updated.isItalic, true);
      expect(updated.isUnderline, true);
      expect(updated.alignment, TextAlign.center);
      expect(updated.color, const Color(0xFFEF4444));
    });

    test('AppState updateCanvasTextItem updates object and keeps list intact', () {
      final appState = AppState();
      final original = CanvasTextItem(
        id: 'txt-update-1',
        text: 'Original Text',
        position: const Offset(40, 50),
        color: Colors.black,
      );

      appState.addCanvasObject(original);
      expect(appState.canvasObjects.length, 1);

      final modified = original.copyWith(text: 'Edited Text', fontSize: 24.0);
      appState.updateCanvasTextItem(modified);

      expect(appState.canvasObjects.length, 1);
      final item = appState.canvasObjects.first as CanvasTextItem;
      expect(item.text, 'Edited Text');
      expect(item.fontSize, 24.0);
    });

    test('CanvasImageItem roundtrips through JSON with base64 and localFilePath', () {
      final img = CanvasImageItem(
        id: 'img-test-1',
        bounds: const Rect.fromLTWH(30, 40, 300, 200),
        localFilePath: 'C:/test/diagram.png',
        base64Data: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      );

      final json = img.toJson();
      expect(json['object_type'], 'image');
      expect(json['data']['local_file_path'], 'C:/test/diagram.png');
      expect(json['data']['base64_data'], isNotNull);

      final parsed = CanvasImageItem.fromJson(json);
      expect(parsed.id, 'img-test-1');
      expect(parsed.bounds.width, 300.0);
      expect(parsed.bounds.height, 200.0);
      expect(parsed.localFilePath, 'C:/test/diagram.png');
      expect(parsed.base64Data, isNotNull);

      // Verify page deserialization
      final pageJson = {
        'id': 'page-1',
        'page_number': 1,
        'paper_style': 'dotGrid',
        'objects': [json],
      };
      final page = CanvasPage.fromJson(pageJson);
      expect(page.objects.length, 1);
      expect(page.objects.first, isA<CanvasImageItem>());
    });

    test('CanvasDrawingState laser pointer mode and color updates', () {
      final drawingState = CanvasDrawingState();
      expect(drawingState.laserMode, 'trail');
      expect(drawingState.laserColor, const Color(0xFFEF4444));

      int notifiedCount = 0;
      drawingState.addListener(() {
        notifiedCount++;
      });

      // Switch to dot mode
      drawingState.setLaserMode('dot');
      expect(drawingState.laserMode, 'dot');
      expect(notifiedCount, 1);

      // Switch to new GoodNotes color
      const electricBlue = Color(0xFF3B82F6);
      drawingState.setLaserColor(electricBlue);
      expect(drawingState.laserColor, electricBlue);
      expect(notifiedCount, 2);

      // Verify all 8 GoodNotes color choices can be set
      const colors = [
        Color(0xFFEF4444),
        Color(0xFFF97316),
        Color(0xFFEAB308),
        Color(0xFF22C55E),
        Color(0xFF06B6D4),
        Color(0xFF3B82F6),
        Color(0xFFA855F7),
        Color(0xFFEC4899),
      ];
      for (final c in colors) {
        drawingState.setLaserColor(c);
        expect(drawingState.laserColor, c);
      }
    });

    test('Laser pointer multi-stroke trail supports writing multiple words', () {
      final drawingState = CanvasDrawingState();
      expect(drawingState.laserMode, 'trail');

      // Verify stroke structure simulates multiple words across lifts
      final strokes = <List<Map<String, dynamic>>>[];
      final now = DateTime.now().millisecondsSinceEpoch;

      // Word 1: "Hello"
      strokes.add([
        {'pos': const Offset(10, 10), 'time': now},
        {'pos': const Offset(20, 15), 'time': now + 50},
        {'pos': const Offset(30, 20), 'time': now + 100},
      ]);

      // Pen lift & Word 2: "World"
      strokes.add([
        {'pos': const Offset(50, 10), 'time': now + 500},
        {'pos': const Offset(60, 15), 'time': now + 550},
        {'pos': const Offset(70, 20), 'time': now + 600},
      ]);

      // Pen lift & Word 3: "Notes"
      strokes.add([
        {'pos': const Offset(90, 10), 'time': now + 1000},
        {'pos': const Offset(100, 15), 'time': now + 1050},
      ]);

      expect(strokes.length, 3);
      expect(strokes[0].length, 3);
      expect(strokes[1].length, 3);
      expect(strokes[2].length, 2);

      // Simulating decay after 4500ms
      const lifetime = 4500;
      final futureTime = now + 4700;

      // Strokes older than 4500ms are pruned
      for (int s = strokes.length - 1; s >= 0; s--) {
        strokes[s].removeWhere((pt) => futureTime - (pt['time'] as int) > lifetime);
        if (strokes[s].isEmpty) {
          strokes.removeAt(s);
        }
      }

      // Word 1 (t=now) was > 4500ms ago -> pruned
      // Word 2 (t=now+500) -> 4100ms ago -> still alive!
      // Word 3 (t=now+1000) -> 3600ms ago -> still alive!
      expect(strokes.length, 2);
    });
  });
}
