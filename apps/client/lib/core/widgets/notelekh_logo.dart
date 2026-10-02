import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable Notelekh brand logo widget with the exact official logo
class NotelekhLogo extends StatelessWidget {
  final double height;
  final bool isDark;
  final bool showTagline;
  final VoidCallback? onTap;

  const NotelekhLogo({
    super.key,
    this.height = 32,
    this.isDark = false,
    this.showTagline = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final iconSize = height;

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        NotelekhIcon(size: iconSize),
        SizedBox(width: iconSize * 0.35),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notelekh',
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: height * 0.72,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                height: 1.1,
              ),
            ),
            if (showTagline)
              Text(
                'Think. Write. Grow.',
                style: GoogleFonts.inter(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontSize: height * 0.32,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
              ),
          ],
        ),
      ],
    );

    if (onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: content,
        ),
      );
    }

    return content;
  }
}

/// Stylized gradient "N" mark with image asset and vector fallback
class NotelekhIcon extends StatelessWidget {
  final double size;

  const NotelekhIcon({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/notelekh_icon.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => CustomPaint(
          size: Size(size, size),
          painter: _NotelekhVectorPainter(),
        ),
      ),
    );
  }
}

/// High-precision vector painter replicating the official Notelekh "N" logo
class _NotelekhVectorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strokeW = w * 0.26;
    final radius = strokeW / 2;

    // Left vertical stroke (blue gradient)
    final leftRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.12, strokeW, h * 0.76),
      Radius.circular(radius),
    );
    final leftPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
      ).createShader(leftRect.outerRect);
    canvas.drawRRect(leftRect, leftPaint);

    // Diagonal fold (transition gradient)
    final diagPath = Path()
      ..moveTo(w * 0.08 + strokeW / 2, h * 0.12 + radius)
      ..lineTo(w * 0.92 - strokeW / 2, h * 0.88 - radius);
    final diagPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(diagPath, diagPaint);

    // Right vertical stroke (purple / magenta gradient)
    final rightRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.92 - strokeW, h * 0.08, strokeW, h * 0.76),
      Radius.circular(radius),
    );
    final rightPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFA855F7), Color(0xFF7C3AED)],
      ).createShader(rightRect.outerRect);
    canvas.drawRRect(rightRect, rightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
