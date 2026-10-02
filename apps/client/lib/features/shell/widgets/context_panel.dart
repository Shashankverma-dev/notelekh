import 'package:flutter/material.dart';
import 'package:ai_workspace_client/core/theme/app_theme.dart';
import 'package:ai_workspace_client/state/app_state.dart';

class ContextPanel extends StatelessWidget {
  final AppState state;

  const ContextPanel({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final isDark = state.isDarkMode;
    final bg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final currentWs = state.currentWorkspace;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: bg,
        border: Border(left: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.layers_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'AI Context Tray',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (state.selectedContextItems.isNotEmpty)
                  TextButton(
                    onPressed: state.clearContextTray,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Clear', style: TextStyle(fontSize: 12, color: AppColors.error)),
                  ),
              ],
            ),
          ),

          const Divider(),

          // Active Context Items Tray
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Text(
                  'ACTIVE CONTEXT (${state.selectedContextItems.length})',
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                if (state.selectedContextItems.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Selective Mode',
                      style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),

          if (state.selectedContextItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    Icon(Icons.touch_app_outlined, color: textMuted, size: 24),
                    const SizedBox(height: 6),
                    Text(
                      'No content selected',
                      style: TextStyle(color: textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select canvas drawings, chat messages, or files to feed only relevant context into AI.',
                      style: TextStyle(color: textMuted, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              flex: 2,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: state.selectedContextItems.length,
                itemBuilder: (context, index) {
                  final item = state.selectedContextItems[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _getContextIcon(item.type),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (item.content != null && item.content!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  item.content!,
                                  style: TextStyle(color: textMuted, fontSize: 11),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => state.removeContextItem(item),
                          child: Icon(Icons.close, size: 14, color: textMuted),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          const Divider(),

          // Workspace Overview Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              'WORKSPACE ASSETS',
              style: TextStyle(
                color: textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),

          if (currentWs != null)
            Expanded(
              flex: 3,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _resourceSummaryTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Saved Conversations',
                    count: state.conversations.length,
                    onTap: () => state.setNavIndex(1),
                    color: AppColors.primary,
                    isDark: isDark,
                  ),
                  _resourceSummaryTile(
                    icon: Icons.gesture_rounded,
                    title: 'Canvas Notebooks',
                    count: currentWs.canvasCount > 0 ? currentWs.canvasCount : 1,
                    onTap: () => state.setNavIndex(3),
                    color: AppColors.accent,
                    isDark: isDark,
                  ),
                  _resourceSummaryTile(
                    icon: Icons.insert_drive_file_outlined,
                    title: 'Attached Files',
                    count: state.workspaceFiles.length,
                    onTap: () => state.setNavIndex(4),
                    color: AppColors.warning,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  // Workspace metadata card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.folder_outlined, size: 15, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                currentWs.name,
                                style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (currentWs.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            currentWs.description,
                            style: TextStyle(color: textMuted, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Select a workspace to view resources',
                style: TextStyle(color: textMuted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _getContextIcon(String type) {
    switch (type) {
      case 'canvas':
        return const Icon(Icons.gesture_rounded, size: 16, color: AppColors.accent);
      case 'file':
        return const Icon(Icons.insert_drive_file_rounded, size: 16, color: AppColors.warning);
      case 'highlight':
        return const Icon(Icons.highlight_rounded, size: 16, color: AppColors.highlightYellow);
      case 'chat':
      default:
        return const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.primary);
    }
  }

  Widget _resourceSummaryTile({
    required IconData icon,
    required String title,
    required int count,
    required VoidCallback onTap,
    required Color color,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
