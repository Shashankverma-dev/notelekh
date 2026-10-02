class ContextItemModel {
  final String id;
  final String type; // 'chat', 'note', 'canvas', 'file', 'highlight'
  final String title;
  final String? content;
  final String? imageBase64;
  final Map<String, dynamic>? metadata;

  ContextItemModel({
    required this.id,
    required this.type,
    required this.title,
    this.content,
    this.imageBase64,
    this.metadata,
  });

  factory ContextItemModel.fromJson(Map<String, dynamic> json) {
    return ContextItemModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as String,
      title: json['title'] as String,
      content: json['content'] as String?,
      imageBase64: json['image_base64'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      if (content != null) 'content': content,
      if (imageBase64 != null) 'image_base64': imageBase64,
      if (metadata != null) 'metadata': metadata,
    };
  }
}
