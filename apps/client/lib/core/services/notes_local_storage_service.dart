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

  /// Safely ensures local storage does not hit browser quota limits (5MB on Web).
  static Future<void> pruneStorageIfNearQuota({int maxTotalChars = 2500000}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      int totalChars = 0;
      final docKeys = <String, int>{};
      final nonEssentialKeys = <String>[];

      for (final k in keys) {
        if (k.startsWith('notelekh_')) {
          final val = prefs.get(k);
          int valLen = 0;
          if (val is String) {
            valLen = val.length;
          } else if (val is List) {
            valLen = val.fold(0, (sum, item) => sum + item.toString().length);
          } else if (val != null) {
            valLen = val.toString().length;
          }
          totalChars += valLen;
          if (k.contains('_files_') || k.contains('_notifications') || k.contains('_anon_') || k.contains('_guest_')) {
            nonEssentialKeys.add(k);
          } else if (k.contains('_doc_') && !k.endsWith('_index') && !k.contains('_active_')) {
            docKeys[k] = valLen;
          }
        }
      }

      if (totalChars < maxTotalChars) return;

      debugPrint('[STORAGE-QUOTA] Storage usage is $totalChars chars (target: $maxTotalChars). Pruning non-essential keys...');
      for (final nk in nonEssentialKeys) {
        await prefs.remove(nk);
      }

      // Re-check
      totalChars = 0;
      for (final k in prefs.getKeys()) {
        if (k.startsWith('notelekh_')) {
          final val = prefs.get(k);
          if (val is String) {
            totalChars += val.length;
          } else if (val is List) {
            totalChars += val.fold(0, (sum, item) => sum + item.toString().length);
          } else if (val != null) {
            totalChars += val.toString().length;
          }
        }
      }

      if (totalChars < maxTotalChars) return;

      // Evict heaviest documents if still above quota threshold
      final sortedDocs = docKeys.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sortedDocs) {
        if (totalChars <= maxTotalChars) break;
        await prefs.remove(entry.key);
        totalChars -= entry.value;
        debugPrint('[STORAGE-QUOTA] Evicted heavy cached document key: ${entry.key}');
      }
    } catch (e) {
      debugPrint('[STORAGE-QUOTA] Error pruning storage: $e');
    }
  }

  /// Emergency cleanup called when Firebase Auth encounters QuotaExceededError.
  /// Removes all local document caches so Firebase Auth credentials can be stored.
  static Future<void> emergencyPruneStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().toList();
      for (final k in keys) {
        // Keep session flag and user ID intact
        if (k == 'notelekh_has_user_session' || k == 'notelekh_last_user_id') continue;
        if (k.startsWith('notelekh_')) {
          await prefs.remove(k);
        }
      }
      debugPrint('[STORAGE-QUOTA] Emergency prune completed.');
    } catch (e) {
      debugPrint('[STORAGE-QUOTA] Emergency prune error: $e');
    }
  }

  /// Saves a complete notebook locally
  static Future<void> saveDocLocally(CanvasDocModel doc, {required String? userId}) async {
    final uid = _getSafeUserId(userId);
    try {
      await pruneStorageIfNearQuota();
      final prefs = await SharedPreferences.getInstance();
      final docJson = jsonEncode(doc.toJson());

      try {
        await prefs.setString('${_docPrefix(uid)}${doc.id}', docJson);
      } catch (writeErr) {
        if (writeErr.toString().toLowerCase().contains('quota')) {
          debugPrint('[STORAGE-QUOTA] Write quota exceeded for doc ${doc.id}. Emergency pruning and retrying...');
          await emergencyPruneStorage();
          await prefs.setString('${_docPrefix(uid)}${doc.id}', docJson);
        } else {
          rethrow;
        }
      }

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
      final Set<String> loadedIds = {};

      for (final id in indexList) {
        final raw = prefs.getString('${_docPrefix(uid)}$id');
        if (raw != null && raw.isNotEmpty) {
          try {
            final map = jsonDecode(raw) as Map<String, dynamic>;
            final doc = CanvasDocModel.fromJson(map);
            result.add(doc);
            loadedIds.add(doc.id);
          } catch (_) {}
        }
      }

      // Also scan prefs for any orphan documents for this uid that missed indexList
      final prefix = _docPrefix(uid);
      for (final key in prefs.getKeys()) {
        if (key.startsWith(prefix) && !key.endsWith('_index')) {
          final docId = key.substring(prefix.length);
          if (!loadedIds.contains(docId)) {
            final raw = prefs.getString(key);
            if (raw != null && raw.isNotEmpty) {
              try {
                final map = jsonDecode(raw) as Map<String, dynamic>;
                final doc = CanvasDocModel.fromJson(map);
                result.add(doc);
                loadedIds.add(doc.id);
              } catch (_) {}
            }
          }
        }
      }

      return result;
    } catch (e) {
      debugPrint('Error loading all local docs: $e');
      return [];
    }
  }

  /// Seamlessly migrates/adopts local notebooks created before login (or under local/guest/anon sessions)
  /// into the authenticated user's workspace so that no created notebook is ever lost.
  static Future<List<CanvasDocModel>> adoptOrMigrateLocalDocs({
    required String targetUserId,
    required String targetWorkspaceId,
  }) async {
    if (targetUserId.isEmpty || targetUserId == 'local_user' || targetUserId == 'anon') {
      return [];
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final List<CanvasDocModel> migratedDocs = [];
      final Set<String> migratedDocIds = {};

      // 1. Candidate unauthenticated / source user IDs
      final sourceUids = {'local_user', 'anon', 'guest_shared'};
      for (final sourceUid in sourceUids) {
        if (sourceUid == targetUserId) continue;
        final sourceDocs = await loadAllDocsLocally(userId: sourceUid);
        for (final doc in sourceDocs) {
          final isUntouchedStarter = (doc.id.startsWith('notebook_default_') ||
                  doc.id.endsWith('_default') ||
                  doc.id.contains('_default')) &&
              doc.pages.every((p) => p.objects.isEmpty);
          if (isUntouchedStarter) continue;

          final adopted = CanvasDocModel(
            id: doc.id,
            workspaceId: targetWorkspaceId,
            name: doc.name,
            documentVersion: doc.documentVersion,
            pages: doc.pages,
            currentPageIndex: doc.currentPageIndex,
            docType: doc.docType,
            coverColor: doc.coverColor,
            coverEmoji: doc.coverEmoji,
            coverStyle: doc.coverStyle,
            coverStyleData: doc.coverStyleData,
            updatedAt: doc.updatedAt ?? DateTime.now(),
          );
          await saveDocLocally(adopted, userId: targetUserId);
          migratedDocs.add(adopted);
          migratedDocIds.add(adopted.id);
        }
      }

      // 2. Scan ALL keys in SharedPreferences starting with 'notelekh_' and containing '_doc_'
      // to recover any other documents from prior unauthenticated sessions
      final targetPrefix = _docPrefix(targetUserId);
      for (final key in prefs.getKeys()) {
        if (key.startsWith('notelekh_') && key.contains('_doc_') && !key.endsWith('_doc_index') && !key.startsWith(targetPrefix)) {
          try {
            final raw = prefs.getString(key);
            if (raw != null && raw.isNotEmpty) {
              final map = jsonDecode(raw) as Map<String, dynamic>;
              final doc = CanvasDocModel.fromJson(map);
              final isUntouchedStarter = (doc.id.startsWith('notebook_default_') ||
                      doc.id.endsWith('_default') ||
                      doc.id.contains('_default')) &&
                  doc.pages.every((p) => p.objects.isEmpty);
              if (isUntouchedStarter) continue;

              if (!migratedDocIds.contains(doc.id)) {
                final adopted = CanvasDocModel(
                  id: doc.id,
                  workspaceId: targetWorkspaceId,
                  name: doc.name,
                  documentVersion: doc.documentVersion,
                  pages: doc.pages,
                  currentPageIndex: doc.currentPageIndex,
                  docType: doc.docType,
                  coverColor: doc.coverColor,
                  coverEmoji: doc.coverEmoji,
                  coverStyle: doc.coverStyle,
                  coverStyleData: doc.coverStyleData,
                  updatedAt: doc.updatedAt ?? DateTime.now(),
                );
                await saveDocLocally(adopted, userId: targetUserId);
                migratedDocs.add(adopted);
                migratedDocIds.add(adopted.id);
              }
            }
          } catch (_) {}
        }
      }

      return migratedDocs;
    } catch (e) {
      debugPrint('Error adopting local docs: $e');
      return [];
    }
  }

  /// Loads cached notebooks belonging to a specific workspace
  static Future<List<CanvasDocModel>> loadDocsForWorkspace(String workspaceId, {required String? userId}) async {
    final all = await loadAllDocsLocally(userId: userId);

    // 1. Direct match for this workspace
    final matched = all.where((d) => d.workspaceId == workspaceId).toList();
    if (matched.isNotEmpty) return matched;

    // 2. Documents with 'default' workspaceId or empty workspaceId — adopt them into this workspace
    final defaultDocs = all.where((d) => d.workspaceId == 'default' || d.workspaceId.isEmpty).toList();
    if (defaultDocs.isNotEmpty) {
      for (final doc in defaultDocs) {
        doc.workspaceId = workspaceId;
        await saveDocLocally(doc, userId: userId);
      }
      return defaultDocs;
    }

    // 3. Fallback: If no docs matched for this workspace, but the user has ANY cached documents locally,
    // adopt all of them into this workspace so user notes are never hidden or lost!
    if (all.isNotEmpty) {
      for (final doc in all) {
        doc.workspaceId = workspaceId;
        await saveDocLocally(doc, userId: userId);
      }
      return all;
    }

    return [];
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
    await deleteDocEverywhere(docId, userId: userId);
  }

  /// Comprehensively deletes a document across all user scopes and orphan keys in SharedPreferences
  /// so it cannot ever resurrect upon page refresh or session switch.
  static Future<void> deleteDocEverywhere(String docId, {required String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final targetUids = {'local_user', 'anon', 'guest_shared'};
      if (userId != null && userId.isNotEmpty) {
        targetUids.add(userId);
      }
      for (final uid in targetUids) {
        await prefs.remove('${_docPrefix(uid)}$docId');
        await prefs.remove('${_todoPrefix(uid)}$docId');
        final List<String> indexList = List<String>.from(prefs.getStringList(_docIndexKey(uid)) ?? []);
        if (indexList.contains(docId)) {
          indexList.remove(docId);
          await prefs.setStringList(_docIndexKey(uid), indexList);
        }
      }
      // Also scrub any keys in prefs ending with '_doc_$docId' or '_todos_$docId'
      for (final key in prefs.getKeys()) {
        if (key.endsWith('_doc_$docId') || key.endsWith('_todos_$docId')) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint('Error deleting doc everywhere: $e');
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

