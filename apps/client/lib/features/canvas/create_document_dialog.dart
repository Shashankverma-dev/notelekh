import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_workspace_client/core/theme/app_theme.dart';
import 'package:ai_workspace_client/core/models/canvas_models.dart';
import 'package:ai_workspace_client/state/app_state.dart';

/// NoteFlow document creation dialog — single-step flow.
/// Shows: Name input → Style picker (Notebook / Whiteboard / Text Document)
///         → Template grid (dynamically filtered by style)
class CreateDocumentDialog extends StatefulWidget {
  final AppState state;

  const CreateDocumentDialog({
    super.key,
    required this.state,
  });

  static Future<void> show(
    BuildContext context, {
    required AppState state,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => CreateDocumentDialog(state: state),
    );
  }

  @override
  State<CreateDocumentDialog> createState() => _CreateDocumentDialogState();
}

class _CreateDocumentDialogState extends State<CreateDocumentDialog>
    with SingleTickerProviderStateMixin {
  CanvasDocType _selectedType = CanvasDocType.notebook;

  // Template selections for each style
  CanvasPaperStyle _notebookTemplate = CanvasPaperStyle.ruledLines;
  String _whiteboardTemplate = 'blank';
  String _textDocTemplate = 'lecture';

  final TextEditingController _nameCtrl = TextEditingController();

  late final AnimationController _animCtrl;
  late final Animation<Offset> _slideIn;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _slideIn = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    // Pre-fill a default name
    _nameCtrl.text = 'Notebook ${widget.state.canvasDocs.length + 1}';
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onStyleChanged(CanvasDocType type) {
    setState(() {
      _selectedType = type;
      final count = widget.state.canvasDocs.length + 1;
      if (type == CanvasDocType.notebook) {
        _nameCtrl.text = 'Notebook $count';
      } else if (type == CanvasDocType.canvas) {
        _nameCtrl.text = 'Whiteboard $count';
      } else {
        _nameCtrl.text = 'Document $count';
      }
    });
  }

  void _create() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop();

    if (_selectedType == CanvasDocType.notebook) {
      widget.state.createNotebook(name, defaultPaperStyle: _notebookTemplate);
      widget.state.setNavIndex(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created Notebook "$name"')),
      );
    } else if (_selectedType == CanvasDocType.canvas) {
      widget.state.createInfiniteCanvas(name, template: _whiteboardTemplate);
      widget.state.setNavIndex(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created Whiteboard "$name"')),
      );
    } else {
      widget.state.createTextDocument(name, template: _textDocTemplate);
      widget.state.setNavIndex(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created Document "$name"')),
      );
    }
  }

  Color get _accentColor {
    switch (_selectedType) {
      case CanvasDocType.notebook:
        return const Color(0xFF6366F1);
      case CanvasDocType.canvas:
        return const Color(0xFF10B981);
      case CanvasDocType.textDocument:
        return const Color(0xFF38BDF8);
    }
  }

  String get _createLabel {
    if (_selectedType == CanvasDocType.notebook) return 'Create Notebook';
    if (_selectedType == CanvasDocType.canvas) return 'Create Whiteboard';
    return 'Create Document';
  }

  IconData get _headerIcon {
    if (_selectedType == CanvasDocType.notebook) return Icons.menu_book_rounded;
    if (_selectedType == CanvasDocType.canvas) return Icons.all_out_rounded;
    return Icons.article_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.state.isDarkMode;
    final bg = isDark ? const Color(0xFF161B2B) : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final surfaceCard = isDark ? const Color(0xFF1E2538) : const Color(0xFFF8FAFC);
    final accent = _accentColor;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: FadeTransition(
        opacity: _fadeIn,
        child: SlideTransition(
          position: _slideIn,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 640),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.18),
                  blurRadius: 48,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: border))),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accent, accent.withValues(alpha: 0.65)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_headerIcon, color: Colors.white, size: 21),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create New',
                              style: GoogleFonts.inter(
                                fontSize: 17, fontWeight: FontWeight.w800,
                                color: textPrimary, letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Name it, pick a style & choose a starting template',
                              style: GoogleFonts.inter(fontSize: 12, color: textMuted),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(Icons.close_rounded, size: 18, color: textMuted),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Body ──────────────────────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Name Field
                        _buildSectionLabel('NAME', textMuted),
                        const SizedBox(height: 8),
                        _buildNameField(isDark, border, textPrimary, textMuted, surfaceCard, accent),
                        const SizedBox(height: 22),

                        // 2. Style Selector
                        _buildSectionLabel('STYLE', textMuted),
                        const SizedBox(height: 10),
                        _buildStyleRow(isDark, surfaceCard, border, textPrimary, textMuted),
                        const SizedBox(height: 22),

                        // 3. Template Selector
                        Row(
                          children: [
                            Icon(Icons.auto_awesome, size: 13, color: accent),
                            const SizedBox(width: 5),
                            _buildSectionLabel('STARTING TEMPLATE', textMuted),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildTemplateGrid(isDark, accent),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // ── Footer ────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: border))),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(foregroundColor: textMuted),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Spacer(),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _create,
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: Text(
                            _createLabel,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text, Color textMuted) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w800, color: textMuted, letterSpacing: 0.9,
      ),
    );
  }

  Widget _buildNameField(bool isDark, Color border, Color textPrimary,
      Color textMuted, Color surfaceCard, Color accent) {
    final hint = _selectedType == CanvasDocType.notebook
        ? 'e.g. Organic Chemistry II'
        : _selectedType == CanvasDocType.canvas
            ? 'e.g. System Architecture'
            : 'e.g. Product Spec Draft';
    return TextField(
      controller: _nameCtrl,
      autofocus: true,
      onSubmitted: (_) => _create(),
      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: textMuted, fontWeight: FontWeight.w400),
        filled: true,
        fillColor: surfaceCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accent, width: 1.8),
        ),
        prefixIcon: Icon(Icons.drive_file_rename_outline_rounded, size: 18, color: textMuted),
      ),
    );
  }

  Widget _buildStyleRow(bool isDark, Color surfaceCard, Color border, Color textPrimary, Color textMuted) {
    final styleItems = [
      (CanvasDocType.notebook, 'Notebook', 'Paginated A4 pages with handwriting & margins',
          Icons.menu_book_rounded, const Color(0xFF6366F1)),
      (CanvasDocType.canvas, 'Whiteboard', 'Infinite canvas for diagrams & brainstorming',
          Icons.all_out_rounded, const Color(0xFF10B981)),
      (CanvasDocType.textDocument, 'Text Document', 'Structured markdown with AI-powered notes',
          Icons.article_rounded, const Color(0xFF38BDF8)),
    ];

    return Row(
      children: styleItems.asMap().entries.map((entry) {
        final i = entry.key;
        final (type, title, subtitle, icon, accent) = entry.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < styleItems.length - 1 ? 10 : 0),
            child: _StyleCard(
              type: type,
              title: title,
              subtitle: subtitle,
              icon: icon,
              accentColor: accent,
              selected: _selectedType == type,
              isDark: isDark,
              surfaceCard: surfaceCard,
              border: border,
              textPrimary: textPrimary,
              textMuted: textMuted,
              onTap: () => _onStyleChanged(type),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTemplateGrid(bool isDark, Color accent) {
    final List<(String, String, String, IconData, CanvasPaperStyle?)> templates;

    if (_selectedType == CanvasDocType.notebook) {
      templates = [
        ('ruled', 'College Ruled', 'Ruled lines + red margin', Icons.format_align_left_rounded, CanvasPaperStyle.ruledLines),
        ('cornell', 'Cornell Notes', 'Cue column + summary footer', Icons.vertical_split_rounded, CanvasPaperStyle.cornell),
        ('dot', 'Dot Grid', 'Bullet journal 5mm dots', Icons.apps_rounded, CanvasPaperStyle.dotGrid),
        ('graph', 'Graph Grid', 'Math & engineering grid', Icons.grid_4x4_rounded, CanvasPaperStyle.graphGrid),
        ('blank', 'Blank Slate', 'Clean ivory paper', Icons.crop_portrait_rounded, CanvasPaperStyle.blankSlate),
      ];
    } else if (_selectedType == CanvasDocType.canvas) {
      templates = [
        ('blank', 'Blank Canvas', 'Open infinite whiteboard', Icons.crop_free_rounded, null),
        ('dots', 'Dot Matrix', 'Infinite coordinate dot grid', Icons.blur_on_rounded, null),
        ('mindmap', 'Mind Map Starter', 'Central topic card & ideas', Icons.hub_rounded, null),
        ('flowchart', 'Flowchart & Flow', 'Starter steps & process cards', Icons.schema_rounded, null),
      ];
    } else {
      templates = [
        ('lecture', 'Lecture Notes', 'Overview, topics & review', Icons.school_rounded, null),
        ('project', 'Project Spec', 'Goals, requirements & scope', Icons.assignment_turned_in_rounded, null),
        ('meeting', 'Meeting Minutes', 'Agenda, discussion & actions', Icons.groups_rounded, null),
        ('blank', 'Blank Document', 'Clean empty markdown file', Icons.description_outlined, null),
      ];
    }

    String selectedId;
    if (_selectedType == CanvasDocType.notebook) {
      selectedId = switch (_notebookTemplate) {
        CanvasPaperStyle.ruledLines => 'ruled',
        CanvasPaperStyle.cornell    => 'cornell',
        CanvasPaperStyle.dotGrid    => 'dot',
        CanvasPaperStyle.graphGrid  => 'graph',
        _                           => 'blank',
      };
    } else if (_selectedType == CanvasDocType.canvas) {
      selectedId = _whiteboardTemplate;
    } else {
      selectedId = _textDocTemplate;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      child: Wrap(
        key: ValueKey(_selectedType),
        spacing: 8,
        runSpacing: 8,
        children: templates.map((t) {
          final (id, name, desc, icon, paperStyle) = t;
          final isSelected = selectedId == id;
          return _TemplateChip(
            title: name,
            desc: desc,
            icon: icon,
            selected: isSelected,
            isDark: isDark,
            accentColor: accent,
            onTap: () {
              setState(() {
                if (_selectedType == CanvasDocType.notebook && paperStyle != null) {
                  _notebookTemplate = paperStyle;
                } else if (_selectedType == CanvasDocType.canvas) {
                  _whiteboardTemplate = id;
                } else {
                  _textDocTemplate = id;
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }
}

// ── Style Selection Card ──────────────────────────────────────────────────────
class _StyleCard extends StatelessWidget {
  final CanvasDocType type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool selected;
  final bool isDark;
  final Color surfaceCard, border, textPrimary, textMuted;
  final VoidCallback onTap;

  const _StyleCard({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.selected,
    required this.isDark,
    required this.surfaceCard,
    required this.border,
    required this.textPrimary,
    required this.textMuted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? accentColor.withValues(alpha: isDark ? 0.12 : 0.08) : surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accentColor : border,
            width: selected ? 2.0 : 1.0,
          ),
          boxShadow: selected
              ? [BoxShadow(color: accentColor.withValues(alpha: 0.2), blurRadius: 14, offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: accentColor),
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: selected
                      ? Icon(Icons.check_circle_rounded, key: const ValueKey('c'), size: 17, color: accentColor)
                      : Container(
                          key: const ValueKey('u'),
                          width: 15, height: 15,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: border, width: 1.5),
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700,
                  color: selected ? accentColor : textPrimary),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: GoogleFonts.inter(fontSize: 10.5, color: textMuted, height: 1.35),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Template Chip ─────────────────────────────────────────────────────────────
class _TemplateChip extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;
  final bool selected;
  final bool isDark;
  final Color accentColor;
  final VoidCallback onTap;

  const _TemplateChip({
    required this.title,
    required this.desc,
    required this.icon,
    required this.selected,
    required this.isDark,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = isDark ? accentColor.withValues(alpha: 0.11) : accentColor.withValues(alpha: 0.08);
    final inactiveBg = isDark ? const Color(0xFF161C2C) : const Color(0xFFF8FAFC);
    final borderColor = selected ? accentColor : (isDark ? AppColors.darkBorder : AppColors.lightBorder);
    final textColor = selected ? accentColor : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 180,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: selected ? 1.6 : 1.0),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: textColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    desc,
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
