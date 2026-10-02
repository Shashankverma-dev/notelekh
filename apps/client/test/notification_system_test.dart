import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_workspace_client/core/models/app_notification_model.dart';
import 'package:ai_workspace_client/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Notification System Tests', () {
    test('AppNotificationItem serializes and deserializes accurately', () {
      final now = DateTime.now();
      final item = AppNotificationItem(
        id: 'test-1',
        title: 'Sync Successful',
        message: 'All notebooks are synced to the cloud.',
        timestamp: now,
        type: NotificationType.sync,
        isRead: false,
        docId: 'doc-123',
      );

      final json = item.toJson();
      final revived = AppNotificationItem.fromJson(json);

      expect(revived.id, equals('test-1'));
      expect(revived.title, equals('Sync Successful'));
      expect(revived.message, equals('All notebooks are synced to the cloud.'));
      expect(revived.type, equals(NotificationType.sync));
      expect(revived.isRead, isFalse);
      expect(revived.docId, equals('doc-123'));
    });

    test('AppState manages notification lifecycle, unread counts, and read status', () {
      final state = AppState();

      // Ensure initial notifications are loaded
      final notifs = state.notifications;
      expect(notifs, isNotEmpty);

      final initialUnread = state.unreadNotificationCount;
      expect(initialUnread, greaterThan(0));

      // Find an unread notification and mark it as read
      final firstUnread = notifs.firstWhere((n) => !n.isRead);
      state.markNotificationAsRead(firstUnread.id);

      expect(state.unreadNotificationCount, equals(initialUnread - 1));

      // Mark all as read
      state.markAllNotificationsAsRead();
      expect(state.unreadNotificationCount, equals(0));

      // Add a new notification
      state.addNotification(
        title: 'New Page Created',
        message: 'Page added to Ruled Notebook.',
        type: NotificationType.notebook,
      );

      expect(state.unreadNotificationCount, equals(1));
      expect(state.notifications.first.title, equals('New Page Created'));

      // Delete the notification
      final newNotifId = state.notifications.first.id;
      state.deleteNotification(newNotifId);
      expect(state.unreadNotificationCount, equals(0));

      // Clear all notifications
      state.clearAllNotifications();
      expect(state.notifications, isEmpty);
      expect(state.unreadNotificationCount, equals(0));
    });
  });
}
