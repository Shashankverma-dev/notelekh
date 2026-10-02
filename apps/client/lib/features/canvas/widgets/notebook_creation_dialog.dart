import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_workspace_client/core/models/canvas_models.dart';
import 'package:ai_workspace_client/core/theme/app_theme.dart';
import 'package:ai_workspace_client/state/app_state.dart';

class NotebookCreationDialog extends StatefulWidget {
  final AppState state;

  const NotebookCreationDialog({super.key, required this.state});

  static Future<void> show(BuildContext context, {required AppState state}) {
    return showDialog(
      context: context,
      builder: (ctx) => NotebookCreationDialog(state: state),
    );
  }

  @override
  State<NotebookCreationDialog> createState() => _NotebookCreationDialogState();
}

class _NotebookCreationDialogState extends State<NotebookCreationDialog> {
  final _nameController = TextEditingController(text: 'My Notebook');
  CanvasPaperStyle _selectedTemplate = CanvasPaperStyle.ruledLines;
  Color _selectedCover = const Color(0xFF2E7D32);
  String _selectedEmoji = '📓';
  bool _isCreating = false;

  static const _coverColors = [
    Color(0xFF2E7D32),   // Forest Green
    Color(0xFF1E3A8A),   // Navy
    Color(0xFF7C3AED),   // Violet
    Color(0xFFBE123C),   // Crimson
    Color(0xFFD97706),   // Amber
    Color(0xFF0F766E),   // Teal
    Color(0xFF374151),   // Slate
    Color(0xFF6B21A8),   // Purple
    Color(0xFF9D174D),   // Rose
    Color(0xFF1E40AF),   // Blue
    Color(0xFF065F46),   // Emerald
    Color(0xFF92400E),   // Brown
  ];

  static const _coverEmojis = ['📓', '📔', '📒', '📕', '📗', '📘', '📙', '🗒️', '✏️', '🎨', '💡', '🔬'];

  static const _templates = [
    (CanvasPaperStyle.ruledLines, 'Ruled', Icons.format_align_left_rounded),
    (CanvasPaperStyle.dotGrid, 'Dot Grid', Icons.apps_rounded),
    (CanvasPaperStyle.graphGrid, 'Graph', Icons.grid_4x4_rounded),
    (CanvasPaperStyle.blankSlate, 'Blank', Icons.crop_portrait_rounded),
    (CanvasPaperStyle.cornell, 'Cornell', Icons.vertical_split_rounded),
    (CanvasPaperStyle.narrowRuled, 'Narrow', Icons.format_align_left_rounded),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.state.isDarkMode;
    final bg = isDark ? const Color(0xFF151922) : Colors.white;
    final border = isDark ? const Color(0xFF252A3A) : const Color(0xFFE8ECEF);
    final textPrimary = isDark ? const Color(0xFFF0F2FF) : const Color(0xFF1E293B);
    final textMuted = isDark ? const Color(0xFF4A5270) : const Color(0xFF8B95A5);
    final sectionBg = isDark ? const Color(0xFF1A1E2B) : const Color(0xFFF8FAFC);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        width: 560,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 18),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  // Notebook preview cover
                  _buildNotebookPreview(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('New Notebook',
                            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
                        const SizedBox(height: 2),
                        Text('Set up your notebook below',
                            style: GoogleFonts.inter(fontSize: 12.5, color: textMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: textMuted,
                    padding: const EdgeInsets.all(4),
                  ),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name input
                  _fieldLabel('NOTEBOOK NAME', textMuted),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    autofocus: true,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                    decoration: InputDecoration(
                      hintText: 'My Notebook',
                      hintStyle: GoogleFonts.inter(color: textMuted, fontSize: 14),
                      filled: true,
                      fillColor: sectionBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Paper template
                  _fieldLabel('PAPER TEMPLATE', textMuted),
                  const SizedBox(height: 10),
                  _buildTemplateGrid(isDark, border),
                  const SizedBox(height: 20),

                  // Cover color
                  _fieldLabel('COVER COLOR', textMuted),
                  const SizedBox(height: 10),
                  _buildCoverColors(border),
                  const SizedBox(height: 20),

                  // Cover emoji
                  _fieldLabel('COVER ICON', textMuted),
                  const SizedBox(height: 10),
                  _buildEmojiRow(),
                  const SizedBox(height: 24),

                  // Create button
                  SizedBox(
                    width: double.infinity,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: ElevatedButton(
                        onPressed: _isCreating ? null : _createNotebook,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedCover,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _isCreating
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(_selectedEmoji, style: const TextStyle(fontSize: 18)),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Create Notebook',
                                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotebookPreview() {
    return Container(
      width: 56, height: 70,
      decoration: BoxDecoration(
        color: _selectedCover,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(3),
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
          bottomLeft: Radius.circular(3),
        ),
        boxShadow: [
          BoxShadow(color: _selectedCover.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(2, 4)),
        ],
      ),
      child: Stack(
        children: [
          // Spine
          Container(
            width: 7,
            decoration: BoxDecoration(
              color: _selectedCover.withValues(alpha: 0.7),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3),
                bottomLeft: Radius.circular(3),
              ),
            ),
          ),
          Center(
            child: Text(_selectedEmoji, style: const TextStyle(fontSize: 24)),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateGrid(bool isDark, Color border) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _templates.map((t) {
        final isSelected = _selectedTemplate == t.$1;
        return GestureDetector(
          onTap: () => setState(() => _selectedTemplate = t.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            width: 84, height: 60,
            decoration: BoxDecoration(
              color: isSelected
                  ? _selectedCover.withValues(alpha: 0.12)
                  : (isDark ? const Color(0xFF1A1E2B) : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? _selectedCover : border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(t.$3, size: 18, color: isSelected ? _selectedCover : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                const SizedBox(height: 4),
                Text(t.$2,
                    style: GoogleFonts.inter(
                      fontSize: 10.5, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? _selectedCover : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCoverColors(Color border) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _coverColors.map((c) {
        final isSelected = _selectedCover.toARGB32() == c.toARGB32();
        return GestureDetector(
          onTap: () => setState(() => _selectedCover = c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)]
                  : [BoxShadow(color: c.withValues(alpha: 0.2), blurRadius: 4)],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmojiRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _coverEmojis.map((e) {
          final isSelected = _selectedEmoji == e;
          return GestureDetector(
            onTap: () => setState(() => _selectedEmoji = e),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.only(right: 8),
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isSelected ? _selectedCover.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? _selectedCover : Colors.transparent,
                  width: isSelected ? 1.5 : 0,
                ),
              ),
              child: Center(child: Text(e, style: const TextStyle(fontSize: 20))),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _fieldLabel(String text, Color color) {
    return Text(text,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.8));
  }

  Future<void> _createNotebook() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isCreating = true);

    try {
      await widget.state.createCanvasDoc(
        name: name,
        paperStyle: _selectedTemplate,
        coverColor: _selectedCover,
        coverEmoji: _selectedEmoji,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() => _isCreating = false);
    }
  }
}
