import 'package:ai_workspace_client/core/models/message_model.dart';

class ConversationModel {
  final String id;
  final String? workspaceId;
  final String userId;
  final String title;
  final String status; // 'active', 'saved', 'archived'
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<MessageModel> messages;

  ConversationModel({
    required this.id,
    this.workspaceId,
    required this.userId,
    required this.title,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    var rawMessages = json['messages'] as List<dynamic>? ?? [];
    List<MessageModel> msgList = rawMessages
        .map((e) => MessageModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return ConversationModel(
      id: json['id'] as String,
      workspaceId: json['workspace_id'] as String?,
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Chat',
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      messages: msgList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workspace_id': workspaceId,
      'user_id': userId,
      'title': title,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }
}
