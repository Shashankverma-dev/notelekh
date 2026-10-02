import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:ai_workspace_client/features/canvas/widgets/goodnotes_tool_icons.dart';

/// Goodnotes-style primary top bar.
/// Houses Undo/Redo pill, document title, primary tool icons, page counter, and export actions.
class CanvasToolbar extends StatelessWidget {
  final CanvasTool currentTool;
  final ValueChanged<CanvasTool> onToolSelected;
  final VoidCallback onOpenToolSettings;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final int currentPageIndex;
  final int totalPages;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onAddPage;
  final VoidCallback onShareExport;
  final VoidCallback onOpenMoreMenu;
  final VoidCallback? onToggleSidebar;
  final VoidCallback? onOpenSearch;
  final VoidCallback? onOpenAiAssistant;
  final VoidCallback? onBack;
  final String documentTitle;
  final bool isDark;

  const CanvasToolbar({
    super.key,
    required this.currentTool,
    required this.onToolSelected,
    required this.onOpenToolSettings,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.currentPageIndex,
    required this.totalPages,
    required this.onPageChanged,
    required this.onAddPage,
    required this.onShareExport,
    required this.onOpenMoreMenu,
    this.onToggleSidebar,
    this.onOpenSearch,
    this.onOpenAiAssistant,
    this.onBack,
    this.documentTitle = 'Preparing',
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF161A28) : const Color(0xFF38659B); // Goodnotes navy blue bar
    final border = isDark ? const Color(0xFF242B40) : const Color(0xFF2E5482);
    final iconColor = Colors.white.withValues(alpha: 0.90);
    final activeToolBg = isDark ? const Color(0xFF2C4A75) : const Color(0xFFD6E4F0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 680;
        final isCompact = constraints.maxWidth < 950;
        final toolIconSize = isCompact ? 22.0 : 25.0;
        final toolPadding = isCompact ? 5.0 : 7.0;
        final toolMargin = isCompact ? 1.5 : 2.0;

        if (isMobile) {
          // ── Mobile Responsive Layout (Two Tiers) ───────────────────────────
          // Tier 1: Document & Navigation header (42px)
          // Tier 2: Dedicated full-width horizontal tools strip (44px)
          return Container(
            decoration: BoxDecoration(
              color: bg,
              border: Border(bottom: BorderSide(color: border, width: 1.0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Top Mobile Bar: Navigation, Page Counter, Undo/Redo & Actions
                Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      if (onBack != null)
                        _iconBtn(
                          icon: Icons.arrow_back_ios_new_rounded,
                          tip: 'Dashboard',
                          onTap: onBack!,
                          color: iconColor,
                          padding: const EdgeInsets.all(6),
                        ),
                      _iconBtn(
                        icon: Icons.menu_book_rounded,
                        tip: 'Notebooks / Pages',
                        onTap: onToggleSidebar ?? () {},
                        color: iconColor,
                        padding: const EdgeInsets.all(6),
                      ),
                      _iconBtn(
                        icon: Icons.auto_awesome_rounded,
                        tip: 'AI Assistant',
                        onTap: onOpenAiAssistant ?? () {},
                        color: const Color(0xFFFDE047),
                        padding: const EdgeInsets.all(6),
                      ),
                      const SizedBox(width: 2),

                      // Document Title (compact truncated)
                      Expanded(
                        child: InkWell(
                          onTap: onOpenMoreMenu,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                            child: Text(
                              documentTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Floating Undo / Redo Capsule
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _capsuleIconBtn(
                              icon: Icons.undo_rounded,
                              tip: 'Undo',
                              enabled: canUndo,
                              onTap: onUndo,
                              hPad: 5,
                            ),
                            _capsuleIconBtn(
                              icon: Icons.redo_rounded,
                              tip: 'Redo',
                              enabled: canRedo,
                              onTap: onRedo,
                              hPad: 5,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 4),

                      // Page counter pill with quick navigation
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (totalPages > 1)
                              InkWell(
                                onTap: currentPageIndex > 0 ? () => onPageChanged(currentPageIndex - 1) : null,
                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                                  child: Icon(
                                    Icons.chevron_left_rounded,
                                    size: 14,
                                    color: currentPageIndex > 0 ? Colors.white : Colors.white24,
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                              child: Text(
                                '${currentPageIndex + 1}/$totalPages',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (totalPages > 1)
                              InkWell(
                                onTap: currentPageIndex < totalPages - 1 ? () => onPageChanged(currentPageIndex + 1) : null,
                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 14,
                                    color: currentPageIndex < totalPages - 1 ? Colors.white : Colors.white24,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 2),

                      _iconBtn(
                        icon: Icons.add_rounded,
                        tip: 'Add Page',
                        onTap: onAddPage,
                        color: iconColor,
                        padding: const EdgeInsets.all(5),
                      ),
                      _iconBtn(
                        icon: Icons.more_horiz_rounded,
                        tip: 'Options',
                        onTap: onOpenMoreMenu,
                        color: iconColor,
                        padding: const EdgeInsets.all(5),
                      ),
                    ],
                  ),
                ),

                // ── Bottom Mobile Bar: Dedicated Horizontal Tool Strip ────────
                Container(
                  height: 44,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF111420) : const Color(0xFF2C517D),
                    border: Border(top: BorderSide(color: border.withValues(alpha: 0.6), width: 0.8)),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      children: _buildToolButtonsList(activeToolBg, 22.0, 5.0, 1.5, isDark),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // ── Desktop / Tablet Single-Row Layout (>= 640px) ────────────────────
        return Container(
          height: 52,
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 4 : 10),
          decoration: BoxDecoration(
            color: bg,
            border: Border(bottom: BorderSide(color: border, width: 1.0)),
          ),
          child: Row(
            children: [
              // ── Left: Document Actions ─────────────────────────────────────
              if (onBack != null)
                _iconBtn(
                  icon: Icons.arrow_back_ios_new_rounded,
                  tip: 'Back to Dashboard',
                  onTap: onBack!,
                  color: iconColor,
                ),
              _iconBtn(
                icon: Icons.menu_book_rounded,
                tip: 'Notebooks / Pages',
                onTap: onToggleSidebar ?? () {},
                color: iconColor,
              ),
              _iconBtn(
                icon: Icons.search_rounded,
                tip: 'Search in Document',
                onTap: onOpenSearch ?? () {},
                color: iconColor,
              ),
              _iconBtn(
                icon: Icons.auto_awesome_rounded,
                tip: 'AI Assistant',
                onTap: onOpenAiAssistant ?? () {},
                color: const Color(0xFFFDE047),
              ),

              const SizedBox(width: 4),

              // Document Title with dropdown chevron
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onOpenMoreMenu,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isCompact ? 90 : 140),
                        child: Text(
                          documentTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.white70),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // ── Floating Undo / Redo Capsule [ ↩  ↪ ] ─────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _capsuleIconBtn(
                      icon: Icons.undo_rounded,
                      tip: 'Undo (Ctrl+Z)',
                      enabled: canUndo,
                      onTap: onUndo,
                    ),
                    _capsuleIconBtn(
                      icon: Icons.redo_rounded,
                      tip: 'Redo (Ctrl+Y)',
                      enabled: canRedo,
                      onTap: onRedo,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),

              // ── Center: Primary Tool Icons Row (Matching Reference Screenshot) ───
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _buildToolButtonsList(activeToolBg, toolIconSize, toolPadding, toolMargin, isDark),
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // ── Right: Add Page, Share / Export, More ───────────────────────
              // Page indicator with quick prev/next navigation
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (totalPages > 1)
                      InkWell(
                        onTap: currentPageIndex > 0 ? () => onPageChanged(currentPageIndex - 1) : null,
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Icon(
                            Icons.chevron_left_rounded,
                            size: 15,
                            color: currentPageIndex > 0 ? Colors.white : Colors.white24,
                          ),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: totalPages > 1 ? 4 : 8,
                        vertical: 4,
                      ),
                      child: Text(
                        '${currentPageIndex + 1}/$totalPages',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (totalPages > 1)
                      InkWell(
                        onTap: currentPageIndex < totalPages - 1 ? () => onPageChanged(currentPageIndex + 1) : null,
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 15,
                            color: currentPageIndex < totalPages - 1 ? Colors.white : Colors.white24,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 4),

              _iconBtn(
                icon: Icons.note_add_outlined,
                tip: 'Add Page',
                onTap: onAddPage,
                color: iconColor,
              ),
              _iconBtn(
                icon: Icons.ios_share_rounded,
                tip: 'Share & Export',
                onTap: onShareExport,
                color: iconColor,
              ),
              _iconBtn(
                icon: Icons.more_horiz_rounded,
                tip: 'Document Options',
                onTap: onOpenMoreMenu,
                color: iconColor,
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildToolButtonsList(Color activeToolBg, double toolIconSize, double toolPadding, double toolMargin, bool isDark) {
    return [
      // 0. Hand Tool (Pan / Read-Only Navigation Mode)
      _primaryToolBtn(CanvasTool.hand, 'Hand Tool (Pan / Travel / Read-Only) [H]', activeToolBg, toolIconSize, toolPadding, toolMargin, isDark),
      _verticalDivider(),
      // 1. Lasso Tool (Dashed loop with pointer cursor)
      _primaryToolBtn(CanvasTool.lasso, 'Lasso Selection [L]', activeToolBg, toolIconSize, toolPadding, toolMargin, isDark),
      // 2. Pen Tool (Pen with cursive flourish)
      _primaryToolBtn(CanvasTool.pen, 'Pen Tool (Fountain / Ball / Brush) [P]', activeToolBg, toolIconSize, toolPadding, toolMargin, isDark),
      // 2b. Pencil Tool (Realistic GoodNotes Graphite Pencil)
      _primaryToolBtn(CanvasTool.pencil, 'Pencil Tool (Realistic Graphite Pencil)', activeToolBg, toolIconSize, toolPadding, toolMargin, isDark),
      // 2c. Highlighter Tool
      _primaryToolBtn(CanvasTool.highlighter, 'Highlighter', activeToolBg, toolIconSize, toolPadding, toolMargin, isDark),
      // 3. Eraser Tool (Angled block eraser)
      _primaryToolBtn(CanvasTool.eraser, 'Eraser (Precision / Stroke / Area) [E]', activeToolBg, toolIconSize, toolPadding, toolMargin, isDark),
      // 4. Text Box ('T' Tile with 4 corner dots)
      _primaryToolBtn(CanvasTool.text, 'Text Box [T]', activeToolBg, toolIconSize, toolPadding, toolMargin, isDark),
      // 5. Elements & Stickers (Peeled Smiley Face Sticker)
      _primaryToolBtn(CanvasTool.elements, 'Elements & Stickers', activeToolBg, toolIconSize, toolPadding, toolMargin, isDark),
      // 6. Image / Media (Crescent Moon & Mountain Peaks)
      _primaryToolBtn(CanvasTool.image, 'Image & Media', activeToolBg, toolIconSize, toolPadding, toolMargin, isDark),
      // 7. Shapes Tool (4-part grid: △ ⤴ ○ ▢)
      _primaryToolBtn(CanvasTool.rectangle, 'Shapes Tool (Geometric Shapes) [S]', activeToolBg, toolIconSize, toolPadding, toolMargin, isDark),
      // 8. Sticky Note / Tape (Sheet with folded corner)
      _primaryToolBtn(CanvasTool.tape, 'Sticky Note / Study Tape', activeToolBg, toolIconSize, toolPadding, toolMargin, isDark),
      // 9. Laser Pointer (Capsule pointer with radiant starburst)
      _primaryToolBtn(CanvasTool.laser, 'Laser Pointer (Trail & Dot)', activeToolBg, toolIconSize, toolPadding, toolMargin, isDark),
    ];
  }

  Widget _verticalDivider() {
    return Container(
      width: 1.0,
      height: 24.0,
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      color: Colors.white.withValues(alpha: 0.22),
    );
  }

  Widget _primaryToolBtn(CanvasTool tool, String tooltip, Color activeBg, double iconSize, double hPad, double hMargin, bool isDark) {
    final isHand = tool == CanvasTool.hand;
    // Treat shapes group as active if tool is any shape
    final isSelected = currentTool == tool ||
        (tool == CanvasTool.rectangle &&
            (currentTool == CanvasTool.circle ||
                currentTool == CanvasTool.triangle ||
                currentTool == CanvasTool.line ||
                currentTool == CanvasTool.arrow));

    // When Hand tool is selected, render signature mint green background & green icon (matching Image 1)
    final effectiveActiveBg = isHand
        ? (isDark ? const Color(0xFF1E3A2F) : const Color(0xFFD6EADC))
        : activeBg;

    final iconColor = isSelected
        ? (isHand
            ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF1B6E39))
            : (isDark ? Colors.white : const Color(0xFF1E3A5F)))
        : Colors.white.withValues(alpha: 0.92);

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          if (isSelected && (tool == CanvasTool.pen || tool == CanvasTool.highlighter)) {
            onOpenToolSettings();
          } else if (isSelected && isHand) {
            onToolSelected(CanvasTool.pen);
          } else {
            onToolSelected(tool);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 38,
          height: 38,
          margin: EdgeInsets.symmetric(horizontal: hMargin),
          decoration: BoxDecoration(
            color: isSelected ? effectiveActiveBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: GoodNotesToolIcon(
              tool: tool,
              color: iconColor,
              size: iconSize,
              isSelected: isSelected,
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required String tip,
    required VoidCallback onTap,
    required Color color,
    double size = 19,
    EdgeInsets? padding,
  }) {
    return Tooltip(
      message: tip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(7),
          child: Icon(icon, size: size, color: color),
        ),
      ),
    );
  }

  Widget _capsuleIconBtn({
    required IconData icon,
    required String tip,
    required bool enabled,
    required VoidCallback onTap,
    double hPad = 7,
  }) {
    return Tooltip(
      message: tip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 5),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? Colors.white : Colors.white30,
          ),
        ),
      ),
    );
  }
}
