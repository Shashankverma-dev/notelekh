import 'package:ai_workspace_client/features/canvas/models/stroke.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';

/// Configurable physical settings for a specific pen type.
/// Allows Fountain Pen, Ball Pen, and Brush Pen to maintain independent
/// parameters for Tip Sharpness, Pressure Sensitivity, Tip Flatness, and Stroke Stabilization.
class PenSettings {
  double tipSharpness;
  PressureSensitivity pressureSensitivity;
  double tipFlatness;
  double strokeStabilization;

  PenSettings({
    required this.tipSharpness,
    required this.pressureSensitivity,
    required this.tipFlatness,
    required this.strokeStabilization,
  });

  /// Factory creating GoodNotes-calibrated defaults for each pen type.
  factory PenSettings.defaultFor(PenType type) {
    switch (type) {
      case PenType.fountainPen:
        return PenSettings(
          tipSharpness: 0.75,       // 75%
          pressureSensitivity: PressureSensitivity.medium,
          tipFlatness: 0.66,        // 66% chisel nib
          strokeStabilization: 0.0, // 0%
        );
      case PenType.ballpoint:
        return PenSettings(
          tipSharpness: 0.0,        // 0% (uniform monoline by default)
          pressureSensitivity: PressureSensitivity.off,
          tipFlatness: 0.0,
          strokeStabilization: 0.20,// 20% jitter reduction
        );
      case PenType.brushPen:
        return PenSettings(
          tipSharpness: 0.75,       // 75% sharp bristle taper
          pressureSensitivity: PressureSensitivity.high, // Expressive dynamic range
          tipFlatness: 0.0,
          strokeStabilization: 0.15,// 15% calligraphy curve smoothing
        );
      case PenType.pencil:
        return PenSettings(
          tipSharpness: 0.50,
          pressureSensitivity: PressureSensitivity.medium,
          tipFlatness: 0.0,
          strokeStabilization: 0.0,
        );
      case PenType.marker:
        return PenSettings(
          tipSharpness: 0.0,
          pressureSensitivity: PressureSensitivity.off,
          tipFlatness: 0.50,
          strokeStabilization: 0.0,
        );
    }
  }

  PenSettings copyWith({
    double? tipSharpness,
    PressureSensitivity? pressureSensitivity,
    double? tipFlatness,
    double? strokeStabilization,
  }) {
    return PenSettings(
      tipSharpness: tipSharpness ?? this.tipSharpness,
      pressureSensitivity: pressureSensitivity ?? this.pressureSensitivity,
      tipFlatness: tipFlatness ?? this.tipFlatness,
      strokeStabilization: strokeStabilization ?? this.strokeStabilization,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tipSharpness': tipSharpness,
      'pressureSensitivity': pressureSensitivity.name,
      'tipFlatness': tipFlatness,
      'strokeStabilization': strokeStabilization,
    };
  }

  factory PenSettings.fromJson(Map<String, dynamic> json) {
    PressureSensitivity sensitivity = PressureSensitivity.medium;
    final sensStr = json['pressureSensitivity'] as String?;
    if (sensStr != null) {
      for (final s in PressureSensitivity.values) {
        if (s.name == sensStr) {
          sensitivity = s;
          break;
        }
      }
    }

    return PenSettings(
      tipSharpness: (json['tipSharpness'] as num?)?.toDouble() ?? 0.75,
      pressureSensitivity: sensitivity,
      tipFlatness: (json['tipFlatness'] as num?)?.toDouble() ?? 0.66,
      strokeStabilization: (json['strokeStabilization'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
