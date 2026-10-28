import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_workspace_client/state/app_state.dart';
import 'package:ai_workspace_client/features/canvas/models/page_model.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';
import 'package:ai_workspace_client/features/canvas/engine/stroke_interpolator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Fast Writing Performance & Undo Stack Bounds', () {
    test('AppState caps undoStack and redoStack at 30 items during continuous rapid writing', () {
      final state = AppState();
      expect(state.undoStack, isEmpty);

      // Simulate writing 60 fast consecutive strokes (e.g. 5-10 words)
      for (int i = 0; i < 60; i++) {
        final stroke = CanvasStrokeItem(
          id: 'stroke-$i',
          points: [
            StrokePoint(x: 10.0 + i, y: 10.0 + i),
            StrokePoint(x: 20.0 + i, y: 20.0 + i),
          ],
          color: Colors.black,
          strokeWidth: 2.0,
          tool: 'pen',
        );
        state.addCanvasObject(stroke);
      }

      // Assert: undoStack must NOT exceed 30 items
      expect(state.undoStack.length, lessThanOrEqualTo(30));
      expect(state.undoStack.length, equals(30));
      expect(state.canvasObjects.length, equals(60));

      // Test undoing past the stack
      for (int i = 0; i < 30; i++) {
        state.undo();
      }
      expect(state.undoStack, isEmpty);
      expect(state.redoStack.length, lessThanOrEqualTo(30));
    });

    test('StrokeInterpolator avoids point explosion on dense strokes', () {
      // Create a dense stroke sampled at 120Hz/240Hz (e.g. 40 points)
      final rawPoints = List.generate(
        40,
        (i) => StrokePoint(
          x: i * 2.0,
          y: i * 2.0,
          timestamp: i * 8,
          pressure: 0.5,
        ),
      );

      final interpolated = StrokeInterpolator.interpolate(rawPoints, defaultSegments: 2);

      // Dense strokes (>=35 points) should not be multiplied by subsegments
      expect(interpolated.length, equals(40));
    });

    test('StrokeInterpolator caps sub-segments on long jumps instead of 10x explosion', () {
      final sparsePoints = [
        StrokePoint(x: 0, y: 0),
        StrokePoint(x: 100, y: 100), // Distance squared = 20,000 > 400
      ];

      final interpolated = StrokeInterpolator.interpolate(sparsePoints, defaultSegments: 2);

      // Sub-segments capped at 3, so total points = 1 + 3 = 4 (never 11+)
      expect(interpolated.length, lessThanOrEqualTo(5));
    });
  });

  group('Cross-Device Notebook Sync & Timestamp Merging', () {
    test('CanvasDocModel serializes and deserializes updatedAt timestamp correctly', () {
      final testTime = DateTime(2026, 10, 2, 14, 30, 0);
      final doc = CanvasDocModel(
        id: 'doc-sync-1',
        workspaceId: 'ws-1',
        name: 'Sync Notebook',
        updatedAt: testTime,
      );

      final json = doc.toJson();
      expect(json['updated_at'], isNotNull);
      expect(json['updated_at'], equals(testTime.toIso8601String()));

      final parsed = CanvasDocModel.fromJson(json);
      expect(parsed.updatedAt, isNotNull);
      expect(parsed.updatedAt!.isAtSameMomentAs(testTime), isTrue);
    });

    test('Newer cloud document takes precedence over stale local document', () {
      final olderLocalTime = DateTime(2026, 10, 1, 10, 0, 0);
      final newerCloudTime = DateTime(2026, 10, 2, 15, 0, 0);

      final localDoc = CanvasDocModel(
        id: 'shared-doc',
        workspaceId: 'ws-1',
        name: 'My Notebook',
        updatedAt: olderLocalTime,
        objects: [
          CanvasStrokeItem(
            id: 'old-local-stroke',
            points: [StrokePoint(x: 1, y: 1)],
            color: Colors.black,
            strokeWidth: 2,
            tool: 'pen',
          )
        ],
      );

      final cloudDoc = CanvasDocModel(
        id: 'shared-doc',
        workspaceId: 'ws-1',
        name: 'My Notebook',
        updatedAt: newerCloudTime,
        objects: [
          CanvasStrokeItem(
            id: 'cloud-stroke-1',
            points: [StrokePoint(x: 10, y: 10)],
            color: Colors.blue,
            strokeWidth: 2,
            tool: 'pen',
          ),
          CanvasStrokeItem(
            id: 'cloud-stroke-2',
            points: [StrokePoint(x: 20, y: 20)],
            color: Colors.red,
            strokeWidth: 2,
            tool: 'pen',
          ),
        ],
      );

      // Simulate merge comparison
      final cloudWins = cloudDoc.updatedAt!.isAfter(localDoc.updatedAt!);
      expect(cloudWins, isTrue);

      final mergedDoc = cloudWins ? cloudDoc : localDoc;
      expect(mergedDoc.objects.length, equals(2));
      expect(mergedDoc.objects.first.id, equals('cloud-stroke-1'));
    });
  });
}
