import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_workspace_client/features/canvas/models/page_model.dart';

/// Production-grade local-first persistence service for Notelekh.
///
/// This saves canvases, text documents, and interactive to-do lists locally using SharedPreferences.
/// Data is segmented by `userId` to support secure multi-tenant switching on the same device.
class NotesLocalStorageService {

  // Key Builders
  static String _docPrefix(String userId) => 'notelekh_${userId}_doc_';
  static String _docIndexKey(String userId) => 'notelekh_${userId}_doc_index';
  static String _currentDocKey(String userId) => 'notelekh_${userId}_active_doc_id';
  static String _todoPrefix(String userId) => 'notelekh_${userId}_todos_';

  static String _getSafeUserId(String? userId) {
    if (userId == null || userId.isEmpty) return 'anon';
    if (userId.startsWith('guest_')) return 'guest_shared';
    return userId;
  }

  /// Saves a complete notebook locally
  static Future<void> saveDocLocally(CanvasDocModel doc, {required String? userId}) async {
    final uid = _getSafeUserId(userId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final docJson = jsonEncode(doc.toJson());
      await prefs.setString('${_docPrefix(uid)}${doc.id}', docJson);

      // Update index of doc IDs
      final List<String> indexList = List<String>.from(prefs.getStringList(_docIndexKey(uid)) ?? []);
      if (!indexList.contains(doc.id)) {
        indexList.add(doc.id);
        await prefs.setStringList(_docIndexKey(uid), indexList);
      }
    } catch (e) {
      debugPrint('Error saving doc locally: $e');
    }
  }

  /// Loads a specific notebook from local storage
  static Future<CanvasDocModel?> loadDocLocally(String docId, {required String? userId}) async {
    final uid = _getSafeUserId(userId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('${_docPrefix(uid)}$docId');
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return CanvasDocModel.fromJson(map);
    } catch (e) {
      debugPrint('Error loading doc $docId locally: $e');
      return null;
    }
  }

  /// Loads all cached notebooks from local storage
  static Future<List<CanvasDocModel>> loadAllDocsLocally({required String? userId}) async {
    final uid = _getSafeUserId(userId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final indexList = prefs.getStringList(_docIndexKey(uid)) ?? [];
      final List<CanvasDocModel> result = [];

      for (final id in indexList) {
        final raw = prefs.getString('${_docPrefix(uid)}$id');
        if (raw != null && raw.isNotEmpty) {
          try {
            final map = jsonDecode(raw) as Map<String, dynamic>;
            result.add(CanvasDocModel.fromJson(map));
          } catch (_) {}
        }
      }
      return result;
    } catch (e) {
      debugPrint('Error loading all local docs: $e');
      return [];
    }
  }

  /// Loads cached notebooks belonging to a specific workspace
  static Future<List<CanvasDocModel>> loadDocsForWorkspace(String workspaceId, {required String? userId}) async {
    final all = await loadAllDocsLocally(userId: userId);
    return all.where((d) => d.workspaceId == workspaceId).toList();
  }

  /// Deletes all local notebooks belonging to a specific workspace
  static Future<void> deleteWorkspaceDocsLocally(String workspaceId, {required String? userId}) async {
    final all = await loadAllDocsLocally(userId: userId);
    for (final doc in all) {
      if (doc.workspaceId == workspaceId) {
        await deleteDocLocally(doc.id, userId: userId);
      }
    }
  }

  /// Deletes a notebook from local storage
  static Future<void> deleteDocLocally(String docId, {required String? userId}) async {
    final uid = _getSafeUserId(userId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_docPrefix(uid)}$docId');
      final List<String> indexList = List<String>.from(prefs.getStringList(_docIndexKey(uid)) ?? []);
      indexList.remove(docId);
      await prefs.setStringList(_docIndexKey(uid), indexList);
    } catch (e) {
      debugPrint('Error deleting local doc: $e');
    }
  }

  /// Remembers the active notebook ID
  static Future<void> saveActiveDocId(String docId, {required String? userId}) async {
    final uid = _getSafeUserId(userId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentDocKey(uid), docId);
    } catch (_) {}
  }

  /// Gets the last active notebook ID
  static Future<String?> getActiveDocId({required String? userId}) async {
    final uid = _getSafeUserId(userId);
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_currentDocKey(uid));
    } catch (_) {
      return null;
    }
  }

  /// Saves to-do checklist items for an individual note
  static Future<void> saveDocTodos(String docId, List<Map<String, dynamic>> todos, {required String? userId}) async {
    final uid = _getSafeUserId(userId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_todoPrefix(uid)}$docId', jsonEncode(todos));
    } catch (e) {
      debugPrint('Error saving doc todos: $e');
    }
  }

  /// Loads to-do checklist items for an individual note
  static Future<List<Map<String, dynamic>>> loadDocTodos(String docId, {required String? userId}) async {
    final uid = _getSafeUserId(userId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('${_todoPrefix(uid)}$docId');
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('Error loading doc todos: $e');
      return [];
    }
  }

  /// Saves notifications list
  static Future<void> saveNotifications(List<Map<String, dynamic>> notifs, {required String? userId}) async {
    final uid = _getSafeUserId(userId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('notelekh_${uid}_notifications', jsonEncode(notifs));
    } catch (e) {
      debugPrint('Error saving notifications: $e');
    }
  }

  /// Loads notifications list
  static Future<List<Map<String, dynamic>>> loadNotifications({required String? userId}) async {
    final uid = _getSafeUserId(userId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('notelekh_${uid}_notifications');
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      return [];
    }
  }

  /// Saves workspace files
  static Future<void> saveWorkspaceFiles(String workspaceId, List<Map<String, dynamic>> files, {required String? userId}) async {
    final uid = _getSafeUserId(userId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('notelekh_${uid}_files_$workspaceId', jsonEncode(files));
    } catch (e) {
      debugPrint('Error saving files for $workspaceId: $e');
    }
  }

  /// Loads workspace files
  static Future<List<Map<String, dynamic>>> loadWorkspaceFiles(String workspaceId, {required String? userId}) async {
    final uid = _getSafeUserId(userId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('notelekh_${uid}_files_$workspaceId');
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('Error loading files for $workspaceId: $e');
      return [];
    }
  }
}

