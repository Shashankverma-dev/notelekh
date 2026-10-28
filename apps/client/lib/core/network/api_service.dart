import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ai_workspace_client/core/models/workspace_model.dart';
import 'package:ai_workspace_client/core/models/conversation_model.dart';
import 'package:ai_workspace_client/core/models/canvas_models.dart';
import 'package:ai_workspace_client/core/models/context_item_model.dart';
import 'package:ai_workspace_client/core/models/file_model.dart';
import 'package:ai_workspace_client/core/models/search_model.dart';

class ApiService {
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (kIsWeb) {
      try {
        final uri = Uri.base;
        final host = uri.host;
        // If loaded via Cloudflare Tunnel, localtunnel, or unified reverse proxy (port 5050)
        if (host.contains('trycloudflare.com') || host.contains('loca.lt') || uri.port == 5050) {
          return '${uri.origin}/v1';
        }
        // If accessed from LAN IP (e.g. 192.168.x.x from an iPad or phone),
        // route backend calls to the same PC host IP on port 8000.
        if (host.isNotEmpty &&
            host != 'localhost' &&
            host != '127.0.0.1' &&
            !host.contains('web.app') &&
            !host.contains('firebaseapp.com')) {
          return 'http://$host:8000/v1';
        }
      } catch (_) {}
    }
    return 'http://127.0.0.1:8000/v1';
  }

  /// True when the web app is running on a live domain (e.g. Firebase Hosting)
  /// and the default baseUrl still points to localhost / 127.0.0.1.
  /// Prevents spamming ClientException: Failed to fetch and hanging the browser network pipeline.
  static bool get isRemoteWebWithoutLocalBackend {
    if (!kIsWeb) return false;
    try {
      final host = Uri.base.host;
      final isCloudHosted = host.contains('web.app') || host.contains('firebaseapp.com');
      final pointsToLocal = baseUrl.contains('127.0.0.1') || baseUrl.contains('localhost');
      return isCloudHosted && pointsToLocal;
    } catch (_) {
      return false;
    }
  }

  Map<String, String> _headers({bool isJson = true}) {
    final map = <String, String>{};
    if (isJson) map['Content-Type'] = 'application/json';
    return map;
  }

  // ================= WORKSPACES =================
  Future<List<WorkspaceModel>> getWorkspaces() async {
    final res = await http.get(
      Uri.parse('$baseUrl/workspaces'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => WorkspaceModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load workspaces');
  }

  Future<WorkspaceModel> createWorkspace({
    required String name,
    String description = '',
    String icon = 'folder',
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/workspaces'),
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'description': description,
        'icon': icon,
      }),
    );
    if (res.statusCode == 200) {
      return WorkspaceModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to create workspace');
  }

  Future<void> deleteWorkspace(String workspaceId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/workspaces/$workspaceId'),
      headers: _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to delete workspace');
    }
  }

  Future<Uint8List> exportWorkspace(String workspaceId, String format) async {
    final res = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/export?format=$format'),
      headers: _headers(isJson: false),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to export workspace: ${res.body}');
    }
    return res.bodyBytes;
  }

  // ================= CONVERSATIONS =================
  Future<List<ConversationModel>> getConversations({String? workspaceId}) async {
    if (isRemoteWebWithoutLocalBackend) {
      return <ConversationModel>[];
    }
    try {
      final uri = workspaceId != null
          ? Uri.parse('$baseUrl/conversations?workspace_id=$workspaceId')
          : Uri.parse('$baseUrl/conversations');
      final res = await http.get(uri, headers: _headers());
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((e) => ConversationModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return <ConversationModel>[];
  }

  Future<ConversationModel> getConversation(String id) async {
    final res = await http.get(
      Uri.parse('$baseUrl/conversations/$id'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return ConversationModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load conversation details');
  }

  Future<ConversationModel> saveConversationToWorkspace({
    required String conversationId,
    required String workspaceId,
    String? title,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/conversations/$conversationId/save'),
      headers: _headers(),
      body: jsonEncode({
        'workspace_id': workspaceId,
        'title': ?title,
      }),
    );
    if (res.statusCode == 200) {
      return ConversationModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to save conversation to workspace');
  }

  // ================= STREAMING AI CHAT (SSE) =================
  Stream<Map<String, dynamic>> streamAIChat({
    required String prompt,
    String? conversationId,
    String? workspaceId,
    String model = 'gpt-4o-mini',
    List<ContextItemModel> contextItems = const [],
  }) async* {
    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse('$baseUrl/ai/chat/stream'));
      request.headers.addAll(_headers());
      request.body = jsonEncode({
        'prompt': prompt,
        'conversation_id': conversationId,
        'workspace_id': workspaceId,
        'model': model,
        'context_items': contextItems.map((c) => c.toJson()).toList(),
      });

      final streamedResponse = await client.send(request);
      if (streamedResponse.statusCode != 200) {
        yield {'type': 'error', 'error': 'Server returned ${streamedResponse.statusCode}'};
        return;
      }

      final lineStream = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lineStream) {
        if (line.startsWith('data: ')) {
          final dataStr = line.substring(6).trim();
          if (dataStr.isNotEmpty) {
            try {
              final jsonEvent = jsonDecode(dataStr) as Map<String, dynamic>;
              yield jsonEvent;
            } catch (_) {}
          }
        }
      }
    } finally {
      client.close();
    }
  }

  // ================= AI SELECTION ANALYSIS =================
  Future<String> analyzeSelection({
    required String action,
    String? prompt,
    String? workspaceId,
    String? selectedText,
    String? selectedImageBase64,
    List<Map<String, dynamic>>? selectedObjects,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ai/analyze-selection'),
      headers: _headers(),
      body: jsonEncode({
        'action': action,
        'prompt': ?prompt,
        'workspace_id': ?workspaceId,
        'selected_text': ?selectedText,
        'selected_image_base64': ?selectedImageBase64,
        'selected_objects': ?selectedObjects,
      }),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['result'] as String? ?? '';
    }
    throw Exception('AI analysis failed: ${res.body}');
  }

  // ================= CANVAS =================
  Future<List<CanvasDocModel>> getWorkspaceCanvasDocs(String workspaceId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/canvas'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => CanvasDocModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load canvas docs');
  }

  Future<void> batchSyncCanvas(
    String canvasId,
    List<CanvasObjectItem> objects, {
    String? workspaceId,
    String? name,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/canvas/$canvasId/batch-sync'),
      headers: _headers(),
      body: jsonEncode({
        'objects': objects.map((o) => o.toJson()).toList(),
        'workspace_id': ?workspaceId,
        'name': ?name,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to sync canvas');
    }
  }

  // ================= FILES =================
  Future<List<FileItemModel>> getWorkspaceFiles(String workspaceId) async {
    if (isRemoteWebWithoutLocalBackend) {
      return <FileItemModel>[];
    }
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/workspaces/$workspaceId/files'),
        headers: _headers(),
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((e) => FileItemModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return <FileItemModel>[];
  }

  Future<FileItemModel> uploadFile({
    required String workspaceId,
    required List<int> bytes,
    required String filename,
    String? mimeType,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/files'));
    request.fields['workspace_id'] = workspaceId;
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
    ));

    final streamedRes = await request.send();
    final res = await http.Response.fromStream(streamedRes);
    if (res.statusCode == 200 || res.statusCode == 201) {
      return FileItemModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to upload file: ${res.body}');
  }

  Future<void> deleteFile(String fileId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/files/$fileId'),
      headers: _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to delete file');
    }
  }

  Future<String> analyzeFile(String fileId, {String? prompt}) async {
    final uri = Uri.parse('$baseUrl/files/$fileId/analyze');
    final res = await http.post(
      uri,
      headers: _headers(),
      body: prompt != null ? jsonEncode({'prompt': prompt}) : null,
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['result'] as String? ?? '';
    }
    throw Exception('Failed to analyze file: ${res.body}');
  }

  // ================= SEARCH =================
  Future<SearchResponseModel> search(String query) async {
    final res = await http.get(
      Uri.parse('$baseUrl/search?q=${Uri.encodeComponent(query)}'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return SearchResponseModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Search failed');
  }
}

final apiService = ApiService();
