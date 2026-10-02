class WorkspaceModel {
  final String id;
  final String userId;
  final String name;
  final String description;
  final String icon;
  final bool isPinned;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int conversationCount;
  final int fileCount;
  final int canvasCount;

  WorkspaceModel({
    required this.id,
    required this.userId,
    required this.name,
    this.description = '',
    this.icon = 'folder',
    this.isPinned = false,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
    this.conversationCount = 0,
    this.fileCount = 0,
    this.canvasCount = 0,
  });

  factory WorkspaceModel.fromJson(Map<String, dynamic> json) {
    return WorkspaceModel(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? 'folder',
      isPinned: json['is_pinned'] as bool? ?? false,
      archivedAt: json['archived_at'] != null ? DateTime.parse(json['archived_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      conversationCount: json['conversation_count'] as int? ?? 0,
      fileCount: json['file_count'] as int? ?? 0,
      canvasCount: json['canvas_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'icon': icon,
      'is_pinned': isPinned,
      'archived_at': archivedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
