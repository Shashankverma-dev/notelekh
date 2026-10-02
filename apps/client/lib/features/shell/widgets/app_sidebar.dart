import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_workspace_client/core/theme/app_theme.dart';
import 'package:ai_workspace_client/core/models/workspace_model.dart';
import 'package:ai_workspace_client/core/models/canvas_models.dart';
import 'package:ai_workspace_client/features/canvas/create_document_dialog.dart';
import 'package:ai_workspace_client/features/dashboard/widgets/notebook_cover_editor_dialog.dart';
import 'package:ai_workspace_client/state/app_state.dart';
import 'package:ai_workspace_client/core/widgets/notelekh_logo.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GoodNotes-Grade Executive Navigation Sidebar
// ─────────────────────────────────────────────────────────────────────────────
class AppSidebar extends StatelessWidget {
  final AppState state;

  const AppSidebar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final isDark = state.isDarkMode;
    final bg = isDark ? const Color(0xFF12151F) : const Color(0xFFF9FAFB);
    final borderColor = isDark ? const Color(0xFF1E2536) : const Color(0xFFE5E7EB);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      width: 255,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: borderColor, width: 1.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Notelekh Logo & Header Bar ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: NotelekhLogo(
                    height: 28,
                    isDark: isDark,
                    showTagline: true,
                  ),
                ),
                // Quick Theme Toggle
                Tooltip(
                  message: isDark ? 'Light mode' : 'Dark mode',
                  child: InkWell(
                    onTap: state.toggleTheme,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1B2232) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF263045) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Icon(
                        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        size: 15,
                        color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Prominent GoodNotes "+ New" Action Button ────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => CreateDocumentDialog.show(context, state: state),
                borderRadius: BorderRadius.circular(10),
                child: Ink(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9.5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_rounded, size: 17, color: Colors.white),
                      const SizedBox(width: 7),
                      Text(
                        'New Notebook',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Scrollable Navigation & Lists ─────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                // ── Primary Navigation Items ────────────────────────────────
                _NotelekhNavItem(
                  icon: Icons.grid_view_rounded,
                  label: 'Home',
                  isSelected: state.selectedNavIndex == 0,
                  isDark: isDark,
                  onTap: () => state.setNavIndex(0),
                ),
                _NotelekhNavItem(
                  icon: Icons.folder_open_rounded,
                  label: 'Files & Media',
                  isSelected: state.selectedNavIndex == 2,
                  isDark: isDark,
                  onTap: () => state.setNavIndex(2),
                ),
                _NotelekhNavItem(
                  icon: Icons.search_rounded,
                  label: 'Search',
                  isSelected: state.selectedNavIndex == 3,
                  isDark: isDark,
                  onTap: () => state.setNavIndex(3),
                ),
                _NotelekhNavItem(
                  icon: Icons.tune_rounded,
                  label: 'Settings',
                  isSelected: state.selectedNavIndex == 4,
                  isDark: isDark,
                  onTap: () => state.setNavIndex(4),
                ),

                const SizedBox(height: 18),

                // ── WORKSPACES Section ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'WORKSPACES',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: textMuted,
                          letterSpacing: 1.1,
                        ),
                      ),
                      InkWell(
                        onTap: () => _showCreateWorkspaceDialog(context),
                        borderRadius: BorderRadius.circular(5),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Icon(Icons.add, size: 15, color: textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                ...state.workspaces.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final ws = entry.value;
                  final isSelected = state.currentWorkspace?.id == ws.id;
                  return _SidebarWorkspaceItem(
                    ws: ws,
                    index: idx,
                    isSelected: isSelected,
                    isDark: isDark,
                    onTap: () => state.selectWorkspace(ws),
                    onDelete: () => _confirmDeleteWorkspace(context, ws),
                  );
                }),

                const SizedBox(height: 18),

                // ── NOTEBOOKS Section ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'NOTEBOOKS',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: textMuted,
                          letterSpacing: 1.1,
                        ),
                      ),
                      InkWell(
                        onTap: () => CreateDocumentDialog.show(context, state: state),
                        borderRadius: BorderRadius.circular(5),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Icon(Icons.add, size: 15, color: textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                ...state.canvasDocs.map((doc) {
                  final isSelected = state.currentCanvasDoc?.id == doc.id;
                  return _SidebarNotebookRow(
                    doc: doc,
                    isSelected: isSelected,
                    isDark: isDark,
                    onTap: () {
                      state.switchNotebook(doc.id);
                      state.setNavIndex(1);
                    },
                    onEditCover: () {
                      showNotebookCoverEditor(context, state, doc.id);
                    },
                    onRename: () {
                      _showRenameNotebookDialog(context, doc);
                    },
                    onDelete: () {
                      _confirmDeleteNotebook(context, doc);
                    },
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // ── GoodNotes Cloud Sync & Storage Card ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B28) : const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: isDark ? const Color(0xFF263045) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.cloud_done_rounded, color: Color(0xFF2563EB), size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Account Storage',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            Text(
                              'Cloud synced & backed up',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: state.storageProgress,
                      minHeight: 3.5,
                      backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${state.accountItemCount} ${state.accountItemCount == 1 ? "notebook" : "notebooks"}',
                        style: GoogleFonts.inter(fontSize: 10, color: textMuted, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${state.formattedStorageUsed} used',
                        style: GoogleFonts.inter(fontSize: 10, color: textMuted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const Divider(height: 14),
                  // Workspace Studio Bar & Settings Access + Sign Out
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => state.setNavIndex(4),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5C59F2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.auto_awesome, color: Colors.white, size: 13),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Notelekh Studio',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: textPrimary),
                                      ),
                                      Text(
                                        'Workspace Active',
                                        style: GoogleFonts.inter(fontSize: 9.5, color: textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.tune_rounded, size: 14, color: textMuted),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'Sign Out (Exit to Landing Page)',
                        child: InkWell(
                          onTap: () async {
                            await state.signOut();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(Icons.logout_rounded, size: 15, color: textMuted),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateWorkspaceDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.create_new_folder_outlined, color: AppColors.primary, size: 22),
            SizedBox(width: 10),
            Text('New Workspace'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Workspace name',
                hintText: 'e.g. Research & Study',
                prefixIcon: Icon(Icons.drive_file_rename_outline_rounded, size: 18),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'What is this workspace for?',
                prefixIcon: Icon(Icons.notes_rounded, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                state.createWorkspace(name: name, description: descCtrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRenameNotebookDialog(BuildContext context, CanvasDocModel doc) {
    final ctrl = TextEditingController(text: doc.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename Notebook'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Notebook Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty) {
                state.renameNotebook(doc.id, newName);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteNotebook(BuildContext context, CanvasDocModel doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 8),
            Text('Delete Notebook'),
          ],
        ),
        content: Text('Are you sure you want to delete "${doc.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () {
              state.deleteNotebook(doc.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteWorkspace(BuildContext context, WorkspaceModel ws) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 10),
            Text('Delete Workspace'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${ws.name}"?',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'This will permanently remove this workspace and all its notebooks, notes, files, and AI conversations. This action cannot be undone.',
              style: GoogleFonts.inter(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ],
        ),
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
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await state.deleteWorkspace(ws.id);
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Workspace "${ws.name}" deleted.'),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Color(0xFFEF4444),
                      content: Text('Failed to delete workspace. Please try again.'),
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Primary Navigation Item (GoodNotes Style)
// ─────────────────────────────────────────────────────────────────────────────
class _NotelekhNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _NotelekhNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = isDark ? const Color(0xFF1E283E) : const Color(0xFFEFF6FF);
    final activeColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    final inactiveColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final inactiveIconColor = isDark ? const Color(0xFF64748B) : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: isSelected
                  ? Border.all(
                      color: isDark ? const Color(0xFF2C3955) : const Color(0xFFDBEAFE),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                if (isSelected)
                  Container(
                    width: 3.5,
                    height: 15,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: activeColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? activeColor : inactiveIconColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? (isDark ? Colors.white : const Color(0xFF1E3A8A)) : inactiveColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GoodNotes Mini Notebook Cover Badge
// ─────────────────────────────────────────────────────────────────────────────
class _SidebarMiniCover extends StatelessWidget {
  final CanvasDocModel doc;
  final bool isSelected;
  final bool isDark;

  const _SidebarMiniCover({
    required this.doc,
    required this.isSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = doc.coverColor;
    final isTextDoc = doc.docType == CanvasDocType.textDocument;
    final isWhiteboard = doc.docType == CanvasDocType.canvas;

    if (isWhiteboard) {
      return Container(
        width: 17,
        height: 22,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: 1,
          ),
        ),
        child: const Center(
          child: Icon(Icons.border_all_rounded, size: 10, color: Color(0xFF64748B)),
        ),
      );
    }

    if (isTextDoc) {
      return Container(
        width: 17,
        height: 22,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isSelected ? const Color(0xFF0284C7) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 3,
              offset: const Offset(1, 1),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.article_outlined, size: 10, color: Color(0xFF0284C7)),
        ),
      );
    }

    // Authentic GoodNotes Notebook mini cover
    return Container(
      width: 17,
      height: 22,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(2),
          bottomLeft: Radius.circular(2),
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
            blurRadius: 3,
            offset: const Offset(1, 1.5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Spine band on left
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3.5,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(2),
                  bottomLeft: Radius.circular(2),
                ),
              ),
            ),
          ),
          // White label plate in center
          Center(
            child: Container(
              width: 8,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GoodNotes Notebook Row
// ─────────────────────────────────────────────────────────────────────────────
class _SidebarNotebookRow extends StatelessWidget {
  final CanvasDocModel doc;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onEditCover;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _SidebarNotebookRow({
    required this.doc,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
    required this.onEditCover,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = isDark ? const Color(0xFF1E283E) : const Color(0xFFEFF6FF);
    final borderColor = isDark ? const Color(0xFF2C3955) : const Color(0xFFDBEAFE);
    final textPri = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected ? Border.all(color: borderColor, width: 1) : null,
            ),
            child: Row(
              children: [
                _SidebarMiniCover(doc: doc, isSelected: isSelected, isDark: isDark),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    doc.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? textPri : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A2234) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2B3750) : const Color(0xFFE2E8F0),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    '${doc.pages.length}p',
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)) : textMuted,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Notebook options',
                  padding: EdgeInsets.zero,
                  iconSize: 14,
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 14,
                    color: isSelected ? (isDark ? Colors.white70 : const Color(0xFF2563EB)) : textMuted,
                  ),
                  color: isDark ? const Color(0xFF1E2333) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) {
                    if (val == 'edit_cover') {
                      onEditCover();
                    } else if (val == 'rename') {
                      onRename();
                    } else if (val == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'edit_cover',
                      child: Row(
                        children: [
                          const Icon(Icons.palette_outlined, size: 16, color: Color(0xFF2563EB)),
                          const SizedBox(width: 8),
                          Text('Change Cover Theme', style: GoogleFonts.inter(fontSize: 12.5)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          const Icon(Icons.drive_file_rename_outline_rounded, size: 16),
                          const SizedBox(width: 8),
                          Text('Rename Notebook', style: GoogleFonts.inter(fontSize: 12.5)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                          const SizedBox(width: 8),
                          Text('Delete Notebook', style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFFEF4444))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Workspace Selector Item
// ─────────────────────────────────────────────────────────────────────────────
class _SidebarWorkspaceItem extends StatelessWidget {
  final WorkspaceModel ws;
  final int index;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SidebarWorkspaceItem({
    required this.ws,
    required this.index,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final activeBg = isDark ? const Color(0xFF1B2335) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? const Color(0xFF2B3954) : const Color(0xFFE2E8F0);

    final gradients = [
      [const Color(0xFF2563EB), const Color(0xFF38BDF8)],
      [const Color(0xFF7C3AED), const Color(0xFFA855F7)],
      [const Color(0xFF059669), const Color(0xFF10B981)],
      [const Color(0xFFEA580C), const Color(0xFFF97316)],
      [const Color(0xFFE11D48), const Color(0xFFFB7185)],
    ];
    final g = gradients[index % gradients.length];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6.5),
            decoration: BoxDecoration(
              color: isSelected ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: isSelected ? Border.all(color: borderColor, width: 1.2) : null,
            ),
            child: Row(
              children: [
                // Workspace monogram squircle
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: g, begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: g[0].withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      ws.name.trim().isNotEmpty ? ws.name.trim()[0].toUpperCase() : 'W',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    ws.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? (isDark ? Colors.white : const Color(0xFF0F172A)) : textMuted,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    margin: const EdgeInsets.only(right: 3),
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 8, color: Colors.white),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'Workspace options',
                  padding: EdgeInsets.zero,
                  iconSize: 14,
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    size: 15,
                    color: textMuted,
                  ),
                  color: isDark ? const Color(0xFF1E2333) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) {
                    if (val == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                          const SizedBox(width: 8),
                          Text(
                            'Delete Workspace',
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFFEF4444)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
