import 'dart:ui';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';

// ── Pen types for rendering behavior ───────────────────────────────────────────
enum PenType {
  fountainPen,   // pressure-sensitive, tapered ends, smooth ink flow
  ballpoint,     // consistent width, slight pressure variation, crisp
  pencil,        // grainy texture, opacity variation
  brushPen,      // strong pressure response, artistic variable thickness
  marker,        // flat opaque strokes, like a thick marker
}

class CanvasStrokeItem extends CanvasObjectItem {
  final List<StrokePoint> points;
  final Color color;
  final double strokeWidth;
  final double opacity;
  final String tool; // 'pen', 'pencil', 'highlighter', 'brush'
  final PenType penType;
  final PressureSensitivity pressureSensitivity;
  final double tipSharpness;
  final double tipFlatness;

  CanvasStrokeItem({
    required super.id,
    required this.points,
    required this.color,
    this.strokeWidth = 3.0,
    this.opacity = 1.0,
    this.tool = 'pen',
    this.penType = PenType.fountainPen,
    this.pressureSensitivity = PressureSensitivity.medium,
    this.tipSharpness = 0.75,
    this.tipFlatness = 0.66,
    super.zIndex = 0,
    super.isSelected = false,
  }) : super(objectType: 'stroke');

  Rect? _cachedBounds;
  Picture? cachedPicture;
  List<StrokePoint>? cachedInterpolatedPoints;

  void invalidateCache() {
    cachedPicture?.dispose();
    cachedPicture = null;
    _cachedBounds = null;
    cachedInterpolatedPoints = null;
  }

  @override
  Rect getBoundingBox() {
    if (_cachedBounds != null) return _cachedBounds!;
    if (points.isEmpty) return _cachedBounds = Rect.zero;
    double minX = points.first.x;
    double maxX = points.first.x;
    double minY = points.first.y;
    double maxY = points.first.y;

    for (var p in points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    return _cachedBounds = Rect.fromLTRB(
      minX - strokeWidth,
      minY - strokeWidth,
      maxX + strokeWidth,
      maxY + strokeWidth,
    );
  }

  @override
  bool hits(Offset point, {double padding = 8.0}) {
    final bbox = getBoundingBox().inflate(padding);
    if (!bbox.contains(point)) return false;

    if (points.isEmpty) return false;
    final totalPad = strokeWidth + padding;
    final totalPadSq = totalPad * totalPad;

    if (points.length == 1) {
      final p0 = points.first.toOffset();
      final dx = point.dx - p0.dx;
      final dy = point.dy - p0.dy;
      return (dx * dx + dy * dy) <= totalPadSq;
    }

    // High-performance point-to-segment distance check using squared math
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i].toOffset();
      final p2 = points[i + 1].toOffset();
      if (_distanceToSegmentSquared(point, p1, p2) <= totalPadSq) {
        return true;
      }
    }
    return false;
  }

  static double _distanceToSegmentSquared(Offset p, Offset a, Offset b) {
    final abx = b.dx - a.dx;
    final aby = b.dy - a.dy;
    final l2 = abx * abx + aby * aby;
    if (l2 == 0) {
      final dx = p.dx - a.dx;
      final dy = p.dy - a.dy;
      return dx * dx + dy * dy;
    }
    final apx = p.dx - a.dx;
    final apy = p.dy - a.dy;
    final t = ((apx * abx + apy * aby) / l2).clamp(0.0, 1.0);
    final projX = a.dx + t * abx;
    final projY = a.dy + t * aby;
    final diffX = p.dx - projX;
    final diffY = p.dy - projY;
    return diffX * diffX + diffY * diffY;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'object_type': 'stroke',
      'z_index': zIndex,
      'data': {
        'tool': tool,
        'pen_type': penType.name,
        'pressure_sensitivity': pressureSensitivity.name,
        'tip_sharpness': tipSharpness,
        'tip_flatness': tipFlatness,
        'color': '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}',
        'stroke_width': strokeWidth,
        'opacity': opacity,
        'points': points.map((p) => p.toJson()).toList(),
      }
    };
  }

  factory CanvasStrokeItem.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final rawColor = data['color'] ?? json['color'];
    String colorHex = (rawColor is String ? rawColor : '').replaceFirst('#', '');
    if (colorHex.length == 6) {
      colorHex = 'FF$colorHex';
    }
    final colorVal = int.tryParse(colorHex, radix: 16) ?? 0xFF1E293B;
    final parsedColor = Color(colorVal);

    final rawPoints = (data['points'] ?? json['points']) as List<dynamic>? ?? [];
    final pts = rawPoints.map((p) => StrokePoint.fromJson(Map<String, dynamic>.from(p))).toList();

    PenType pt = PenType.fountainPen;
    final ptStr = (data['pen_type'] ?? json['pen_type']) as String?;
    if (ptStr != null) {
      for (final v in PenType.values) {
        if (v.name == ptStr) { pt = v; break; }
      }
    }

    PressureSensitivity sens = PressureSensitivity.medium;
    final sensStr = (data['pressure_sensitivity'] ?? json['pressure_sensitivity']) as String?;
    if (sensStr != null) {
      for (final s in PressureSensitivity.values) {
        if (s.name == sensStr) { sens = s; break; }
      }
    }

    return CanvasStrokeItem(
      id: (json['id'] ?? data['id'] ?? 'stroke-${DateTime.now().microsecondsSinceEpoch}') as String,
      points: pts,
      color: parsedColor,
      strokeWidth: ((data['stroke_width'] ?? data['width'] ?? json['width']) as num?)?.toDouble() ?? 3.0,
      opacity: (data['opacity'] as num?)?.toDouble() ?? 1.0,
      tool: (data['tool'] ?? json['tool']) as String? ?? 'pen',
      penType: pt,
      pressureSensitivity: sens,
      tipSharpness: (data['tip_sharpness'] as num?)?.toDouble() ?? 0.75,
      tipFlatness: (data['tip_flatness'] as num?)?.toDouble() ?? 0.66,
      zIndex: json['z_index'] as int? ?? 0,
    );
  }

  CanvasStrokeItem copyWith({
    String? id,
    List<StrokePoint>? points,
    Color? color,
    double? strokeWidth,
    double? opacity,
    String? tool,
    PenType? penType,
    PressureSensitivity? pressureSensitivity,
    double? tipSharpness,
    double? tipFlatness,
    int? zIndex,
    bool? isSelected,
  }) {
    return CanvasStrokeItem(
      id: id ?? this.id,
      points: points ?? this.points,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity ?? this.opacity,
      tool: tool ?? this.tool,
      penType: penType ?? this.penType,
      pressureSensitivity: pressureSensitivity ?? this.pressureSensitivity,
      tipSharpness: tipSharpness ?? this.tipSharpness,
      tipFlatness: tipFlatness ?? this.tipFlatness,
      zIndex: zIndex ?? this.zIndex,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
