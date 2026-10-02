import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_workspace_client/core/models/canvas_models.dart';
import 'package:ai_workspace_client/core/theme/app_theme.dart';
import 'package:ai_workspace_client/state/app_state.dart';
import 'package:ai_workspace_client/features/canvas/engine/stroke_engine.dart';
import 'package:ai_workspace_client/features/canvas/widgets/goodnotes_tool_icons.dart';

class PenSettingsPanel extends StatefulWidget {
  final AppState state;
  final bool isDark;
  final VoidCallback onClose;

  const PenSettingsPanel({
    super.key,
    required this.state,
    required this.isDark,
    required this.onClose,
  });

  @override
  State<PenSettingsPanel> createState() => _PenSettingsPanelState();
}

class _PenSettingsPanelState extends State<PenSettingsPanel> {
  // Local preview drawing
  final List<StrokePoint> _previewPoints = [];
  bool _isDrawing = false;

  static const _presetColors = [
    Color(0xFF0A0A0A),   // Near Black
    Color(0xFF1E3A8A),   // Deep Navy
    Color(0xFF0F766E),   // Teal
    Color(0xFF2E7D32),   // Forest Green
    Color(0xFF7C3AED),   // Purple
    Color(0xFFBE123C),   // Crimson
    Color(0xFFD97706),   // Amber
    Color(0xFFE2E8F0),   // Near White
    Color(0xFF38BDF8),   // Sky Blue
    Color(0xFFF472B6),   // Pink
    Color(0xFF84CC16),   // Lime
    Color(0xFFF97316),   // Orange
  ];

  static const _highlighterColors = [
    Color(0xFFFEF08A),   // Lemon
    Color(0xFFBBF7D0),   // Mint
    Color(0xFFBAE6FD),   // Sky
    Color(0xFFFBCFE8),   // Rose
    Color(0xFFFED7AA),   // Peach
    Color(0xFFE9D5FF),   // Lavender
    Color(0xFFFCA5A5),   // Salmon
    Color(0xFF6EE7B7),   // Emerald
  ];

  bool get _isHighlighter => widget.state.currentTool == CanvasTool.highlighter;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF1A1E2B) : Colors.white;
    final border = widget.isDark ? const Color(0xFF252A3A) : const Color(0xFFE8ECEF);
    final textPrimary = widget.isDark ? const Color(0xFFF0F2FF) : const Color(0xFF1E293B);
    final textMuted = widget.isDark ? const Color(0xFF4A5270) : const Color(0xFF8B95A5);

    return Container(
      width: 320,
      constraints: const BoxConstraints(maxHeight: 600),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.4 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          _buildHeader(textPrimary, border),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Pen Type Selector (only for pen tool) ──────────────────
                  if (!_isHighlighter) ...[
                    _sectionLabel('PEN TYPE', textMuted),
                    const SizedBox(height: 8),
                    _buildPenTypeSelector(),
                    const SizedBox(height: 16),
                  ],

                  // ── Size ────────────────────────────────────────────────────
                  _sectionLabel('SIZE', textMuted),
                  const SizedBox(height: 8),
                  _buildSizeSelector(textPrimary),
                  const SizedBox(height: 16),

                  // ── Opacity ─────────────────────────────────────────────────
                  _sectionLabel('OPACITY', textMuted),
                  const SizedBox(height: 8),
                  _buildOpacitySelector(textPrimary),
                  const SizedBox(height: 16),

                  // ── Pressure Sensitivity ────────────────────────────────────
                  if (!_isHighlighter) ...[
                    _sectionLabel('PRESSURE', textMuted),
                    const SizedBox(height: 8),
                    _buildPressureSelector(textPrimary),
                    const SizedBox(height: 16),
                  ],

                  // ── Color Palette ────────────────────────────────────────────
                  _sectionLabel('COLOR', textMuted),
                  const SizedBox(height: 8),
                  _buildColorPalette(),
                  const SizedBox(height: 8),
                  _buildCustomColorButton(textPrimary, border),
                  const SizedBox(height: 16),

                  // ── Preview area ─────────────────────────────────────────────
                  _sectionLabel('PREVIEW (draw here)', textMuted),
                  const SizedBox(height: 8),
                  _buildPreviewArea(border),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color textPrimary, Color border) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: GoodNotesToolIcon(
                tool: _isHighlighter ? CanvasTool.highlighter : CanvasTool.pen,
                color: Colors.white,
                size: 15,
                isSelected: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _isHighlighter ? 'Highlighter Settings' : 'Pen Settings',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: widget.onClose,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            color: widget.isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, Color color) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildPenTypeSelector() {
    final types = [
      (PenType.fountainPen, 'Fountain', CanvasTool.pen),
      (PenType.ballpoint, 'Ballpoint', CanvasTool.pencil),
      (PenType.pencil, 'Pencil', CanvasTool.pencil),
      (PenType.brushPen, 'Brush', CanvasTool.brush),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((t) {
        final isSelected = widget.state.currentPenType == t.$1;
        final iconColor = isSelected ? AppColors.primary : (widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);
        return GestureDetector(
          onTap: () => setState(() => widget.state.setPenType(t.$1)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : (widget.isDark ? const Color(0xFF252A3A) : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppColors.primary : (widget.isDark ? const Color(0xFF252A3A) : const Color(0xFFE8ECEF)),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GoodNotesToolIcon(
                  tool: t.$3,
                  color: iconColor,
                  size: 14,
                  isSelected: isSelected,
                ),
                const SizedBox(width: 5),
                Text(
                  t.$2,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.primary : (widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSizeSelector(Color textPrimary) {
    final sizes = _isHighlighter
        ? [4.0, 8.0, 14.0, 20.0, 30.0]
        : [1.0, 2.0, 3.5, 6.0, 10.0, 16.0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: sizes.map((s) {
            final isSelected = (widget.state.strokeWidth - s).abs() < 0.8;
            final dotSize = _isHighlighter ? (s / 2.2).clamp(4.0, 16.0) : (s + 2).clamp(3.0, 16.0);
            return GestureDetector(
              onTap: () => setState(() => widget.state.setStrokeWidth(s)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: _isHighlighter ? 22 : dotSize,
                    height: _isHighlighter ? dotSize : dotSize,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : (widget.isDark ? Colors.white60 : Colors.black54),
                      borderRadius: BorderRadius.circular(_isHighlighter ? 3 : 10),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        // Continuous slider
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: widget.isDark ? const Color(0xFF252A3A) : const Color(0xFFE8ECEF),
            thumbColor: AppColors.primary,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: widget.state.strokeWidth.clamp(_isHighlighter ? 1.0 : 0.5, 40.0),
            min: _isHighlighter ? 1.0 : 0.5,
            max: _isHighlighter ? 40.0 : 20.0,
            onChanged: (v) => setState(() => widget.state.setStrokeWidth(v)),
          ),
        ),
      ],
    );
  }

  Widget _buildOpacitySelector(Color textPrimary) {
    final opacities = [0.25, 0.5, 0.75, 1.0];
    return Row(
      children: opacities.map((o) {
        final isSelected = (widget.state.strokeOpacity - o).abs() < 0.1;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => widget.state.setStrokeOpacity(o)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : (widget.isDark ? const Color(0xFF252A3A) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppColors.primary : (widget.isDark ? const Color(0xFF252A3A) : const Color(0xFFE8ECEF)),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  '${(o * 100).round()}%',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.primary : (widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPressureSelector(Color textPrimary) {
    final options = [
      (PressureSensitivity.off, 'Off'),
      (PressureSensitivity.low, 'Low'),
      (PressureSensitivity.medium, 'Medium'),
      (PressureSensitivity.high, 'High'),
    ];
    return Row(
      children: options.map((o) {
        final isSelected = widget.state.pressureSensitivity == o.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => widget.state.setPressureSensitivity(o.$1)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : (widget.isDark ? const Color(0xFF252A3A) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppColors.primary : (widget.isDark ? const Color(0xFF252A3A) : const Color(0xFFE8ECEF)),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  o.$2,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.primary : (widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorPalette() {
    final colors = _isHighlighter ? _highlighterColors : _presetColors;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...colors.map((c) {
          final isSelected = widget.state.strokeColor.toARGB32() == c.toARGB32();
          return GestureDetector(
            onTap: () => setState(() => widget.state.setStrokeColor(c)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? (widget.isDark ? Colors.white : Colors.black87)
                      : Colors.transparent,
                  width: isSelected ? 2.5 : 0,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)]
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                  : null,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCustomColorButton(Color textPrimary, Color border) {
    return GestureDetector(
      onTap: () => _showColorPicker(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple],
                  begin: Alignment.centerLeft, end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Custom color…',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1A1E2B) : Colors.white,
        title: Text('Pick a Color',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: widget.state.strokeColor,
            onColorChanged: (c) => setState(() => widget.state.setStrokeColor(c)),
            pickerAreaHeightPercent: 0.7,
            enableAlpha: false,
            labelTypes: const [],
            displayThumbColor: true,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewArea(Color border) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF141822) : const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          children: [
            Positioned.fill(
              child: Listener(
                onPointerDown: (e) {
                  setState(() {
                    _isDrawing = true;
                    _previewPoints.clear();
                    _previewPoints.add(StrokePoint(
                      x: e.localPosition.dx, y: e.localPosition.dy,
                      pressure: e.pressureMin != e.pressureMax
                          ? ((e.pressure - e.pressureMin) / (e.pressureMax - e.pressureMin)).clamp(0.1, 1.0)
                          : 0.5,
                    ));
                  });
                },
                onPointerMove: (e) {
                  if (!_isDrawing) return;
                  setState(() {
                    _previewPoints.add(StrokePoint(
                      x: e.localPosition.dx, y: e.localPosition.dy,
                      pressure: e.pressureMin != e.pressureMax
                          ? ((e.pressure - e.pressureMin) / (e.pressureMax - e.pressureMin)).clamp(0.1, 1.0)
                          : 0.5,
                    ));
                  });
                },
                onPointerUp: (_) => setState(() => _isDrawing = false),
                child: CustomPaint(
                  painter: _PreviewPainter(
                    points: _previewPoints,
                    color: widget.state.strokeColor,
                    baseWidth: widget.state.strokeWidth,
                    penType: widget.state.currentPenType,
                    sensitivity: widget.state.pressureSensitivity,
                    opacity: widget.state.strokeOpacity,
                    isHighlighter: _isHighlighter,
                  ),
                ),
              ),
            ),
            if (_previewPoints.isEmpty)
              Center(
                child: Text(
                  'Draw here to preview',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: widget.isDark ? const Color(0xFF3A4260) : const Color(0xFFCBD5E1),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            if (_previewPoints.isNotEmpty)
              Positioned(
                top: 6, right: 6,
                child: GestureDetector(
                  onTap: () => setState(() => _previewPoints.clear()),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF252A3A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.clear_rounded, size: 12,
                        color: widget.isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  final List<StrokePoint> points;
  final Color color;
  final double baseWidth;
  final PenType penType;
  final PressureSensitivity sensitivity;
  final double opacity;
  final bool isHighlighter;

  const _PreviewPainter({
    required this.points,
    required this.color,
    required this.baseWidth,
    required this.penType,
    required this.sensitivity,
    required this.opacity,
    required this.isHighlighter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final stroke = CanvasStrokeItem(
      id: 'preview',
      points: StrokeEngine.injectVelocity(points),
      color: color,
      strokeWidth: baseWidth,
      opacity: opacity,
      tool: isHighlighter ? 'highlighter' : 'pen',
      penType: penType,
    );

    StrokeEngine.drawVariableWidthStroke(canvas, stroke, sensitivity, isLive: true);
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter old) => true;
}
