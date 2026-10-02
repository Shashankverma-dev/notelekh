import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_workspace_client/core/theme/app_theme.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke.dart';
import 'package:ai_workspace_client/features/canvas/canvas_state.dart';
import 'package:ai_workspace_client/features/canvas/widgets/color_picker.dart';
import 'package:ai_workspace_client/features/canvas/widgets/goodnotes_tool_icons.dart';

/// Pixel-accurate Goodnotes Floating Secondary Contextual Toolbar.
/// Floating rounded pill that adapts to the active tool:
/// - Pen Tool: Sub-pen trigger [ 🖋️ ⌵ ], companion tools, 3 thickness lines, and color swatches.
/// - Eraser Tool: Erase modes (Precision / Stroke / Segment), Erase Highlighter Only, Clear.
/// - Highlighter: 3 thicknesses, pastels, Straight Line toggle.
/// - Shapes: Fill toggle, snap to shapes.
/// - Laser: Dot mode vs Trail mode.
class FloatingSecondaryToolbar extends StatelessWidget {
  final CanvasDrawingState state;
  final VoidCallback onOpenPenOptions;
  final VoidCallback? onOpenLassoOptions;
  final VoidCallback onClearPage;
  final bool isDark;

  const FloatingSecondaryToolbar({
    super.key,
    required this.state,
    required this.onOpenPenOptions,
    this.onOpenLassoOptions,
    required this.onClearPage,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final tool = state.currentTool;

        final bg = isDark ? const Color(0xFF1E2333) : Colors.white;
        final border = isDark ? const Color(0xFF2C344A) : const Color(0xFFE2E8F0);
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 640;

        return Material(
          color: Colors.transparent,
          child: Container(
            height: isMobile ? 44 : 48,
            constraints: BoxConstraints(maxWidth: math.max(120.0, screenWidth - 16.0)),
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8, vertical: isMobile ? 2 : 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: border, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                if (tool == CanvasTool.pen || tool == CanvasTool.pencil || tool == CanvasTool.brush) ...[
                  _buildPenSecondaryRow(context, isDark),
                ] else if (tool == CanvasTool.highlighter) ...[
                  _buildHighlighterSecondaryRow(context, isDark),
                ] else if (tool == CanvasTool.eraser) ...[
                  _buildEraserSecondaryRow(context, isDark),
                ] else if (tool == CanvasTool.lasso) ...[
                  _buildLassoSecondaryRow(context, isDark),
                ] else if (tool == CanvasTool.laser) ...[
                  _buildLaserSecondaryRow(context, isDark),
                ] else if (tool == CanvasTool.rectangle ||
                    tool == CanvasTool.circle ||
                    tool == CanvasTool.triangle ||
                    tool == CanvasTool.line ||
                    tool == CanvasTool.arrow) ...[
                  _buildShapesSecondaryRow(context, isDark),
                ] else if (tool == CanvasTool.tape) ...[
                  _buildTapeSecondaryRow(context, isDark),
                ] else if (tool == CanvasTool.text) ...[
                  _buildTextSecondaryRow(context, isDark),
                ] else ...[
                  _buildDefaultSecondaryRow(context, isDark),
                ],
              ],
            ),
          ),
        ),
      );
      },
    );
  }

  // ── Pen Tool Secondary Toolbar (Matching Screenshot Top Box) ───────────────
  Widget _buildPenSecondaryRow(BuildContext context, bool isDark) {
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sub-pen pill with dropdown trigger [ 🖋️ ⌵ ]
        Tooltip(
          message: 'Pen Options (Tap for settings)',
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onOpenPenOptions,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF293145) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  state.currentPenType == PenType.brushPen
                      ? GoodNotesToolIcon(tool: CanvasTool.brush, color: state.strokeColor, size: 18, isSelected: true)
                      : (state.currentPenType == PenType.pencil
                          ? GoodNotesToolIcon(tool: CanvasTool.pencil, color: state.strokeColor, size: 18, isSelected: true)
                          : GoodNotesToolIcon(tool: CanvasTool.pen, color: state.strokeColor, size: 18, isSelected: true)),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: textSecondary),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 6),

        // Companion Quick Tools (Pencil, Highlighter, Eraser, Lasso)
        _miniToolIcon(
          tool: CanvasTool.pencil,
          tip: 'Pencil',
          isActive: state.currentTool == CanvasTool.pencil,
          onTap: () => state.setTool(CanvasTool.pencil),
          isDark: isDark,
        ),
        _miniToolIcon(
          tool: CanvasTool.highlighter,
          tip: 'Highlighter',
          isActive: state.currentTool == CanvasTool.highlighter,
          onTap: () => state.setTool(CanvasTool.highlighter),
          isDark: isDark,
        ),
        _miniToolIcon(
          tool: CanvasTool.eraser,
          tip: 'Eraser',
          isActive: state.currentTool == CanvasTool.eraser,
          onTap: () => state.setTool(CanvasTool.eraser),
          isDark: isDark,
        ),
        _miniToolIcon(
          tool: CanvasTool.lasso,
          tip: 'Lasso',
          isActive: state.currentTool == CanvasTool.lasso,
          onTap: () => state.setTool(CanvasTool.lasso),
          isDark: isDark,
        ),

        _divider(isDark),

        // 3 Stroke Thickness Lines ( — , — , — )
        for (int i = 0; i < 3; i++) _buildThicknessPill(i, isDark),

        _divider(isDark),

        // Quick Color Swatches + Active Color Pill
        _buildColorSwatchesRow(context, isDark),
      ],
    );
  }

  // ── Highlighter Secondary Toolbar ───────────────────────────────────────────
  Widget _buildHighlighterSecondaryRow(BuildContext context, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 3 Thickness presets
        for (int i = 0; i < 3; i++) _buildThicknessPill(i, isDark, isHighlighter: true),

        _divider(isDark),

        // Straight line assist toggle
        Tooltip(
          message: 'Draw in Straight Line',
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => state.setHighlighterStraightLine(!state.highlighterStraightLine),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: state.highlighterStraightLine
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: state.highlighterStraightLine ? AppColors.primary : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.straighten_rounded,
                    size: 16,
                    color: state.highlighterStraightLine
                        ? AppColors.primary
                        : (isDark ? Colors.white60 : Colors.black54),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Straight Line',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: state.highlighterStraightLine
                          ? AppColors.primary
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        _divider(isDark),

        // Quick Pastel Colors
        _buildColorSwatchesRow(context, isDark),
      ],
    );
  }

  // ── Eraser Secondary Toolbar ────────────────────────────────────────────────
  Widget _buildEraserSecondaryRow(BuildContext context, bool isDark) {
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Erase Mode Pills
        _eraserModeBtn(
          label: 'Precision',
          icon: Icons.grain_rounded,
          mode: EraserMode.segment,
          isDark: isDark,
        ),
        const SizedBox(width: 4),
        _eraserModeBtn(
          label: 'Stroke',
          icon: Icons.draw_rounded,
          mode: EraserMode.stroke,
          isDark: isDark,
        ),
        const SizedBox(width: 4),
        _eraserModeBtn(
          label: 'Area',
          icon: Icons.crop_free_rounded,
          mode: EraserMode.area,
          isDark: isDark,
        ),

        _divider(isDark),

        // Erase Highlighter Only Toggle
        Tooltip(
          message: 'Erase Highlighter Only',
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => state.setEraseHighlighterOnly(!state.eraseHighlighterOnly),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: state.eraseHighlighterOnly
                    ? Colors.amber.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: state.eraseHighlighterOnly ? Colors.amber : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GoodNotesToolIcon(
                    tool: CanvasTool.highlighter,
                    size: 16,
                    color: state.eraseHighlighterOnly ? Colors.amber[700]! : textSecondary,
                    isSelected: state.eraseHighlighterOnly,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Highlighter Only',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: state.eraseHighlighterOnly ? Colors.amber[700] : textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        _divider(isDark),

        // Eraser Size label
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lens_blur_rounded, size: 14, color: textSecondary),
            const SizedBox(width: 4),
            Text(
              'Size:',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),

        // 3 Thickness presets for eraser
        for (int i = 0; i < 3; i++) _buildThicknessPill(i, isDark, isEraser: true),

        _divider(isDark),

        // Clear Page
        Tooltip(
          message: 'Clear entire page',
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onClearPage,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.delete_sweep_outlined, size: 16, color: Colors.redAccent),
                  const SizedBox(width: 4),
                  Text(
                    'Clear Page',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Lasso Secondary Toolbar ────────────────────────────────────────────────
  Widget _buildLassoSecondaryRow(BuildContext context, bool isDark) {
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final activeFiltersCount = [
      state.lassoIncludeHandwriting,
      state.lassoIncludeImages,
      state.lassoIncludeShapes,
      state.lassoIncludeArrows,
      state.lassoIncludeTextBox,
      state.lassoIncludeEquations,
      state.lassoIncludeTape,
      state.lassoIncludeStickyNotes,
    ].where((e) => e).length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mode: Freehand
        _lassoModeBtn(
          label: 'Freehand',
          icon: Icons.gesture_rounded,
          mode: LassoSelectionMode.freehand,
          isDark: isDark,
        ),
        const SizedBox(width: 4),

        // Mode: Rectangular
        _lassoModeBtn(
          label: 'Rectangular',
          icon: Icons.crop_square_rounded,
          mode: LassoSelectionMode.rectangular,
          isDark: isDark,
        ),

        _divider(isDark),

        // Includes / Filter settings popover button
        Tooltip(
          message: 'Lasso Includes & Settings (8 Categories)',
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onOpenLassoOptions,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF293145) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF3B4561) : const Color(0xFFCBD5E1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 15,
                    color: activeFiltersCount == 8 ? AppColors.primary : textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Includes ($activeFiltersCount/8)',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: textSecondary),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _lassoModeBtn({
    required String label,
    required IconData icon,
    required LassoSelectionMode mode,
    required bool isDark,
  }) {
    final isSelected = state.lassoMode == mode;
    return GestureDetector(
      onTap: () => state.setLassoMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shapes Secondary Toolbar ────────────────────────────────────────────────
  Widget _buildShapesSecondaryRow(BuildContext context, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Shape selector pills
        _shapeIconBtn(CanvasTool.rectangle, isDark),
        _shapeIconBtn(CanvasTool.circle, isDark),
        _shapeIconBtn(CanvasTool.triangle, isDark),
        _shapeIconBtn(CanvasTool.line, isDark),
        _shapeIconBtn(CanvasTool.arrow, isDark),

        _divider(isDark),

        // 3 Thickness presets
        for (int i = 0; i < 3; i++) _buildThicknessPill(i, isDark),

        _divider(isDark),

        // Quick Colors
        _buildColorSwatchesRow(context, isDark),
      ],
    );
  }

  // ── Laser Pointer Secondary Toolbar ────────────────────────────────────────
  Widget _buildLaserSecondaryRow(BuildContext context, bool isDark) {
    const laserColors = <Map<String, dynamic>>[
      {'color': Color(0xFFEF4444), 'name': 'Crimson Red'},
      {'color': Color(0xFFF97316), 'name': 'Sunset Orange'},
      {'color': Color(0xFFEAB308), 'name': 'Amber Gold'},
      {'color': Color(0xFF22C55E), 'name': 'Emerald Green'},
      {'color': Color(0xFF06B6D4), 'name': 'Cyan Glow'},
      {'color': Color(0xFF3B82F6), 'name': 'Electric Blue'},
      {'color': Color(0xFFA855F7), 'name': 'Neon Purple'},
      {'color': Color(0xFFEC4899), 'name': 'Vibrant Pink'},
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mode buttons with icons & tooltips
        Tooltip(
          message: 'Trail Mode: Drawing leaves a fading glowing beam',
          child: _laserModeBtn(label: 'Trail', mode: 'trail', isDark: isDark, icon: Icons.gesture_rounded),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: 'Dot Mode: Clean glowing laser pointer without trail',
          child: _laserModeBtn(label: 'Dot', mode: 'dot', isDark: isDark, icon: Icons.circle),
        ),

        _divider(isDark),

        // Color palette with 8 GoodNotes colors
        ...laserColors.map((item) {
          final c = item['color'] as Color;
          final name = item['name'] as String;
          final isSelected = state.laserColor.toARGB32() == c.toARGB32();
          final ringColor = isDark ? Colors.white : const Color(0xFF0F172A);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: Tooltip(
              message: name,
              child: GestureDetector(
                onTap: () => state.setLaserColor(c),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: isSelected ? 24 : 20,
                    height: isSelected ? 24 : 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? ringColor : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: isSelected ? 14 : 12,
                        height: isSelected ? 14 : 12,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: c.withValues(alpha: isSelected ? 0.65 : 0.25),
                              blurRadius: isSelected ? 8 : 2,
                              spreadRadius: isSelected ? 1 : 0,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTapeSecondaryRow(BuildContext context, bool isDark) {
    const tapeColors = [
      Color(0xFFFDE047), // Yellow (Classic GoodNotes tape)
      Color(0xFF86EFAC), // Mint Green
      Color(0xFF93C5FD), // Sky Blue
      Color(0xFFF472B6), // Coral Pink
      Color(0xFFC084FC), // Lavender
    ];

    const tapeHeights = [
      {'label': 'S', 'height': 20.0, 'tooltip': 'Thin tape (20pt)'},
      {'label': 'M', 'height': 28.0, 'tooltip': 'Standard tape (28pt)'},
      {'label': 'L', 'height': 38.0, 'tooltip': 'Wide tape (38pt)'},
    ];

    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in tapeHeights)
          Tooltip(
            message: item['tooltip'] as String,
            child: GestureDetector(
              onTap: () => state.setTapeHeight(item['height'] as double),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 32,
                height: 30,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: state.tapeHeight == item['height']
                      ? (isDark ? const Color(0xFF2E3850) : const Color(0xFFE2E8F0))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                  border: state.tapeHeight == item['height']
                      ? Border.all(color: isDark ? const Color(0xFF455478) : const Color(0xFFCBD5E1), width: 1.2)
                      : null,
                ),
                child: Center(
                  child: Text(
                    item['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: state.tapeHeight == item['height']
                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                          : textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        _divider(isDark),
        for (final col in tapeColors)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => state.setTapeColor(col),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: col,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: state.tapeColor == col
                        ? (isDark ? Colors.white : Colors.black87)
                        : Colors.black12,
                    width: state.tapeColor == col ? 2.5 : 1,
                  ),
                  boxShadow: state.tapeColor == col
                      ? [
                          BoxShadow(
                            color: col.withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
              ),
            ),
          ),
        _divider(isDark),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.visibility_off_outlined, size: 15, color: textSecondary),
              const SizedBox(width: 4),
              Text(
                'Drag over text • Tap to reveal',
                style: TextStyle(fontSize: 11.5, color: textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextSecondaryRow(BuildContext context, bool isDark) {
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Text tool mode badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.title_rounded, size: 16, color: Color(0xFF6366F1)),
              SizedBox(width: 4),
              Text(
                'Text Box',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6366F1),
                ),
              ),
            ],
          ),
        ),
        _divider(isDark),

        // Text ink color swatches
        _buildColorSwatchesRow(context, isDark),
        _divider(isDark),

        // Hint
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app_outlined, size: 15, color: textSecondary),
              const SizedBox(width: 4),
              Text(
                'Tap to write • Double-tap to edit • Drag handles to resize',
                style: TextStyle(fontSize: 11.5, color: textSecondary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultSecondaryRow(BuildContext context, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 3; i++) _buildThicknessPill(i, isDark),
        _divider(isDark),
        _buildColorSwatchesRow(context, isDark),
      ],
    );
  }

  // ── Thickness Line Pill (Thin, Medium, Thick) ───────────────────────────────
  Widget _buildThicknessPill(int index, bool isDark, {bool isHighlighter = false, bool isEraser = false}) {
    final isSelected = isEraser ? state.selectedEraserPresetIndex == index : state.selectedPresetIndex == index;
    final widthList = isEraser ? state.eraserWidthPresets : (isHighlighter ? state.highlighterWidthPresets : state.penWidthPresets);
    final w = widthList[index];

    // Visual line height representing the thickness
    final lineHeight = isEraser 
        ? (index == 0 ? 8.0 : (index == 1 ? 14.0 : 20.0))
        : (isHighlighter ? (index == 0 ? 6.0 : (index == 1 ? 10.0 : 16.0)) : (index == 0 ? 1.5 : (index == 1 ? 3.0 : 5.5)));

    return Tooltip(
      message: '${w.toStringAsFixed(1)} pt',
      child: GestureDetector(
        onTap: () => isEraser ? state.selectEraserWidthPreset(index) : state.selectWidthPreset(index),
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 38,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2.5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2E3850) : const Color(0xFFE2E8F0))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: isDark ? const Color(0xFF455478) : const Color(0xFFCBD5E1), width: 1.2)
              : null,
        ),
        child: Center(
          child: Container(
            width: isEraser ? lineHeight : 20, // Circular for eraser, line for pen
            height: lineHeight,
            decoration: BoxDecoration(
              color: isEraser ? (isDark ? Colors.white54 : Colors.black54) : (isDark ? Colors.white70 : Colors.black87),
              border: isEraser ? Border.all(color: isDark ? Colors.white70 : Colors.black87, width: 2) : null,
              borderRadius: BorderRadius.circular(lineHeight / 2),
            ),
          ),
        ),
      ),
    ),
  );
}

  // ── Color Swatches Row (Active Dot + Swatches + Color Picker trigger) ───────
  Widget _buildColorSwatchesRow(BuildContext context, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Swatches from state.quickPalette
        for (final color in state.quickPalette)
          GestureDetector(
            onTap: () => state.setColor(color),
            child: Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: state.strokeColor.toARGB32() == color.toARGB32()
                      ? (isDark ? Colors.white : AppColors.primary)
                      : (isDark ? Colors.white24 : Colors.black12),
                  width: state.strokeColor.toARGB32() == color.toARGB32() ? 2.5 : 1.0,
                ),
                boxShadow: state.strokeColor.toARGB32() == color.toARGB32()
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              child: state.strokeColor.toARGB32() == color.toARGB32()
                  ? const Center(
                      child: Icon(Icons.check_rounded, size: 12, color: Colors.white),
                    )
                  : null,
            ),
          ),

        const SizedBox(width: 4),

        // Full Color Picker wheel trigger
        GestureDetector(
          onTap: () => CanvasColorPicker.showFullPicker(
            context: context,
            currentColor: state.strokeColor,
            onColorChanged: (c) => state.setColor(c),
            isDark: isDark,
          ),
          child: Container(
            width: 24,
            height: 24,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [
                  Colors.red,
                  Colors.amber,
                  Colors.green,
                  Colors.cyan,
                  Colors.blue,
                  Colors.purple,
                  Colors.red,
                ],
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: state.strokeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniToolIcon({
    IconData? icon,
    CanvasTool? tool,
    required String tip,
    required bool isActive,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final iconColor = isActive
        ? AppColors.primary
        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));

    return Tooltip(
      message: tip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? AppColors.primary.withValues(alpha: 0.2) : const Color(0xFFEEF2FF))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: tool != null
                ? GoodNotesToolIcon(
                    tool: tool,
                    size: 18,
                    color: iconColor,
                    isSelected: isActive,
                  )
                : Icon(
                    icon ?? Icons.edit_rounded,
                    size: 18,
                    color: iconColor,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _eraserModeBtn({
    required String label,
    required IconData icon,
    required EraserMode mode,
    required bool isDark,
  }) {
    final isSelected = state.eraserMode == mode;
    return GestureDetector(
      onTap: () => state.setEraserMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shapeIconBtn(CanvasTool tool, bool isDark) {
    final isSelected = state.currentTool == tool;
    final iconColor = isSelected ? AppColors.primary : (isDark ? Colors.white60 : Colors.black54);

    // Map individual shapes to Material icons for sub-tool selection
    // (CanvasTool.rectangle in GoodNotesToolIcon shows composite shapes icon)
    const shapeIconMap = <CanvasTool, IconData>{
      CanvasTool.rectangle: Icons.crop_square_rounded,
      CanvasTool.circle: Icons.circle_outlined,
      CanvasTool.triangle: Icons.change_history_rounded,
      CanvasTool.line: Icons.show_chart_rounded,
      CanvasTool.arrow: Icons.arrow_right_alt_rounded,
    };

    return GestureDetector(
      onTap: () => state.setTool(tool),
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(
            shapeIconMap[tool] ?? Icons.crop_square_rounded,
            size: 18,
            color: iconColor,
          ),
        ),
      ),
    );
  }

  Widget _laserModeBtn({required String label, required String mode, required bool isDark, IconData? icon}) {
    final isSelected = state.laserMode == mode;
    return GestureDetector(
      onTap: () => state.setLaserMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: isSelected ? AppColors.primary : (isDark ? Colors.white70 : Colors.black54)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: isDark ? const Color(0xFF2C344A) : const Color(0xFFE2E8F0),
    );
  }
}
