import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_workspace_client/core/theme/app_theme.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:ai_workspace_client/features/canvas/canvas_state.dart';
import 'package:ai_workspace_client/features/canvas/engine/stroke_renderer.dart';

/// Pixel-accurate Goodnotes Floating Pen Options Pop-Up.
/// Displays live calligraphic curve preview wave, 3 pen type selectors,
/// and sliders for Tip Sharpness, Pressure Sensitivity, Tip Flatness, and Stroke Stabilization.
class FloatingPenOptionsDialog extends StatefulWidget {
  final CanvasDrawingState drawingState;
  final bool isDark;
  final VoidCallback? onClose;

  const FloatingPenOptionsDialog({
    super.key,
    required this.drawingState,
    this.isDark = true,
    this.onClose,
  });

  @override
  State<FloatingPenOptionsDialog> createState() => _FloatingPenOptionsDialogState();
}

class _FloatingPenOptionsDialogState extends State<FloatingPenOptionsDialog> {
  @override
  Widget build(BuildContext context) {
    final ds = widget.drawingState;
    final isDark = widget.isDark;

    final bg = isDark ? const Color(0xFF1B1F2D) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E364D) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    String penTitle = 'Fountain Pen';
    if (ds.currentPenType == PenType.ballpoint) penTitle = 'Ball Pen';
    if (ds.currentPenType == PenType.brushPen) penTitle = 'Brush Pen';
    if (ds.currentPenType == PenType.pencil) penTitle = 'Pencil (GoodNotes Graphite)';

    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final maxDialogH = math.min(480.0, screenH - 120.0);
    final maxDialogW = math.min(360.0, screenW - 24.0);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: maxDialogW,
        constraints: BoxConstraints(maxHeight: maxDialogH),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header Title & Close Button ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 4),
              child: Row(
                children: [
                  const SizedBox(width: 28),
                  Expanded(
                    child: Center(
                      child: Text(
                        penTitle,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18, color: textSecondary),
                    onPressed: widget.onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // ── Scrollable Body ──────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Dynamic Calligraphic Preview Wave ─────────────────────
                    Container(
                      height: (screenH < 700) ? 80 : 105,
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF141824) : const Color(0xFFFAFAFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CustomPaint(
                          painter: _CalligraphicWavePainter(
                            penType: ds.currentPenType,
                            sharpness: ds.tipSharpness,
                            flatness: ds.tipFlatness,
                            sensitivity: ds.pressureSensitivity,
                            color: ds.strokeColor,
                            strokeWidth: ds.strokeWidth,
                          ),
                        ),
                      ),
                    ),

            // ── Pen Type Selectors (Fountain, Ball, Brush, Pencil) ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  _penTypeCard(
                    title: 'Fountain',
                    icon: Icons.draw_rounded,
                    type: PenType.fountainPen,
                    isSelected: ds.currentPenType == PenType.fountainPen,
                    isDark: isDark,
                    onTap: () => setState(() => ds.setPenType(PenType.fountainPen)),
                  ),
                  const SizedBox(width: 6),
                  _penTypeCard(
                    title: 'Ball Pen',
                    icon: Icons.edit_outlined,
                    type: PenType.ballpoint,
                    isSelected: ds.currentPenType == PenType.ballpoint,
                    isDark: isDark,
                    onTap: () => setState(() => ds.setPenType(PenType.ballpoint)),
                  ),
                  const SizedBox(width: 6),
                  _penTypeCard(
                    title: 'Brush',
                    icon: Icons.brush_rounded,
                    type: PenType.brushPen,
                    isSelected: ds.currentPenType == PenType.brushPen,
                    isDark: isDark,
                    onTap: () => setState(() => ds.setPenType(PenType.brushPen)),
                  ),
                  const SizedBox(width: 6),
                  _penTypeCard(
                    title: 'Pencil',
                    icon: Icons.create_outlined,
                    type: PenType.pencil,
                    isSelected: ds.currentPenType == PenType.pencil,
                    isDark: isDark,
                    onTap: () => setState(() => ds.setPenType(PenType.pencil)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // ── Slider Settings (Matching GoodNotes) ───────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // 1. TIP SHARPNESS (Fountain Pen, Ball Pen, Brush Pen)
                  _buildSliderRow(
                    title: 'TIP SHARPNESS',
                    valueStr: '${(ds.tipSharpness * 100).round()}%',
                    value: ds.tipSharpness,
                    onChanged: (v) => setState(() => ds.setTipSharpness(v)),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),

                  // 2. PRESSURE SENSITIVITY
                  _buildPressureSliderRow(
                    title: 'PRESSURE SENSITIVITY',
                    sensitivity: ds.pressureSensitivity,
                    onChanged: (s) => setState(() => ds.setPressureSensitivity(s)),
                    isDark: isDark,
                  ),

                  // 3. TIP FLATNESS (Fountain Pen chisel nib)
                  if (ds.currentPenType == PenType.fountainPen) ...[
                    const SizedBox(height: 12),
                    _buildSliderRow(
                      title: 'TIP FLATNESS',
                      valueStr: '${(ds.tipFlatness * 100).round()}%',
                      value: ds.tipFlatness,
                      onChanged: (v) => setState(() => ds.setTipFlatness(v)),
                      isDark: isDark,
                    ),
                  ],

                  const SizedBox(height: 12),

                  // 4. STROKE STABILIZATION (All pen types)
                  _buildSliderRow(
                    title: 'STROKE STABILIZATION',
                    valueStr: '${(ds.strokeStabilization * 100).round()}%',
                    value: ds.strokeStabilization,
                    onChanged: (v) => setState(() => ds.setStrokeStabilization(v)),
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Divider(color: borderColor, height: 1),

            // ── Draw and Hold Toggle ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.auto_fix_high_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Draw and Hold',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'Snap lines and shapes when held',
                          style: GoogleFonts.inter(fontSize: 11, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: ds.drawAndHold,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => ds.setDrawAndHold(val)),
                  ),
                ],
              ),
            ),

            Divider(color: borderColor, height: 1),

            // ── Draw with Finger Toggle (Apple Pencil / Palm Rejection) ─
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 18,
                    color: ds.fingerDrawingEnabled ? AppColors.primary : textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Draw with Finger',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          ds.fingerDrawingEnabled
                              ? 'Fingers draw ink strokes'
                              : 'Fingers pan/pinch; Apple Pencil writes exclusively',
                          style: GoogleFonts.inter(fontSize: 11, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: ds.fingerDrawingEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => ds.setFingerDrawingEnabled(val)),
                  ),
                ],
              ),
            ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _penTypeCard({
    required String title,
    required IconData icon,
    required PenType type,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final border = isSelected
        ? AppColors.primary
        : (isDark ? const Color(0xFF2F374E) : const Color(0xFFE2E8F0));
    final bg = isSelected
        ? (isDark ? AppColors.primary.withValues(alpha: 0.15) : const Color(0xFFEEF2FF))
        : (isDark ? const Color(0xFF222738) : const Color(0xFFF8FAFC));

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: isSelected ? 1.8 : 1.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String title,
    required String valueStr,
    required double value,
    required ValueChanged<double> onChanged,
    required bool isDark,
  }) {
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: textSecondary,
              ),
            ),
            Text(
              valueStr,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: isDark ? const Color(0xFF2B3246) : const Color(0xFFE2E8F0),
            thumbColor: Colors.white,
          ),
          child: Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildPressureSliderRow({
    required String title,
    required PressureSensitivity sensitivity,
    required ValueChanged<PressureSensitivity> onChanged,
    required bool isDark,
  }) {
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);

    String label = 'Medium';
    double sliderVal = 0.66;
    if (sensitivity == PressureSensitivity.off) {
      label = 'Off';
      sliderVal = 0.0;
    } else if (sensitivity == PressureSensitivity.low) {
      label = 'Low';
      sliderVal = 0.33;
    } else if (sensitivity == PressureSensitivity.medium) {
      label = 'Medium';
      sliderVal = 0.66;
    } else if (sensitivity == PressureSensitivity.high) {
      label = 'Max';
      sliderVal = 1.0;
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: textSecondary,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: isDark ? const Color(0xFF2B3246) : const Color(0xFFE2E8F0),
            thumbColor: Colors.white,
          ),
          child: Slider(
            value: sliderVal,
            min: 0.0,
            max: 1.0,
            divisions: 3,
            onChanged: (val) {
              if (val <= 0.1) {
                onChanged(PressureSensitivity.off);
              } else if (val <= 0.4) {
                onChanged(PressureSensitivity.low);
              } else if (val <= 0.8) {
                onChanged(PressureSensitivity.medium);
              } else {
                onChanged(PressureSensitivity.high);
              }
            },
          ),
        ),
      ],
    );
  }
}

/// Draws an organic S-wave calligraphic ribbon responding in real-time to pen sliders
class _CalligraphicWavePainter extends CustomPainter {
  final PenType penType;
  final double sharpness;
  final double flatness;
  final PressureSensitivity sensitivity;
  final Color color;
  final double strokeWidth;

  _CalligraphicWavePainter({
    required this.penType,
    required this.sharpness,
    required this.flatness,
    required this.sensitivity,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cy = h / 2.0;

    const pointsCount = 60;

    // Pencil: Render authentic GoodNotes graphite wave with paper-tooth texture
    if (penType == PenType.pencil) {
      final wavePoints = <StrokePoint>[];
      for (int i = 0; i <= pointsCount; i++) {
        final t = i / pointsCount;
        final x = 30.0 + t * (w - 60.0);
        final y = cy + (16.0 * math.sin(t * math.pi * 2.0));
        final pressure = (0.28 + 0.62 * math.sin(t * math.pi)).clamp(0.12, 1.0);
        wavePoints.add(StrokePoint(
          x: x,
          y: y,
          pressure: pressure,
          tilt: 0.15,
          velocity: 0.5,
          timestamp: (t * 500).round(),
        ));
      }
      StrokeRenderer.drawStroke(
        canvas: canvas,
        points: wavePoints,
        color: color,
        baseWidth: strokeWidth,
        opacity: 0.85,
        penType: PenType.pencil,
        sensitivity: sensitivity,
      );
      return;
    }

    // Ball Pen: Draw uniform stroke with round caps if default monoline
    if (penType == PenType.ballpoint && sharpness <= 0.02 && sensitivity == PressureSensitivity.off) {
      final strokePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = (strokeWidth * 1.5).clamp(1.5, 40.0)
        ..isAntiAlias = true;

      final path = Path();
      for (int i = 0; i <= pointsCount; i++) {
        final t = i / pointsCount;
        final x = 30.0 + t * (w - 60.0);
        final y = cy + (16.0 * math.sin(t * math.pi * 2.0));
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, strokePaint);
      return;
    }

    final leftBorder = <Offset>[];
    final rightBorder = <Offset>[];

    // Sensitivity factor
    final sensMultiplier = switch (sensitivity) {
      PressureSensitivity.off => 0.4,
      PressureSensitivity.low => 0.7,
      PressureSensitivity.medium => 1.0,
      PressureSensitivity.high => 1.35,
      PressureSensitivity.custom => 1.0,
    };

    // Build S-wave backbone with pen physics
    for (int i = 0; i <= pointsCount; i++) {
      final t = i / pointsCount;
      final x = 30.0 + t * (w - 60.0);
      final y = cy + (18.0 * math.sin(t * math.pi * 2.0));

      // Tangent direction for chisel angle
      final dx = (w - 60.0) / pointsCount;
      final dy = 18.0 * (2.0 * math.pi / pointsCount) * math.cos(t * math.pi * 2.0);
      final dir = Offset(dx, dy);
      final angle = math.atan2(dir.dy, dir.dx);

      double widthFactor = 1.0;
      if (penType == PenType.fountainPen) {
        // Belly flex from pressure
        final belly = 0.50 + 1.20 * sensMultiplier * math.sin(t * math.pi);
        // Taper ends with sharpness
        final distFromEnd = math.min(t, 1.0 - t) * 2.0; // 0.0 at ends, 1.0 in center
        final minScale = (0.12 + (1.0 - sharpness) * 0.78).clamp(0.12, 1.0);
        final taper = minScale + (1.0 - minScale) * math.pow(distFromEnd.clamp(0.0, 1.0), 0.7);
        // Chisel flatness angle
        final chisel = 1.0 - (flatness * 0.55 * math.pow(math.cos(angle - math.pi / 4.0), 2));
        widthFactor = belly * taper * chisel;
      } else if (penType == PenType.brushPen) {
        // Broad calligraphic bristle spread
        final belly = 0.35 + 2.30 * sensMultiplier * math.pow(math.sin(t * math.pi), 1.3);
        final distFromEnd = math.min(t, 1.0 - t) * 2.0;
        final minScale = (0.06 + (1.0 - sharpness) * 0.74).clamp(0.06, 0.95);
        final taper = minScale + (1.0 - minScale) * math.pow(distFromEnd.clamp(0.0, 1.0), 0.85);
        widthFactor = belly * taper;
      } else if (penType == PenType.ballpoint) {
        final belly = 0.90 + 0.20 * sensMultiplier * math.sin(t * math.pi);
        final distFromEnd = math.min(t, 1.0 - t) * 2.0;
        final minScale = (0.20 + (1.0 - sharpness) * 0.80).clamp(0.20, 1.0);
        final taper = minScale + (1.0 - minScale) * math.pow(distFromEnd.clamp(0.0, 1.0), 0.6);
        widthFactor = belly * taper;
      }

      final halfW = (strokeWidth * 1.5 * widthFactor.clamp(0.10, 3.5)) / 2.0;
      final d = dir.distance;
      final normal = d > 0.0001 ? Offset(-dir.dy / d, dir.dx / d) : const Offset(0, 1);

      leftBorder.add(Offset(x + normal.dx * halfW, y + normal.dy * halfW));
      rightBorder.add(Offset(x - normal.dx * halfW, y - normal.dy * halfW));
    }

    final path = Path();
    path.moveTo(leftBorder.first.dx, leftBorder.first.dy);
    for (int i = 1; i < leftBorder.length; i++) {
      path.lineTo(leftBorder[i].dx, leftBorder[i].dy);
    }
    for (int i = rightBorder.length - 1; i >= 0; i--) {
      path.lineTo(rightBorder[i].dx, rightBorder[i].dy);
    }
    path.close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CalligraphicWavePainter old) {
    return old.penType != penType ||
        old.sharpness != sharpness ||
        old.flatness != flatness ||
        old.sensitivity != sensitivity ||
        old.color != color ||
        old.strokeWidth != strokeWidth;
  }
}
