import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:ai_workspace_client/features/canvas/engine/stroke_engine.dart';
import 'package:ai_workspace_client/features/canvas/canvas_state.dart';

void main() {
  group('GoodNotes Realistic Pencil Engine Tests', () {
    test('Pencil tool configures PenType.pencil and organic graphite opacity in CanvasDrawingState', () {
      final state = CanvasDrawingState();
      state.setTool(CanvasTool.pencil);

      expect(state.currentTool, CanvasTool.pencil);
      expect(state.currentPenType, PenType.pencil);
      expect(state.strokeOpacity, closeTo(0.85, 0.01));
    });

    test('StrokeRenderer renders realistic pencil stroke with pressure and Apple Pencil tilt shading without error', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final points = [
        StrokePoint(x: 100, y: 100, pressure: 0.2, tilt: 0.1, timestamp: 0),
        StrokePoint(x: 120, y: 110, pressure: 0.5, tilt: 0.15, timestamp: 10),
        StrokePoint(x: 150, y: 130, pressure: 0.85, tilt: 0.45, timestamp: 25), // Tilted shading
        StrokePoint(x: 180, y: 160, pressure: 0.9, tilt: 0.60, timestamp: 40),  // Broad side shading
        StrokePoint(x: 210, y: 190, pressure: 0.4, tilt: 0.2, timestamp: 55),
      ];

      expect(() {
        StrokeRenderer.drawStroke(
          canvas: canvas,
          points: points,
          color: const Color(0xFF334155),
          baseWidth: 2.5,
          opacity: 0.85,
          penType: PenType.pencil,
          sensitivity: PressureSensitivity.medium,
          tool: 'pencil',
        );
      }, returnsNormally);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('Single-dot pencil tap renders authentic graphite dot with soft halo and micro-stippling', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final dotPoint = [
        StrokePoint(x: 50, y: 50, pressure: 0.7, tilt: 0.1, timestamp: 0),
      ];

      expect(() {
        StrokeRenderer.drawStroke(
          canvas: canvas,
          points: dotPoint,
          color: const Color(0xFF2C3E50),
          baseWidth: 3.0,
          opacity: 0.85,
          penType: PenType.pencil,
          sensitivity: PressureSensitivity.medium,
          tool: 'pencil',
        );
      }, returnsNormally);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('StrokeEngine.drawVariableWidthStroke caches and draws realistic pencil stroke', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final stroke = CanvasStrokeItem(
        id: 'pencil-stroke-1',
        points: [
          StrokePoint(x: 10, y: 10, pressure: 0.3, tilt: 0.1, timestamp: 0),
          StrokePoint(x: 30, y: 30, pressure: 0.7, tilt: 0.35, timestamp: 16),
          StrokePoint(x: 60, y: 50, pressure: 0.5, tilt: 0.15, timestamp: 32),
        ],
        color: const Color(0xFF1E293B),
        strokeWidth: 2.0,
        opacity: 0.85,
        tool: 'pencil',
        penType: PenType.pencil,
      );

      expect(() {
        StrokeEngine.drawVariableWidthStroke(
          canvas,
          stroke,
          PressureSensitivity.medium,
        );
      }, returnsNormally);
    });
  });
}
