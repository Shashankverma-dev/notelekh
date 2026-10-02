import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_workspace_client/core/models/search_model.dart';
import 'package:ai_workspace_client/state/app_state.dart';

class SearchScreen extends StatefulWidget {
  final AppState state;

  const SearchScreen({super.key, required this.state});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedFilter = 'all';

  final List<String> _suggestedQueries = [
    'GoodNotes Engine',
    'Personal Notes',
    'Physics',
    'Formulas',
    'Cell Biology',
    'Checklists',
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = widget.state.searchQuery;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _runSearch(String query) {
    setState(() {
      _searchCtrl.text = query;
      _searchCtrl.selection = TextSelection.fromPosition(TextPosition(offset: query.length));
    });
    widget.state.performSearch(query);
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

        final allResults = widget.state.searchResults;
        final filteredResults = allResults.where((r) {
          if (_selectedFilter == 'all') return true;
          if (_selectedFilter == 'canvas') return r.entityType == 'canvas';
          if (_selectedFilter == 'note') return r.entityType == 'note';
          if (_selectedFilter == 'file') return r.entityType == 'file';
          if (_selectedFilter == 'chat') return r.entityType == 'conversation' || r.entityType == 'message';
          return r.entityType == _selectedFilter;
        }).toList();

        final canvasCount = allResults.where((r) => r.entityType == 'canvas').length;
        final noteCount = allResults.where((r) => r.entityType == 'note').length;
        final fileCount = allResults.where((r) => r.entityType == 'file').length;
        final chatCount = allResults.where((r) => r.entityType == 'conversation' || r.entityType == 'message').length;

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
                      Row(
                        children: [
                          Container(
                            width: isMobile ? 36 : 38,
                            height: isMobile ? 36 : 38,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(Icons.search_rounded, color: Colors.white, size: isMobile ? 18 : 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Global Search',
                                  style: GoogleFonts.inter(
                                    fontSize: isMobile ? 18 : 20,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  isMobile
                                      ? 'Search notebooks, documents & notes'
                                      : 'Search notebooks, handwritten sketches, documents, and checklists',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: isMobile ? 12 : 13,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Back to Dashboard Button
                          if (isMobile)
                            IconButton(
                              onPressed: () => widget.state.setNavIndex(0),
                              icon: const Icon(Icons.arrow_back_rounded, size: 20),
                              tooltip: 'Dashboard',
                              color: textSecondary,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            )
                          else
                            TextButton.icon(
                              onPressed: () => widget.state.setNavIndex(0),
                              icon: const Icon(Icons.arrow_back_rounded, size: 16),
                              label: const Text('Dashboard'),
                              style: TextButton.styleFrom(
                                foregroundColor: textSecondary,
                                textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),

                  const SizedBox(height: 14),

                  // ── Search Input Field ──────────────────────────────────────
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A2234) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _searchCtrl.text.isNotEmpty
                            ? const Color(0xFF2563EB)
                            : borderColor,
                        width: _searchCtrl.text.isNotEmpty ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 22,
                          color: _searchCtrl.text.isNotEmpty
                              ? const Color(0xFF2563EB)
                              : textMuted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            autofocus: true,
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              color: textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Type to search across notebooks, notes, files, tags...',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 14,
                                color: textMuted,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (val) => widget.state.performSearch(val),
                          ),
                        ),
                        if (_searchCtrl.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.cancel_rounded, size: 18),
                            color: textMuted,
                            tooltip: 'Clear',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            onPressed: () {
                              _searchCtrl.clear();
                              widget.state.performSearch('');
                            },
                          ),
                      ],
                    ),
                  ),

                  // ── Filter Pills Bar ────────────────────────────────────────
                  if (allResults.isNotEmpty || _searchCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterPill(
                            label: 'All (${allResults.length})',
                            value: 'all',
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterPill(
                            label: 'Notebooks ($canvasCount)',
                            value: 'canvas',
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterPill(
                            label: 'Notes & Cards ($noteCount)',
                            value: 'note',
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterPill(
                            label: 'Files & Media ($fileCount)',
                            value: 'file',
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterPill(
                            label: 'Chats ($chatCount)',
                            value: 'chat',
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Search Results or Suggestions ─────────────────────────────────
            Expanded(
              child: widget.state.isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _searchCtrl.text.trim().isEmpty
                      ? _buildSuggestionsView(isDark, textPrimary, textSecondary, textMuted, isMobile)
                      : filteredResults.isEmpty
                          ? _buildNoResultsView(isDark, textPrimary, textSecondary, textMuted)
                          : ListView.separated(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 16 : 28,
                                vertical: isMobile ? 14 : 20,
                              ),
                              itemCount: filteredResults.length,
                              separatorBuilder: (_, _) => SizedBox(height: isMobile ? 8 : 12),
                              itemBuilder: (context, index) {
                                final item = filteredResults[index];
                                return _buildResultCard(
                                  item: item,
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

  Widget _buildFilterPill({
    required String label,
    required String value,
    required bool isDark,
  }) {
    final isSelected = _selectedFilter == value;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = value),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF1E2838) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsView(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
    bool isMobile,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 28,
        vertical: isMobile ? 18 : 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SUGGESTED SEARCHES',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: textMuted,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _suggestedQueries.map((q) {
              return InkWell(
                onTap: () => _runSearch(q),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF182030) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF28364F) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.north_west_rounded, size: 14, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Text(
                        q,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 36),
          Text(
            'SEARCH SHORTCUTS & CAPABILITIES',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: textMuted,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 14),
          _buildShortcutRow(
            icon: Icons.menu_book_rounded,
            title: 'Search by Notebook & Canvas Name',
            subtitle: 'Quickly jump to any notebook such as "Personal Notes" or "Notebook 2".',
            color: const Color(0xFF2563EB),
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 10),
          _buildShortcutRow(
            icon: Icons.edit_note_rounded,
            title: 'Search Handwritten Notes & Text Cards',
            subtitle: 'Index content inside individual pages, sticky notes, formulas, and todo checklists.',
            color: const Color(0xFFF59E0B),
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 10),
          _buildShortcutRow(
            icon: Icons.insert_drive_file_rounded,
            title: 'Search Workspace Documents & Files',
            subtitle: 'Search across lecture notes, Markdown files, and imported study PDFs.',
            color: const Color(0xFF10B981),
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161C28) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF243046) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
    );
  }

  Widget _buildNoResultsView(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
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
              child: Icon(Icons.search_off_rounded, size: 32, color: textMuted),
            ),
            const SizedBox(height: 18),
            Text(
              'No matches found for "${_searchCtrl.text}"',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try checking for typos or searching with different keywords.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _searchCtrl.clear();
                widget.state.performSearch('');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'Clear Search',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard({
    required SearchResultItemModel item,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
  }) {
    final typeColor = _getTypeColor(item.entityType);
    final typeIcon = _getTypeIcon(item.entityType);
    final typeLabel = _getTypeLabel(item.entityType);

    return InkWell(
      onTap: () => _handleResultTap(item),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(typeIcon, color: typeColor, size: 20),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          typeLabel,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: typeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.snippet,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: textSecondary,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.folder_outlined, size: 13, color: textMuted),
                      const SizedBox(width: 4),
                      Text(
                        item.workspaceName ?? 'Workspace',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _getActionText(item.entityType),
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: typeColor,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.arrow_forward_rounded, size: 13, color: typeColor),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleResultTap(SearchResultItemModel item) {
    if (item.entityType == 'canvas' || item.entityType == 'note') {
      // Find the notebook and open it directly
      widget.state.switchNotebook(item.id);
      widget.state.setNavIndex(1); // 1 = UnifiedStudioScreen (Notebook Canvas)
    } else if (item.entityType == 'file') {
      widget.state.setNavIndex(2); // 2 = Files & Media Screen
    } else if (item.entityType == 'conversation' || item.entityType == 'message') {
      widget.state.setNavIndex(1); // 1 = UnifiedStudioScreen
    } else if (item.entityType == 'workspace') {
      final found = widget.state.workspaces.firstWhere(
        (w) => w.id == item.id,
        orElse: () => widget.state.workspaces.first,
      );
      widget.state.selectWorkspace(found);
      widget.state.setNavIndex(0); // 0 = Dashboard
    } else {
      widget.state.setNavIndex(0);
    }
  }

  String _getActionText(String type) {
    switch (type) {
      case 'canvas':
        return 'Open Notebook';
      case 'note':
        return 'View in Canvas';
      case 'file':
        return 'View File';
      case 'conversation':
      case 'message':
        return 'Open Chat';
      case 'workspace':
        return 'Switch Workspace';
      default:
        return 'Open';
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'canvas':
        return 'NOTEBOOK';
      case 'note':
        return 'NOTE / CARD';
      case 'file':
        return 'FILE';
      case 'conversation':
      case 'message':
        return 'AI CHAT';
      case 'workspace':
        return 'WORKSPACE';
      default:
        return 'ITEM';
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'canvas':
        return const Color(0xFF2563EB); // Royal Blue
      case 'note':
        return const Color(0xFFF59E0B); // Amber
      case 'file':
        return const Color(0xFF10B981); // Emerald
      case 'conversation':
      case 'message':
        return const Color(0xFF8B5CF6); // Violet
      case 'workspace':
        return const Color(0xFF0284C7); // Sky Blue
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'canvas':
        return Icons.menu_book_rounded;
      case 'note':
        return Icons.edit_note_rounded;
      case 'file':
        return Icons.insert_drive_file_rounded;
      case 'conversation':
      case 'message':
        return Icons.forum_rounded;
      case 'workspace':
        return Icons.folder_rounded;
      default:
        return Icons.article_rounded;
    }
  }
}
