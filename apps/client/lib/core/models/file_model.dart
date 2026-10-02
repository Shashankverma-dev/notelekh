class FileItemModel {
  final String id;
  final String workspaceId;
  final String name;
  final String mimeType;
  final int size;
  final String storageKey;
  final String processingStatus;
  final DateTime createdAt;
  final String? content;

  FileItemModel({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.mimeType,
    required this.size,
    required this.storageKey,
    this.processingStatus = 'ready',
    required this.createdAt,
    this.content,
  });

  factory FileItemModel.fromJson(Map<String, dynamic> json) {
    return FileItemModel(
      id: json['id'] as String,
      workspaceId: json['workspace_id'] as String? ?? 'default',
      name: json['name'] as String,
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
      size: json['size'] as int? ?? 0,
      storageKey: json['storage_key'] as String? ?? '',
      processingStatus: json['processing_status'] as String? ?? 'ready',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      content: json['content'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workspace_id': workspaceId,
      'name': name,
      'mime_type': mimeType,
      'size': size,
      'storage_key': storageKey,
      'processing_status': processingStatus,
      'created_at': createdAt.toIso8601String(),
      if (content != null) 'content': content,
    };
  }

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
