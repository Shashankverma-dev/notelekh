import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:ai_workspace_client/state/app_state.dart';
import 'package:ai_workspace_client/core/models/canvas_models.dart';
import 'package:ai_workspace_client/core/services/pdf_extractor_service.dart';
import 'package:ai_workspace_client/core/services/pdf_viewer_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PDF Document Model & Study Pages
// ─────────────────────────────────────────────────────────────────────────────
class PdfDocumentData {
  final String id;
  final String title;
  final int fileSizeBytes;
  final int totalPages;
  final List<PdfPageData> pages;
  final Uint8List? rawBytes;

  const PdfDocumentData({
    required this.id,
    required this.title,
    required this.fileSizeBytes,
    required this.totalPages,
    required this.pages,
    this.rawBytes,
  });

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static PdfDocumentData createDefault(String fileName, {int sizeBytes = 345000, Uint8List? bytes}) {
    final cleanName = fileName.isNotEmpty ? fileName : 'Lecture_04_Neural_Networks.pdf';
    final baseTitle = cleanName
        .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
        .replaceAll('_', ' ')
        .trim();

    List<PdfPageData> pages = [];

    // 1. If actual PDF bytes are present, parse the real text from the user's PDF!
    if (bytes != null && bytes.isNotEmpty) {
      final extracted = PdfExtractorService.extractPages(bytes, docTitle: baseTitle);
      if (extracted.isNotEmpty) {
        pages = extracted.map((ep) {
          final text = ep.text;
          final lines = text
              .split(RegExp(r'\r?\n|\. '))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
          final summaryText = lines.take(2).join('. ');
          final bullets = lines.skip(2).take(4).toList();
          return PdfPageData(
            pageNumber: ep.pageNumber,
            sectionTitle: ep.title,
            summary: summaryText.isNotEmpty
                ? summaryText
                : (text.length > 200 ? '${text.substring(0, 200)}...' : text),
            bulletPoints: bullets.isNotEmpty
                ? bullets
                : [text.length > 100 ? '${text.substring(0, 100)}...' : text],
            keyTakeaway: lines.isNotEmpty ? lines.first : 'Notes from ${ep.title}',
            rawContent: text,
          );
        }).toList();
      }
    }

    // 2. Fallback if PDF has no text streams or when no bytes passed (e.g. preview / demo)
    if (pages.isEmpty) {
      pages = [
        PdfPageData(
          pageNumber: 1,
          sectionTitle: 'Chapter 1: $baseTitle - Overview',
          summary:
              'Core introduction and principles for $cleanName. Ready for direct handwriting, highlighting, and study notes.',
          bulletPoints: [
            'Fundamental definitions, axioms, and structural framework.',
            'Key architectural paradigms and standard methodology.',
            'Initial baseline equations and domain principles.',
          ],
          keyTakeaway:
              'Foundational concepts and principles required for master synthesis.',
          rawContent:
              'Chapter 1: $baseTitle Overview\n\nFoundational principles and formulas for active study and note-taking.',
        ),
        PdfPageData(
          pageNumber: 2,
          sectionTitle: 'Chapter 2: Analytical Methods & Theorems',
          summary:
              'In-depth exploration of core theorems, mathematical formulations, and proof strategies.',
          bulletPoints: [
            'Rigorous derivation of key properties and operating limits.',
            'Comparative analysis of classical vs modern frameworks.',
            'Parametric optimization and boundary constraints.',
          ],
          keyTakeaway:
              'Theoretical mechanics and rigorous validation techniques.',
          rawContent:
              'Chapter 2: Analytical Methods & Theorems\n\nIn-depth mathematical formulations and boundary limits.',
        ),
        PdfPageData(
          pageNumber: 3,
          sectionTitle: 'Chapter 3: Experimental Results & Applications',
          summary:
              'Empirical validation, benchmark evaluations, and practical implementation patterns.',
          bulletPoints: [
            'Empirical testing methodology and observational data.',
            'Performance metrics, error bounds, and scaling curves.',
            'Real-world case studies and industry best practices.',
          ],
          keyTakeaway:
              'Empirical outcomes establish high precision across standard benchmarks.',
          rawContent:
              'Chapter 3: Experimental Results & Applications\n\nEmpirical validation, benchmark metrics, and practical implementations.',
        ),
        PdfPageData(
          pageNumber: 4,
          sectionTitle: 'Chapter 4: Synthesis, Future Work & Review Questions',
          summary:
              'Comprehensive synthesis, summary review checklists, and practice study questions.',
          bulletPoints: [
            'Synthesis checklist covering all foundational takeaways.',
            'Open problems, research extensions, and next steps.',
            'Self-test review prompts for spaced repetition recall.',
          ],
          keyTakeaway:
              'Mastery of concepts through active recall and handwritten problem-solving.',
          rawContent:
              'Chapter 4: Synthesis & Review\n\nComprehensive review checklist and study synthesis.',
        ),
      ];
    }

    return PdfDocumentData(
      id: 'pdf-doc-${DateTime.now().millisecondsSinceEpoch}',
      title: cleanName,
      fileSizeBytes: sizeBytes > 0 ? sizeBytes : 345000,
      totalPages: pages.length,
      rawBytes: bytes,
      pages: pages,
    );
  }
}

class PdfPageData {
  final int pageNumber;
  final String sectionTitle;
  final String summary;
  final List<String> bulletPoints;
  final String keyTakeaway;
  final String? rawContent;

  const PdfPageData({
    required this.pageNumber,
    required this.sectionTitle,
    required this.summary,
    required this.bulletPoints,
    required this.keyTakeaway,
    this.rawContent,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Authentic GoodNotes PDF Document Card for Canvas
// ─────────────────────────────────────────────────────────────────────────────
class GoodNotesPdfCanvasCard extends StatefulWidget {
  final CanvasNoteCardItem card;
  final bool isDark;
  final VoidCallback onOpenStudyReader;
  final VoidCallback onImportToNotebook;
  final VoidCallback onRemove;
  final void Function(Offset delta) onMove;

  const GoodNotesPdfCanvasCard({
    super.key,
    required this.card,
    required this.isDark,
    required this.onOpenStudyReader,
    required this.onImportToNotebook,
    required this.onRemove,
    required this.onMove,
  });

  @override
  State<GoodNotesPdfCanvasCard> createState() => _GoodNotesPdfCanvasCardState();
}

class _GoodNotesPdfCanvasCardState extends State<GoodNotesPdfCanvasCard> {
  int _activePage = 1;
  late PdfDocumentData _docData;

  @override
  void initState() {
    super.initState();
    _docData = PdfDocumentData.createDefault(
      widget.card.title.replaceAll('📄', '').trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBg = isDark ? const Color(0xFF1E2436) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final currentPageData = _docData.pages[(_activePage - 1).clamp(0, _docData.pages.length - 1)];

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 360,
        height: 250,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            // ── Top Draggable Bar ───────────────────────────
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) => widget.onMove(d.delta),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161B2E) : const Color(0xFFF8FAFC),
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    const MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Icon(Icons.drag_indicator_rounded, size: 15, color: Colors.grey),
                    ),
                    const SizedBox(width: 4),
                    // Red PDF pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE11D48),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'PDF',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _docData.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    // Quick Action: Open Study Reader
                    Tooltip(
                      message: 'Open Side-by-Side Study Reader',
                      child: IconButton(
                        icon: const Icon(Icons.vertical_split_rounded, size: 16, color: Color(0xFFE11D48)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        onPressed: widget.onOpenStudyReader,
                      ),
                    ),
                    // Quick Action: Import as Notebook Pages
                    Tooltip(
                      message: 'Import into Notebook Pages',
                      child: IconButton(
                        icon: const Icon(Icons.post_add_rounded, size: 17, color: Color(0xFF2563EB)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        onPressed: widget.onImportToNotebook,
                      ),
                    ),
                    // Close / Remove
                    Tooltip(
                      message: 'Remove Document Card',
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        onPressed: widget.onRemove,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Document Page Preview Body ──────────────────
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                color: isDark ? const Color(0xFF131722) : const Color(0xFFF1F5F9),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2436) : const Color(0xFFFFFDF8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE5DECE),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Document Chapter Title & Page Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              currentPageData.sectionTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white12 : const Color(0xFFEDE8DD),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'p. $_activePage',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Summary preview
                      Expanded(
                        child: Text(
                          currentPageData.summary,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            height: 1.35,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Key takeaway banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48).withValues(alpha: isDark ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFE11D48).withValues(alpha: 0.25),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lightbulb_outline_rounded, size: 12, color: Color(0xFFE11D48)),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                currentPageData.keyTakeaway,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFE11D48),
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

            // ── Footer Controls Bar ─────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B2E) : Colors.white,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  // Page flipper
                  InkWell(
                    onTap: _activePage > 1 ? () => setState(() => _activePage--) : null,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: 16,
                        color: _activePage > 1 ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                      ),
                    ),
                  ),
                  Text(
                    '$_activePage / ${_docData.totalPages}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                  ),
                  InkWell(
                    onTap: _activePage < _docData.totalPages ? () => setState(() => _activePage++) : null,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: _activePage < _docData.totalPages ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Study button
                  InkWell(
                    onTap: widget.onOpenStudyReader,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.menu_book_rounded, size: 12, color: Color(0xFFE11D48)),
                          const SizedBox(width: 3),
                          Text(
                            'Study',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFE11D48),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Annotate button
                  InkWell(
                    onTap: widget.onImportToNotebook,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit_note_rounded, size: 12, color: Color(0xFF2563EB)),
                          const SizedBox(width: 3),
                          Text(
                            'Annotate',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ],
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
}

// ─────────────────────────────────────────────────────────────────────────────
// GoodNotes Side-by-Side PDF Study Split-Screen Reader Panel
// ─────────────────────────────────────────────────────────────────────────────
class GoodNotesPdfStudyPanel extends StatefulWidget {
  final PdfDocumentData document;
  final bool isDark;
  final VoidCallback onClose;
  final void Function(int pageNumber, String text) onInsertPageToNotebook;
  final void Function(String text) onCopyTextToCanvas;
  final VoidCallback? onImportAllToNotebook;

  const GoodNotesPdfStudyPanel({
    super.key,
    required this.document,
    required this.isDark,
    required this.onClose,
    required this.onInsertPageToNotebook,
    required this.onCopyTextToCanvas,
    this.onImportAllToNotebook,
  });

  @override
  State<GoodNotesPdfStudyPanel> createState() => _GoodNotesPdfStudyPanelState();
}

class _GoodNotesPdfStudyPanelState extends State<GoodNotesPdfStudyPanel> {
  int _currentPage = 1;
  double _zoom = 1.0;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? const Color(0xFF0F131D) : const Color(0xFFF8FAFC);
    final sheetBg = isDark ? const Color(0xFF1E2436) : const Color(0xFFFFFDF8);
    final borderColor = isDark ? const Color(0xFF2B3448) : const Color(0xFFE2E8F0);
    final curPage = widget.document.pages[(_currentPage - 1).clamp(0, widget.document.pages.length - 1)];

    final screenW = MediaQuery.of(context).size.width;
    final panelWidth = math.min(480.0, math.max(340.0, screenW * 0.38));
    final sheetWidth = (370.0 * _zoom).clamp(260.0, panelWidth - 36.0);

    return Container(
      width: panelWidth,
      decoration: BoxDecoration(
        color: bg,
        border: Border(left: BorderSide(color: borderColor, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.15),
            blurRadius: 24,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header Bar ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B2A) : Colors.white,
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFE11D48), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.document.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'GoodNotes Study Mode • ${widget.document.formattedSize}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onImportAllToNotebook != null)
                  Tooltip(
                    message: 'Import all pages into notebook for direct pen annotations',
                    child: TextButton.icon(
                      onPressed: widget.onImportAllToNotebook,
                      icon: const Icon(Icons.post_add_rounded, size: 15, color: Color(0xFF2563EB)),
                      label: Text(
                        'Annotate All',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                if (widget.document.rawBytes != null && widget.document.rawBytes!.isNotEmpty)
                  Tooltip(
                    message: 'Open original PDF in browser tab',
                    child: IconButton(
                      icon: const Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF64748B)),
                      onPressed: () {
                        openPdfInBrowserTab(widget.document.rawBytes!, '${widget.document.title}.pdf');
                      },
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Close Study View',
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // ── Study Toolbar (Navigation & Zoom) ───────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141825) : const Color(0xFFF1F5F9),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                // Page Flipper
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 14),
                  tooltip: 'Previous Page',
                  onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white12 : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    'Page $_currentPage of ${widget.document.totalPages}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  tooltip: 'Next Page',
                  onPressed: _currentPage < widget.document.totalPages ? () => setState(() => _currentPage++) : null,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                ),
                const Spacer(),
                // Zoom out
                InkWell(
                  onTap: () => setState(() => _zoom = (_zoom - 0.15).clamp(0.7, 1.6)),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.zoom_out_rounded, size: 16, color: isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
                Text(
                  '${(_zoom * 100).toInt()}%',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey),
                ),
                // Zoom in
                InkWell(
                  onTap: () => setState(() => _zoom = (_zoom + 0.15).clamp(0.7, 1.6)),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.zoom_in_rounded, size: 16, color: isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ],
            ),
          ),

          // ── Scrollable Document Sheet ───────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Container(
                  width: sheetWidth,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: sheetBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE5DECE),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Page Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'STUDY DOCUMENT',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: const Color(0xFFE11D48),
                            ),
                          ),
                          Row(
                            children: [
                              Tooltip(
                                message: 'Copy page summary to clipboard',
                                child: InkWell(
                                  onTap: () {
                                    final text = '${curPage.sectionTitle}\n\n${curPage.summary}\n\nKey Points:\n${curPage.bulletPoints.map((b) => '• $b').join('\n')}';
                                    Clipboard.setData(ClipboardData(text: text));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Copied document excerpt to clipboard!'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: const Padding(
                                    padding: EdgeInsets.all(3),
                                    child: Icon(Icons.copy_rounded, size: 14, color: Colors.grey),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'PAGE $_currentPage OF ${widget.document.totalPages}',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 18),
                      Text(
                        curPage.sectionTitle,
                        style: GoogleFonts.inter(
                          fontSize: 16 * _zoom.clamp(0.85, 1.25),
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        curPage.summary,
                        style: GoogleFonts.inter(
                          fontSize: 12.5 * _zoom.clamp(0.85, 1.25),
                          height: 1.6,
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Key Concepts & Principles:',
                        style: GoogleFonts.inter(
                          fontSize: 12 * _zoom.clamp(0.85, 1.25),
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...curPage.bulletPoints.map((bp) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.bold)),
                              Expanded(
                                child: SelectableText(
                                  bp,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5 * _zoom.clamp(0.85, 1.25),
                                    height: 1.45,
                                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 14),
                      // Callout Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48).withValues(alpha: isDark ? 0.12 : 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.bookmark_added_rounded, color: Color(0xFFE11D48), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                curPage.keyTakeaway,
                                style: GoogleFonts.inter(
                                  fontSize: 11 * _zoom.clamp(0.85, 1.25),
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF881337),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (curPage.rawContent != null && curPage.rawContent!.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Full Extracted Text:',
                          style: GoogleFonts.inter(
                            fontSize: 12 * _zoom.clamp(0.85, 1.25),
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: SelectableText(
                            curPage.rawContent!.trim(),
                            style: GoogleFonts.inter(
                              fontSize: 11 * _zoom.clamp(0.85, 1.25),
                              height: 1.55,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom Action Strip ─────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B2A) : Colors.white,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final snippet = '${curPage.sectionTitle}\n\n${curPage.summary}';
                      widget.onCopyTextToCanvas(snippet);
                    },
                    icon: const Icon(Icons.note_add_rounded, size: 15),
                    label: const Text('Add as Note Card', style: TextStyle(fontSize: 11.5)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      foregroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      final content = '${curPage.sectionTitle}\n\n${curPage.summary}\n\nKey Concepts:\n${curPage.bulletPoints.map((b) => '• $b').join('\n')}\n\nTakeaway:\n${curPage.keyTakeaway}';
                      widget.onInsertPageToNotebook(_currentPage, content);
                    },
                    icon: const Icon(Icons.post_add_rounded, size: 15),
                    label: const Text('Add to Notebook', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GoodNotes-grade PDF Import Options Dialog
// ─────────────────────────────────────────────────────────────────────────────
Future<void> showGoodNotesPdfImportDialog({
  required BuildContext context,
  required AppState state,
  required String fileName,
  required int sizeBytes,
  Uint8List? fileBytes,
  required void Function(PdfDocumentData doc) onSelectStudyCard,
  required void Function(PdfDocumentData doc) onImportAsNotebookPages,
}) async {
  final isDark = state.isDarkMode;
  final docData = PdfDocumentData.createDefault(
    fileName,
    sizeBytes: sizeBytes,
    bytes: fileBytes,
  );

  await showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131722) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF2A3447) : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.18),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFE11D48), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import PDF Document',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '${docData.title} • ${docData.formattedSize} • ${docData.totalPages} pages',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 24),
              Text(
                'How would you like to study this document?',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 12),

              // Option 1: Import directly as Notebook Pages
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  onImportAsNotebookPages(docData);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2436) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.post_add_rounded, color: Color(0xFF2563EB), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Import as Notebook Pages (Annotate Directly)',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Appends pages to your notebook so you can draw, highlight, sketch, and write with pens directly on the document.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                height: 1.35,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Option 2: Side-by-Side Study Reader & Canvas Card
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  onSelectStudyCard(docData);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2436) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.vertical_split_rounded, color: Color(0xFFE11D48), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Side-by-Side Study Reader (Split Screen)',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Places a PDF card on the canvas and opens a docked study reader to reference materials while taking notes.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                height: 1.35,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    ],
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
