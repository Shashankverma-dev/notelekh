import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Color, Paint, PaintingStyle, StrokeCap, StrokeJoin, Path, Offset, Rect, RRect, Radius, TextAlign;
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:ai_workspace_client/core/models/workspace_model.dart';
import 'package:ai_workspace_client/features/canvas/models/page_model.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke.dart';
import 'package:ai_workspace_client/features/canvas/engine/stroke_renderer.dart';
import 'package:ai_workspace_client/core/services/file_download_helper.dart';

class WorkspaceExportService {
  // ── Notebook Export (single doc, named after the notebook) ────────────────
  /// Export a single notebook/doc as the chosen format.
  /// The downloaded file is named `<NotebookName>.<ext>` (no suffix).
  static Future<void> exportNotebook({
    required CanvasDocModel doc,
    required String format,
  }) async {
    final cleanFormat = format.toLowerCase().trim();
    final safeName = doc.name
        .replaceAll(RegExp(r'[^\w\s-]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    final baseName = safeName.isNotEmpty ? safeName : 'notebook';

    switch (cleanFormat) {
      case 'pdf':
        await _exportNotebookAsPdf(doc, baseName);
        break;
      case 'docx':
      case 'word':
        await _exportNotebookAsDocx(doc, baseName);
        break;
      case 'md':
      case 'markdown':
        await _exportNotebookAsMarkdown(doc, baseName);
        break;
      case 'txt':
      case 'text':
      default:
        await _exportNotebookAsText(doc, baseName);
        break;
    }
  }

  /// Export a single active page of a notebook as a high-fidelity PNG image.
  static Future<void> exportActivePageAsPng({
    required CanvasDocModel doc,
    required int pageIndex,
  }) async {
    if (doc.pages.isEmpty) return;
    final idx = pageIndex.clamp(0, doc.pages.length - 1);
    final page = doc.pages[idx];
    const double pxW = 1720.0;
    const double pxH = 2400.0;
    final pngBytes = await _renderPageToImage(page: page, width: pxW, height: pxH);
    final safeName = doc.name
        .replaceAll(RegExp(r'[^\w\s-]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    final baseName = safeName.isNotEmpty ? safeName : 'notebook';
    FileDownloadHelper.downloadBytes(
      bytes: pngBytes,
      filename: '${baseName}_page_${idx + 1}.png',
      mimeType: 'image/png',
    );
  }

  // ── Notebook PDF (true canvas render — captures all handwriting & drawings) ─
  static Future<void> _exportNotebookAsPdf(
    CanvasDocModel doc,
    String baseName,
  ) async {
    // A4 at 2× pixel density for sharp output (matches 860×1200 native page ratio)
    const double pxW = 1720.0; // 860 * 2
    const double pxH = 2400.0; // 1200 * 2

    final pdf = pw.Document(
      title: doc.name,
      author: 'Notelekh',
      creator: 'Notelekh Notes',
    );

    final fontBold = pw.Font.helveticaBold();
    final fontRegular = pw.Font.helvetica();

    // ── Cover page ──────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.Container(
          width: double.infinity,
          height: double.infinity,
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              begin: pw.Alignment.topLeft,
              end: pw.Alignment.bottomRight,
              colors: [
                PdfColor.fromHex('#1E293B'),
                PdfColor.fromHex('#0F172A'),
              ],
            ),
          ),
          child: pw.Padding(
            padding: const pw.EdgeInsets.all(60),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  doc.coverEmoji.isNotEmpty ? doc.coverEmoji : '📓',
                  style: pw.TextStyle(font: fontRegular, fontSize: 56),
                ),
                pw.SizedBox(height: 24),
                pw.Text(
                  doc.name,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 36,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  '${doc.pages.length} page${doc.pages.length == 1 ? '' : 's'}',
                  style: pw.TextStyle(
                    font: fontRegular,
                    fontSize: 14,
                    color: PdfColors.grey400,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Exported ${DateTime.now().toLocal().toString().split('.')[0]}',
                  style: pw.TextStyle(
                    font: fontRegular,
                    fontSize: 12,
                    color: PdfColors.grey500,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Notelekh',
                  style: pw.TextStyle(
                    font: fontRegular,
                    fontSize: 11,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // ── One A4 page per notebook page ────────────────────────────────────────
    for (int pi = 0; pi < doc.pages.length; pi++) {
      final page = doc.pages[pi];

      // Render this canvas page to a PNG image at A4@200dpi
      final pngBytes = await _renderPageToImage(
        page: page,
        width: pxW,
        height: pxH,
      );

      final pwImage = pw.MemoryImage(pngBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (ctx) => pw.Stack(
            children: [
              // Full-page canvas image
              pw.Positioned.fill(
                child: pw.Image(pwImage, fit: pw.BoxFit.fill),
              ),
              // Page header: notebook name + page number
              pw.Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F8FAFC'),
                    border: const pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        doc.name,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 8.5,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        'Page ${pi + 1} of ${doc.pages.length}${page.title != 'Page ${pi + 1}' ? ' · ${page.title}' : ''}',
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 8.5,
                          color: PdfColors.grey500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bytes = await pdf.save();
    FileDownloadHelper.downloadBytes(
      bytes: Uint8List.fromList(bytes),
      filename: '$baseName.pdf',
      mimeType: 'application/pdf',
    );
  }

  // ── Render a CanvasPage to a raw PNG Uint8List at the given pixel size ─────
  static Future<Uint8List> _renderPageToImage({
    required CanvasPage page,
    required double width,
    required double height,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width, height),
    );

    // 1. Warm ivory paper background (matches GoodNotes sheet tone)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFFFFFDF8),
    );

    // GoodNotes Standard iPad A4 Page Dimensions (World coordinates)
    const double kPageW = 860.0;
    const double kPageH = 1200.0;
    const double kPageLeft = -430.0;
    const double kPageTop = -50.0;

    // Detect if objects are in GoodNotes centered coordinate space (left = -430)
    bool hasNegativeCoords = false;
    for (final obj in page.objects) {
      if (obj is CanvasStrokeItem) {
        if (obj.points.any((p) => p.x < -5.0)) {
          hasNegativeCoords = true;
          break;
        }
      } else {
        final box = obj.getBoundingBox();
        if (box.left < -5.0) {
          hasNegativeCoords = true;
          break;
        }
      }
    }

    final double scale = width / kPageW;
    final double shiftX = hasNegativeCoords ? -kPageLeft : 0.0;
    final double shiftY = hasNegativeCoords ? -kPageTop : 0.0;

    canvas.save();
    canvas.scale(scale, scale);
    canvas.translate(shiftX, shiftY);

    // 2. Draw authentic GoodNotes paper style lines
    _drawPaperLines(
      canvas: canvas,
      style: page.paperStyle,
      pageLeft: hasNegativeCoords ? kPageLeft : 0.0,
      pageTop: hasNegativeCoords ? kPageTop : 0.0,
      pageWidth: kPageW,
      pageHeight: kPageH,
    );

    // 3. Sort objects by zIndex
    final sorted = List<CanvasObjectItem>.from(page.objects)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    // 3a. Highlighters first (so they sit underneath pen ink and don't muddy lines)
    for (final obj in sorted) {
      if (obj is CanvasStrokeItem && obj.tool == 'highlighter') {
        _renderStroke(canvas, obj);
      }
    }

    // 3b. Opaque ink strokes, shapes, text, note cards, tape
    for (final obj in sorted) {
      if (obj is CanvasStrokeItem && obj.tool != 'highlighter') {
        _renderStroke(canvas, obj);
      } else if (obj is CanvasShapeItem) {
        _renderShape(canvas, obj);
      } else if (obj is CanvasTextItem) {
        _renderTextItem(canvas, obj);
      } else if (obj is CanvasNoteCardItem) {
        _renderNoteCard(canvas, obj);
      } else if (obj is CanvasTapeItem) {
        _renderTape(canvas, obj);
      }
    }

    canvas.restore();

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    img.dispose();

    return byteData!.buffer.asUint8List();
  }

  // ── Draw authentic paper lines matching the GoodNotes canvas sheet ─────────
  static void _drawPaperLines({
    required ui.Canvas canvas,
    required CanvasPaperStyle style,
    required double pageLeft,
    required double pageTop,
    required double pageWidth,
    required double pageHeight,
  }) {
    if (style == CanvasPaperStyle.blankSlate) return;

    final linePaint = Paint()
      ..color = const Color(0xFFD8E1F0).withAlpha(215)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final marginPaint = Paint()
      ..color = const Color(0xFFF43F5E).withAlpha(115) // Rose notebook margin line
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    if (style == CanvasPaperStyle.ruledLines || style == CanvasPaperStyle.narrowRuled) {
      final lineHeight = style == CanvasPaperStyle.narrowRuled ? 24.0 : 32.0;
      final startY = pageTop + 48.0 + 28.0;
      final endY = pageTop + pageHeight - 20.0;
      for (double y = startY; y < endY; y += lineHeight) {
        canvas.drawLine(Offset(pageLeft, y), Offset(pageLeft + pageWidth, y), linePaint);
      }
      // Vertical rose notebook margin line
      final marginX = pageLeft + 72.0;
      canvas.drawLine(Offset(marginX, pageTop + 48.0), Offset(marginX, pageTop + pageHeight), marginPaint);
      return;
    }

    if (style == CanvasPaperStyle.graphGrid) {
      const step = 28.0;
      for (double x = pageLeft; x <= pageLeft + pageWidth; x += step) {
        canvas.drawLine(Offset(x, pageTop + 48.0), Offset(x, pageTop + pageHeight), linePaint);
      }
      for (double y = pageTop + 48.0; y <= pageTop + pageHeight; y += step) {
        canvas.drawLine(Offset(pageLeft, y), Offset(pageLeft + pageWidth, y), linePaint);
      }
      return;
    }

    if (style == CanvasPaperStyle.dotGrid) {
      final dotPaint = Paint()
        ..color = const Color(0xFFCBD5E1)
        ..style = PaintingStyle.fill;
      const step = 28.0;
      for (double x = pageLeft + 20.0; x < pageLeft + pageWidth; x += step) {
        for (double y = pageTop + 48.0 + 20.0; y < pageTop + pageHeight - 10.0; y += step) {
          canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
        }
      }
      return;
    }

    if (style == CanvasPaperStyle.cornell) {
      const lineHeight = 32.0;
      final startY = pageTop + 76.0;
      final endY = pageTop + pageHeight - 120.0;
      for (double y = startY; y < endY; y += lineHeight) {
        canvas.drawLine(Offset(pageLeft, y), Offset(pageLeft + pageWidth, y), linePaint);
      }
      final divX = pageLeft + pageWidth * 0.28;
      canvas.drawLine(Offset(divX, pageTop + 48.0), Offset(divX, pageTop + pageHeight - 120.0), marginPaint);
      canvas.drawLine(Offset(pageLeft, pageTop + pageHeight - 120.0), Offset(pageLeft + pageWidth, pageTop + pageHeight - 120.0), marginPaint);
      return;
    }

    if (style == CanvasPaperStyle.planner) {
      const blockHeight = 60.0;
      for (double y = pageTop + 60.0; y < pageTop + pageHeight; y += blockHeight) {
        canvas.drawLine(Offset(pageLeft, y), Offset(pageLeft + pageWidth, y), linePaint);
      }
      final marginX = pageLeft + 80.0;
      canvas.drawLine(Offset(marginX, pageTop + 48.0), Offset(marginX, pageTop + pageHeight), marginPaint);
      return;
    }
  }

  // Map pure white or near-white colors (from dark mode writing) to dark slate for paper readability
  static Color _adjustColorForLightPaper(Color color) {
    final r = (color.r * 255.0).round();
    final g = (color.g * 255.0).round();
    final b = (color.b * 255.0).round();
    if (r > 230 && g > 230 && b > 230) {
      return const Color(0xFF0F172A);
    }
    return color;
  }

  // ── Render a stroke using the existing StrokeRenderer ─────────────────────
  static void _renderStroke(ui.Canvas canvas, CanvasStrokeItem stroke) {
    if (stroke.points.isEmpty) return;
    StrokeRenderer.drawStroke(
      canvas: canvas,
      points: stroke.points,
      color: _adjustColorForLightPaper(stroke.color),
      baseWidth: stroke.strokeWidth,
      penType: stroke.penType,
      opacity: stroke.opacity,
      sensitivity: PressureSensitivity.medium,
      tool: stroke.tool,
    );
  }

  // ── Render a shape ────────────────────────────────────────────────────────
  static void _renderShape(ui.Canvas canvas, CanvasShapeItem shape) {
    final strokePaint = Paint()
      ..color = shape.strokeColor
      ..strokeWidth = shape.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = shape.fillColor != null
        ? (Paint()
          ..color = shape.fillColor!
          ..style = PaintingStyle.fill)
        : null;

    final r = shape.bounds;

    if (shape.rotation != 0) {
      canvas.save();
      canvas.translate(r.center.dx, r.center.dy);
      canvas.rotate(shape.rotation);
      canvas.translate(-r.center.dx, -r.center.dy);
    }

    switch (shape.shapeType) {
      case 'rectangle':
        if (fillPaint != null) canvas.drawRect(r, fillPaint);
        canvas.drawRect(r, strokePaint);
        break;
      case 'circle':
        if (fillPaint != null) canvas.drawOval(r, fillPaint);
        canvas.drawOval(r, strokePaint);
        break;
      case 'triangle':
        final path = Path()
          ..moveTo(r.center.dx, r.top)
          ..lineTo(r.right, r.bottom)
          ..lineTo(r.left, r.bottom)
          ..close();
        if (fillPaint != null) canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
        break;
      case 'line':
        final p1 = shape.startPoint ?? r.topLeft;
        final p2 = shape.endPoint ?? r.bottomRight;
        canvas.drawLine(p1, p2, strokePaint);
        break;
      case 'arrow':
        final p1 = shape.startPoint ?? r.topLeft;
        final p2 = shape.endPoint ?? r.bottomRight;
        canvas.drawLine(p1, p2, strokePaint);
        // Directional arrow head pointing from p1 to p2
        final angle = math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);
        final arrowSize = (shape.strokeWidth * 3.5).clamp(10.0, 22.0);
        const arrowAngle = 26.0 * math.pi / 180.0;
        final arrowPaint = Paint()
          ..color = shape.strokeColor
          ..style = PaintingStyle.fill;
        final arrowPath = Path()
          ..moveTo(p2.dx, p2.dy)
          ..lineTo(
            p2.dx - arrowSize * math.cos(angle - arrowAngle),
            p2.dy - arrowSize * math.sin(angle - arrowAngle),
          )
          ..lineTo(
            p2.dx - arrowSize * math.cos(angle + arrowAngle),
            p2.dy - arrowSize * math.sin(angle + arrowAngle),
          )
          ..close();
        canvas.drawPath(arrowPath, arrowPaint);
        break;
      default:
        if (fillPaint != null) canvas.drawRect(r, fillPaint);
        canvas.drawRect(r, strokePaint);
    }

    if (shape.rotation != 0) canvas.restore();
  }

  // ── Render a typed text item ───────────────────────────────────────────────
  static void _renderTextItem(ui.Canvas canvas, CanvasTextItem item) {
    if (item.text.trim().isEmpty) return;

    final paragraphStyle = ui.ParagraphStyle(
      textAlign: _toUiTextAlign(item.alignment),
      fontSize: item.fontSize,
      maxLines: null,
    );

    final textStyle = ui.TextStyle(
      color: _adjustColorForLightPaper(item.color),
      fontSize: item.fontSize,
      fontWeight: item.isBold ? ui.FontWeight.bold : ui.FontWeight.normal,
      fontStyle: item.isItalic ? ui.FontStyle.italic : ui.FontStyle.normal,
      decoration: item.isUnderline ? ui.TextDecoration.underline : ui.TextDecoration.none,
    );

    final maxW = (item.boxWidth ?? item.maxWidth).clamp(80.0, 900.0);
    final pb = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(textStyle)
      ..addText(item.text);
    final para = pb.build()..layout(ui.ParagraphConstraints(width: maxW));
    canvas.drawParagraph(para, item.position);
  }

  // ── Render a note card ────────────────────────────────────────────────────
  static void _renderNoteCard(ui.Canvas canvas, CanvasNoteCardItem card) {
    final r = card.getBoundingBox();

    // Card background
    final bgPaint = Paint()
      ..color = const Color(0xFFFFFBEB) // warm yellow card
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color(0xFFFDE68A)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(r, const Radius.circular(8));
    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect, borderPaint);

    // Title
    double yOffset = r.top + 12;
    if (card.title.isNotEmpty) {
      final titleStyle = ui.ParagraphStyle(fontSize: 13, maxLines: 1);
      final ts = ui.TextStyle(
        color: const Color(0xFF92400E),
        fontSize: 13,
        fontWeight: ui.FontWeight.bold,
      );
      final pb = ui.ParagraphBuilder(titleStyle)
        ..pushStyle(ts)
        ..addText(card.title);
      final para = pb.build()
        ..layout(ui.ParagraphConstraints(width: r.width - 24));
      canvas.drawParagraph(para, Offset(r.left + 12, yOffset));
      yOffset += para.height + 8;

      // Divider
      canvas.drawLine(
        Offset(r.left + 8, yOffset),
        Offset(r.right - 8, yOffset),
        Paint()
          ..color = const Color(0xFFFDE68A)
          ..strokeWidth = 1.0,
      );
      yOffset += 8;
    }

    // Content
    if (card.content.isNotEmpty) {
      final contentStyle = ui.ParagraphStyle(fontSize: 11, maxLines: null);
      final cs = ui.TextStyle(
        color: const Color(0xFF713F12),
        fontSize: 11,
      );
      final pb = ui.ParagraphBuilder(contentStyle)
        ..pushStyle(cs)
        ..addText(card.content);
      final para = pb.build()
        ..layout(ui.ParagraphConstraints(width: r.width - 24));
      canvas.drawParagraph(para, Offset(r.left + 12, yOffset));
    }
  }

  // ── Render tape ───────────────────────────────────────────────────────────
  static void _renderTape(ui.Canvas canvas, CanvasTapeItem tape) {
    final paint = Paint()
      ..color = tape.color.withAlpha(tape.isMasked ? 230 : 100)
      ..style = PaintingStyle.fill;
    canvas.drawRect(tape.rect, paint);
  }

  static ui.TextAlign _toUiTextAlign(TextAlign align) {
    switch (align) {
      case TextAlign.center: return ui.TextAlign.center;
      case TextAlign.right:  return ui.TextAlign.right;
      case TextAlign.justify: return ui.TextAlign.justify;
      default: return ui.TextAlign.left;
    }
  }


  // ── Notebook DOCX ─────────────────────────────────────────────────────────
  static Future<void> _exportNotebookAsDocx(
    CanvasDocModel doc,
    String baseName,
  ) async {
    final archive = Archive();

    const contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';
    archive.addFile(ArchiveFile('[Content_Types].xml', utf8.encode(contentTypesXml).length, utf8.encode(contentTypesXml)));

    const relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', utf8.encode(relsXml).length, utf8.encode(relsXml)));

    const docRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>''';
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', utf8.encode(docRelsXml).length, utf8.encode(docRelsXml)));

    final docBuffer = StringBuffer();
    docBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    docBuffer.writeln('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">');
    docBuffer.writeln('  <w:body>');

    // Notebook title
    docBuffer.write(_docxParagraph(doc.name, bold: true, fontSizeHalfPt: 48, color: '0F172A'));
    docBuffer.write(_docxParagraph(
      'Exported: ${DateTime.now().toLocal().toString().split('.')[0]}',
      italic: true,
      fontSizeHalfPt: 20,
      color: '64748B',
    ));
    docBuffer.write(_docxParagraph('', spaceAfter: 200));

    for (int p = 0; p < doc.pages.length; p++) {
      final page = doc.pages[p];
      if (doc.pages.length > 1) {
        docBuffer.write(_docxParagraph(
          'Page ${p + 1}: ${page.title}',
          bold: true,
          fontSizeHalfPt: 28,
          color: '1E293B',
          spaceBefore: 240,
          spaceAfter: 100,
        ));
      }

      final extracted = _extractPageContent(page);
      if (extracted.isEmpty) {
        docBuffer.write(_docxParagraph('*(Visual drawing / canvas handwriting)*', italic: true, fontSizeHalfPt: 20, color: '94A3B8'));
      } else {
        for (final section in extracted) {
          if (section.title.isNotEmpty) {
            docBuffer.write(_docxParagraph(section.title, bold: true, fontSizeHalfPt: 22, color: '1E293B', spaceBefore: 80, spaceAfter: 40));
          }
          if (section.body.isNotEmpty) {
            for (final line in section.body.split('\n')) {
              docBuffer.write(_docxParagraph(line, fontSizeHalfPt: 22, color: '334155', spaceAfter: 60));
            }
          }
        }
      }
    }

    docBuffer.writeln('  </w:body>');
    docBuffer.writeln('</w:document>');

    final docXmlStr = docBuffer.toString();
    archive.addFile(ArchiveFile('word/document.xml', utf8.encode(docXmlStr).length, utf8.encode(docXmlStr)));

    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);
    FileDownloadHelper.downloadBytes(
      bytes: Uint8List.fromList(zipBytes),
      filename: '$baseName.docx',
      mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
  }

  // ── Notebook Markdown ─────────────────────────────────────────────────────
  static Future<void> _exportNotebookAsMarkdown(
    CanvasDocModel doc,
    String baseName,
  ) async {
    final buffer = StringBuffer();
    buffer.writeln('# ${doc.name}');
    buffer.writeln('');
    buffer.writeln('**Exported**: ${DateTime.now().toLocal().toString().split('.')[0]}  ');
    buffer.writeln('**Pages**: ${doc.pages.length}  ');
    buffer.writeln('');

    for (int p = 0; p < doc.pages.length; p++) {
      final page = doc.pages[p];
      if (doc.pages.length > 1) {
        buffer.writeln('---');
        buffer.writeln('## Page ${p + 1}: ${page.title}');
        buffer.writeln('');
      }

      final extracted = _extractPageContent(page);
      if (extracted.isEmpty) {
        buffer.writeln('*(Visual drawing / canvas handwriting)*');
        buffer.writeln('');
      } else {
        for (final section in extracted) {
          if (section.title.isNotEmpty) {
            buffer.writeln('### ${section.title}');
          }
          if (section.body.isNotEmpty) {
            buffer.writeln(section.body);
          }
          buffer.writeln('');
        }
      }
    }

    final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
    FileDownloadHelper.downloadBytes(
      bytes: bytes,
      filename: '$baseName.md',
      mimeType: 'text/markdown',
    );
  }

  // ── Notebook Plain Text ───────────────────────────────────────────────────
  static Future<void> _exportNotebookAsText(
    CanvasDocModel doc,
    String baseName,
  ) async {
    final buffer = StringBuffer();
    buffer.writeln('====================================================');
    buffer.writeln('NOTEBOOK: ${doc.name}');
    buffer.writeln('EXPORTED: ${DateTime.now().toLocal().toString().split('.')[0]}');
    buffer.writeln('PAGES: ${doc.pages.length}');
    buffer.writeln('====================================================');
    buffer.writeln('');

    for (int p = 0; p < doc.pages.length; p++) {
      final page = doc.pages[p];
      if (doc.pages.length > 1) {
        buffer.writeln('----------------------------------------------------');
        buffer.writeln('Page ${p + 1}: ${page.title}');
        buffer.writeln('----------------------------------------------------');
        buffer.writeln('');
      }

      final extracted = _extractPageContent(page);
      if (extracted.isEmpty) {
        buffer.writeln('  *(Visual drawing / canvas handwriting)*');
      } else {
        for (final section in extracted) {
          if (section.title.isNotEmpty) {
            buffer.writeln('  [${section.title}]');
          }
          if (section.body.isNotEmpty) {
            for (final line in section.body.split('\n')) {
              buffer.writeln('  $line');
            }
          }
          buffer.writeln('');
        }
      }
      buffer.writeln('');
    }

    final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
    FileDownloadHelper.downloadBytes(
      bytes: bytes,
      filename: '$baseName.txt',
      mimeType: 'text/plain',
    );
  }

  /// Export workspace documents into the specified format (pdf, docx, md, txt, json)
  /// and trigger browser file download with the matching extension and mime-type.
  static Future<void> exportWorkspace({
    required WorkspaceModel workspace,
    required List<CanvasDocModel> docs,
    required String format,
  }) async {
    final cleanFormat = format.toLowerCase().trim();
    final safeName = workspace.name
        .replaceAll(RegExp(r'[^\w\s-]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    final baseName = safeName.isNotEmpty ? safeName : 'workspace';

    switch (cleanFormat) {
      case 'pdf':
        await _exportAsPdf(workspace, docs, baseName);
        break;
      case 'docx':
      case 'word':
        await _exportAsDocx(workspace, docs, baseName);
        break;
      case 'md':
      case 'markdown':
        await _exportAsMarkdown(workspace, docs, baseName);
        break;
      case 'json':
        await _exportAsJson(workspace, docs, baseName);
        break;
      case 'txt':
      case 'text':
      default:
        await _exportAsText(workspace, docs, baseName);
        break;
    }
  }

  // ── 1. PDF Export ─────────────────────────────────────────────────────────
  static Future<void> _exportAsPdf(
    WorkspaceModel workspace,
    List<CanvasDocModel> docs,
    String baseName,
  ) async {
    final pdf = pw.Document(
      title: workspace.name,
      author: 'Notelekh AI Workspace',
      creator: 'Notelekh Notes',
    );

    final fontBold = pw.Font.helveticaBold();
    final fontRegular = pw.Font.helvetica();
    final fontOblique = pw.Font.helveticaOblique();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 16),
            padding: const pw.EdgeInsets.only(bottom: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  workspace.name,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  'Notelekh Workspace Export',
                  style: pw.TextStyle(
                    font: fontRegular,
                    fontSize: 9,
                    color: PdfColors.grey500,
                  ),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.center,
            margin: const pw.EdgeInsets.only(top: 16),
            padding: const pw.EdgeInsets.only(top: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Exported on ${DateTime.now().toLocal().toString().split('.')[0]}',
                  style: pw.TextStyle(
                    font: fontRegular,
                    fontSize: 8,
                    color: PdfColors.grey500,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          final widgets = <pw.Widget>[];

          // Workspace Header Banner
          widgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F1F5F9'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1'), width: 1),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    workspace.name,
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 22,
                      color: PdfColor.fromHex('#0F172A'),
                    ),
                  ),
                  if (workspace.description.isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    pw.Text(
                      workspace.description,
                      style: pw.TextStyle(
                        font: fontOblique,
                        fontSize: 11,
                        color: PdfColor.fromHex('#475569'),
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Total Documents: ${docs.length}  |  Exported: ${DateTime.now().toLocal().toString().split('.')[0]}',
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 9.5,
                      color: PdfColor.fromHex('#64748B'),
                    ),
                  ),
                ],
              ),
            ),
          );

          widgets.add(pw.SizedBox(height: 20));

          if (docs.isEmpty) {
            widgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 24),
                child: pw.Center(
                  child: pw.Text(
                    'No documents in this workspace.',
                    style: pw.TextStyle(font: fontOblique, fontSize: 12, color: PdfColors.grey600),
                  ),
                ),
              ),
            );
            return widgets;
          }

          // Document items
          for (int d = 0; d < docs.length; d++) {
            final doc = docs[d];
            final docTypeLabel = doc.docType == CanvasDocType.canvas
                ? 'Whiteboard'
                : (doc.docType == CanvasDocType.textDocument ? 'Text Document' : 'Notebook');

            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 14, bottom: 8),
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#E2E8F0'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '${d + 1}. ${doc.name}',
                      style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColor.fromHex('#1E293B')),
                    ),
                    pw.Text(
                      '$docTypeLabel (${doc.pages.length} page${doc.pages.length == 1 ? '' : 's'})',
                      style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColor.fromHex('#475569')),
                    ),
                  ],
                ),
              ),
            );

            for (int p = 0; p < doc.pages.length; p++) {
              final page = doc.pages[p];
              if (doc.pages.length > 1) {
                widgets.add(
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 8, bottom: 4, left: 6),
                    child: pw.Text(
                      'Page ${p + 1}: ${page.title}',
                      style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColor.fromHex('#334155')),
                    ),
                  ),
                );
              }

              final extracted = _extractPageContent(page);
              if (extracted.isEmpty) {
                widgets.add(
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 12, bottom: 6),
                    child: pw.Text(
                      '*(Visual drawing / canvas handwriting)*',
                      style: pw.TextStyle(font: fontOblique, fontSize: 9.5, color: PdfColors.grey500),
                    ),
                  ),
                );
              } else {
                for (final section in extracted) {
                  if (section.title.isNotEmpty) {
                    widgets.add(
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 10, top: 4, bottom: 2),
                        child: pw.Text(
                          section.title,
                          style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: PdfColor.fromHex('#0F172A')),
                        ),
                      ),
                    );
                  }
                  if (section.body.isNotEmpty) {
                    widgets.add(
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 14, bottom: 6),
                        child: pw.Text(
                          section.body,
                          style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColor.fromHex('#1E293B'), lineSpacing: 2),
                        ),
                      ),
                    );
                  }
                }
              }
            }

            widgets.add(pw.SizedBox(height: 10));
            if (d < docs.length - 1) {
              widgets.add(pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 0.8));
            }
          }

          return widgets;
        },
      ),
    );

    final bytes = await pdf.save();
    FileDownloadHelper.downloadBytes(
      bytes: Uint8List.fromList(bytes),
      filename: '${baseName}_export.pdf',
      mimeType: 'application/pdf',
    );
  }

  // ── 2. Word (.docx) Export ────────────────────────────────────────────────
  static Future<void> _exportAsDocx(
    WorkspaceModel workspace,
    List<CanvasDocModel> docs,
    String baseName,
  ) async {
    final archive = Archive();

    // 1. [Content_Types].xml
    const contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';
    archive.addFile(ArchiveFile(
      '[Content_Types].xml',
      utf8.encode(contentTypesXml).length,
      utf8.encode(contentTypesXml),
    ));

    // 2. _rels/.rels
    const relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile(
      '_rels/.rels',
      utf8.encode(relsXml).length,
      utf8.encode(relsXml),
    ));

    // 3. word/_rels/document.xml.rels
    const docRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>''';
    archive.addFile(ArchiveFile(
      'word/_rels/document.xml.rels',
      utf8.encode(docRelsXml).length,
      utf8.encode(docRelsXml),
    ));

    // 4. word/document.xml
    final docBuffer = StringBuffer();
    docBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    docBuffer.writeln('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">');
    docBuffer.writeln('  <w:body>');

    // Title
    docBuffer.write(_docxParagraph(
      workspace.name,
      bold: true,
      fontSizeHalfPt: 48, // 24pt
      color: '0F172A',
    ));

    if (workspace.description.isNotEmpty) {
      docBuffer.write(_docxParagraph(
        workspace.description,
        italic: true,
        fontSizeHalfPt: 24, // 12pt
        color: '475569',
      ));
    }

    docBuffer.write(_docxParagraph(
      'Exported: ${DateTime.now().toLocal().toString().split('.')[0]} • Notelekh Workspace',
      italic: true,
      fontSizeHalfPt: 20,
      color: '64748B',
    ));

    docBuffer.write(_docxParagraph('', spaceAfter: 200));

    // Documents
    for (int d = 0; d < docs.length; d++) {
      final doc = docs[d];
      final docTypeLabel = doc.docType == CanvasDocType.canvas
          ? 'Whiteboard'
          : (doc.docType == CanvasDocType.textDocument ? 'Text Document' : 'Notebook');

      docBuffer.write(_docxParagraph(
        '${d + 1}. ${doc.name} ($docTypeLabel)',
        bold: true,
        fontSizeHalfPt: 32, // 16pt
        color: '1E293B',
        spaceBefore: 300,
        spaceAfter: 120,
      ));

      for (int p = 0; p < doc.pages.length; p++) {
        final page = doc.pages[p];
        if (doc.pages.length > 1) {
          docBuffer.write(_docxParagraph(
            'Page ${p + 1}: ${page.title}',
            bold: true,
            fontSizeHalfPt: 24,
            color: '334155',
            spaceBefore: 120,
            spaceAfter: 60,
          ));
        }

        final extracted = _extractPageContent(page);
        if (extracted.isEmpty) {
          docBuffer.write(_docxParagraph(
            '*(Visual drawing / canvas handwriting)*',
            italic: true,
            fontSizeHalfPt: 20,
            color: '94A3B8',
          ));
        } else {
          for (final section in extracted) {
            if (section.title.isNotEmpty) {
              docBuffer.write(_docxParagraph(
                section.title,
                bold: true,
                fontSizeHalfPt: 22,
                color: '1E293B',
                spaceBefore: 80,
                spaceAfter: 40,
              ));
            }
            if (section.body.isNotEmpty) {
              for (final line in section.body.split('\n')) {
                docBuffer.write(_docxParagraph(
                  line,
                  fontSizeHalfPt: 22,
                  color: '334155',
                  spaceAfter: 60,
                ));
              }
            }
          }
        }
      }

      if (d < docs.length - 1) {
        // Page break between major documents
        docBuffer.writeln('    <w:p><w:r><w:br w:type="page"/></w:r></w:p>');
      }
    }

    docBuffer.writeln('  </w:body>');
    docBuffer.writeln('</w:document>');

    final docXmlStr = docBuffer.toString();
    archive.addFile(ArchiveFile(
      'word/document.xml',
      utf8.encode(docXmlStr).length,
      utf8.encode(docXmlStr),
    ));

    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);
    FileDownloadHelper.downloadBytes(
      bytes: Uint8List.fromList(zipBytes),
      filename: '${baseName}_export.docx',
      mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
  }

  // ── 3. Markdown (.md) Export ──────────────────────────────────────────────
  static Future<void> _exportAsMarkdown(
    WorkspaceModel workspace,
    List<CanvasDocModel> docs,
    String baseName,
  ) async {
    final buffer = StringBuffer();
    buffer.writeln('# ${workspace.name}');
    if (workspace.description.isNotEmpty) {
      buffer.writeln('> ${workspace.description}');
    }
    buffer.writeln('');
    buffer.writeln('**Exported**: ${DateTime.now().toLocal().toString().split('.')[0]}  ');
    buffer.writeln('**Total Documents**: ${docs.length}  ');
    buffer.writeln('');

    for (final doc in docs) {
      buffer.writeln('---');
      final typeLabel = doc.docType == CanvasDocType.canvas
          ? 'Whiteboard'
          : (doc.docType == CanvasDocType.textDocument ? 'Text Document' : 'Notebook');
      buffer.writeln('## ${doc.name} *($typeLabel)*');
      buffer.writeln('');

      for (int p = 0; p < doc.pages.length; p++) {
        final page = doc.pages[p];
        if (doc.pages.length > 1) {
          buffer.writeln('### Page ${p + 1}: ${page.title}');
          buffer.writeln('');
        }

        final extracted = _extractPageContent(page);
        if (extracted.isEmpty) {
          buffer.writeln('*(Visual drawing / canvas handwriting)*');
          buffer.writeln('');
        } else {
          for (final section in extracted) {
            if (section.title.isNotEmpty) {
              buffer.writeln('#### ${section.title}');
            }
            if (section.body.isNotEmpty) {
              buffer.writeln(section.body);
            }
            buffer.writeln('');
          }
        }
      }
    }

    final content = buffer.toString();
    final bytes = Uint8List.fromList(utf8.encode(content));
    FileDownloadHelper.downloadBytes(
      bytes: bytes,
      filename: '${baseName}_export.md',
      mimeType: 'text/markdown',
    );
  }

  // ── 4. Plain Text (.txt) Export ───────────────────────────────────────────
  static Future<void> _exportAsText(
    WorkspaceModel workspace,
    List<CanvasDocModel> docs,
    String baseName,
  ) async {
    final buffer = StringBuffer();
    buffer.writeln('====================================================');
    buffer.writeln('WORKSPACE: ${workspace.name}');
    if (workspace.description.isNotEmpty) {
      buffer.writeln('DESCRIPTION: ${workspace.description}');
    }
    buffer.writeln('EXPORTED: ${DateTime.now().toLocal().toString().split('.')[0]}');
    buffer.writeln('DOCUMENTS: ${docs.length}');
    buffer.writeln('====================================================');
    buffer.writeln('');

    for (int d = 0; d < docs.length; d++) {
      final doc = docs[d];
      final typeLabel = doc.docType == CanvasDocType.canvas
          ? 'Whiteboard'
          : (doc.docType == CanvasDocType.textDocument ? 'Text Document' : 'Notebook');
      buffer.writeln('----------------------------------------------------');
      buffer.writeln('${d + 1}. ${doc.name} ($typeLabel)');
      buffer.writeln('----------------------------------------------------');
      buffer.writeln('');

      for (int p = 0; p < doc.pages.length; p++) {
        final page = doc.pages[p];
        if (doc.pages.length > 1) {
          buffer.writeln('[Page ${p + 1}: ${page.title}]');
        }

        final extracted = _extractPageContent(page);
        if (extracted.isEmpty) {
          buffer.writeln('  *(Visual drawing / canvas handwriting)*');
        } else {
          for (final section in extracted) {
            if (section.title.isNotEmpty) {
              buffer.writeln('  [${section.title}]');
            }
            if (section.body.isNotEmpty) {
              for (final line in section.body.split('\n')) {
                buffer.writeln('  $line');
              }
            }
            buffer.writeln('');
          }
        }
        buffer.writeln('');
      }
    }

    final content = buffer.toString();
    final bytes = Uint8List.fromList(utf8.encode(content));
    FileDownloadHelper.downloadBytes(
      bytes: bytes,
      filename: '${baseName}_export.txt',
      mimeType: 'text/plain',
    );
  }

  // ── 5. JSON Backup (.json) Export ─────────────────────────────────────────
  static Future<void> _exportAsJson(
    WorkspaceModel workspace,
    List<CanvasDocModel> docs,
    String baseName,
  ) async {
    final exportData = {
      'app': 'Notelekh',
      'version': '1.0.0',
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'workspace': workspace.toJson(),
      'documents': docs.map((d) => d.toJson()).toList(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    final content = encoder.convert(exportData);
    final bytes = Uint8List.fromList(utf8.encode(content));
    FileDownloadHelper.downloadBytes(
      bytes: bytes,
      filename: '${baseName}_export.json',
      mimeType: 'application/json',
    );
  }

  // ── Helper: Extract rich content from CanvasPage ──────────────────────────
  static List<_ExtractedSection> _extractPageContent(CanvasPage page) {
    final sections = <_ExtractedSection>[];

    // 1. Note Cards (markdown docs and note cards)
    final noteCards = page.objects.whereType<CanvasNoteCardItem>().toList();
    for (final card in noteCards) {
      if (card.title.isNotEmpty || card.content.isNotEmpty) {
        sections.add(_ExtractedSection(title: card.title, body: card.content));
      }
    }

    // 2. Text Items (typed text, OCR results, AI answers)
    final textItems = page.objects
        .whereType<CanvasTextItem>()
        .where((t) => t.text.trim().isNotEmpty)
        .toList();
    for (final item in textItems) {
      sections.add(_ExtractedSection(
        title: item.title ?? '',
        body: item.text.trim(),
      ));
    }

    return sections;
  }

  // ── Helper: Word XML Paragraph Builder ────────────────────────────────────
  static String _docxParagraph(
    String text, {
    bool bold = false,
    bool italic = false,
    int fontSizeHalfPt = 22,
    String color = '000000',
    int spaceBefore = 0,
    int spaceAfter = 100,
  }) {
    final escaped = _xmlEscape(text);
    return '''    <w:p>
      <w:pPr>
        <w:spacing w:before="$spaceBefore" w:after="$spaceAfter"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          ${bold ? '<w:b/>' : ''}
          ${italic ? '<w:i/>' : ''}
          <w:color w:val="$color"/>
          <w:sz w:val="$fontSizeHalfPt"/>
          <w:szCs w:val="$fontSizeHalfPt"/>
        </w:rPr>
        <w:t xml:space="preserve">$escaped</w:t>
      </w:r>
    </w:p>
''';
  }

  static String _xmlEscape(String str) {
    return str
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

class _ExtractedSection {
  final String title;
  final String body;
  _ExtractedSection({required this.title, required this.body});
}
