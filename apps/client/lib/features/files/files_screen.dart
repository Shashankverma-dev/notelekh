import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ai_workspace_client/core/models/file_model.dart';
import 'package:ai_workspace_client/core/models/canvas_models.dart';
import 'package:ai_workspace_client/state/app_state.dart';

class FilesScreen extends StatefulWidget {
  final AppState state;

  const FilesScreen({super.key, required this.state});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  String _selectedFilter = 'all'; // all, doc, pdf, image
  bool _isGridView = false;
  String _searchFilter = '';
  final TextEditingController _filterCtrl = TextEditingController();

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final isDark = widget.state.isDarkMode;
        final bg = isDark ? const Color(0xFF0F1219) : const Color(0xFFF8FAFC);
        final cardBg = isDark ? const Color(0xFF161C28) : Colors.white;
        final borderColor = isDark ? const Color(0xFF263249) : const Color(0xFFE2E8F0);
        final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
        final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
        final textMuted = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

        final allFiles = widget.state.workspaceFiles;
        final filtered = allFiles.where((f) {
          // Type filter
          if (_selectedFilter == 'doc') {
            if (!f.mimeType.contains('markdown') && !f.mimeType.contains('text') && !f.name.endsWith('.md') && !f.name.endsWith('.txt')) {
              return false;
            }
          } else if (_selectedFilter == 'pdf') {
            if (!f.mimeType.contains('pdf') && !f.name.endsWith('.pdf')) {
              return false;
            }
          } else if (_selectedFilter == 'image') {
            if (!f.mimeType.contains('image') && !f.name.endsWith('.png') && !f.name.endsWith('.jpg') && !f.name.endsWith('.jpeg')) {
              return false;
            }
          }
          // Text search filter
          if (_searchFilter.trim().isNotEmpty) {
            final q = _searchFilter.trim().toLowerCase();
            return f.name.toLowerCase().contains(q) || (f.content?.toLowerCase().contains(q) ?? false);
          }
          return true;
        }).toList();

        final docCount = allFiles.where((f) => f.mimeType.contains('markdown') || f.mimeType.contains('text') || f.name.endsWith('.md') || f.name.endsWith('.txt')).length;
        final pdfCount = allFiles.where((f) => f.mimeType.contains('pdf') || f.name.endsWith('.pdf')).length;
        final imgCount = allFiles.where((f) => f.mimeType.contains('image') || f.name.endsWith('.png') || f.name.endsWith('.jpg')).length;

        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 640;

        return Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Top Header ────────────────────────────────────────────────────
                Container(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 16 : 28,
                    isMobile ? 16 : 24,
                    isMobile ? 16 : 28,
                    isMobile ? 12 : 16,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131823) : Colors.white,
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isMobile) ...[
                        // Mobile Header: Title Row
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.folder_open_rounded, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Files & Media',
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: textPrimary,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  Text(
                                    'Notes, PDFs & attachments',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Mobile Header: Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickAndUploadFile(context),
                                icon: const Icon(Icons.upload_file_rounded, size: 15),
                                label: const Text('Upload File'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: textPrimary,
                                  side: BorderSide(color: borderColor),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  textStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showCreateDocumentDialog(context),
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('New Document'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                  textStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // Desktop / Tablet Header Row
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                                ),
                                borderRadius: BorderRadius.circular(11),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.folder_open_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Files & Media',
                                    style: GoogleFonts.inter(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: textPrimary,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Manage notes, lecture documents, imported PDFs, and study attachments',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: () => _pickAndUploadFile(context),
                              icon: const Icon(Icons.upload_file_rounded, size: 16),
                              label: const Text('Upload File'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: textPrimary,
                                side: BorderSide(color: borderColor),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: () => _showCreateDocumentDialog(context),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('New Document'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                                textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 14),

                      // ── Search & Filter Controls Bar ───────────────────────────
                      if (isMobile) ...[
                        // Mobile: Search field and Grid/List toggle in one row
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1A2234) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: borderColor),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Row(
                                  children: [
                                    Icon(Icons.search_rounded, size: 17, color: textMuted),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: TextField(
                                        controller: _filterCtrl,
                                        style: GoogleFonts.inter(fontSize: 12.5, color: textPrimary),
                                        decoration: InputDecoration(
                                          hintText: 'Filter files...',
                                          hintStyle: GoogleFonts.inter(fontSize: 12.5, color: textMuted),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        onChanged: (val) => setState(() => _searchFilter = val),
                                      ),
                                    ),
                                    if (_searchFilter.isNotEmpty)
                                      InkWell(
                                        onTap: () {
                                          _filterCtrl.clear();
                                          setState(() => _searchFilter = '');
                                        },
                                        child: Icon(Icons.cancel_rounded, size: 16, color: textMuted),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A2234) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.view_list_rounded, size: 18),
                                    tooltip: 'List view',
                                    color: !_isGridView ? const Color(0xFF2563EB) : textMuted,
                                    onPressed: () => setState(() => _isGridView = false),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.grid_view_rounded, size: 17),
                                    tooltip: 'Grid view',
                                    color: _isGridView ? const Color(0xFF2563EB) : textMuted,
                                    onPressed: () => setState(() => _isGridView = true),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Mobile: Filter Pills horizontal row
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _buildFilterPill('All (${allFiles.length})', 'all', isDark),
                              const SizedBox(width: 6),
                              _buildFilterPill('Notes ($docCount)', 'doc', isDark),
                              const SizedBox(width: 6),
                              _buildFilterPill('PDFs ($pdfCount)', 'pdf', isDark),
                              const SizedBox(width: 6),
                              _buildFilterPill('Images ($imgCount)', 'image', isDark),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Desktop: Search + Pills + Toggle in single row
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 42,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1A2234) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  children: [
                                    Icon(Icons.search_rounded, size: 18, color: textMuted),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _filterCtrl,
                                        style: GoogleFonts.inter(fontSize: 13, color: textPrimary),
                                        decoration: InputDecoration(
                                          hintText: 'Filter files by name or content...',
                                          hintStyle: GoogleFonts.inter(fontSize: 13, color: textMuted),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        onChanged: (val) => setState(() => _searchFilter = val),
                                      ),
                                    ),
                                    if (_searchFilter.isNotEmpty)
                                      InkWell(
                                        onTap: () {
                                          _filterCtrl.clear();
                                          setState(() => _searchFilter = '');
                                        },
                                        child: Icon(Icons.cancel_rounded, size: 16, color: textMuted),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildFilterPill('All (${allFiles.length})', 'all', isDark),
                                  const SizedBox(width: 6),
                                  _buildFilterPill('Notes ($docCount)', 'doc', isDark),
                                  const SizedBox(width: 6),
                                  _buildFilterPill('PDFs ($pdfCount)', 'pdf', isDark),
                                  const SizedBox(width: 6),
                                  _buildFilterPill('Images ($imgCount)', 'image', isDark),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A2234) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.view_list_rounded, size: 18),
                                    tooltip: 'List view',
                                    color: !_isGridView ? const Color(0xFF2563EB) : textMuted,
                                    onPressed: () => setState(() => _isGridView = false),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.grid_view_rounded, size: 17),
                                    tooltip: 'Grid view',
                                    color: _isGridView ? const Color(0xFF2563EB) : textMuted,
                                    onPressed: () => setState(() => _isGridView = true),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

            // ── Files Body ────────────────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState(isDark, textPrimary, textSecondary, textMuted)
                  : _isGridView
                      ? GridView.builder(
                          padding: EdgeInsets.all(isMobile ? 14 : 28),
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: isMobile ? 200 : 280,
                            crossAxisSpacing: isMobile ? 10 : 16,
                            mainAxisSpacing: isMobile ? 10 : 16,
                            childAspectRatio: isMobile ? 0.95 : 1.15,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final file = filtered[index];
                            return _buildGridCard(
                              file: file,
                              isDark: isDark,
                              cardBg: cardBg,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              textMuted: textMuted,
                            );
                          },
                        )
                      : ListView.separated(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 16 : 28,
                            vertical: isMobile ? 12 : 20,
                          ),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => SizedBox(height: isMobile ? 8 : 10),
                          itemBuilder: (context, index) {
                            final file = filtered[index];
                            return _buildListRow(
                              file: file,
                              isDark: isDark,
                              cardBg: cardBg,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              textMuted: textMuted,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildFilterPill(String label, String value, bool isDark) {
    final isSelected = _selectedFilter == value;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = value),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF1E2838) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    final hasSearch = _searchFilter.trim().isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C2536) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasSearch ? Icons.search_off_rounded : Icons.folder_open_rounded,
                size: 32,
                color: textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'No files matching "$_searchFilter"'
                  : 'No files in this category',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasSearch
                  ? 'Try a different search keyword or clear the search field.'
                  : 'Add notes or upload study materials to get started.',
              style: GoogleFonts.inter(fontSize: 13, color: textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showCreateDocumentDialog(context),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Create New Document'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListRow({
    required FileItemModel file,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
  }) {
    final color = _getFileColor(file.mimeType, file.name);
    final icon = _getFileIcon(file.mimeType, file.name);
    final isMobile = MediaQuery.of(context).size.width < 640;

    return InkWell(
      onTap: () => _showFilePreviewDialog(context, file),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 12 : 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(icon, color: color, size: 19),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.name,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${file.formattedSize} • ${_formatDate(file.createdAt)}',
                              style: GoogleFonts.inter(fontSize: 11, color: textMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        color: const Color(0xFFEF4444),
                        tooltip: 'Delete',
                        onPressed: () => _confirmDeleteFile(context, file),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _insertFileToCanvas(context, file),
                          icon: const Icon(Icons.post_add_rounded, size: 14),
                          label: const Text('Insert to Canvas'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB),
                            side: const BorderSide(color: Color(0xFF93C5FD)),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            textStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showFilePreviewDialog(context, file),
                          icon: const Icon(Icons.visibility_outlined, size: 14),
                          label: const Text('Preview'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF1E2838) : const Color(0xFFF1F5F9),
                            foregroundColor: textPrimary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            textStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  // Icon
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 14),

                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              file.formattedSize,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('•', style: TextStyle(color: textMuted, fontSize: 10)),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(file.createdAt),
                              style: GoogleFonts.inter(fontSize: 11.5, color: textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Action: Insert to Canvas Note Card
                  OutlinedButton.icon(
                    onPressed: () => _insertFileToCanvas(context, file),
                    icon: const Icon(Icons.post_add_rounded, size: 14),
                    label: const Text('Insert to Canvas'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF93C5FD)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Action: Preview Document
                  ElevatedButton.icon(
                    onPressed: () => _showFilePreviewDialog(context, file),
                    icon: const Icon(Icons.visibility_outlined, size: 14),
                    label: const Text('Preview'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF1E2838) : const Color(0xFFF1F5F9),
                      foregroundColor: textPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Action: Delete
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: const Color(0xFFEF4444),
                    tooltip: 'Delete',
                    onPressed: () => _confirmDeleteFile(context, file),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildGridCard({
    required FileItemModel file,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
  }) {
    final color = _getFileColor(file.mimeType, file.name);
    final icon = _getFileIcon(file.mimeType, file.name);

    return InkWell(
      onTap: () => _showFilePreviewDialog(context, file),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.more_horiz_rounded, size: 18),
                  color: textMuted,
                  onPressed: () => _showFilePreviewDialog(context, file),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${file.formattedSize} • ${_formatDate(file.createdAt)}',
                  style: GoogleFonts.inter(fontSize: 11, color: textMuted),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tap to preview',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: const Color(0xFF2563EB),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF2563EB)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _insertFileToCanvas(BuildContext context, FileItemModel file) {
    final noteContent = file.content != null && file.content!.isNotEmpty
        ? file.content!
        : 'Imported file reference: ${file.name} (${file.formattedSize})';

    final previewSnippet = noteContent.length > 280
        ? '${noteContent.substring(0, 280)}...'
        : noteContent;

    final noteCard = CanvasNoteCardItem(
      id: 'card_${DateTime.now().millisecondsSinceEpoch}',
      title: file.name,
      content: previewSnippet,
      position: const Offset(120, 160),
      backgroundColor: const Color(0xFFEFF6FF),
      textColor: const Color(0xFF1E3A8A),
      zIndex: widget.state.canvasObjects.length + 1,
    );

    widget.state.addCanvasObject(noteCard);

    // Show feedback and switch to canvas
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Inserted "${file.name}" to active notebook canvas!'),
        action: SnackBarAction(
          label: 'View Canvas',
          onPressed: () => widget.state.setNavIndex(1),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result != null && result.files.isNotEmpty) {
        final picked = result.files.first;
        if (picked.bytes != null) {
          final uploaded = await widget.state.uploadFile(
            filename: picked.name,
            bytes: picked.bytes!,
          );
          if (uploaded != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('File "${picked.name}" uploaded successfully!')),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload info: $e')),
        );
      }
    }
  }

  void _showCreateDocumentDialog(BuildContext context) {
    final titleController = TextEditingController(
      text: 'Notes_${DateTime.now().month}_${DateTime.now().day}.md',
    );
    final contentController = TextEditingController(
      text: '# Lecture & Study Notes\n\n'
          '## Key Topics & Concepts\n'
          '- Key Theorem: Definition and practical implications\n'
          '- Core Equations & Formulas\n\n'
          '### Summary\n'
          'Detailed explanations, examples, and study questions.\n',
    );

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final isDark = widget.state.isDarkMode;
        final bg = isDark ? const Color(0xFF131823) : Colors.white;
        final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);

        return AlertDialog(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.note_add_rounded, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'New Workspace Note',
                style: GoogleFonts.inter(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  style: GoogleFonts.inter(fontSize: 13.5, color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'File Name',
                    hintText: 'e.g. quantum_physics.md',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Content (Markdown supported):',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: contentController,
                  maxLines: 8,
                  style: GoogleFonts.jetBrainsMono(fontSize: 12.5, color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Enter note or markdown content...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final content = contentController.text;
                if (title.isEmpty) return;

                Navigator.pop(dialogCtx);
                await widget.state.createDocumentFile(filename: title, content: content);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Document "$title" saved to workspace!')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Create Note', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  void _showFilePreviewDialog(BuildContext context, FileItemModel file) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        final isDark = widget.state.isDarkMode;
        final bg = isDark ? const Color(0xFF131823) : Colors.white;
        final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
        final borderColor = isDark ? const Color(0xFF263249) : const Color(0xFFE2E8F0);
        final content = file.content ?? 'File: ${file.name}\nSize: ${file.formattedSize}\nType: ${file.mimeType}';

        return Dialog(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 640,
            constraints: const BoxConstraints(maxHeight: 680),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Modal Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_getFileIcon(file.mimeType, file.name), color: const Color(0xFF2563EB), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${file.mimeType} • ${file.formattedSize}',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: borderColor, height: 1),
                const SizedBox(height: 16),

                // Preview Content
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A2234) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: SingleChildScrollView(
                      child: MarkdownBody(
                        data: content,
                        styleSheet: MarkdownStyleSheet(
                          p: GoogleFonts.inter(fontSize: 13.5, color: textPrimary, height: 1.5),
                          h1: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary),
                          h2: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary),
                          h3: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600, color: textPrimary),
                          code: GoogleFonts.jetBrainsMono(fontSize: 12.5),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Content copied to clipboard!')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 15),
                      label: const Text('Copy Content'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogCtx);
                            _insertFileToCanvas(context, file);
                          },
                          icon: const Icon(Icons.post_add_rounded, size: 16),
                          label: const Text('Insert into Canvas'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteFile(BuildContext context, FileItemModel file) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete File?'),
        content: Text('Are you sure you want to delete "${file.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.state.deleteFile(file.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String mime, String name) {
    if (mime.contains('pdf') || name.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (mime.contains('image') || name.endsWith('.png') || name.endsWith('.jpg') || name.endsWith('.jpeg')) {
      return Icons.image_rounded;
    }
    if (name.endsWith('.md') || mime.contains('markdown')) return Icons.article_rounded;
    if (name.endsWith('.json') || mime.contains('json')) return Icons.data_object_rounded;
    return Icons.description_rounded;
  }

  Color _getFileColor(String mime, String name) {
    if (mime.contains('pdf') || name.endsWith('.pdf')) return const Color(0xFFEF4444); // Red
    if (mime.contains('image') || name.endsWith('.png') || name.endsWith('.jpg')) return const Color(0xFF10B981); // Green
    if (name.endsWith('.md') || mime.contains('markdown')) return const Color(0xFF2563EB); // Blue
    return const Color(0xFF8B5CF6); // Purple
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
