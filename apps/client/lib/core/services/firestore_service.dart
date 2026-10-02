import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ai_workspace_client/core/models/workspace_model.dart';
import 'package:ai_workspace_client/core/models/canvas_models.dart';
import 'package:ai_workspace_client/core/models/conversation_model.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Helper to safely convert Firestore values to JSON-compatible formats
  Map<String, dynamic> _normalizeTimestamps(Map<String, dynamic> data) {
    data.forEach((key, value) {
      if (value is Timestamp) {
        data[key] = value.toDate().toIso8601String();
      } else if (value is Map<String, dynamic>) {
        data[key] = _normalizeTimestamps(value);
      } else if (value is List) {
        data[key] = value.map((e) => e is Map<String, dynamic> ? _normalizeTimestamps(e) : e).toList();
      }
    });
    return data;
  }

  // ================= WORKSPACES =================
  Future<List<WorkspaceModel>> getWorkspaces(String userId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('workspaces')
          .get();
          
      final list = snapshot.docs.map((doc) {
        final data = _normalizeTimestamps(doc.data());
        data['id'] = doc.id;
        return WorkspaceModel.fromJson(data);
      }).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint('Firestore Error getting workspaces: $e');
      rethrow;
    }
  }

  Future<WorkspaceModel> createWorkspace({
    required String userId,
    required String name,
    String description = '',
    String icon = 'folder',
  }) async {
    final docRef = _db.collection('users').doc(userId).collection('workspaces').doc();
    
    final now = FieldValue.serverTimestamp();
    final data = {
      'user_id': userId,
      'name': name,
      'description': description,
      'icon': icon,
      'is_pinned': false,
      'created_at': now,
      'updated_at': now,
      'conversation_count': 0,
      'file_count': 0,
      'canvas_count': 0,
    };

    await docRef.set(data);
    
    return WorkspaceModel(
      id: docRef.id,
      userId: userId,
      name: name,
      description: description,
      icon: icon,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> deleteWorkspace(String userId, String workspaceId) async {
    final workspaceRef = _db.collection('users').doc(userId).collection('workspaces').doc(workspaceId);
    
    // Create a batch for atomic deletion
    final batch = _db.batch();
    
    try {
      // 1. Delete all canvas docs
      final canvasDocs = await workspaceRef.collection('canvas_docs').get();
      for (final doc in canvasDocs.docs) {
        batch.delete(doc.reference);
      }
      
      // 2. Delete all conversations
      final conversations = await workspaceRef.collection('conversations').get();
      for (final doc in conversations.docs) {
        batch.delete(doc.reference);
      }
      
      // 3. Delete the workspace itself
      batch.delete(workspaceRef);
      
      await batch.commit();
    } catch (e) {
      debugPrint('Firestore Error deleting workspace and subcollections: $e');
      rethrow;
    }
  }

  // ================= CANVAS DOCS =================
  Future<List<CanvasDocModel>> getWorkspaceCanvasDocs(String userId, String workspaceId) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _db
            .collection('users')
            .doc(userId)
            .collection('workspaces')
            .doc(workspaceId)
            .collection('canvas_docs')
            .orderBy('updated_at', descending: true)
            .get();
      } catch (orderE) {
        debugPrint('Ordering canvas_docs by updated_at failed, falling back to unordered get: $orderE');
        snapshot = await _db
            .collection('users')
            .doc(userId)
            .collection('workspaces')
            .doc(workspaceId)
            .collection('canvas_docs')
            .get();
      }
          
      final list = snapshot.docs.map((doc) {
        final data = _normalizeTimestamps(doc.data());
        data['id'] = doc.id;
        return CanvasDocModel.fromJson(data);
      }).toList();
      return list;
    } catch (e) {
      debugPrint('Firestore Error getting canvas docs: $e');
      return [];
    }
  }

  /// Real-time live synchronization stream for all canvas documents in a workspace.
  /// Allows other devices with the same user ID to immediately receive live changes.
  Stream<List<CanvasDocModel>> streamWorkspaceCanvasDocs(String userId, String workspaceId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('workspaces')
        .doc(workspaceId)
        .collection('canvas_docs')
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) {
            final data = _normalizeTimestamps(doc.data());
            data['id'] = doc.id;
            return CanvasDocModel.fromJson(data);
          }).toList();
          return list;
        });
  }

  /// Real-time live synchronization stream for a single active canvas notebook.
  Stream<CanvasDocModel?> streamCanvasDoc(String userId, String workspaceId, String docId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('workspaces')
        .doc(workspaceId)
        .collection('canvas_docs')
        .doc(docId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists || snapshot.data() == null) return null;
          final data = _normalizeTimestamps(snapshot.data()!);
          data['id'] = snapshot.id;
          return CanvasDocModel.fromJson(data);
        });
  }

  Future<void> saveCanvasDoc(String userId, String workspaceId, CanvasDocModel doc) async {
    try {
      final data = doc.toJson();
      // Calculate bytes for scalable storage aggregation before adding non-JSON FieldValue
      data['size_bytes'] = utf8.encode(jsonEncode(data)).length;
      data['updated_at'] = FieldValue.serverTimestamp();
      
      await _db
          .collection('users')
          .doc(userId)
          .collection('workspaces')
          .doc(workspaceId)
          .collection('canvas_docs')
          .doc(doc.id)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore Error saving canvas doc: $e');
    }
  }

  Future<void> deleteCanvasDoc(String userId, String workspaceId, String docId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('workspaces')
          .doc(workspaceId)
          .collection('canvas_docs')
          .doc(docId)
          .delete();
    } catch (e) {
      debugPrint('Firestore Error deleting canvas doc: $e');
    }
  }

  // ================= CONVERSATIONS =================
  Future<List<ConversationModel>> getConversations(String userId, String workspaceId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('workspaces')
          .doc(workspaceId)
          .collection('conversations')
          .orderBy('updated_at', descending: true)
          .get();
          
      return snapshot.docs.map((doc) {
        final data = _normalizeTimestamps(doc.data());
        data['id'] = doc.id;
        return ConversationModel.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Firestore Error getting conversations: $e');
      rethrow;
    }
  }

  // ================= MIGRATION =================
  Future<void> migrateGuestData(String guestId, String newUserId) async {
    try {
      // Get all workspaces from the guest user's subcollection
      final snapshot = await _db
          .collection('users')
          .doc(guestId)
          .collection('workspaces')
          .get();
          
      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        // Move to the new user's subcollection
        final newDocRef = _db.collection('users').doc(newUserId).collection('workspaces').doc(doc.id);
        batch.set(newDocRef, doc.data());
        batch.update(newDocRef, {'user_id': newUserId});
        batch.delete(doc.reference); // Delete from guest

        // Migrate canvas_docs
        final canvasDocsSnapshot = await doc.reference.collection('canvas_docs').get();
        for (final canvasDoc in canvasDocsSnapshot.docs) {
          final newCanvasDocRef = newDocRef.collection('canvas_docs').doc(canvasDoc.id);
          batch.set(newCanvasDocRef, canvasDoc.data());
          batch.delete(canvasDoc.reference);
        }

        // Migrate conversations
        final convosSnapshot = await doc.reference.collection('conversations').get();
        for (final convo in convosSnapshot.docs) {
          final newConvoRef = newDocRef.collection('conversations').doc(convo.id);
          batch.set(newConvoRef, convo.data());
          batch.delete(convo.reference);
        }
      }
      await batch.commit();
      debugPrint('Successfully migrated ${snapshot.docs.length} workspaces from guest to user.');
    } catch (e) {
      debugPrint('Firestore Error migrating guest data: $e');
      rethrow;
    }
  }

  // ================= USERS / ACCOUNT STORAGE =================
  Future<void> updateUserStorageStats(String userId, int storageBytes, int itemCount) async {
    try {
      await _db.collection('users').doc(userId).set({
        'storage_bytes': storageBytes,
        'item_count': itemCount,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore Error updating user storage: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserStorageStats(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      debugPrint('Firestore Error getting user storage: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> computeUserStorageStats(String userId) async {
    try {
      final workspacesSnapshot = await _db.collection('users').doc(userId).collection('workspaces').get();
      int totalBytes = 0;
      int totalItems = 0;
      for (final ws in workspacesSnapshot.docs) {
        try {
          final docsSnap = await ws.reference.collection('canvas_docs').get();
          totalItems += docsSnap.docs.length;
          for (final doc in docsSnap.docs) {
            final data = doc.data();
            final bytes = (data['size_bytes'] as num?)?.toInt() ?? utf8.encode(jsonEncode(data)).length;
            totalBytes += bytes;
          }
        } catch (innerE) {
          debugPrint('Error getting canvas_docs for ws ${ws.id}: $innerE');
        }
      }
      
      // Cache this value in the user's document for quick access on startup
      await updateUserStorageStats(userId, totalBytes, totalItems);
      
      return {'storage_bytes': totalBytes, 'item_count': totalItems};
    } catch (e) {
      debugPrint('Firestore Error computing aggregate storage: $e');
      return {'storage_bytes': 0, 'item_count': 0};
    }
  }
}

final firestoreService = FirestoreService();
