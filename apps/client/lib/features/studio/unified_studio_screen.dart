import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_workspace_client/core/theme/app_theme.dart';
import 'package:ai_workspace_client/state/app_state.dart';
import 'package:ai_workspace_client/features/canvas/canvas_screen.dart';
import 'package:ai_workspace_client/features/chat/chat_screen.dart';

class UnifiedStudioScreen extends StatefulWidget {
  final AppState state;

  const UnifiedStudioScreen({super.key, required this.state});

  @override
  State<UnifiedStudioScreen> createState() => _UnifiedStudioScreenState();
}

class _UnifiedStudioScreenState extends State<UnifiedStudioScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _dividerAnim;

  @override
  void initState() {
    super.initState();
    _dividerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _dividerAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark     = widget.state.isDarkMode;
    final surfaceColor = isDark ? AppColors.darkSurface     : AppColors.lightSurface;
    final borderColor  = isDark ? AppColors.darkBorder      : AppColors.lightBorder;
    final textMuted    = isDark ? AppColors.darkTextMuted   : AppColors.lightTextMuted;
    final mode         = widget.state.viewMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Column(
        children: [
          // ── Studio Top Header (Hidden in canvasOnly mode to avoid duplicate header & maximize drawing space) ──
          if (mode != WorkspaceViewMode.canvasOnly)
            Container(
              height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                // Back to NoteFlow Dashboard button
                InkWell(
                  onTap: () => widget.state.setNavIndex(0),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_back_rounded,
                          size: 14,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Dashboard',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Toggle Sidebar button (quick access to sidebar if needed)
                Tooltip(
                  message: widget.state.isNotebookSidebarVisible ? 'Hide Sidebar' : 'Show Sidebar',
                  child: InkWell(
                    onTap: () => widget.state.toggleNotebookSidebar(),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: widget.state.isNotebookSidebarVisible
                            ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                            : (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: widget.state.isNotebookSidebarVisible ? AppColors.primary : borderColor,
                        ),
                      ),
                      child: Icon(
                        widget.state.isNotebookSidebarVisible
                            ? Icons.view_sidebar_rounded
                            : Icons.view_sidebar_outlined,
                        size: 15,
                        color: widget.state.isNotebookSidebarVisible
                            ? AppColors.primary
                            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Active Workspace badge
                if (widget.state.currentWorkspace != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2638) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2E3D59) : const Color(0xFFBFDBFE),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.workspaces_filled, size: 13, color: Color(0xFF2563EB)),
                        const SizedBox(width: 5),
                        Text(
                          widget.state.currentWorkspace!.name,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded, size: 16, color: textMuted),
                  const SizedBox(width: 6),
                ],

                // Active Notebook badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.menu_book_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        widget.state.currentCanvasDoc?.name ?? 'Notebook',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // ── Right Actions ─────────────────────────────────────────
                // AI Chat toggle button
                Tooltip(
                  message: widget.state.viewMode == WorkspaceViewMode.canvasOnly
                      ? 'Open AI Chat'
                      : 'Close AI Chat',
                  child: InkWell(
                    onTap: () {
                      if (widget.state.viewMode == WorkspaceViewMode.canvasOnly) {
                        widget.state.setViewMode(WorkspaceViewMode.split);
                      } else {
                        widget.state.setViewMode(WorkspaceViewMode.canvasOnly);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.state.viewMode != WorkspaceViewMode.canvasOnly
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: widget.state.viewMode != WorkspaceViewMode.canvasOnly
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : borderColor,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 13,
                            color: widget.state.viewMode != WorkspaceViewMode.canvasOnly
                                ? AppColors.primary
                                : textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.state.viewMode != WorkspaceViewMode.canvasOnly
                                ? 'Close Chat'
                                : 'AI Assistant',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: widget.state.viewMode != WorkspaceViewMode.canvasOnly
                                  ? AppColors.primary
                                  : textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Auto-canvas toggle indicator
                Tooltip(
                  message: widget.state.autoWriteToCanvas
                      ? 'AI chat answers are written directly onto the infinite canvas'
                      : 'Auto-write to canvas is disabled',
                  child: InkWell(
                    onTap: widget.state.toggleAutoWriteToCanvas,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.state.autoWriteToCanvas
                            ? AppColors.accentGlow
                            : (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: widget.state.autoWriteToCanvas
                              ? AppColors.accent.withValues(alpha: 0.35)
                              : borderColor,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 12,
                            color: widget.state.autoWriteToCanvas ? AppColors.accent : textMuted,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            widget.state.autoWriteToCanvas ? 'AI→Canvas: ON' : 'AI→Canvas: OFF',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: widget.state.autoWriteToCanvas ? AppColors.accent : textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Main Workspace Area ───────────────────────────────────────────
          Expanded(
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;

                  // Canvas-only mode (default when opening notebook): pure canvas, NO chat section!
                  if (totalWidth < 700 || mode == WorkspaceViewMode.canvasOnly) {
                    return CanvasScreen(state: widget.state);
                  }

                  if (mode == WorkspaceViewMode.chatOnly) {
                    return ChatScreen(state: widget.state, autoPlaceOnCanvas: false);
                  }

                  // Split view (only when user explicitly toggled AI Assistant)
                  final canvasW = totalWidth * widget.state.splitRatio;
                  final chatW   = totalWidth - canvasW - 6;

                  return Row(
                    children: [
                      SizedBox(width: canvasW, child: CanvasScreen(state: widget.state)),

                      // Draggable divider
                      MouseRegion(
                        cursor: SystemMouseCursors.resizeColumn,
                        onEnter: (_) => _dividerAnim.forward(),
                        onExit:  (_) => _dividerAnim.reverse(),
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragUpdate: (details) {
                            final newRatio = (canvasW + details.delta.dx) / totalWidth;
                            widget.state.setSplitRatio(newRatio);
                          },
                          child: AnimatedBuilder(
                            animation: _dividerAnim,
                            builder: (_, child) => Container(
                              width: 6,
                              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                              child: Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: _dividerAnim.value > 0.5 ? 4 : 3,
                                  height: _dividerAnim.value > 0.5 ? 48 : 32,
                                  decoration: BoxDecoration(
                                    color: _dividerAnim.value > 0.5
                                        ? AppColors.primary.withValues(alpha: 0.6)
                                        : borderColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Chat panel with quick close button
                      SizedBox(
                        width: chatW,
                        child: Stack(
                          children: [
                            ChatScreen(state: widget.state, autoPlaceOnCanvas: true),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Tooltip(
                                message: 'Close Chat',
                                child: InkWell(
                                  onTap: () => widget.state.setViewMode(WorkspaceViewMode.canvasOnly),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E2430) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Icon(Icons.close_rounded, size: 16, color: textMuted),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

