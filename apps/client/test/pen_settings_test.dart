import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:ai_workspace_client/features/canvas/models/pen_settings.dart';
import 'package:ai_workspace_client/features/canvas/canvas_state.dart';
import 'package:ai_workspace_client/features/canvas/engine/stroke_smoother.dart';
import 'package:ai_workspace_client/features/canvas/engine/pressure_engine.dart';
import 'package:ai_workspace_client/features/canvas/widgets/goodnotes_tool_icons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PenSettings & Per-Pen Independent Configuration', () {
    test('Default PenSettings calibrated for Fountain, Ball, and Brush pens', () {
      final fountain = PenSettings.defaultFor(PenType.fountainPen);
      expect(fountain.tipSharpness, 0.75);
      expect(fountain.pressureSensitivity, PressureSensitivity.medium);
      expect(fountain.tipFlatness, 0.66);
      expect(fountain.strokeStabilization, 0.0);

      final ballpoint = PenSettings.defaultFor(PenType.ballpoint);
      expect(ballpoint.tipSharpness, 0.0);
      expect(ballpoint.pressureSensitivity, PressureSensitivity.off);
      expect(ballpoint.tipFlatness, 0.0);
      expect(ballpoint.strokeStabilization, 0.20);

      final brush = PenSettings.defaultFor(PenType.brushPen);
      expect(brush.tipSharpness, 0.75);
      expect(brush.pressureSensitivity, PressureSensitivity.high);
      expect(brush.tipFlatness, 0.0);
      expect(brush.strokeStabilization, 0.15);
    });

    test('CanvasDrawingState maintains independent settings across pen types', () {
      final state = CanvasDrawingState();

      // Configure Fountain Pen
      state.setPenType(PenType.fountainPen);
      state.setTipSharpness(0.85);
      state.setPressureSensitivity(PressureSensitivity.high);
      state.setTipFlatness(0.70);
      state.setStrokeStabilization(0.30);

      expect(state.tipSharpness, 0.85);
      expect(state.pressureSensitivity, PressureSensitivity.high);
      expect(state.tipFlatness, 0.70);
      expect(state.strokeStabilization, 0.30);

      // Switch to Ball Pen — should have its own separate defaults/settings
      state.setPenType(PenType.ballpoint);
      expect(state.tipSharpness, 0.0);
      expect(state.pressureSensitivity, PressureSensitivity.off);
      expect(state.strokeStabilization, 0.20);

      // Mutate Ball Pen settings
      state.setTipSharpness(0.40);
      state.setPressureSensitivity(PressureSensitivity.low);
      state.setStrokeStabilization(0.50);

      expect(state.tipSharpness, 0.40);
      expect(state.pressureSensitivity, PressureSensitivity.low);
      expect(state.strokeStabilization, 0.50);

      // Switch to Brush Pen
      state.setPenType(PenType.brushPen);
      expect(state.tipSharpness, 0.75);
      expect(state.pressureSensitivity, PressureSensitivity.high);
      expect(state.strokeStabilization, 0.15);

      // Switch back to Fountain Pen — verify it preserved its custom values!
      state.setPenType(PenType.fountainPen);
      expect(state.tipSharpness, 0.85);
      expect(state.pressureSensitivity, PressureSensitivity.high);
      expect(state.tipFlatness, 0.70);
      expect(state.strokeStabilization, 0.30);

      // Switch back to Ball Pen — verify it preserved its custom values!
      state.setPenType(PenType.ballpoint);
      expect(state.tipSharpness, 0.40);
      expect(state.pressureSensitivity, PressureSensitivity.low);
      expect(state.strokeStabilization, 0.50);
    });

    test('StrokeSmoother does not freeze at 100% stabilization', () {
      final smoother = StrokeSmoother(stabilization: 1.0);
      expect(smoother.stabilization, 1.0);

      final p0 = StrokePoint(x: 10, y: 10, pressure: 0.5, velocity: 1.0);
      final p1 = StrokePoint(x: 30, y: 30, pressure: 0.5, velocity: 1.0);

      final f0 = smoother.filter(p0);
      expect(f0.x, 10.0);
      expect(f0.y, 10.0);

      final f1 = smoother.filter(p1);
      // At 100% stabilization, the point must smoothly advance rather than staying stuck at 10.0
      expect(f1.x, greaterThan(10.0));
      expect(f1.y, greaterThan(10.0));
    });

    test('StrokeSmoother.smoothList eliminates jitter on points with stabilization', () {
      final rawPoints = [
        StrokePoint(x: 0, y: 0, pressure: 0.5, velocity: 1.0),
        StrokePoint(x: 5, y: 10, pressure: 0.5, velocity: 1.0), // sharp jitter spike
        StrokePoint(x: 10, y: 0, pressure: 0.5, velocity: 1.0),
      ];

      final smoothed = StrokeSmoother.smoothList(rawPoints, stabilization: 0.8);
      expect(smoothed.length, 3);
      // The middle point's y should be attenuated from 10 towards the baseline
      expect(smoothed[1].y, lessThan(10.0));
      expect(smoothed[1].y, greaterThan(0.0));
    });

    test('PressureEngine handles Ballpoint sensitivity correctly', () {
      final point = StrokePoint(x: 0, y: 0, pressure: 0.9, velocity: 0.5);

      // Off -> strictly baseWidth
      final wOff = PressureEngine.computeWidth(
        baseWidth: 10.0,
        point: point,
        penType: PenType.ballpoint,
        sensitivity: PressureSensitivity.off,
      );
      expect(wOff, 10.0);

      // Low -> slight variation
      final wLow = PressureEngine.computeWidth(
        baseWidth: 10.0,
        point: point,
        penType: PenType.ballpoint,
        sensitivity: PressureSensitivity.low,
      );
      expect(wLow, greaterThan(10.0));

      // High -> stronger variation
      final wHigh = PressureEngine.computeWidth(
        baseWidth: 10.0,
        point: point,
        penType: PenType.ballpoint,
        sensitivity: PressureSensitivity.high,
      );
      expect(wHigh, greaterThan(wLow));
    });

    test('CanvasStrokeItem stores and serializes independent pen properties', () {
      final stroke = CanvasStrokeItem(
        id: 'test-stroke',
        points: [
          StrokePoint(x: 0, y: 0, pressure: 0.5, velocity: 0.0),
          StrokePoint(x: 10, y: 10, pressure: 0.7, velocity: 1.0),
        ],
        color: const Color(0xFF10B981),
        strokeWidth: 4.0,
        penType: PenType.brushPen,
        pressureSensitivity: PressureSensitivity.high,
        tipSharpness: 0.90,
        tipFlatness: 0.15,
      );

      final json = stroke.toJson();
      expect(json['data']['pen_type'], 'brushPen');
      expect(json['data']['pressure_sensitivity'], 'high');
      expect(json['data']['tip_sharpness'], 0.90);
      expect(json['data']['tip_flatness'], 0.15);

      final restored = CanvasStrokeItem.fromJson(json);
      expect(restored.penType, PenType.brushPen);
      expect(restored.pressureSensitivity, PressureSensitivity.high);
      expect(restored.tipSharpness, 0.90);
      expect(restored.tipFlatness, 0.15);
    });

    testWidgets('GoodNotesToolIcon renders properly for all primary tools', (tester) async {
      for (final tool in CanvasTool.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: GoodNotesToolIcon(
                  tool: tool,
                  color: Colors.blue,
                  size: 20.0,
                  isSelected: true,
                ),
              ),
            ),
          ),
        );
        expect(find.byType(GoodNotesToolIcon), findsOneWidget);
      }
    });
  });
}

