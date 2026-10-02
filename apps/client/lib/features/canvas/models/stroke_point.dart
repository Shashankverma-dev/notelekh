import 'dart:ui';

/// Represents a single sampled point along a drawing stroke with full digitizer telemetry.
class StrokePoint {
  final double x;
  final double y;
  final double pressure;
  final double tilt;
  final double velocity; // pixels/ms — used for velocity-based width modulation
  final int timestamp;
  final bool isStylus;

  StrokePoint({
    required this.x,
    required this.y,
    this.pressure = 0.5,
    this.tilt = 0.0,
    this.velocity = 0.0,
    this.isStylus = false,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  factory StrokePoint.fromJson(Map<String, dynamic> json) {
    return StrokePoint(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      pressure: (json['pressure'] as num?)?.toDouble() ?? 0.5,
      tilt: (json['tilt'] as num?)?.toDouble() ?? 0.0,
      velocity: (json['velocity'] as num?)?.toDouble() ?? 0.0,
      isStylus: (json['is_stylus'] as bool?) ?? false,
      timestamp: json['timestamp'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'pressure': pressure,
      'tilt': tilt,
      'velocity': velocity,
      'is_stylus': isStylus,
      'timestamp': timestamp,
    };
  }

  Offset toOffset() => Offset(x, y);

  StrokePoint copyWith({
    double? x,
    double? y,
    double? pressure,
    double? tilt,
    double? velocity,
    bool? isStylus,
    int? timestamp,
  }) {
    return StrokePoint(
      x: x ?? this.x,
      y: y ?? this.y,
      pressure: pressure ?? this.pressure,
      tilt: tilt ?? this.tilt,
      velocity: velocity ?? this.velocity,
      isStylus: isStylus ?? this.isStylus,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
