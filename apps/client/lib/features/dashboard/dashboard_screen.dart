import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:ai_workspace_client/core/theme/app_theme.dart';
import 'package:ai_workspace_client/core/models/canvas_models.dart';
import 'package:ai_workspace_client/features/canvas/create_document_dialog.dart';
import 'package:ai_workspace_client/state/app_state.dart';
import 'package:ai_workspace_client/features/dashboard/widgets/notebook_cover_editor_dialog.dart';
import 'package:ai_workspace_client/features/dashboard/widgets/notebook_cover_widget.dart';
import 'package:ai_workspace_client/features/dashboard/widgets/notification_center_dialog.dart';
import 'package:ai_workspace_client/core/services/workspace_export_service.dart';

class DashboardScreen extends StatefulWidget {
  final AppState state;

  const DashboardScreen({super.key, required this.state});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isGridView = true;
  String? _selectedNoteIdForTodo;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final state = widget.state;
        final isDark = state.isDarkMode;
        final bg = isDark ? AppColors.darkBg : const Color(0xFFF8F9FA);
        final textPrimary = isDark ? AppColors.darkTextPrimary : const Color(0xFF1E293B);
        final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B);
        final textMuted = isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8);
        final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0);

        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 640;

        return Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 28,
                isMobile ? 16 : 20,
                isMobile ? 16 : 28,
                isMobile ? 28 : 48,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top Search Bar & Header Bar ────────────────────────────────
                  _buildTopSearchBar(context, isDark, textPrimary, textSecondary, textMuted, borderColor, isMobile),
                  SizedBox(height: isMobile ? 20 : 32),

                  // ── Greeting Header ───────────────────────────────────────────
                  _buildGreetingHeader(state, isDark, textPrimary, textSecondary, textMuted, isMobile),
                  SizedBox(height: isMobile ? 18 : 24),

                  // ── Notebooks Carousel / Covers ───────────────────────────────
                  _buildNotebooksSection(context, state, isDark, textPrimary, textMuted),
                  SizedBox(height: isMobile ? 24 : 36),

                  // ── Bottom Section: Continue Writing ──────────────────────────
                  _buildContinueWritingSection(context, state, isDark, textPrimary, textSecondary, textMuted, borderColor),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Top Search Bar ─────────────────────────────────────────────────────────
  Widget _buildTopSearchBar(
    BuildContext context,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
    Color borderColor,
    bool isMobile,
  ) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: isMobile ? 42 : 46,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151923) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? const Color(0xFF252D3D) : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: isMobile ? 18 : 20, color: textMuted),
                SizedBox(width: isMobile ? 8 : 12),
                Expanded(
                  child: TextField(
                    onSubmitted: (q) {
                      if (q.trim().isNotEmpty) {
                        widget.state.performSearch(q.trim());
                        widget.state.setNavIndex(3);
                      }
                    },
                    style: GoogleFonts.inter(
                      fontSize: isMobile ? 12.5 : 13.5,
                      color: textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: isMobile ? 'Search notes, notebooks...' : 'Search notes, notebooks, tags...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: isMobile ? 12.5 : 13.5,
                        color: textMuted,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: isMobile ? 8 : 14),
        // Interactive Notifications Bell
        Tooltip(
          message: 'Notifications',
          child: InkWell(
            key: const ValueKey('notification_bell_button'),
            onTap: () => NotificationCenterDialog.show(context, widget.state),
            borderRadius: BorderRadius.circular(21),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: isMobile ? 38 : 42,
                  height: isMobile ? 38 : 42,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF151923) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF252D3D) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.state.unreadNotificationCount > 0
                        ? Icons.notifications_rounded
                        : Icons.notifications_none_rounded,
                    color: widget.state.unreadNotificationCount > 0
                        ? const Color(0xFF2563EB)
                        : (isDark ? Colors.white70 : const Color(0xFF475569)),
                    size: isMobile ? 18 : 20,
                  ),
                ),
                if (widget.state.unreadNotificationCount > 0)
                  Positioned(
                    top: isMobile ? 6 : 8,
                    right: isMobile ? 7 : 9,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF151923) : Colors.white,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(width: isMobile ? 8 : 10),
        // User Profile & Settings Avatar Button (Visible on mobile & desktop)
        Tooltip(
          message: 'Account & Settings',
          child: InkWell(
            key: const ValueKey('dashboard_profile_button'),
            onTap: () => _showMobileProfileSheet(
              context,
              widget.state,
              isDark,
              textPrimary,
              textSecondary,
              textMuted,
              borderColor,
            ),
            borderRadius: BorderRadius.circular(21),
            child: Container(
              width: isMobile ? 38 : 42,
              height: isMobile ? 38 : 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.35 : 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  widget.state.displayName.isNotEmpty
                      ? widget.state.displayName.substring(0, 1).toUpperCase()
                      : 'U',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: isMobile ? 15 : 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Mobile Profile Bottom Sheet ─────────────────────────────────────────────
  void _showMobileProfileSheet(
    BuildContext context,
    AppState state,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
    Color borderColor,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF131823) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // User Profile Row
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        state.displayName.isNotEmpty
                            ? state.displayName.substring(0, state.displayName.length >= 2 ? 2 : 1).toUpperCase()
                            : 'US',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.displayName.isNotEmpty ? state.displayName : 'Workspace User',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          state.userEmail,
                          style: GoogleFonts.inter(fontSize: 12.5, color: textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Storage info bar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A2234) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Account Storage',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
                        ),
                        Text(
                          '${state.formattedStorageUsed} used',
                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: state.storageProgress,
                        minHeight: 4,
                        backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Settings & Preferences Action
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2838) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.settings_rounded, color: Color(0xFF2563EB), size: 20),
                ),
                title: Text(
                  'Settings & Preferences',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                ),
                subtitle: Text(
                  'AI model, stylus sensitivity, appearance',
                  style: GoogleFonts.inter(fontSize: 11.5, color: textMuted),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () {
                  Navigator.pop(ctx);
                  state.setNavIndex(4);
                },
              ),
              const SizedBox(height: 4),
              // Theme Toggle Action
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2838) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                    size: 20,
                  ),
                ),
                title: Text(
                  isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                ),
                trailing: Switch(
                  value: isDark,
                  onChanged: (_) {
                    state.toggleTheme();
                  },
                  activeThumbColor: const Color(0xFF2563EB),
                ),
                onTap: () => state.toggleTheme(),
              ),
              const SizedBox(height: 6),
              Divider(height: 1, color: borderColor),
              const SizedBox(height: 6),
              // Sign Out Action
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 19),
                ),
                title: Text(
                  'Sign Out of Workspace',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFFEF4444)),
                ),
                subtitle: Text(
                  'Exit studio and return to landing page',
                  style: GoogleFonts.inter(fontSize: 11.5, color: textMuted),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await state.signOut();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Greeting Header ────────────────────────────────────────────────────────
  Widget _buildGreetingHeader(
    AppState state,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
    bool isMobile,
  ) {
    final now = DateTime.now();
    final hour = now.hour;
    final timeGreeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(now);
    final name = state.displayName.isNotEmpty ? state.displayName : 'there';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateStr,
          style: GoogleFonts.inter(
            fontSize: isMobile ? 12 : 13,
            fontWeight: FontWeight.w500,
            color: textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$timeGreeting, $name',
          style: GoogleFonts.inter(
            fontSize: isMobile ? 22 : 28,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Capture your ideas. Build knowledge. Make progress.',
          style: GoogleFonts.inter(
            fontSize: isMobile ? 13 : 14,
            fontWeight: FontWeight.w400,
            color: textSecondary,
          ),
        ),
      ],
    );
  }


  // ── Notebooks Carousel / Book Covers ───────────────────────────────────────
  Widget _buildNotebooksSection(BuildContext context, AppState state, bool isDark, Color textPrimary, Color textMuted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Notebooks',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 20, color: textMuted),
              ],
            ),
            Row(
              children: [
                InkWell(
                  onTap: () => state.setNavIndex(2),
                  child: Text(
                    'View all',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Grid toggle
                InkWell(
                  onTap: () => setState(() => _isGridView = true),
                  child: Icon(
                    Icons.grid_view_rounded,
                    size: 18,
                    color: _isGridView ? const Color(0xFF15803D) : textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => setState(() => _isGridView = false),
                  child: Icon(
                    Icons.format_list_bulleted_rounded,
                    size: 18,
                    color: !_isGridView ? const Color(0xFF15803D) : textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Book Covers Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              ...state.canvasDocs.map((doc) {
                return Padding(
                  padding: const EdgeInsets.only(right: 18),
                  child: _buildBookCover(
                    context: context,
                    state: state,
                    docId: doc.id,
                    title: doc.name,
                    noteCount: doc.pages.length,
                    coverColor: doc.coverColor,
                    illustration: Text(
                      doc.coverEmoji.isNotEmpty ? doc.coverEmoji : '📓',
                      style: const TextStyle(fontSize: 28),
                    ),
                    isDark: isDark,
                    onTap: () {
                      state.switchNotebook(doc.id);
                      state.setNavIndex(1);
                    },
                  ),
                );
              }),
              _buildNewNotebookCard(context, isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBookCover({
    required BuildContext context,
    required AppState state,
    required String docId,
    required String title,
    required int noteCount,
    required Color coverColor,
    required Widget illustration,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final pageLabel = noteCount == 1 ? '1 page' : '$noteCount pages';
    final doc = state.canvasDocs.firstWhere(
      (d) => d.id == docId,
      orElse: () => state.canvasDocs.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Real GoodNotes Journal Cover ──────────────────
        NotebookCoverWidget(
          title: title,
          pageCount: noteCount,
          docType: doc.docType,
          coverColor: doc.coverColor,
          coverEmoji: doc.coverEmoji,
          coverStyle: doc.coverStyle,
          coverStyleData: doc.coverStyleData,
          width: 144,
          height: 184,
          isDark: isDark,
          onTap: onTap,
          onEditCover: () => showNotebookCoverEditor(context, state, docId),
        ),
        const SizedBox(height: 10),

        // ── Title & Meta Info ─────────────────────────────
        SizedBox(
          width: 144,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 36,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      pageLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: PopupMenuButton<String>(
                        tooltip: 'Notebook options',
                        padding: EdgeInsets.zero,
                        iconSize: 16,
                        icon: Icon(
                          Icons.more_horiz_rounded,
                          size: 16,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: isDark ? const Color(0xFF1E2433) : Colors.white,
                        onSelected: (action) {
                          if (action == 'open') {
                            state.switchNotebook(docId);
                            state.setNavIndex(1);
                          } else if (action == 'edit_cover') {
                            showNotebookCoverEditor(context, state, docId);
                          } else if (action == 'rename') {
                            _showRenameNotebookDialog(context, state, docId, title);
                          } else if (action == 'export') {
                            final doc = state.canvasDocs.firstWhere((d) => d.id == docId);
                            _showExportNotebookDialog(context, doc);
                          } else if (action == 'delete') {
                            _showDeleteNotebookDialog(context, state, docId, title);
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'open',
                            child: Row(
                              children: [
                                const Icon(Icons.open_in_new_rounded, size: 16),
                                const SizedBox(width: 8),
                                Text('Open', style: GoogleFonts.inter(fontSize: 12.5)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'edit_cover',
                            child: Row(
                              children: [
                                const Icon(Icons.palette_outlined, size: 16, color: Color(0xFF15803D)),
                                const SizedBox(width: 8),
                                Text('Edit Cover', style: GoogleFonts.inter(fontSize: 12.5, color: Color(0xFF15803D))),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'rename',
                            child: Row(
                              children: [
                                const Icon(Icons.edit_outlined, size: 16),
                                const SizedBox(width: 8),
                                Text('Rename', style: GoogleFonts.inter(fontSize: 12.5)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'export',
                            child: Row(
                              children: [
                                const Icon(Icons.download_rounded, size: 16, color: Color(0xFF2563EB)),
                                const SizedBox(width: 8),
                                Text('Export', style: GoogleFonts.inter(fontSize: 12.5, color: Color(0xFF2563EB))),
                              ],
                            ),
                          ),
                          if (state.canvasDocs.length > 1)
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                                  const SizedBox(width: 8),
                                  Text('Delete', style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.danger)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNewNotebookCard(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── New Notebook Placeholder Cover ───────────────
        InkWell(
          onTap: () => _showCreateNotebookDialog(context),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(5),
            bottomLeft: Radius.circular(5),
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          child: Container(
            width: 144,
            height: 184,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141923) : const Color(0xFFFBFBFA),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                bottomLeft: Radius.circular(5),
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border.all(
                color: isDark ? const Color(0xFF2B3447) : const Color(0xFFDCD2C0),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Left spine impression
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 18,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B2232) : const Color(0xFFF1ECE1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        bottomLeft: Radius.circular(4),
                      ),
                      border: Border(
                        right: BorderSide(
                          color: isDark ? const Color(0xFF2B3447) : const Color(0xFFDCD2C0),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
                // Center plus button & label
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF222B3D) : const Color(0xFFEDE8DD),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF38455E) : const Color(0xFFD0C4B0),
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          size: 24,
                          color: isDark ? const Color(0xFF818CF8) : const Color(0xFF15803D),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'New Notebook',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ── Matching Title & Subtitle Area ────────────────
        SizedBox(
          width: 144,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 36,
                child: Text(
                  'New Notebook',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 20,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Create collection',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  // ── Bottom Section: Continue Writing (Individual Note To-Do System) ─────────
  Widget _buildContinueWritingSection(
    BuildContext context,
    AppState state,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
    Color borderColor,
  ) {
    final docs = state.canvasDocs;
    if (docs.isEmpty) {
      return const SizedBox.shrink();
    }

    // Determine the active or selected individual note
    final selectedDoc = docs.firstWhere(
      (d) => d.id == _selectedNoteIdForTodo,
      orElse: () => state.currentCanvasDoc ?? docs.first,
    );

    final todos = state.getNoteTodos(selectedDoc.id);
    final completedCount = todos.where((t) => t.isCompleted).length;
    final totalCount = todos.length;
    final progress = totalCount == 0 ? 0.0 : (completedCount / totalCount);

    final docTitle = selectedDoc.name;
    final docSubtitle = '${selectedDoc.pages.length} page(s) • ${selectedDoc.docType == CanvasDocType.canvas ? "Infinite Board" : "Notebook"}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Continue Writing',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Note To-Do List',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textMuted,
                    ),
                  ),
                ),
              ],
            ),
            if (docs.length > 1)
              PopupMenuButton<String>(
                tooltip: 'Switch Note for To-Do List',
                onSelected: (id) => setState(() => _selectedNoteIdForTodo = id),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: isDark ? const Color(0xFF1E2433) : Colors.white,
                itemBuilder: (ctx) => docs.map((d) {
                  final isCurrent = d.id == selectedDoc.id;
                  return PopupMenuItem<String>(
                    value: d.id,
                    child: Row(
                      children: [
                        Text(d.coverEmoji.isNotEmpty ? d.coverEmoji : '📓'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            d.name,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                              color: isCurrent ? const Color(0xFF15803D) : textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrent)
                          const Icon(Icons.check, size: 16, color: Color(0xFF15803D)),
                      ],
                    ),
                  );
                }).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2433) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horiz_rounded, size: 14, color: textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'Switch note',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: textSecondary),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151923) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header of note card
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2E2216) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      selectedDoc.coverEmoji.isNotEmpty ? selectedDoc.coverEmoji : '📓',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          docTitle,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          docSubtitle,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Humanized Task Counter Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: totalCount == 0
                          ? (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9))
                          : (completedCount == totalCount
                              ? (isDark ? const Color(0xFF132A1C) : const Color(0xFFECFDF5))
                              : (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9))),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: totalCount == 0
                            ? (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0))
                            : (completedCount == totalCount
                                ? (isDark ? const Color(0xFF166534) : const Color(0xFFA7F3D0))
                                : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0))),
                      ),
                    ),
                    child: Text(
                      totalCount == 0
                          ? '0 tasks'
                          : (completedCount == totalCount
                              ? 'All done ✓'
                              : '$completedCount of $totalCount done'),
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: totalCount == 0
                            ? textMuted
                            : (completedCount == totalCount
                                ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF059669))
                                : textSecondary),
                      ),
                    ),
                  ),
                ],
              ),

              if (totalCount > 0) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress == 1.0 ? const Color(0xFF15803D) : const Color(0xFF22C55E),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Individual Note To-Do Checklist Items
              if (todos.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.checklist_rtl_rounded,
                          size: 32,
                          color: textMuted.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No tasks yet for ${selectedDoc.name}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add your first action item or goal below to stay organized.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...todos.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => state.toggleNoteTodo(selectedDoc.id, item.id),
                          borderRadius: BorderRadius.circular(5),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: item.isCompleted
                                      ? const Color(0xFF22C55E)
                                      : (isDark ? Colors.white12 : Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: item.isCompleted ? const Color(0xFF22C55E) : borderColor,
                                    width: 1.5,
                                  ),
                                ),
                                child: item.isCompleted
                                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                item.title,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: item.isCompleted ? FontWeight.w500 : FontWeight.w600,
                                  color: item.isCompleted ? textMuted : textPrimary,
                                  decoration: item.isCompleted
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => state.removeNoteTodo(selectedDoc.id, item.id),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.close_rounded, size: 15, color: textMuted),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 12),

              // Action buttons row: Add task, Clear completed, Open Notebook
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () => _showAddNoteTodoDialog(context, state, selectedDoc.id, selectedDoc.name),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_rounded, size: 16, color: Color(0xFF2563EB)),
                              const SizedBox(width: 4),
                              Text(
                                'Add task',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (completedCount > 0) ...[
                        const SizedBox(width: 16),
                        InkWell(
                          onTap: () => state.clearCompletedNoteTodos(selectedDoc.id),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                            child: Text(
                              'Clear completed',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      state.switchNotebook(selectedDoc.id);
                      state.setNavIndex(1);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Open Notebook',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCreateNotebookDialog(BuildContext context) {
    CreateDocumentDialog.show(context, state: widget.state);
  }

  void _showExportNotebookDialog(BuildContext context, CanvasDocModel doc) {
    final isDark = widget.state.isDarkMode;
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2333) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.download_rounded, color: Color(0xFF2563EB)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Export "${doc.name}"',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _exportOption(
              ctx: ctx,
              doc: doc,
              format: 'pdf',
              label: 'PDF Document (.pdf)',
              subtitle: 'Formatted pages with headers & footers',
              icon: Icons.picture_as_pdf_outlined,
              color: Colors.redAccent,
              messenger: messenger,
            ),
            _exportOption(
              ctx: ctx,
              doc: doc,
              format: 'docx',
              label: 'Word Document (.docx)',
              subtitle: 'Microsoft Word compatible format',
              icon: Icons.description_outlined,
              color: Colors.blueAccent,
              messenger: messenger,
            ),
            _exportOption(
              ctx: ctx,
              doc: doc,
              format: 'md',
              label: 'Markdown (.md)',
              subtitle: 'Structured text for developers & writers',
              icon: Icons.code_rounded,
              color: Colors.teal,
              messenger: messenger,
            ),
            _exportOption(
              ctx: ctx,
              doc: doc,
              format: 'txt',
              label: 'Plain Text (.txt)',
              subtitle: 'Simple text content, no formatting',
              icon: Icons.text_snippet_outlined,
              color: Colors.grey,
              messenger: messenger,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _exportOption({
    required BuildContext ctx,
    required CanvasDocModel doc,
    required String format,
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
    required ScaffoldMessengerState messenger,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 11.5)),
      onTap: () async {
        Navigator.pop(ctx);
        try {
          await WorkspaceExportService.exportNotebook(doc: doc, format: format);
          messenger.showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              content: Text('"${doc.name}" exported as .$format successfully!'),
              duration: const Duration(seconds: 3),
            ),
          );
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFEF4444),
              content: Text('Export failed: $e'),
            ),
          );
        }
      },
    );
  }

  void _showRenameNotebookDialog(BuildContext context, AppState state, String docId, String currentName) {
    final ctrl = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename Notebook'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Notebook Name',
            hintText: 'Enter notebook name',
          ),
          onSubmitted: (val) {
            if (val.trim().isNotEmpty) {
              state.renameNotebook(docId, val.trim());
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                state.renameNotebook(docId, ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteNotebookDialog(BuildContext context, AppState state, String docId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Notebook'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              state.deleteNotebook(docId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddNoteTodoDialog(BuildContext context, AppState state, String docId, String docName) {
    final taskCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Task for $docName'),
        content: TextField(
          controller: taskCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Task Description',
            hintText: 'e.g. Prepare presentation notes',
          ),
          onSubmitted: (val) {
            if (val.trim().isNotEmpty) {
              state.addNoteTodo(docId, val.trim());
              Navigator.of(ctx).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (taskCtrl.text.trim().isNotEmpty) {
                state.addNoteTodo(docId, taskCtrl.text.trim());
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }


}

