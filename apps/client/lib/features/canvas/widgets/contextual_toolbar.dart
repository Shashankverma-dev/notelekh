import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_workspace_client/core/theme/app_theme.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';

/// Floating contextual toolbar displayed above selected strokes, shapes, or notes.
/// Provides instant actions: Duplicate, Delete, Recolor, and Layer Order.
class ContextualToolbar extends StatelessWidget {
  final List<CanvasObjectItem> selectedObjects;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final ValueChanged<Color> onRecolor;
  final VoidCallback onBringToFront;
  final VoidCallback onSendToBack;
  final VoidCallback onDeselect;
  final bool isDark;

  const ContextualToolbar({
    super.key,
    required this.selectedObjects,
    required this.onDuplicate,
    required this.onDelete,
    required this.onRecolor,
    required this.onBringToFront,
    required this.onSendToBack,
    required this.onDeselect,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedObjects.isEmpty) return const SizedBox.shrink();

    final bg = isDark ? const Color(0xFF1E2433) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2A3245) : const Color(0xFFE2E8F0);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final quickColors = [
      const Color(0xFF0F172A),
      const Color(0xFF2563EB),
      const Color(0xFFDC2626),
      const Color(0xFF059669),
      const Color(0xFF7C3AED),
    ];

    final screenWidth = MediaQuery.of(context).size.width;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxWidth: (screenWidth - 20.0).clamp(120.0, double.infinity)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selected item count badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${selectedObjects.length} selected',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),

              const SizedBox(width: 6),
              _divider(borderColor),
              const SizedBox(width: 6),

              // Quick recolor swatches
              for (final color in quickColors)
                GestureDetector(
                  onTap: () => onRecolor(color),
                  child: Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                    ),
                  ),
                ),

              const SizedBox(width: 6),
              _divider(borderColor),
              const SizedBox(width: 4),

              // Duplicate button
              _actionBtn(
                icon: Icons.copy_rounded,
                tooltip: 'Duplicate',
                onPressed: onDuplicate,
                color: textSecondary,
              ),

              // Bring forward
              _actionBtn(
                icon: Icons.flip_to_front_rounded,
                tooltip: 'Bring to Front',
                onPressed: onBringToFront,
                color: textSecondary,
              ),

              // Send backward
              _actionBtn(
                icon: Icons.flip_to_back_rounded,
                tooltip: 'Send to Back',
                onPressed: onSendToBack,
                color: textSecondary,
              ),

              _divider(borderColor),

              // Delete button
              _actionBtn(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Delete',
                onPressed: onDelete,
                color: Colors.redAccent,
              ),

              // Close / Deselect
              _actionBtn(
                icon: Icons.close_rounded,
                tooltip: 'Deselect',
                onPressed: onDeselect,
                color: textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider(Color color) {
    return Container(
      width: 1,
      height: 20,
      color: color,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}
