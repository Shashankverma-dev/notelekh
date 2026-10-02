import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_workspace_client/state/app_state.dart';
import 'package:ai_workspace_client/features/dashboard/widgets/notification_center_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('NotificationCenterDialog displays notifications, filters tabs, and marks read', (tester) async {
    final state = AppState();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationCenterDialog(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify dialog header
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.textContaining('All ('), findsOneWidget);
    expect(find.textContaining('Unread ('), findsOneWidget);

    // Verify initial notifications are rendered
    expect(find.text('GoodNotes Engine Active'), findsOneWidget);
    expect(find.text('Cloud Auto-Backup Complete'), findsOneWidget);

    // Tap on Unread filter tab
    final unreadTab = find.textContaining('Unread (');
    await tester.tap(unreadTab);
    await tester.pumpAndSettle();

    // Tap "Mark all as read" icon button
    final markAllButton = find.byTooltip('Mark all as read');
    expect(markAllButton, findsOneWidget);
    await tester.tap(markAllButton);
    await tester.pumpAndSettle();

    // In Unread tab, after marking all as read, should show empty state
    expect(find.text('All Caught Up!'), findsOneWidget);
    expect(state.unreadNotificationCount, equals(0));

    // Switch back to "All" tab
    final allTab = find.textContaining('All (');
    await tester.tap(allTab);
    await tester.pumpAndSettle();

    // Still has notifications in All
    expect(find.text('GoodNotes Engine Active'), findsOneWidget);

    // Tap "Clear all" button
    final clearAllButton = find.text('Clear all');
    expect(clearAllButton, findsOneWidget);
    await tester.tap(clearAllButton);
    await tester.pumpAndSettle();

    // Everything is cleared
    expect(find.text('All Caught Up!'), findsOneWidget);
    expect(find.text('No notifications at this time.'), findsOneWidget);
    expect(state.notifications, isEmpty);
  });
}
