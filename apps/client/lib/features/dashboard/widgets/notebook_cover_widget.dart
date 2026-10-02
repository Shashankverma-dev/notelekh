import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_workspace_client/core/models/canvas_models.dart';
import 'dart:math' as math;

// ─────────────────────────────────────────────────────────────────────────────
// Curated Luxury Color Palettes (Solid Leather & Bookcloth)
// ─────────────────────────────────────────────────────────────────────────────
class LuxuryCoverTheme {
  static const List<(Color, String)> solidColors = [
    (Color(0xFF1B2A47), 'Oxford Navy'),
    (Color(0xFF17382B), 'Racing Green'),
    (Color(0xFF4A1525), 'Bordeaux Wine'),
    (Color(0xFF1E222A), 'Charcoal Noir'),
    (Color(0xFF38261E), 'Espresso Leather'),
    (Color(0xFF963E2B), 'Terracotta Clay'),
    (Color(0xFF466355), 'Sage Eucalyptus'),
    (Color(0xFF2C4257), 'Nordic Slate'),
    (Color(0xFF53354C), 'Dusty Plum'),
    (Color(0xFF826A57), 'Warm Cashmere'),
    (Color(0xFFA87524), 'Mustard Ochre'),
    (Color(0xFF99525F), 'Desert Rose'),
    (Color(0xFF0E3F30), 'Deep Forest'),
    (Color(0xFF153E46), 'Midnight Teal'),
    (Color(0xFFC9BFAC), 'Oatmeal Linen'),
    (Color(0xFF3E4D5D), 'Storm Steel'),
  ];

  static const List<List<String>> gradients = [
    ['1B263B', '0D1B2A', 'Velvet Midnight'],
    ['4A1525', '240810', 'Bordeaux Royale'],
    ['1B3B2B', '0D2218', 'Emerald Forest'],
    ['78350F', '451A03', 'Cognac Leather'],
    ['3B1D50', '1E0A2E', 'Velvet Twilight'],
    ['1E3A5F', '0F1D30', 'Nordic Dusk'],
    ['6B2D40', '3A1220', 'Rose Gold'],
    ['334155', '1E293B', 'Slate Obsidian'],
    ['155E75', '083344', 'Aegean Deep'],
    ['854D0E', '422006', 'Smoked Amber'],
    ['1E40AF', '172554', 'Pacific Marina'],
    ['262626', '121212', 'Titanium Noir'],
  ];

  static const List<(String, String, IconData)> patterns = [
    ('leather', 'Saddle Leather', Icons.shield_outlined),
    ('linen', 'Belgian Bookcloth', Icons.grid_view_rounded),
    ('marbled', 'Archival Marbled', Icons.waves_rounded),
    ('chevron', 'Herringbone Weave', Icons.view_column_outlined),
    ('grid', 'Debossed Grid', Icons.grid_4x4_rounded),
    ('dots', 'Blind Dot Matrix', Icons.blur_on_rounded),
    ('stripes', 'Fine Pinstripe', Icons.reorder_rounded),
  ];
}

Color parseHexColor(String hex, {Color fallback = const Color(0xFF1B2A47)}) {
  try {
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
    if (clean.length == 8) return Color(int.parse(clean, radix: 16));
    return fallback;
  } catch (_) {
    return fallback;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Realistic GoodNotes Notebook Cover Widget
// ─────────────────────────────────────────────────────────────────────────────
class NotebookCoverWidget extends StatelessWidget {
  final String title;
  final int pageCount;
  final CanvasDocType docType;
  final Color coverColor;
  final String coverEmoji;
  final String coverStyle; // 'solid' | 'gradient' | 'pattern'
  final String coverStyleData;
  final double width;
  final double height;
  final bool isDark;
  final VoidCallback? onTap;
  final VoidCallback? onEditCover;

  const NotebookCoverWidget({
    super.key,
    required this.title,
    this.pageCount = 1,
    this.docType = CanvasDocType.notebook,
    required this.coverColor,
    this.coverEmoji = '📓',
    this.coverStyle = 'solid',
    this.coverStyleData = '',
    this.width = 144,
    this.height = 184,
    required this.isDark,
    this.onTap,
    this.onEditCover,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Base Gradient / Fill
    final bool isGradient = coverStyle == 'gradient' && coverStyleData.contains(',');
    Gradient? baseGradient;
    Color primaryColor = coverColor;

    if (isGradient) {
      final parts = coverStyleData.split(',');
      final c1 = parseHexColor(parts[0], fallback: coverColor);
      final c2 = parseHexColor(parts[1], fallback: coverColor);
      primaryColor = c1;
      baseGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [c1, c2],
      );
    }

    // Book spine tone (subtly deeper than cover)
    final spineDarken = HSLColor.fromColor(primaryColor);
    final spineColor = spineDarken.withLightness((spineDarken.lightness * 0.72).clamp(0.06, 0.90)).toColor();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onSecondaryTap: onEditCover,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // A. Deep layered ambient & contact drop shadows
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(5),
                      bottomLeft: Radius.circular(5),
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.18),
                        blurRadius: 20,
                        offset: const Offset(0, 9),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),

              // B. Right-edge Ivory Paper Block (Physical book page block peek)
              Positioned(
                top: 5,
                bottom: 5,
                right: 0,
                width: 6,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A3142) : const Color(0xFFF9F6EE),
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
                    border: Border(
                      right: BorderSide(
                        color: isDark ? const Color(0xFF1E2432) : const Color(0xFFE5DECE),
                        width: 1.0,
                      ),
                      top: BorderSide(
                        color: isDark ? const Color(0xFF1E2432) : const Color(0xFFE5DECE),
                        width: 1.0,
                      ),
                      bottom: BorderSide(
                        color: isDark ? const Color(0xFF1E2432) : const Color(0xFFE5DECE),
                        width: 1.0,
                      ),
                    ),
                  ),
                  child: CustomPaint(
                    painter: _PageBlockLinesPainter(isDark: isDark),
                  ),
                ),
              ),

              // C. Main Hardcover Board
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                right: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: isGradient ? null : primaryColor,
                    gradient: baseGradient,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(5),
                      bottomLeft: Radius.circular(5),
                      topRight: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.22),
                      width: 1.0,
                    ),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Stack(
                    children: [
                      // 1. Texture Pattern Overlay
                      if (coverStyle == 'pattern')
                        Positioned.fill(
                          child: CustomPaint(
                            painter: CoverPatternPainter(
                              type: coverStyleData.isNotEmpty ? coverStyleData : 'leather',
                              baseColor: primaryColor,
                            ),
                          ),
                        ),

                      // 2. Realistic Book Ambient Sheen (Top highlight & bottom shadow)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.16),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.20),
                              ],
                              stops: const [0.0, 0.35, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // 3. Bound Spine Wrap on the Left
                      Positioned(
                        top: 0,
                        bottom: 0,
                        left: 0,
                        width: 22,
                        child: Container(
                          decoration: BoxDecoration(
                            color: spineColor.withValues(alpha: 0.88),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              bottomLeft: Radius.circular(4),
                            ),
                            border: Border(
                              right: BorderSide(
                                color: Colors.black.withValues(alpha: 0.30),
                                width: 1.2,
                              ),
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Spine shadow roll
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.35),
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.25),
                                      ],
                                      stops: const [0.0, 0.5, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              // Delicate saddle stitches along spine
                              Positioned(
                                top: 6,
                                bottom: 6,
                                right: 3,
                                width: 2,
                                child: CustomPaint(
                                  painter: _SpineStitchPainter(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 4. Spine Hinge Crease Line (Shadow + Highlight)
                      Positioned(
                        top: 0,
                        bottom: 0,
                        left: 22,
                        width: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.28),
                                Colors.white.withValues(alpha: 0.20),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 5. Hanging Silk Bookmark Ribbon on Top Right
                      Positioned(
                        top: 0,
                        right: 20,
                        width: 12,
                        height: 30,
                        child: CustomPaint(
                          painter: _RibbonMarkerPainter(
                            color: _resolveRibbonColor(primaryColor),
                          ),
                        ),
                      ),

                      // 6. Signature GoodNotes Bookplate Nameplate (Center/Upper)
                      Positioned(
                        top: 42,
                        left: 32,
                        right: 14,
                        height: 72,
                        child: _buildGoodNotesNameplate(isDark),
                      ),

                      // 7. Footer document category deboss
                      Positioned(
                        bottom: 12,
                        left: 32,
                        right: 14,
                        child: Row(
                          children: [
                            Icon(
                              _docTypeIcon(docType),
                              size: 11,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _docTypeLabel(docType).toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: Colors.white.withValues(alpha: 0.60),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 8. Quick Edit Cover Hover Button (Top Right)
                      if (onEditCover != null)
                        Positioned(
                          top: 7,
                          right: 7,
                          child: Tooltip(
                            message: 'Customize Cover',
                            child: InkWell(
                              onTap: onEditCover,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.palette_outlined,
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Signature GoodNotes Bookplate Label ──────────────────────────────────────
  Widget _buildGoodNotesNameplate(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2436).withValues(alpha: 0.94) : const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? const Color(0xFF384362) : const Color(0xFFDCD2C0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Stack(
        children: [
          // Inner fine gold/metallic framing border
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF6366F1).withValues(alpha: 0.25)
                      : const Color(0xFFC5A880).withValues(alpha: 0.45),
                  width: 0.8,
                ),
              ),
            ),
          ),

          // Label Content: Mini foil emblem + Typeset title + ruled note lines
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mini foil crest or clean icon
                  if (coverEmoji.isNotEmpty && coverEmoji != '📓' && coverEmoji != '📄' && coverEmoji != '📐')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        coverEmoji,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),

                  // Neatly typeset title
                  Text(
                    title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      letterSpacing: 0.2,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),

                  const SizedBox(height: 4),
                  // Faint ruled note line
                  Container(
                    width: 48,
                    height: 1,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : const Color(0xFFD4C8B5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _resolveRibbonColor(Color base) {
    final hsl = HSLColor.fromColor(base);
    // Contrast silk ribbon: deep red, gold, or navy depending on cover tone
    if (hsl.hue > 340 || hsl.hue < 40) {
      return const Color(0xFFD97706); // Gold ribbon on red/terracotta
    } else if (hsl.hue >= 40 && hsl.hue < 160) {
      return const Color(0xFFBE123C); // Crimson ribbon on green/sage
    } else {
      return const Color(0xFFE11D48); // Rose red ribbon on navy/slate
    }
  }

  IconData _docTypeIcon(CanvasDocType type) {
    switch (type) {
      case CanvasDocType.notebook:
        return Icons.auto_stories_rounded;
      case CanvasDocType.canvas:
        return Icons.all_out_rounded;
      case CanvasDocType.textDocument:
        return Icons.article_rounded;
    }
  }

  String _docTypeLabel(CanvasDocType type) {
    switch (type) {
      case CanvasDocType.notebook:
        return 'Journal';
      case CanvasDocType.canvas:
        return 'Whiteboard';
      case CanvasDocType.textDocument:
        return 'Document';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page Block stacked sheet lines painter
// ─────────────────────────────────────────────────────────────────────────────
class _PageBlockLinesPainter extends CustomPainter {
  final bool isDark;
  const _PageBlockLinesPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08)
      ..strokeWidth = 0.8;

    for (double y = 4; y < size.height - 4; y += 3.5) {
      canvas.drawLine(Offset(1, y), Offset(size.width - 1, y), paint);
    }
  }

  @override
  bool shouldRepaint(_PageBlockLinesPainter old) => old.isDark != isDark;
}

// ─────────────────────────────────────────────────────────────────────────────
// Spine saddle stitch dashed painter
// ─────────────────────────────────────────────────────────────────────────────
class _SpineStitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFDE68A).withValues(alpha: 0.45) // Golden thread
      ..strokeWidth = 1.0;

    for (double y = 4; y < size.height - 4; y += 7.0) {
      canvas.drawLine(Offset(0, y), Offset(0, y + 3.5), paint);
    }
  }

  @override
  bool shouldRepaint(_SpineStitchPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Hanging Silk Ribbon Marker with V-notch
// ─────────────────────────────────────────────────────────────────────────────
class _RibbonMarkerPainter extends CustomPainter {
  final Color color;
  const _RibbonMarkerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height - 6)
      ..lineTo(0, size.height)
      ..close();

    // Ribbon drop shadow
    canvas.drawPath(
      path.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Ribbon body
    canvas.drawPath(path, Paint()..color = color);

    // Subtle center fold highlight
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height - 6),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_RibbonMarkerPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Real Tactile Luxury Cover Pattern Painter
// ─────────────────────────────────────────────────────────────────────────────
class CoverPatternPainter extends CustomPainter {
  final String type;
  final Color baseColor;
  const CoverPatternPainter({required this.type, required this.baseColor});

  Color get _sheenLight {
    final lum = baseColor.computeLuminance();
    return lum > 0.45
        ? Colors.black.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.14);
  }

  Color get _sheenDark {
    return Colors.black.withValues(alpha: 0.22);
  }

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case 'leather':
        _drawLeatherGrain(canvas, size);
        break;
      case 'linen':
        _drawBelgianLinen(canvas, size);
        break;
      case 'marbled':
        _drawArchivalMarbled(canvas, size);
        break;
      case 'chevron':
        _drawHerringbone(canvas, size);
        break;
      case 'grid':
        _drawDebossedGrid(canvas, size);
        break;
      case 'dots':
        _drawBlindDots(canvas, size);
        break;
      case 'stripes':
        _drawPinstripes(canvas, size);
        break;
      default:
        _drawLeatherGrain(canvas, size);
    }
  }

  // 1. Realistic Stippled Leather Grain with Saddle Perimeter Stitch
  void _drawLeatherGrain(Canvas canvas, Size size) {
    final dotPaintLight = Paint()
      ..color = _sheenLight
      ..style = PaintingStyle.fill;
    final dotPaintDark = Paint()
      ..color = _sheenDark
      ..style = PaintingStyle.fill;

    // Organic leather stipple
    final rng = math.Random(42);
    for (int i = 0; i < 280; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = 0.6 + rng.nextDouble() * 1.0;
      canvas.drawCircle(Offset(x, y), r, i.isEven ? dotPaintLight : dotPaintDark);
    }

    // Outer perimeter blind saddle deboss line (inset 5px)
    final borderRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(26, 6, size.width - 32, size.height - 12),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      borderRect,
      Paint()
        ..color = _sheenDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    canvas.drawRRect(
      borderRect.shift(const Offset(0.5, 0.5)),
      Paint()
        ..color = _sheenLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  // 2. Belgian Bookcloth Woven Linen (Cross-hatch micro fibers)
  void _drawBelgianLinen(Canvas canvas, Size size) {
    final warpPaint = Paint()
      ..color = _sheenLight.withValues(alpha: 0.12)
      ..strokeWidth = 0.8;
    final weftPaint = Paint()
      ..color = _sheenDark.withValues(alpha: 0.14)
      ..strokeWidth = 0.8;

    const step = 4.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), warpPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), weftPaint);
    }
  }

  // 3. Archival Florentine Wave Marbled Paper
  void _drawArchivalMarbled(Canvas canvas, Size size) {
    final wavePaintLight = Paint()
      ..color = _sheenLight.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final wavePaintDark = Paint()
      ..color = _sheenDark.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const step = 18.0;
    const amp = 6.0;
    const freq = 0.05;

    for (double y = -10; y < size.height + 20; y += step) {
      final p1 = Path()..moveTo(0, y);
      final p2 = Path()..moveTo(0, y + 6);
      for (double x = 0; x <= size.width; x += 4) {
        final sinVal = math.sin(x * freq + y * 0.02) * amp;
        p1.lineTo(x, y + sinVal);
        p2.lineTo(x, y + 6 - sinVal);
      }
      canvas.drawPath(p1, wavePaintLight);
      canvas.drawPath(p2, wavePaintDark);
    }
  }

  // 4. Herringbone / Chevron Bookcloth Weave
  void _drawHerringbone(Canvas canvas, Size size) {
    final chevronPaint = Paint()
      ..color = _sheenLight.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const colW = 16.0;
    const rowH = 8.0;

    for (double x = 0; x < size.width; x += colW) {
      final bool flip = ((x / colW).floor()).isOdd;
      for (double y = 0; y < size.height; y += rowH) {
        if (flip) {
          canvas.drawLine(Offset(x, y), Offset(x + colW, y + rowH), chevronPaint);
        } else {
          canvas.drawLine(Offset(x, y + rowH), Offset(x + colW, y), chevronPaint);
        }
      }
    }
  }

  // 5. Blind-Debossed Architectural Fine Grid
  void _drawDebossedGrid(Canvas canvas, Size size) {
    final darkLine = Paint()
      ..color = _sheenDark.withValues(alpha: 0.20)
      ..strokeWidth = 0.9;
    final lightLine = Paint()
      ..color = _sheenLight.withValues(alpha: 0.14)
      ..strokeWidth = 0.7;

    const s = 14.0;
    for (double x = 0; x < size.width; x += s) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), darkLine);
      canvas.drawLine(Offset(x + 0.6, 0), Offset(x + 0.6, size.height), lightLine);
    }
    for (double y = 0; y < size.height; y += s) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), darkLine);
      canvas.drawLine(Offset(0, y + 0.6), Offset(size.width, y + 0.6), lightLine);
    }
  }

  // 6. Tactile Blind Dot Matrix
  void _drawBlindDots(Canvas canvas, Size size) {
    final pShadow = Paint()
      ..color = _sheenDark.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    final pLight = Paint()
      ..color = _sheenLight.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    const s = 14.0;
    for (double x = s / 2; x < size.width; x += s) {
      for (double y = s / 2; y < size.height; y += s) {
        canvas.drawCircle(Offset(x, y), 1.2, pShadow);
        canvas.drawCircle(Offset(x + 0.5, y + 0.5), 1.0, pLight);
      }
    }
  }

  // 7. Refined University Tailored Pinstripes
  void _drawPinstripes(Canvas canvas, Size size) {
    final stripePaint = Paint()
      ..color = _sheenLight.withValues(alpha: 0.16)
      ..strokeWidth = 1.0;
    const s = 9.0;
    for (double x = 0; x < size.width; x += s) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), stripePaint);
    }
  }

  @override
  bool shouldRepaint(CoverPatternPainter old) =>
      old.type != type || old.baseColor != baseColor;
}
