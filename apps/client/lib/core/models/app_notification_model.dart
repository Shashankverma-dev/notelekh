enum NotificationType {
  system,
  sync,
  study,
  notebook,
  ai,
}

class AppNotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  bool isRead;
  final String? docId;
  final String? route;

  AppNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.type = NotificationType.system,
    this.isRead = false,
    this.docId,
    this.route,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        'type': type.name,
        'isRead': isRead,
        if (docId != null) 'docId': docId,
        if (route != null) 'route': route,
      };

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) => AppNotificationItem(
        id: json['id'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
        type: NotificationType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => NotificationType.system,
        ),
        isRead: json['isRead'] as bool? ?? false,
        docId: json['docId'] as String?,
        route: json['route'] as String?,
      );
}
