import 'package:ai_workspace_client/core/models/context_item_model.dart';

class MessageModel {
  final String id;
  final String conversationId;
  final String role; // 'user', 'assistant', 'system'
  final String content;
  final String model;
  final List<ContextItemModel> selectedContext;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.model = 'gpt-4o-mini',
    this.selectedContext = const [],
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    var rawContext = json['selected_context'] as List<dynamic>? ?? [];
    List<ContextItemModel> ctxList = rawContext
        .map((e) => ContextItemModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String? ?? '',
      role: json['role'] as String,
      content: json['content'] as String,
      model: json['model'] as String? ?? 'gpt-4o-mini',
      selectedContext: ctxList,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'role': role,
      'content': content,
      'model': model,
      'selected_context': selectedContext.map((c) => c.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  MessageModel copyWith({String? content}) {
    return MessageModel(
      id: id,
      conversationId: conversationId,
      role: role,
      content: content ?? this.content,
      model: model,
      selectedContext: selectedContext,
      createdAt: createdAt,
    );
  }
}
