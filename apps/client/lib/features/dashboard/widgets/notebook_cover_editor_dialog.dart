import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_workspace_client/state/app_state.dart';
import 'package:ai_workspace_client/features/canvas/models/page_model.dart';
import 'package:ai_workspace_client/features/dashboard/widgets/notebook_cover_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry-point
// ─────────────────────────────────────────────────────────────────────────────
Future<void> showNotebookCoverEditor(
  BuildContext context,
  AppState state,
  String docId,
) async {
  final doc = state.canvasDocs.firstWhere(
    (d) => d.id == docId,
    orElse: () => state.currentCanvasDoc!,
  );
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => NotebookCoverEditorDialog(state: state, doc: doc),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog widget
// ─────────────────────────────────────────────────────────────────────────────
class NotebookCoverEditorDialog extends StatefulWidget {
  final AppState state;
  final CanvasDocModel doc;
  const NotebookCoverEditorDialog({super.key, required this.state, required this.doc});

  @override
  State<NotebookCoverEditorDialog> createState() => _NotebookCoverEditorDialogState();
}

class _NotebookCoverEditorDialogState extends State<NotebookCoverEditorDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Color _color;
  late String _emoji;
  late String _style;
  late String _styleData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _color = widget.doc.coverColor;
    _emoji = widget.doc.coverEmoji;
    _style = widget.doc.coverStyle.isNotEmpty ? widget.doc.coverStyle : 'solid';
    _styleData = widget.doc.coverStyleData;
    switch (_style) {
      case 'gradient':
        _tabController.index = 1;
        break;
      case 'pattern':
        _tabController.index = 2;
        break;
      default:
        _tabController.index = 0;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _save() {
    widget.state.updateNotebookCover(
      widget.doc.id,
      coverColor: _color,
      coverEmoji: _emoji,
      coverStyle: _style,
      coverStyleData: _styleData,
    );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Cover updated for "${widget.doc.name}"'),
          ],
        ),
        backgroundColor: const Color(0xFF15803D),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getSelectedColorName(Color color) {
    for (final item in LuxuryCoverTheme.solidColors) {
      if (item.$1.toARGB32() == color.toARGB32()) {
        return item.$2;
      }
    }
    return 'Custom';
  }

  Widget _buildPreview(bool isDark) {
    return Center(
      child: NotebookCoverWidget(
        title: widget.doc.name,
        pageCount: widget.doc.pages.length,
        docType: widget.doc.docType,
        coverColor: _color,
        coverEmoji: _emoji,
        coverStyle: _style,
        coverStyleData: _styleData,
        width: 148,
        height: 188,
        isDark: isDark,
      ),
    );
  }

  Widget _buildColorsTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CURATED BOOKCLOTH & LEATHER',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
              if (_style == 'solid')
                Text(
                  _getSelectedColorName(_color),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF15803D),
                  ),
                ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: LuxuryCoverTheme.solidColors.length,
          itemBuilder: (ctx, i) {
            final item = LuxuryCoverTheme.solidColors[i];
            final c = item.$1;
            final name = item.$2;
            final sel = _style == 'solid' && _color.toARGB32() == c.toARGB32();
            return Tooltip(
              message: name,
              child: GestureDetector(
                onTap: () => setState(() {
                  _color = c;
                  _style = 'solid';
                  _styleData = '';
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: sel ? Colors.white : Colors.black.withValues(alpha: 0.15),
                      width: sel ? 3 : 1,
                    ),
                    boxShadow: sel
                        ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 1)]
                        : [],
                  ),
                  child: sel
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                      : null,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGradientsTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'LUXURY DUO-TONE GRADIENTS',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.1,
          ),
          itemCount: LuxuryCoverTheme.gradients.length,
          itemBuilder: (ctx, i) {
            final g = LuxuryCoverTheme.gradients[i];
            final data = '${g[0]},${g[1]}';
            final sel = _style == 'gradient' && _styleData == data;
            final c1 = parseHexColor(g[0]);
            final c2 = parseHexColor(g[1]);
            return GestureDetector(
              onTap: () => setState(() {
                _style = 'gradient';
                _styleData = data;
                _color = c1;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [c1, c2],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sel ? Colors.white : Colors.white.withValues(alpha: 0.2),
                    width: sel ? 2.5 : 1,
                  ),
                  boxShadow: sel
                      ? [BoxShadow(color: c1.withValues(alpha: 0.5), blurRadius: 8)]
                      : [],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        g[2],
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (sel)
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 14),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPatternsTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'PHYSICAL EMBOSSED TEXTURES',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.1,
          ),
          itemCount: LuxuryCoverTheme.patterns.length,
          itemBuilder: (ctx, i) {
            final p = LuxuryCoverTheme.patterns[i];
            final pKey = p.$1;
            final pName = p.$2;
            final pIcon = p.$3;
            final sel = _style == 'pattern' && _styleData == pKey;
            return GestureDetector(
              onTap: () => setState(() {
                _style = 'pattern';
                _styleData = pKey;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sel
                        ? const Color(0xFF15803D)
                        : (isDark ? const Color(0xFF384357) : const Color(0xFFCBD5E1)),
                    width: sel ? 2.5 : 1,
                  ),
                  boxShadow: sel
                      ? [BoxShadow(color: const Color(0xFF15803D).withValues(alpha: 0.4), blurRadius: 6)]
                      : [],
                ),
                clipBehavior: Clip.hardEdge,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: CoverPatternPainter(type: pKey, baseColor: _color),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.65)
                            : Colors.white.withValues(alpha: 0.85),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(pIcon, size: 11, color: isDark ? Colors.white70 : const Color(0xFF1E293B)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                pName,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (sel)
                      const Positioned(
                        top: 4,
                        right: 4,
                        child: Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 16),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Base Tone for Texture',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white60 : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 30,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: LuxuryCoverTheme.solidColors.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (ctx, i) {
              final c = LuxuryCoverTheme.solidColors[i].$1;
              final name = LuxuryCoverTheme.solidColors[i].$2;
              final sel = _color.toARGB32() == c.toARGB32();
              return Tooltip(
                message: name,
                child: GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: sel ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: sel
                          ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 4)]
                          : [],
                    ),
                    child: sel
                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmojiRow(bool isDark) {
    const emblems = [
      ('', 'None (Classic Bookplate)'),
      ('📓', 'Classic Journal'),
      ('📖', 'Open Book'),
      ('🖋️', 'Fountain Pen'),
      ('🌿', 'Botanical Leaf'),
      ('🏛️', 'Classical Column'),
      ('⚜️', 'Fleur-de-lis'),
      ('📜', 'Archival Scroll'),
      ('🧭', 'Navigator Compass'),
      ('⚖️', 'Scales of Justice'),
      ('💼', 'Executive Portfolio'),
      ('🎓', 'Academic Scholar'),
      ('☕', 'Espresso Roastery'),
      ('📐', 'Architect Ruler'),
      ('🎨', 'Artist Palette'),
      ('✨', 'Constellation'),
      ('🔬', 'Laboratory Science'),
      ('💡', 'Ideation Beacon'),
      ('🚀', 'Discovery Rocket'),
      ('⭐', 'Prestige Star'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'COVER CREST / EMBLEM',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
            Text(
              _emoji.isEmpty || _emoji == 'none'
                  ? 'Classic Plain Plate'
                  : 'Emblem Active',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF15803D),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: emblems.map((item) {
            final code = item.$1;
            final label = item.$2;
            final isNone = code.isEmpty;
            final sel = (isNone && (_emoji.isEmpty || _emoji == 'none')) || _emoji == code;

            if (isNone) {
              return Tooltip(
                message: label,
                child: GestureDetector(
                  onTap: () => setState(() => _emoji = ''),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFF15803D).withValues(alpha: 0.18)
                          : (isDark ? const Color(0xFF1E2433) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: sel ? const Color(0xFF15803D) : Colors.transparent,
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.block_rounded,
                          size: 14,
                          color: sel ? const Color(0xFF15803D) : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'None',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: sel ? const Color(0xFF15803D) : (isDark ? Colors.white70 : const Color(0xFF334155)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Tooltip(
              message: label,
              child: GestureDetector(
                onTap: () => setState(() => _emoji = code),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFF15803D).withValues(alpha: 0.18)
                        : (isDark ? const Color(0xFF1E2433) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: sel ? const Color(0xFF15803D) : Colors.transparent,
                      width: sel ? 2 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(code, style: const TextStyle(fontSize: 18)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.state.isDarkMode;
    final dialogBg = isDark ? const Color(0xFF131722) : Colors.white;
    final tabBg = isDark ? const Color(0xFF1E2433) : const Color(0xFFF1F5F9);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textMuted = isDark ? Colors.white54 : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF2A3447) : const Color(0xFFE2E8F0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: dialogBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.16),
                blurRadius: 28,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF15803D).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.palette_outlined,
                        color: Color(0xFF15803D),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Notebook Cover',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            widget.doc.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 20, color: textMuted),
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Scrollable body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Real Realistic Preview
                      _buildPreview(isDark),
                      const SizedBox(height: 18),

                      // Style Tabs
                      Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: tabBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: const Color(0xFF15803D),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                          unselectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                          labelColor: Colors.white,
                          unselectedLabelColor: textMuted,
                          tabs: const [
                            Tab(text: '🎨 Solid Leather'),
                            Tab(text: '🌈 Silk Gradient'),
                            Tab(text: '📐 Tactile Pattern'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Tab View contents
                      SizedBox(
                        height: 170,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            SingleChildScrollView(child: _buildColorsTab(isDark)),
                            SingleChildScrollView(child: _buildGradientsTab(isDark)),
                            SingleChildScrollView(child: _buildPatternsTab(isDark)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),

                      // Crest selector
                      _buildEmojiRow(isDark),
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F121B) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: textMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: Text(
                        'Save Cover',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF15803D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
