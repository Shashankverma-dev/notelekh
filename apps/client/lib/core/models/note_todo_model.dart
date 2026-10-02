class NoteTodoItem {
  final String id;
  String title;
  bool isCompleted;
  DateTime createdAt;

  NoteTodoItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
        'createdAt': createdAt.toIso8601String(),
      };

  factory NoteTodoItem.fromJson(Map<String, dynamic> json) => NoteTodoItem(
        id: json['id'] as String? ?? 'todo-${DateTime.now().millisecondsSinceEpoch}',
        title: json['title'] as String? ?? '',
        isCompleted: json['isCompleted'] as bool? ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );
}
