import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_workspace_client/core/theme/app_theme.dart';

/// Comprehensive color picker widget supporting:
/// - Compact toolbar swatches
/// - Recently used colors with SharedPreferences persistence
/// - Preset curated Goodnotes palettes
/// - Full flutter_colorpicker custom picker with HSV / RGB
/// - HEX input field
/// - Opacity slider
/// - Old vs New color preview
class CanvasColorPicker {
  static const String _prefRecentColorsKey = 'canvas_recent_colors';

  /// Default curated Goodnotes-style palette
  static const List<Color> presetColors = [
    // Standard Inks
    Color(0xFF0F172A), // Slate Black
    Color(0xFF1E293B), // Dark Charcoal
    Color(0xFF2563EB), // Royal Blue
    Color(0xFF3B82F6), // Sky Blue
    Color(0xFF059669), // Forest Green
    Color(0xFF10B981), // Emerald
    Color(0xFFDC2626), // Crimson
    Color(0xFFEA580C), // Deep Orange
    Color(0xFF7C3AED), // Violet
    Color(0xFFDB2777), // Pink
    // Highlighters / Pastels
    Color(0xFFFDE047), // Pastel Yellow
    Color(0xFF86EFAC), // Pastel Green
    Color(0xFF93C5FD), // Pastel Blue
    Color(0xFFF9A8D4), // Pastel Pink
    Color(0xFFC4B5FD), // Pastel Lavender
    Color(0xFFFDBA74), // Pastel Peach
  ];

  /// Loads recent colors from local storage
  static Future<List<Color>> loadRecentColors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_prefRecentColorsKey);
      if (savedJson != null) {
        final List<dynamic> list = jsonDecode(savedJson);
        return list.map((val) => Color(val as int)).toList();
      }
    } catch (_) {}
    return [
      const Color(0xFF0F172A),
      const Color(0xFF2563EB),
      const Color(0xFFDC2626),
      const Color(0xFF059669),
    ];
  }

  /// Saves a color to recent history (max 8)
  static Future<void> addRecentColor(Color color) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recents = await loadRecentColors();
      final colorVal = color.toARGB32();

      final updated = [colorVal, ...recents.map((c) => c.toARGB32()).where((v) => v != colorVal)].take(8).toList();
      await prefs.setString(_prefRecentColorsKey, jsonEncode(updated));
    } catch (_) {}
  }

  /// Opens the full modal color picker dialog
  static Future<void> showFullPicker({
    required BuildContext context,
    required Color currentColor,
    required ValueChanged<Color> onColorChanged,
    bool isDark = true,
  }) async {
    final recents = await loadRecentColors();

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => _FullColorPickerDialog(
        initialColor: currentColor,
        recentColors: recents,
        isDark: isDark,
        onColorSelected: (newColor) async {
          await addRecentColor(newColor);
          onColorChanged(newColor);
        },
      ),
    );
  }
}

/// Compact inline toolbar color selector widget
class CompactColorSelector extends StatelessWidget {
  final Color currentColor;
  final ValueChanged<Color> onColorChanged;
  final VoidCallback onOpenFullPicker;
  final bool isDark;

  const CompactColorSelector({
    super.key,
    required this.currentColor,
    required this.onColorChanged,
    required this.onOpenFullPicker,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    // Top 3 quick colors + full picker button
    final quickColors = [
      const Color(0xFF0F172A),
      const Color(0xFF2563EB),
      const Color(0xFFDC2626),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2433) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 3 Quick swatches
          for (final color in quickColors)
            GestureDetector(
              onTap: () => onColorChanged(color),
              child: Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: currentColor.toARGB32() == color.toARGB32()
                        ? (isDark ? Colors.white : AppColors.primary)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            ),

          const SizedBox(width: 2),

          // Active color button (tapping opens full picker)
          GestureDetector(
            onTap: onOpenFullPicker,
            child: Tooltip(
              message: 'Custom Color Picker',
              child: Container(
                width: 24,
                height: 24,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(
                    colors: [
                      Colors.red,
                      Colors.amber,
                      Colors.green,
                      Colors.cyan,
                      Colors.blue,
                      Colors.purple,
                      Colors.red,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: currentColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full comprehensive modal dialog with HSV, RGB, HEX, Swatches, and Recents
class _FullColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final List<Color> recentColors;
  final ValueChanged<Color> onColorSelected;
  final bool isDark;

  const _FullColorPickerDialog({
    required this.initialColor,
    required this.recentColors,
    required this.onColorSelected,
    required this.isDark,
  });

  @override
  State<_FullColorPickerDialog> createState() => _FullColorPickerDialogState();
}

class _FullColorPickerDialogState extends State<_FullColorPickerDialog> {
  late Color _pickerColor;
  late TextEditingController _hexController;
  late List<Color> _recents;

  @override
  void initState() {
    super.initState();
    _pickerColor = widget.initialColor;
    _recents = List.from(widget.recentColors);
    _hexController = TextEditingController(
      text: _pickerColor.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase().substring(2),
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _onColorChanged(Color color) {
    setState(() {
      _pickerColor = color;
      _hexController.text = color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase().substring(2);
    });
  }

  void _onHexSubmitted(String hex) {
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6 || clean.length == 8) {
      final val = int.tryParse(clean.length == 6 ? 'FF$clean' : clean, radix: 16);
      if (val != null) {
        setState(() {
          _pickerColor = Color(val);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF161A26) : Colors.white;
    final textPrimary = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = widget.isDark ? const Color(0xFF1E2433) : const Color(0xFFF8FAFC);
    final borderColor = widget.isDark ? const Color(0xFF2A3245) : const Color(0xFFE2E8F0);

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor),
      ),
      child: Container(
        width: 380,
        constraints: const BoxConstraints(maxHeight: 680),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Color Palette',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Old vs New color preview & HEX input
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    // Dual preview box (original vs current)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 56,
                        height: 38,
                        child: Row(
                          children: [
                            Expanded(child: Container(color: widget.initialColor)),
                            Expanded(child: Container(color: _pickerColor)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // HEX input field
                    Expanded(
                      child: TextField(
                        controller: _hexController,
                        style: GoogleFonts.firaCode(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                        decoration: InputDecoration(
                          prefixText: '# ',
                          prefixStyle: GoogleFonts.firaCode(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                        ),
                        onSubmitted: _onHexSubmitted,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Full flutter_colorpicker ColorPicker widget
              ColorPicker(
                pickerColor: _pickerColor,
                onColorChanged: _onColorChanged,
                enableAlpha: true,
                displayThumbColor: true,
                paletteType: PaletteType.hsvWithHue,
                labelTypes: const [ColorLabelType.rgb, ColorLabelType.hsv],
                pickerAreaHeightPercent: 0.55,
                pickerAreaBorderRadius: BorderRadius.circular(12),
              ),

              const SizedBox(height: 16),

              // Preset curated swatches
              Text(
                'PRESETS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CanvasColorPicker.presetColors.map((color) {
                  final isSelected = _pickerColor.toARGB32() == color.toARGB32();
                  return GestureDetector(
                    onTap: () => _onColorChanged(color),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : (widget.isDark ? Colors.black26 : Colors.black12),
                          width: isSelected ? 2.5 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.5),
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

              // Recently used colors
              if (_recents.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'RECENTLY USED',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _recents.map((color) {
                    final isSelected = _pickerColor.toARGB32() == color.toARGB32();
                    return GestureDetector(
                      onTap: () => _onColorChanged(color),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : (widget.isDark ? Colors.black26 : Colors.black12),
                            width: isSelected ? 2.5 : 1.0,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 20),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(color: textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () {
                      widget.onColorSelected(_pickerColor);
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Apply Color',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
