import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';

/// Exact GoodNotes 6 tool icons matching the official reference screenshot.
/// Features the signature peeled smiley face sticker for Elements,
/// pen with cursive flourish, dashed lasso with cursor, text box with cyan fill,
/// shapes 4-grid (△ ⤴ ○ ▢), night photo with crescent moon, folded note, and starburst laser.
class GoodNotesToolIcon extends StatelessWidget {
  final CanvasTool tool;
  final Color color;
  final double size;
  final bool isSelected;
  final bool showCompositeShapes;

  const GoodNotesToolIcon({
    super.key,
    required this.tool,
    required this.color,
    this.size = 24.0,
    this.isSelected = false,
    this.showCompositeShapes = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _getPainter(),
      ),
    );
  }

  CustomPainter _getPainter() {
    switch (tool) {
      case CanvasTool.pen:
        return _PenIconPainter(color: color);
      case CanvasTool.eraser:
        return _EraserIconPainter(color: color);
      case CanvasTool.highlighter:
        return _HighlighterIconPainter(color: color);
      case CanvasTool.lasso:
        return _LassoIconPainter(color: color);
      case CanvasTool.tape:
        return _NoteTapeIconPainter(color: color);
      case CanvasTool.laser:
        return _LaserIconPainter(color: color);
      case CanvasTool.text:
        return _TextIconPainter(color: color, isSelected: isSelected);
      case CanvasTool.rectangle:
        return showCompositeShapes ? _ShapesCompositeIconPainter(color: color) : _RectangleIconPainter(color: color);
      case CanvasTool.circle:
        return _CircleIconPainter(color: color);
      case CanvasTool.triangle:
        return _TriangleIconPainter(color: color);
      case CanvasTool.line:
        return _LineIconPainter(color: color);
      case CanvasTool.arrow:
        return _ArrowIconPainter(color: color);
      case CanvasTool.elements:
        return _ElementsIconPainter(color: color);
      case CanvasTool.image:
        return _ImageIconPainter(color: color);
      case CanvasTool.hand:
        return _HandIconPainter(color: color, isSelected: isSelected);
      case CanvasTool.pencil:
        return _PencilIconPainter(color: color);
      case CanvasTool.brush:
        return _BrushIconPainter(color: color);
      default:
        return _PenIconPainter(color: color);
    }
  }
}

/// Shared outline paint — bold, smooth 1.8px stroke with rounded caps and joins
Paint _outlinePaint(Color color) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1.8
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// Helper to draw dashed paths using Flutter's native computeMetrics
void _drawDashedPath(Canvas canvas, Path path, Paint paint, {double dashWidth = 2.4, double dashSpace = 2.0}) {
  for (final metric in path.computeMetrics()) {
    double distance = 0.0;
    while (distance < metric.length) {
      final end = math.min(distance + dashWidth, metric.length);
      canvas.drawPath(metric.extractPath(distance, end), paint);
      distance += dashWidth + dashSpace;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Lasso Tool — Dashed freeform selection loop with pointer cursor arrow
// ─────────────────────────────────────────────────────────────────────────────
class _LassoIconPainter extends CustomPainter {
  final Color color;
  _LassoIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    canvas.save();
    canvas.scale(s, s);
    final p = _outlinePaint(color);

    // Freehand organic lasso loop path
    final loop = Path()
      ..moveTo(10.5, 3.5)
      ..cubicTo(5.5, 4.0, 3.5, 7.5, 3.5, 11.0)
      ..cubicTo(3.5, 14.5, 5.0, 16.5, 4.0, 19.0)
      ..cubicTo(3.5, 20.5, 7.0, 20.8, 9.5, 19.8)
      ..cubicTo(12.0, 18.8, 13.5, 16.5, 14.0, 13.5)
      ..cubicTo(14.5, 9.0, 15.5, 6.0, 13.5, 4.0)
      ..close();

    _drawDashedPath(canvas, loop, p, dashWidth: 2.2, dashSpace: 2.0);

    // Selection cursor arrow at bottom-right pointing into the loop
    final arrow = Path()
      ..moveTo(20.0, 20.0)
      ..lineTo(14.5, 14.5)
      ..lineTo(14.5, 19.0)
      ..lineTo(19.0, 19.0)
      ..close();
    canvas.drawPath(arrow, p);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LassoIconPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Pen Tool — Angled pen with handwritten cursive flourish loop at the tip
// ─────────────────────────────────────────────────────────────────────────────
class _PenIconPainter extends CustomPainter {
  final Color color;
  _PenIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    canvas.save();
    canvas.scale(s, s);
    final p = _outlinePaint(color);

    // Pen body angled at 45 degrees
    final pen = Path()
      ..moveTo(14.5, 4.0)
      ..arcToPoint(const Offset(19.0, 8.5), radius: const Radius.circular(2.5))
      ..lineTo(12.5, 15.0)
      ..lineTo(7.0, 16.5) // tip
      ..lineTo(8.5, 11.0)
      ..close();
    canvas.drawPath(pen, p);

    // Nib collar band line
    canvas.drawLine(const Offset(9.2, 13.0), const Offset(13.0, 13.0), p..strokeWidth = 1.2);

    // Cursive flourish loop stroke coming out of the tip
    final curl = Path()
      ..moveTo(7.0, 16.5)
      ..cubicTo(5.2, 18.0, 4.0, 19.5, 5.5, 20.5)
      ..cubicTo(7.2, 21.5, 9.8, 19.8, 8.5, 17.8)
      ..cubicTo(7.5, 16.2, 5.5, 18.0, 7.0, 20.2);
    canvas.drawPath(curl, p);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PenIconPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Eraser Tool — Angled block eraser with body division and beveled head
// ─────────────────────────────────────────────────────────────────────────────
class _EraserIconPainter extends CustomPainter {
  final Color color;
  _EraserIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    canvas.save();
    canvas.scale(s, s);

    // Rotate canvas around center (12, 12) by -35 degrees
    canvas.translate(12.0, 12.0);
    canvas.rotate(-math.pi * 0.20);
    canvas.translate(-12.0, -12.0);

    final p = _outlinePaint(color);

    // Eraser outer rounded block
    final outerRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(8.0, 3.5, 8.0, 17.0),
      const Radius.circular(2.4),
    );
    canvas.drawRRect(outerRect, p);

    // Sleeve wrapper divider line
    canvas.drawLine(const Offset(8.0, 12.0), const Offset(16.0, 12.0), p);

    // Angled wipe chamfer line at bottom rubber head
    canvas.drawLine(const Offset(8.0, 17.5), const Offset(16.0, 16.0), p);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EraserIconPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Text Tool — Card with 4 corner dots, cyan fill & dark 'T' when active
// ─────────────────────────────────────────────────────────────────────────────
class _TextIconPainter extends CustomPainter {
  final Color color;
  final bool isSelected;
  _TextIconPainter({required this.color, this.isSelected = false});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    canvas.save();
    canvas.scale(s, s);

    final boxRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4.0, 4.0, 16.0, 16.0),
      const Radius.circular(3.0),
    );

    // When selected: cyan filled interior with dark text (matching GoodNotes reference)
    if (isSelected) {
      canvas.drawRRect(boxRect, Paint()..color = const Color(0xFF38BDF8)..style = PaintingStyle.fill);
      canvas.drawRRect(boxRect, _outlinePaint(const Color(0xFF0F172A)));
    } else {
      canvas.drawRRect(boxRect, _outlinePaint(color));
    }

    // 4 Corner handle dots
    const dots = [
      Offset(4.0, 4.0),
      Offset(20.0, 4.0),
      Offset(4.0, 20.0),
      Offset(20.0, 20.0),
    ];
    final dotColor = isSelected ? const Color(0xFF0F172A) : color;
    for (final d in dots) {
      canvas.drawCircle(d, 1.4, Paint()..color = dotColor..style = PaintingStyle.fill);
    }

    // Letter 'T'
    final tColor = isSelected ? const Color(0xFF0F172A) : color;
    final tPaint = _outlinePaint(tColor)..strokeWidth = 2.0;
    // Crossbar
    canvas.drawLine(const Offset(8.0, 8.5), const Offset(16.0, 8.5), tPaint);
    // Vertical stem
    canvas.drawLine(const Offset(12.0, 8.5), const Offset(12.0, 16.5), tPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TextIconPainter old) => old.color != color || old.isSelected != isSelected;
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Elements Tool — EXACT GoodNotes 6 Peeled Smiley Face Sticker
// ─────────────────────────────────────────────────────────────────────────────
class _ElementsIconPainter extends CustomPainter {
  final Color color;
  _ElementsIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    canvas.save();
    canvas.scale(s, s);
    final p = _outlinePaint(color);

    // Circular sticker with top-right corner peeled over
    // 1. Draw outer circle arc from Point B (20.2, 10.0) around to Point A (14.5, 4.3):
    final circleArc = Path()
      ..moveTo(20.2, 10.0)
      ..arcToPoint(
        const Offset(14.5, 4.3),
        radius: const Radius.circular(8.5),
        largeArc: true,
        clockwise: true,
      );
    canvas.drawPath(circleArc, p);

    // 2. Fold crease line connecting A and B
    canvas.drawLine(const Offset(14.5, 4.3), const Offset(20.2, 10.0), p);

    // 3. Peeled flap curling inward
    final flap = Path()
      ..moveTo(14.5, 4.3)
      ..quadraticBezierTo(15.2, 9.8, 20.2, 10.0);
    canvas.drawPath(flap, p);

    // 4. Smiley face inside sticker
    // Left eye dot
    canvas.drawCircle(const Offset(9.0, 11.8), 0.9, Paint()..color = color..style = PaintingStyle.fill);
    // Right eye dot
    canvas.drawCircle(const Offset(13.8, 12.6), 0.9, Paint()..color = color..style = PaintingStyle.fill);

    // Happy curved smile arc
    final smile = Path()
      ..moveTo(8.5, 14.8)
      ..quadraticBezierTo(11.2, 18.0, 14.2, 15.5);
    canvas.drawPath(smile, p);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ElementsIconPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. Image Tool — Photo card with crescent moon & mountain peaks
// ─────────────────────────────────────────────────────────────────────────────
class _ImageIconPainter extends CustomPainter {
  final Color color;
  _ImageIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    canvas.save();
    canvas.scale(s, s);
    final p = _outlinePaint(color);

    // Photo frame
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(3.5, 3.5, 17.0, 17.0), const Radius.circular(3.5)),
      p,
    );

    // Crescent moon in upper left
    final moon = Path()
      ..moveTo(8.5, 6.5)
      ..arcToPoint(const Offset(8.5, 10.5), radius: const Radius.circular(2.2))
      ..arcToPoint(const Offset(8.5, 6.5), radius: const Radius.circular(1.6), clockwise: false);
    canvas.drawPath(moon, p);

    // Two mountain peaks in foreground
    final peaks = Path()
      ..moveTo(3.5, 18.5)
      ..lineTo(8.0, 13.5)
      ..lineTo(12.0, 17.5)
      ..lineTo(15.0, 14.0)
      ..lineTo(18.5, 17.5)
      ..lineTo(20.5, 18.5);
    canvas.drawPath(peaks, p);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ImageIconPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. Shapes Tool — 4-item grid: Triangle △, Curved arrow ⤴, Circle ○, Square ▢
// ─────────────────────────────────────────────────────────────────────────────
class _ShapesCompositeIconPainter extends CustomPainter {
  final Color color;
  _ShapesCompositeIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    canvas.save();
    canvas.scale(s, s);
    final p = _outlinePaint(color);

    // 1. Triangle at top-left
    final tri = Path()
      ..moveTo(6.5, 4.0)
      ..lineTo(9.5, 9.5)
      ..lineTo(3.5, 9.5)
      ..close();
    canvas.drawPath(tri, p);

    // 2. Curved arrow at top-right
    final arrow = Path()
      ..moveTo(14.0, 9.0)
      ..quadraticBezierTo(14.5, 5.0, 18.5, 5.0)
      ..lineTo(18.5, 8.5);
    canvas.drawPath(arrow, p);
    // Arrowhead
    final head = Path()
      ..moveTo(16.5, 7.0)
      ..lineTo(18.5, 9.0)
      ..lineTo(20.5, 7.0);
    canvas.drawPath(head, p);

    // 3. Circle at bottom-left
    canvas.drawCircle(const Offset(6.5, 16.5), 3.0, p);

    // 4. Rounded square at bottom-right
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(13.5, 13.5, 6.5, 6.5), const Radius.circular(1.8)),
      p,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShapesCompositeIconPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 8. Sticky Note / Tape Tool — Note sheet with folded bottom-right corner & lines
// ─────────────────────────────────────────────────────────────────────────────
class _NoteTapeIconPainter extends CustomPainter {
  final Color color;
  _NoteTapeIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    canvas.save();
    canvas.scale(s, s);
    final p = _outlinePaint(color);

    // Note sheet with folded bottom-right corner
    final sheet = Path()
      ..moveTo(4.5, 3.5)
      ..lineTo(19.5, 3.5)
      ..lineTo(19.5, 14.0)
      ..lineTo(14.0, 19.5)
      ..lineTo(4.5, 19.5)
      ..close();
    canvas.drawPath(sheet, p);

    // Folded corner flap
    final fold = Path()
      ..moveTo(14.0, 14.0)
      ..lineTo(19.5, 14.0)
      ..moveTo(14.0, 14.0)
      ..lineTo(14.0, 19.5);
    canvas.drawPath(fold, p);

    // 2 Horizontal text lines
    canvas.drawLine(const Offset(7.5, 8.5), const Offset(15.0, 8.5), p);
    canvas.drawLine(const Offset(7.5, 12.0), const Offset(12.5, 12.0), p);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NoteTapeIconPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 9. Laser Pointer Tool — Capsule wand with button & 8 radiant starburst rays
// ─────────────────────────────────────────────────────────────────────────────
class _LaserIconPainter extends CustomPainter {
  final Color color;
  _LaserIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    canvas.save();
    canvas.scale(s, s);
    final p = _outlinePaint(color);

    // Rotate canvas around center (12, 12) by -45 degrees
    canvas.translate(12.0, 12.0);
    canvas.rotate(-math.pi / 4);
    canvas.translate(-12.0, -12.0);

    // Vertical capsule body
    final capsule = RRect.fromRectAndRadius(
      const Rect.fromLTWH(9.5, 9.0, 5.0, 12.5),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(capsule, p);

    // Button dot near bottom
    canvas.drawCircle(const Offset(12.0, 17.5), 1.0, p);

    // Starburst rays at the tip (12.0, 6.5)
    const center = Offset(12.0, 6.5);
    canvas.drawCircle(center, 0.9, Paint()..color = color..style = PaintingStyle.fill);

    const rayLengths = [2.8, 2.0, 2.8, 2.0, 2.8, 2.0, 2.8, 2.0];
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4);
      const rInner = 1.6;
      final rOuter = rInner + rayLengths[i];
      final x1 = center.dx + rInner * math.cos(angle);
      final y1 = center.dy + rInner * math.sin(angle);
      final x2 = center.dx + rOuter * math.cos(angle);
      final y2 = center.dy + rOuter * math.sin(angle);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), p..strokeWidth = 1.2);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LaserIconPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 10. Highlighter Tool — Wide-body marker with chisel nib
// ─────────────────────────────────────────────────────────────────────────────
class _HighlighterIconPainter extends CustomPainter {
  final Color color;
  _HighlighterIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    canvas.save();
    canvas.scale(s, s);

    // Rotate canvas around center (12, 12) by -45 degrees
    canvas.translate(12.0, 12.0);
    canvas.rotate(-math.pi / 4);
    canvas.translate(-12.0, -12.0);

    final p = _outlinePaint(color);

    // Marker barrel with rounded top corners
    final body = Path()
      ..moveTo(7.5, 5.0)
      ..arcToPoint(const Offset(9.5, 3.0), radius: const Radius.circular(2.0))
      ..lineTo(14.5, 3.0)
      ..arcToPoint(const Offset(16.5, 5.0), radius: const Radius.circular(2.0))
      ..lineTo(16.5, 13.5)
      ..lineTo(7.5, 13.5)
      ..close();
    canvas.drawPath(body, p);

    // Cap line band
    canvas.drawLine(const Offset(7.5, 6.5), const Offset(16.5, 6.5), p);

    // Chisel nib (asymmetrical slanted marker cut)
    final nib = Path()
      ..moveTo(8.5, 13.5)
      ..lineTo(15.5, 13.5)
      ..lineTo(15.5, 18.5)
      ..lineTo(9.5, 21.2)
      ..lineTo(8.5, 18.5)
      ..close();
    canvas.drawPath(nib, p);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HighlighterIconPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 11. Hand Tool — Natural, organic human hand silhouette with smooth rounded fingers
// ─────────────────────────────────────────────────────────────────────────────
class _HandIconPainter extends CustomPainter {
  final Color color;
  final bool isSelected;
  _HandIconPainter({required this.color, this.isSelected = false});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    canvas.save();
    canvas.scale(s, s);

    // Smooth, natural hand shape
    final hand = Path()
      // Left wrist / palm base
      ..moveTo(7.5, 20.5)
      // Thumb curving outward naturally
      ..cubicTo(5.5, 17.5, 4.0, 14.5, 3.5, 12.0)
      ..arcToPoint(const Offset(5.5, 10.5), radius: const Radius.circular(1.6))
      ..cubicTo(6.5, 11.5, 7.0, 13.0, 8.0, 11.0)
      // Index finger
      ..lineTo(8.0, 5.0)
      ..arcToPoint(const Offset(10.2, 5.0), radius: const Radius.circular(1.1))
      ..lineTo(10.2, 10.0)
      // Middle finger
      ..lineTo(10.5, 3.5)
      ..arcToPoint(const Offset(12.7, 3.5), radius: const Radius.circular(1.1))
      ..lineTo(12.7, 10.0)
      // Ring finger
      ..lineTo(13.0, 4.5)
      ..arcToPoint(const Offset(15.2, 4.5), radius: const Radius.circular(1.1))
      ..lineTo(15.2, 11.0)
      // Pinky finger
      ..lineTo(15.5, 7.0)
      ..arcToPoint(const Offset(17.5, 7.0), radius: const Radius.circular(1.0))
      ..cubicTo(17.5, 11.5, 17.5, 16.0, 16.0, 18.5)
      // Bottom wrist
      ..cubicTo(14.5, 21.0, 9.5, 21.0, 7.5, 20.5)
      ..close();

    if (isSelected) {
      canvas.drawPath(hand, Paint()..color = color..style = PaintingStyle.fill..isAntiAlias = true);
    } else {
      final p = _outlinePaint(color);
      canvas.drawPath(hand, p);
      // Palm crease line
      canvas.drawLine(const Offset(8.5, 15.0), const Offset(14.5, 15.5), p..strokeWidth = 1.0);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HandIconPainter old) => old.color != color || old.isSelected != isSelected;
}

// ─────────────────────────────────────────────────────────────────────────────
// 12. Pencil Tool — Hexagonal pencil with ferrule, eraser, & lead tip
// ─────────────────────────────────────────────────────────────────────────────
class _PencilIconPainter extends CustomPainter {
  final Color color;
  _PencilIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    canvas.save();
    canvas.scale(s, s);

    // Rotate canvas around center (12, 12) by -45 degrees
    canvas.translate(12.0, 12.0);
    canvas.rotate(-math.pi / 4);
    canvas.translate(-12.0, -12.0);

    final p = _outlinePaint(color);

    // Pencil barrel with rounded eraser top
    final body = Path()
      ..moveTo(9.5, 4.5)
      ..arcToPoint(const Offset(14.5, 4.5), radius: const Radius.circular(2.5))
      ..lineTo(14.5, 16.5)
      ..lineTo(9.5, 16.5)
      ..close();
    canvas.drawPath(body, p);

    // Ferrule crimp lines
    canvas.drawLine(const Offset(9.5, 6.0), const Offset(14.5, 6.0), p);
    canvas.drawLine(const Offset(9.5, 8.0), const Offset(14.5, 8.0), p);

    // Sharpened cone collar & graphite tip
    final tip = Path()
      ..moveTo(9.5, 16.5)
      ..lineTo(12.0, 22.0)
      ..lineTo(14.5, 16.5)
      ..close();
    canvas.drawPath(tip, p);

    // Graphite lead tip fill
    final lead = Path()
      ..moveTo(11.0, 19.5)
      ..lineTo(12.0, 22.0)
      ..lineTo(13.0, 19.5)
      ..close();
    canvas.drawPath(lead, Paint()..color = color..style = PaintingStyle.fill);

    // Body facet line
    canvas.drawLine(const Offset(12.0, 8.0), const Offset(12.0, 16.5), p..strokeWidth = 1.0);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PencilIconPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 13. Brush Tool — Calligraphy brush with slender handle & organic bristle head
// ─────────────────────────────────────────────────────────────────────────────
class _BrushIconPainter extends CustomPainter {
  final Color color;
  _BrushIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    canvas.save();
    canvas.scale(s, s);

    // Rotate canvas around center (12, 12) by -45 degrees
    canvas.translate(12.0, 12.0);
    canvas.rotate(-math.pi / 4);
    canvas.translate(-12.0, -12.0);

    final p = _outlinePaint(color);

    // Slender handle with rounded top
    final handle = Path()
      ..moveTo(10.5, 2.5)
      ..arcToPoint(const Offset(13.5, 2.5), radius: const Radius.circular(1.5))
      ..lineTo(13.5, 13.0)
      ..lineTo(10.5, 13.0)
      ..close();
    canvas.drawPath(handle, p);

    // Ferrule ring
    canvas.drawRect(const Rect.fromLTWH(10.0, 13.0, 4.0, 2.0), p);

    // Flowing teardrop calligraphy bristle head
    final bristles = Path()
      ..moveTo(10.5, 15.0)
      ..cubicTo(9.0, 17.5, 10.5, 20.5, 12.0, 22.5)
      ..cubicTo(13.5, 20.5, 15.0, 17.5, 13.5, 15.0)
      ..close();
    canvas.drawPath(bristles, p);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BrushIconPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 14. Rectangle — Clean rounded rectangle
// ─────────────────────────────────────────────────────────────────────────────
class _RectangleIconPainter extends CustomPainter {
  final Color color;
  _RectangleIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    canvas.save();
    canvas.scale(s, s);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(3.0, 5.0, 18.0, 14.0), const Radius.circular(2.5)),
      _outlinePaint(color),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RectangleIconPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 15. Circle — Clean smooth circle
// ─────────────────────────────────────────────────────────────────────────────
class _CircleIconPainter extends CustomPainter {
  final Color color;
  _CircleIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    canvas.save();
    canvas.scale(s, s);
    canvas.drawCircle(const Offset(12.0, 12.0), 9.0, _outlinePaint(color));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CircleIconPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 16. Triangle — Clean rounded triangle
// ─────────────────────────────────────────────────────────────────────────────
class _TriangleIconPainter extends CustomPainter {
  final Color color;
  _TriangleIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    canvas.save();
    canvas.scale(s, s);
    final tri = Path()
      ..moveTo(12.0, 3.5)
      ..lineTo(21.0, 20.0)
      ..lineTo(3.0, 20.0)
      ..close();
    canvas.drawPath(tri, _outlinePaint(color));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TriangleIconPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 17. Line — Diagonal line with soft rounded endpoints
// ─────────────────────────────────────────────────────────────────────────────
class _LineIconPainter extends CustomPainter {
  final Color color;
  _LineIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    canvas.save();
    canvas.scale(s, s);
    final p = _outlinePaint(color);
    canvas.drawLine(const Offset(4.0, 20.0), const Offset(20.0, 4.0), p);
    final dot = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(4.0, 20.0), 1.6, dot);
    canvas.drawCircle(const Offset(20.0, 4.0), 1.6, dot);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LineIconPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 18. Arrow — Diagonal arrow with smooth arrowhead
// ─────────────────────────────────────────────────────────────────────────────
class _ArrowIconPainter extends CustomPainter {
  final Color color;
  _ArrowIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    canvas.save();
    canvas.scale(s, s);
    final p = _outlinePaint(color);
    canvas.drawLine(const Offset(4.0, 20.0), const Offset(19.0, 5.0), p);
    final head = Path()
      ..moveTo(13.5, 4.5)
      ..lineTo(19.5, 4.5)
      ..lineTo(19.5, 10.5);
    canvas.drawPath(head, p);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArrowIconPainter old) => old.color != color;
}
