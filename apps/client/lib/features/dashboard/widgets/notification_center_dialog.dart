import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_workspace_client/core/models/app_notification_model.dart';
import 'package:ai_workspace_client/state/app_state.dart';

class NotificationCenterDialog extends StatefulWidget {
  final AppState state;

  const NotificationCenterDialog({super.key, required this.state});

  static Future<void> show(BuildContext context, AppState state) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => NotificationCenterDialog(state: state),
    );
  }

  @override
  State<NotificationCenterDialog> createState() => _NotificationCenterDialogState();
}

class _NotificationCenterDialogState extends State<NotificationCenterDialog> {
  int _selectedTab = 0; // 0: All, 1: Unread

  String _formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}';
  }

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.system:
        return const Color(0xFF2563EB); // Royal Blue
      case NotificationType.sync:
        return const Color(0xFF10B981); // Emerald
      case NotificationType.study:
        return const Color(0xFFF59E0B); // Amber
      case NotificationType.notebook:
        return const Color(0xFF0284C7); // Sky Blue
      case NotificationType.ai:
        return const Color(0xFF8B5CF6); // Violet
    }
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.system:
        return Icons.auto_awesome_rounded;
      case NotificationType.sync:
        return Icons.cloud_done_rounded;
      case NotificationType.study:
        return Icons.school_rounded;
      case NotificationType.notebook:
        return Icons.menu_book_rounded;
      case NotificationType.ai:
        return Icons.psychology_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.state.isDarkMode;
    final allNotifs = widget.state.notifications;
    final unreadCount = widget.state.unreadNotificationCount;
    final displayed = _selectedTab == 0
        ? allNotifs
        : allNotifs.where((n) => !n.isRead).toList();

    final bgColor = isDark ? const Color(0xFF131823) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1A2234) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF263249) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 72, right: 32),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 400,
            constraints: const BoxConstraints(maxHeight: 560),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Top Header ─────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF171E2D) : const Color(0xFFF8FAFC),
                      border: Border(bottom: BorderSide(color: borderColor)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 17),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'Notifications',
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              if (unreadCount > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    '$unreadCount new',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFEF4444),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (unreadCount > 0)
                          IconButton(
                            icon: const Icon(Icons.done_all_rounded, size: 19),
                            tooltip: 'Mark all as read',
                            visualDensity: VisualDensity.compact,
                            color: const Color(0xFF2563EB),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: () {
                              setState(() {
                                widget.state.markAllNotificationsAsRead();
                              });
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          tooltip: 'Close',
                          visualDensity: VisualDensity.compact,
                          color: textMuted,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),

                  // ── Tab Filters ───────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        _buildFilterTab(
                          label: 'All (${allNotifs.length})',
                          index: 0,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterTab(
                          label: 'Unread ($unreadCount)',
                          index: 1,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  // ── List of Notifications ─────────────────────────────────
                  Flexible(
                    child: displayed.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E2838) : const Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.done_all_rounded,
                                    size: 28,
                                    color: textMuted,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'All Caught Up!',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedTab == 1
                                      ? 'You have no unread notifications.'
                                      : 'No notifications at this time.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color: textMuted,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            itemCount: displayed.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (ctx, idx) {
                              final item = displayed[idx];
                              return _buildNotificationCard(
                                item: item,
                                cardBg: cardBg,
                                borderColor: borderColor,
                                textPrimary: textPrimary,
                                textMuted: textMuted,
                                isDark: isDark,
                              );
                            },
                          ),
                  ),

                  // ── Bottom Action Bar ─────────────────────────────────────
                  if (allNotifs.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF171E2D) : const Color(0xFFF8FAFC),
                        border: Border(top: BorderSide(color: borderColor)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFEF4444),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              setState(() {
                                widget.state.clearAllNotifications();
                              });
                            },
                            child: Text(
                              'Clear all',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              'Notelekh Workspace Sync',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 11.5, color: textMuted),
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
      ),
    );
  }

  Widget _buildFilterTab({
    required String label,
    required int index,
    required bool isDark,
  }) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF1E2838) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard({
    required AppNotificationItem item,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textMuted,
    required bool isDark,
  }) {
    final color = _getTypeColor(item.type);
    final icon = _getTypeIcon(item.type);

    return InkWell(
      onTap: () {
        setState(() {
          widget.state.markNotificationAsRead(item.id);
        });
        if (item.docId != null || item.route != null) {
          Navigator.of(context).pop();
          widget.state.setNavIndex(1);
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: item.isRead
              ? cardBg
              : (isDark ? const Color(0xFF1C273C) : const Color(0xFFEFF6FF)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: item.isRead
                ? borderColor
                : (isDark ? const Color(0xFF334B73) : const Color(0xFFBFDBFE)),
            width: item.isRead ? 1.0 : 1.4,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 12),
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w700,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatRelativeTime(item.timestamp),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.message,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Unread dot / Dismiss button
            Column(
              children: [
                if (!item.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 4, bottom: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 14),
                  tooltip: 'Dismiss',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  color: textMuted.withValues(alpha: 0.6),
                  onPressed: () {
                    setState(() {
                      widget.state.deleteNotification(item.id);
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
