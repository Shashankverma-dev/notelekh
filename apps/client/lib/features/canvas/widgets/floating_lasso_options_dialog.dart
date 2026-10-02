import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_workspace_client/core/theme/app_theme.dart';
import 'package:ai_workspace_client/features/canvas/canvas_state.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:ai_workspace_client/features/canvas/widgets/goodnotes_tool_icons.dart';

/// Goodnotes-style Floating Lasso Options Popover Dialog.
/// Allows selecting between "Freehand" and "Rectangular" selection modes,
/// and toggling inclusion filters for 8 content types:
/// Handwriting, Images, Shapes, Arrows, Text Box, Equations, Tape, and Sticky Notes.
class FloatingLassoOptionsDialog extends StatefulWidget {
  final CanvasDrawingState drawingState;
  final bool isDark;
  final VoidCallback? onClose;

  const FloatingLassoOptionsDialog({
    super.key,
    required this.drawingState,
    this.isDark = true,
    this.onClose,
  });

  @override
  State<FloatingLassoOptionsDialog> createState() => _FloatingLassoOptionsDialogState();
}

class _FloatingLassoOptionsDialogState extends State<FloatingLassoOptionsDialog> {
  @override
  Widget build(BuildContext context) {
    final ds = widget.drawingState;
    final isDark = widget.isDark;

    final bg = isDark ? const Color(0xFF1B1F2D) : Colors.white;
    final cardBg = isDark ? const Color(0xFF242A3C) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF2E364D) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final activeFiltersCount = [
      ds.lassoIncludeHandwriting,
      ds.lassoIncludeImages,
      ds.lassoIncludeShapes,
      ds.lassoIncludeArrows,
      ds.lassoIncludeTextBox,
      ds.lassoIncludeEquations,
      ds.lassoIncludeTape,
      ds.lassoIncludeStickyNotes,
    ].where((e) => e).length;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 360,
        constraints: const BoxConstraints(maxHeight: 620),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header Title & Close ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: GoodNotesToolIcon(
                        tool: CanvasTool.lasso,
                        size: 18,
                        color: AppColors.primary,
                        isSelected: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Lasso Tool',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: textSecondary),
                    splashRadius: 18,
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 1),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Selection Method Segmented Tabs ─────────────────────
                    Text(
                      'SELECTION MODE',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildModeTab(
                              title: 'Freehand',
                              icon: Icons.gesture_rounded,
                              isSelected: ds.lassoMode == LassoSelectionMode.freehand,
                              onTap: () {
                                setState(() {
                                  ds.setLassoMode(LassoSelectionMode.freehand);
                                });
                              },
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _buildModeTab(
                              title: 'Rectangular',
                              icon: Icons.crop_square_rounded,
                              isSelected: ds.lassoMode == LassoSelectionMode.rectangular,
                              onTap: () {
                                setState(() {
                                  ds.setLassoMode(LassoSelectionMode.rectangular);
                                });
                              },
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Include Section Header with Toggle All ──────────────
                    Row(
                      children: [
                        Text(
                          'INCLUDE IN SELECTION',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            setState(() {
                              final allActive = activeFiltersCount == 8;
                              ds.setAllLassoFilters(!allActive);
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Text(
                              activeFiltersCount == 8 ? 'Deselect All' : 'Select All',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ── 8 Content Type Toggles in Card ──────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          _buildFilterRow(
                            label: 'Handwriting',
                            subtitle: 'Pen, pencil, and highlighter strokes',
                            icon: Icons.draw_rounded,
                            value: ds.lassoIncludeHandwriting,
                            onChanged: (v) => setState(() => ds.setLassoIncludeHandwriting(v)),
                            isDark: isDark,
                          ),
                          _divider(borderColor),
                          _buildFilterRow(
                            label: 'Images',
                            subtitle: 'Photos, imported graphics, and media',
                            icon: Icons.image_outlined,
                            value: ds.lassoIncludeImages,
                            onChanged: (v) => setState(() => ds.setLassoIncludeImages(v)),
                            isDark: isDark,
                          ),
                          _divider(borderColor),
                          _buildFilterRow(
                            label: 'Shapes',
                            subtitle: 'Rectangles, circles, triangles, stars',
                            icon: Icons.category_outlined,
                            value: ds.lassoIncludeShapes,
                            onChanged: (v) => setState(() => ds.setLassoIncludeShapes(v)),
                            isDark: isDark,
                          ),
                          _divider(borderColor),
                          _buildFilterRow(
                            label: 'Arrows',
                            subtitle: 'Connecting lines, arrows, and vectors',
                            icon: Icons.arrow_forward_rounded,
                            value: ds.lassoIncludeArrows,
                            onChanged: (v) => setState(() => ds.setLassoIncludeArrows(v)),
                            isDark: isDark,
                          ),
                          _divider(borderColor),
                          _buildFilterRow(
                            label: 'Text Box',
                            subtitle: 'Typed text and paragraphs',
                            icon: Icons.text_fields_rounded,
                            value: ds.lassoIncludeTextBox,
                            onChanged: (v) => setState(() => ds.setLassoIncludeTextBox(v)),
                            isDark: isDark,
                          ),
                          _divider(borderColor),
                          _buildFilterRow(
                            label: 'Equations',
                            subtitle: 'Math formulas and LaTeX equations',
                            icon: Icons.functions_rounded,
                            value: ds.lassoIncludeEquations,
                            onChanged: (v) => setState(() => ds.setLassoIncludeEquations(v)),
                            isDark: isDark,
                          ),
                          _divider(borderColor),
                          _buildFilterRow(
                            label: 'Tape',
                            subtitle: 'Study tape and masking strips',
                            icon: Icons.view_headline_rounded,
                            value: ds.lassoIncludeTape,
                            onChanged: (v) => setState(() => ds.setLassoIncludeTape(v)),
                            isDark: isDark,
                          ),
                          _divider(borderColor),
                          _buildFilterRow(
                            label: 'Sticky Notes',
                            subtitle: 'AI cards, notes, and memos',
                            icon: Icons.sticky_note_2_outlined,
                            value: ds.lassoIncludeStickyNotes,
                            onChanged: (v) => setState(() => ds.setLassoIncludeStickyNotes(v)),
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2E3854) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected ? AppColors.primary : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : AppColors.primary)
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: value
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : (isDark ? const Color(0xFF1E2333) : const Color(0xFFEDEFEF)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 17,
                color: value
                    ? AppColors.primary
                    : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch.adaptive(
              value: value,
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.35),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(Color borderColor) {
    return Divider(height: 1, thickness: 1, color: borderColor);
  }
}
