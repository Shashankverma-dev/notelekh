import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

/// GoodNotes 6 professional floating text toolbar.
///
/// Features:
/// - Frosted glassmorphism background with blur and subtle elevation.
/// - One-tap Note Card / Sticky Note style presets (Plain, Sticky, Mint, Sky, Rose, Lavender, Card, Outlined).
/// - Handwriting & note-taking font family selector with live typography preview.
/// - Stepper and tap-to-select font size selector (10pt to 96pt).
/// - Rich formatting: Bold, Italic, Underline, Strikethrough, Text Alignment (Left, Center, Right, Justify).
/// - Curated GoodNotes ink palette + Custom Color Wheel.
/// - Text Box Appearance dialog (Background fill, border stroke, corner radius, padding).
/// - Actions: Edit Text, Duplicate, Delete, Done.
class FloatingTextToolbar extends StatelessWidget {
  final CanvasTextItem textItem;
  final ValueChanged<CanvasTextItem> onUpdate;
  final VoidCallback onEditText;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onClose;
  final bool isDark;

  const FloatingTextToolbar({
    super.key,
    required this.textItem,
    required this.onUpdate,
    required this.onEditText,
    required this.onDuplicate,
    required this.onDelete,
    required this.onClose,
    this.isDark = true,
  });

  static const List<String> _fonts = [
    'Inter',
    'Caveat',
    'Patrick Hand',
    'Outfit',
    'Merriweather',
    'Kalam',
    'Fira Code',
    'Montserrat',
    'Comic Neue',
  ];

  static const List<double> _presetSizes = [
    12, 14, 16, 18, 20, 24, 28, 32, 40, 48, 64,
  ];

  static const List<Color> _quickColors = [
    Color(0xFF0F172A), // Slate Black
    Color(0xFFFFFFFF), // Pure White
    Color(0xFF64748B), // Pencil Grey
    Color(0xFF3B82F6), // Note Blue
    Color(0xFF10B981), // Emerald Green
    Color(0xFFEF4444), // Crimson Red
    Color(0xFFF59E0B), // Amber Gold
    Color(0xFF8B5CF6), // Violet Purple
    Color(0xFFEC4899), // Rose Pink
  ];

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? const Color(0xEE1E2436)
        : const Color(0xFAFFFFFF);
    final border = isDark ? const Color(0xFF2E3852) : const Color(0xFFE2E8F0);
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final iconCol = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final primaryAccent = const Color(0xFF6366F1);

    return Material(
      color: Colors.transparent,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Edit text button (GoodNotes primary action)
                  _buildActionButton(
                    icon: Icons.edit_note_rounded,
                    tooltip: 'Edit text (Double-tap canvas)',
                    label: 'Edit',
                    accentColor: primaryAccent,
                    isDark: isDark,
                    onTap: onEditText,
                  ),
                  _buildDivider(border),

                  // 2. Text Box Style Presets (Plain, Sticky, Mint, Card, etc.)
                  _buildStylePresetsButton(context, isDark, primaryAccent),
                  _buildDivider(border),

                  // 3. Font Family Dropdown
                  Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF262E44) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF333E5C) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _fonts.contains(textItem.fontFamily) ? textItem.fontFamily : 'Inter',
                        dropdownColor: isDark ? const Color(0xFF1E2436) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: iconCol, size: 18),
                        style: TextStyle(color: textCol, fontSize: 13, fontWeight: FontWeight.w600),
                        items: _fonts.map((f) {
                          return DropdownMenuItem<String>(
                            value: f,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  f,
                                  style: GoogleFonts.getFont(
                                    f,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textCol,
                                  ),
                                ),
                                if (f == 'Caveat' || f == 'Kalam' || f == 'Patrick Hand') ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: primaryAccent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Script',
                                      style: TextStyle(fontSize: 9, color: primaryAccent, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            onUpdate(textItem.copyWith(fontFamily: val));
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // 4. Font size stepper & quick menu
                  Container(
                    height: 34,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF262E44) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF333E5C) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                          onTap: () {
                            if (textItem.fontSize > 10) {
                              onUpdate(textItem.copyWith(fontSize: textItem.fontSize - 2));
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                            child: Icon(Icons.remove, size: 14, color: iconCol),
                          ),
                        ),
                        PopupMenuButton<double>(
                          tooltip: 'Choose font size',
                          initialValue: textItem.fontSize,
                          color: isDark ? const Color(0xFF1E2436) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${textItem.fontSize.toInt()}',
                                  style: TextStyle(color: textCol, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'pt',
                                  style: TextStyle(color: iconCol, fontSize: 10, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          itemBuilder: (ctx) => _presetSizes.map((s) {
                            final isSel = textItem.fontSize.toInt() == s.toInt();
                            return PopupMenuItem<double>(
                              value: s,
                              height: 32,
                              child: Row(
                                children: [
                                  Text(
                                    '${s.toInt()} pt',
                                    style: TextStyle(
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                      color: isSel ? primaryAccent : textCol,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (isSel) ...[
                                    const Spacer(),
                                    Icon(Icons.check, size: 16, color: primaryAccent),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                          onSelected: (val) => onUpdate(textItem.copyWith(fontSize: val)),
                        ),
                        InkWell(
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                          onTap: () {
                            if (textItem.fontSize < 96) {
                              onUpdate(textItem.copyWith(fontSize: textItem.fontSize + 2));
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                            child: Icon(Icons.add, size: 14, color: iconCol),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildDivider(border),

                  // 5. Bold, Italic, Underline, Strikethrough
                  _buildFormatToggle(
                    icon: Icons.format_bold_rounded,
                    isActive: textItem.isBold,
                    tooltip: 'Bold',
                    isDark: isDark,
                    onTap: () => onUpdate(textItem.copyWith(isBold: !textItem.isBold)),
                  ),
                  const SizedBox(width: 3),
                  _buildFormatToggle(
                    icon: Icons.format_italic_rounded,
                    isActive: textItem.isItalic,
                    tooltip: 'Italic',
                    isDark: isDark,
                    onTap: () => onUpdate(textItem.copyWith(isItalic: !textItem.isItalic)),
                  ),
                  const SizedBox(width: 3),
                  _buildFormatToggle(
                    icon: Icons.format_underlined_rounded,
                    isActive: textItem.isUnderline,
                    tooltip: 'Underline',
                    isDark: isDark,
                    onTap: () => onUpdate(textItem.copyWith(isUnderline: !textItem.isUnderline)),
                  ),
                  const SizedBox(width: 3),
                  _buildFormatToggle(
                    icon: Icons.strikethrough_s_rounded,
                    isActive: textItem.isStrikethrough,
                    tooltip: 'Strikethrough',
                    isDark: isDark,
                    onTap: () => onUpdate(textItem.copyWith(isStrikethrough: !textItem.isStrikethrough)),
                  ),
                  _buildDivider(border),

                  // 6. Text Alignment
                  _buildFormatToggle(
                    icon: Icons.format_align_left_rounded,
                    isActive: textItem.alignment == TextAlign.left,
                    tooltip: 'Align Left',
                    isDark: isDark,
                    onTap: () => onUpdate(textItem.copyWith(alignment: TextAlign.left)),
                  ),
                  const SizedBox(width: 2),
                  _buildFormatToggle(
                    icon: Icons.format_align_center_rounded,
                    isActive: textItem.alignment == TextAlign.center,
                    tooltip: 'Align Center',
                    isDark: isDark,
                    onTap: () => onUpdate(textItem.copyWith(alignment: TextAlign.center)),
                  ),
                  const SizedBox(width: 2),
                  _buildFormatToggle(
                    icon: Icons.format_align_right_rounded,
                    isActive: textItem.alignment == TextAlign.right,
                    tooltip: 'Align Right',
                    isDark: isDark,
                    onTap: () => onUpdate(textItem.copyWith(alignment: TextAlign.right)),
                  ),
                  _buildDivider(border),

                  // 7. Quick Ink Color Swatches
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _quickColors.map((c) {
                      final isSelected = textItem.color.toARGB32() == c.toARGB32();
                      return GestureDetector(
                        onTap: () => onUpdate(textItem.copyWith(color: c)),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? primaryAccent
                                  : (c == Colors.white ? const Color(0xFFCBD5E1) : Colors.transparent),
                              width: isSelected ? 2.5 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: primaryAccent.withValues(alpha: 0.4),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    )
                                  ]
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  // Custom Color Picker
                  IconButton(
                    icon: const Icon(Icons.palette_outlined, size: 18),
                    tooltip: 'Custom text color',
                    color: iconCol,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => _showCustomColorPicker(context),
                  ),
                  _buildDivider(border),

                  // 8. Box Styling Customizer (Fill, Border, Roundness)
                  _buildBoxCustomizerButton(context, isDark, primaryAccent),
                  _buildDivider(border),

                  // 9. Duplicate
                  _buildIconButton(
                    icon: Icons.copy_rounded,
                    tooltip: 'Duplicate text box',
                    color: iconCol,
                    onTap: onDuplicate,
                  ),
                  const SizedBox(width: 2),

                  // 10. Delete
                  _buildIconButton(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Delete text box',
                    color: const Color(0xFFEF4444),
                    onTap: onDelete,
                  ),
                  const SizedBox(width: 4),

                  // 11. Done
                  _buildIconButton(
                    icon: Icons.check_circle_outline_rounded,
                    tooltip: 'Done',
                    color: primaryAccent,
                    onTap: onClose,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Style Presets Popup ───────────────────────────────────────────────────

  Widget _buildStylePresetsButton(BuildContext context, bool isDark, Color primaryAccent) {
    final hasBackground = textItem.backgroundColor != null;
    final iconCol = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Tooltip(
      message: 'Card & Note Box Presets',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showPresetsSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: hasBackground
                ? primaryAccent.withValues(alpha: 0.15)
                : (isDark ? const Color(0xFF262E44) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasBackground ? primaryAccent : (isDark ? const Color(0xFF333E5C) : const Color(0xFFE2E8F0)),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasBackground ? Icons.style_rounded : Icons.style_outlined,
                size: 16,
                color: hasBackground ? primaryAccent : iconCol,
              ),
              const SizedBox(width: 5),
              Text(
                'Box Style',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: hasBackground ? primaryAccent : (isDark ? Colors.white : Colors.black87),
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.arrow_drop_down, size: 16, color: iconCol),
            ],
          ),
        ),
      ),
    );
  }

  void _showPresetsSheet(BuildContext context) {
    final presets = [
      {
        'title': 'Plain Text',
        'desc': 'No background, clean notes',
        'bg': null,
        'border': null,
        'borderWidth': 0.0,
        'textCol': isDark ? Colors.white : const Color(0xFF0F172A),
        'icon': Icons.title_rounded,
      },
      {
        'title': 'Sticky Note',
        'desc': 'Classic warm amber paper',
        'bg': const Color(0xFFFEF3C7),
        'border': const Color(0xFFF59E0B),
        'borderWidth': 1.2,
        'textCol': const Color(0xFF78350F),
        'icon': Icons.note_alt_rounded,
      },
      {
        'title': 'Pastel Mint',
        'desc': 'Refreshing green callout',
        'bg': const Color(0xFFD1FAE5),
        'border': const Color(0xFF10B981),
        'borderWidth': 1.2,
        'textCol': const Color(0xFF065F46),
        'icon': Icons.eco_rounded,
      },
      {
        'title': 'Sky Blue',
        'desc': 'Professional info note',
        'bg': const Color(0xFFDBEAFE),
        'border': const Color(0xFF3B82F6),
        'borderWidth': 1.2,
        'textCol': const Color(0xFF1E40AF),
        'icon': Icons.info_outline_rounded,
      },
      {
        'title': 'Blush Rose',
        'desc': 'Warm highlight box',
        'bg': const Color(0xFFFCE7F3),
        'border': const Color(0xFFEC4899),
        'borderWidth': 1.2,
        'textCol': const Color(0xFF9D174D),
        'icon': Icons.favorite_border_rounded,
      },
      {
        'title': 'Soft Lavender',
        'desc': 'Creative idea card',
        'bg': const Color(0xFFEDE9FE),
        'border': const Color(0xFF8B5CF6),
        'borderWidth': 1.2,
        'textCol': const Color(0xFF5B21B6),
        'icon': Icons.lightbulb_outline_rounded,
      },
      {
        'title': 'Modern Note Card',
        'desc': 'Clean card with soft border',
        'bg': isDark ? const Color(0xFF1E293B) : Colors.white,
        'border': isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        'borderWidth': 1.5,
        'textCol': isDark ? Colors.white : const Color(0xFF0F172A),
        'icon': Icons.crop_square_rounded,
      },
      {
        'title': 'Outlined Box',
        'desc': 'Transparent with border',
        'bg': null,
        'border': const Color(0xFF6366F1),
        'borderWidth': 1.8,
        'textCol': isDark ? Colors.white : const Color(0xFF0F172A),
        'icon': Icons.border_all_rounded,
      },
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2436) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.style_rounded, color: Color(0xFF6366F1), size: 22),
            const SizedBox(width: 8),
            Text(
              'GoodNotes Text Box Styles',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: presets.map((p) {
                final bgCol = p['bg'] as Color?;
                final borderCol = p['border'] as Color?;
                final tCol = p['textCol'] as Color;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onUpdate(textItem.copyWith(
                        backgroundColor: bgCol,
                        clearBackgroundColor: bgCol == null,
                        borderColor: borderCol,
                        clearBorderColor: borderCol == null,
                        borderWidth: (p['borderWidth'] as double?) ?? 0.0,
                        color: tCol,
                        padding: bgCol != null || borderCol != null ? 12.0 : 8.0,
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: bgCol ?? (isDark ? const Color(0xFF262E44) : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: borderCol ?? (isDark ? const Color(0xFF333E5C) : const Color(0xFFE2E8F0)),
                          width: (p['borderWidth'] as double?) ?? 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(p['icon'] as IconData, size: 20, color: tCol),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['title'] as String,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: tCol,
                                  ),
                                ),
                                Text(
                                  p['desc'] as String,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: tCol.withValues(alpha: 0.75),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: tCol.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Apply',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tCol),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  // ── Box Customizer (Fill, Border, Radius, Padding) ─────────────────────────

  Widget _buildBoxCustomizerButton(BuildContext context, bool isDark, Color primaryAccent) {
    return Tooltip(
      message: 'Customize Box Fill & Border',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showBoxCustomizerDialog(context),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(Icons.tune_rounded, size: 20, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
        ),
      ),
    );
  }

  void _showBoxCustomizerDialog(BuildContext context) {
    Color? tempBg = textItem.backgroundColor;
    Color? tempBorder = textItem.borderColor;
    double tempBorderWidth = textItem.borderWidth;
    double tempRadius = textItem.borderRadius;
    double tempPadding = textItem.padding;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E2436) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'Text Box Appearance',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Background fill
                  const Text('Fill Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildMiniColorCircle(
                        color: Colors.transparent,
                        label: 'None',
                        isSelected: tempBg == null,
                        onTap: () => setDialogState(() => tempBg = null),
                      ),
                      const SizedBox(width: 8),
                      for (final c in [
                        const Color(0xFFFEF3C7), // Yellow
                        const Color(0xFFD1FAE5), // Mint
                        const Color(0xFFDBEAFE), // Sky
                        const Color(0xFFFCE7F3), // Rose
                        const Color(0xFFEDE9FE), // Lavender
                        isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9), // Neutral
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: _buildMiniColorCircle(
                            color: c,
                            isSelected: tempBg?.toARGB32() == c.toARGB32(),
                            onTap: () => setDialogState(() => tempBg = c),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Border stroke
                  const Text('Border Stroke', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildMiniColorCircle(
                        color: Colors.transparent,
                        label: 'None',
                        isSelected: tempBorder == null || tempBorderWidth == 0,
                        onTap: () => setDialogState(() {
                          tempBorder = null;
                          tempBorderWidth = 0.0;
                        }),
                      ),
                      const SizedBox(width: 8),
                      for (final c in [
                        const Color(0xFF6366F1), // Indigo
                        const Color(0xFF0F172A), // Black
                        const Color(0xFFCBD5E1), // Light Grey
                        const Color(0xFF10B981), // Green
                        const Color(0xFFEF4444), // Red
                        const Color(0xFFF59E0B), // Amber
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: _buildMiniColorCircle(
                            color: c,
                            isSelected: tempBorder?.toARGB32() == c.toARGB32(),
                            onTap: () => setDialogState(() {
                              tempBorder = c;
                              if (tempBorderWidth == 0) tempBorderWidth = 1.5;
                            }),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Corner Radius Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Corner Radius', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('${tempRadius.toInt()}px', style: const TextStyle(fontSize: 12, color: Color(0xFF6366F1))),
                    ],
                  ),
                  Slider(
                    value: tempRadius.clamp(0.0, 32.0),
                    min: 0.0,
                    max: 32.0,
                    divisions: 16,
                    activeColor: const Color(0xFF6366F1),
                    onChanged: (v) => setDialogState(() => tempRadius = v),
                  ),

                  // Internal Padding Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Internal Padding', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('${tempPadding.toInt()}px', style: const TextStyle(fontSize: 12, color: Color(0xFF6366F1))),
                    ],
                  ),
                  Slider(
                    value: tempPadding.clamp(4.0, 32.0),
                    min: 4.0,
                    max: 32.0,
                    divisions: 14,
                    activeColor: const Color(0xFF6366F1),
                    onChanged: (v) => setDialogState(() => tempPadding = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Apply'),
              onPressed: () {
                Navigator.of(ctx).pop();
                onUpdate(textItem.copyWith(
                  backgroundColor: tempBg,
                  clearBackgroundColor: tempBg == null,
                  borderColor: tempBorder,
                  clearBorderColor: tempBorder == null,
                  borderWidth: tempBorderWidth,
                  borderRadius: tempRadius,
                  padding: tempPadding,
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniColorCircle({
    required Color color,
    String? label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color == Colors.transparent ? Colors.grey.withValues(alpha: 0.2) : color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFCBD5E1),
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: label != null
            ? const Center(
                child: Text('∅', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
              )
            : (isSelected
                ? const Icon(Icons.check, size: 14, color: Color(0xFF6366F1))
                : null),
      ),
    );
  }

  // ── Custom Ink Color Picker Dialog ────────────────────────────────────────

  void _showCustomColorPicker(BuildContext context) {
    Color pickerColor = textItem.color;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2436) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Pick Text Ink Color',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (c) => pickerColor = c,
            enableAlpha: false,
            displayThumbColor: true,
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Select'),
            onPressed: () {
              Navigator.of(ctx).pop();
              onUpdate(textItem.copyWith(color: pickerColor));
            },
          ),
        ],
      ),
    );
  }

  // ── Helper Widgets ────────────────────────────────────────────────────────

  Widget _buildDivider(Color borderColor) {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 7),
      color: borderColor,
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required String label,
    required Color accentColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: accentColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }

  Widget _buildFormatToggle({
    required IconData icon,
    required bool isActive,
    required String tooltip,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? const Color(0xFF6366F1).withValues(alpha: 0.28) : const Color(0xFFEEF2FF))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? const Color(0xFF6366F1) : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive
                ? const Color(0xFF6366F1)
                : (isDark ? Colors.white70 : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }
}
