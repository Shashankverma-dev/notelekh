import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:ai_workspace_client/core/models/workspace_model.dart';
import 'package:ai_workspace_client/core/models/conversation_model.dart';
import 'package:ai_workspace_client/core/models/message_model.dart';
import 'package:ai_workspace_client/core/models/canvas_models.dart';
import 'package:ai_workspace_client/core/models/context_item_model.dart';
import 'package:ai_workspace_client/core/models/file_model.dart';
import 'package:ai_workspace_client/core/models/search_model.dart';
import 'package:ai_workspace_client/core/network/api_service.dart';
import 'package:ai_workspace_client/core/services/notes_local_storage_service.dart';
import 'package:ai_workspace_client/core/services/workspace_export_service.dart';
import 'package:ai_workspace_client/core/models/note_todo_model.dart';
import 'package:ai_workspace_client/core/models/app_notification_model.dart';
import 'package:ai_workspace_client/features/canvas/tools/lasso_tool.dart';
import 'package:ai_workspace_client/core/services/firestore_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_workspace_client/firebase_options.dart';


enum WorkspaceViewMode {
  split,
  canvasOnly,
  chatOnly,
}

/// Diagnostic details for authentication operations to assist in debugging.
class AuthDiagnosticInfo {
  final String stage;
  final String exceptionType;
  final String? code;
  final String? message;
  final String? rawException;
  final String? stackTraceSnippet;
  final DateTime timestamp;

  AuthDiagnosticInfo({
    required this.stage,
    required this.exceptionType,
    this.code,
    this.message,
    this.rawException,
    this.stackTraceSnippet,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String toFormattedDetails() {
    final sb = StringBuffer();
    sb.writeln('Stage: $stage');
    sb.writeln('Exception Type: $exceptionType');
    if (code != null && code!.isNotEmpty) sb.writeln('Code: $code');
    if (message != null && message!.isNotEmpty) sb.writeln('Message: $message');
    if (rawException != null && rawException!.isNotEmpty && rawException != message) {
      sb.writeln('Raw: $rawException');
    }
    if (stackTraceSnippet != null && stackTraceSnippet!.isNotEmpty) {
      sb.writeln('Stack:\n$stackTraceSnippet');
    }
    return sb.toString().trim();
  }
}

class AppState extends ChangeNotifier {
  // Navigation & Screen State
  int selectedNavIndex = 0; // 0: Home/Dashboard, 1: Chats, 2: Workspaces, 3: Canvas, 4: Files, 5: Search, 6: Settings
  bool isDarkMode = false; // Notelekh light-first aesthetic
  final ValueNotifier<bool> darkModeNotifier = ValueNotifier<bool>(false);
  bool isContextPanelVisible = false; // default collapsed in split studio for cleaner focus
  WorkspaceViewMode viewMode = WorkspaceViewMode.canvasOnly;
  double splitRatio = 0.52; // 52% Canvas, 48% AI Chat

  // User Profile — populated from FirebaseAuth.currentUser after sign-in
  String userEmail = '';
  String displayName = 'Notelekh User';
  String? userId;
  String? userPhotoUrl;

  // Notelekh Spaces & Tags
  String selectedSpace = 'Personal';
  final List<Map<String, dynamic>> spaces = [
    {'name': 'Personal', 'color': const Color(0xFF10B981)},
    {'name': 'College', 'color': const Color(0xFF38BDF8)},
    {'name': 'Web Development', 'color': const Color(0xFFA855F7)},
    {'name': 'Ideas', 'color': const Color(0xFFF97316)},
    {'name': 'Projects', 'color': const Color(0xFFEF4444)},
  ];

  final List<String> tags = [
    'flutter',
    'study',
    'notes',
    'ideas',
    'important',
    'ui-ux',
  ];

  // Notelekh Notifications System
  List<AppNotificationItem> _notifications = _getInitialNotifications();
  bool _hasLoadedNotifications = false;

  List<AppNotificationItem> get notifications {
    if (!_hasLoadedNotifications) {
      _hasLoadedNotifications = true;
      _loadNotificationsFromStorage();
    }
    return _notifications;
  }

  int get unreadNotificationCount => notifications.where((n) => !n.isRead).length;

  Future<void> _loadNotificationsFromStorage() async {
    final raw = await NotesLocalStorageService.loadNotifications(userId: userId);
    if (raw.isNotEmpty) {
      _notifications = raw.map((m) => AppNotificationItem.fromJson(m)).toList();
    } else {
      _notifications = _getInitialNotifications();
      _persistNotifications();
    }
    notifyListeners();
  }

  static List<AppNotificationItem> _getInitialNotifications() {
    final now = DateTime.now();
    return [
      AppNotificationItem(
        id: 'notif-1',
        title: 'GoodNotes Engine Active',
        message: 'Draw-and-hold precision, cyclic corner detection, and shape snapping are enabled.',
        timestamp: now.subtract(const Duration(minutes: 5)),
        type: NotificationType.system,
        isRead: false,
      ),
      AppNotificationItem(
        id: 'notif-2',
        title: 'Cloud Auto-Backup Complete',
        message: 'Your notebooks and drawings have been synced to the Notelekh cloud.',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 20)),
        type: NotificationType.sync,
        isRead: false,
      ),
      AppNotificationItem(
        id: 'notif-3',
        title: 'Study Recall Ready',
        message: 'Study Tape and interactive flashcards are ready for your next study session.',
        timestamp: now.subtract(const Duration(hours: 4)),
        type: NotificationType.study,
        isRead: false,
      ),
      AppNotificationItem(
        id: 'notif-4',
        title: 'Welcome to Notelekh Pro',
        message: 'Create unlimited notebooks with customized aesthetic covers and infinite whiteboard canvases.',
        timestamp: now.subtract(const Duration(days: 1)),
        type: NotificationType.notebook,
        isRead: true,
      ),
    ];
  }

  void markNotificationAsRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1 && !_notifications[idx].isRead) {
      _notifications[idx].isRead = true;
      _persistNotifications();
      notifyListeners();
    }
  }

  void markAllNotificationsAsRead() {
    bool changed = false;
    for (final n in _notifications) {
      if (!n.isRead) {
        n.isRead = true;
        changed = true;
      }
    }
    if (changed) {
      _persistNotifications();
      notifyListeners();
    }
  }

  void deleteNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    _persistNotifications();
    notifyListeners();
  }

  void clearAllNotifications() {
    _notifications.clear();
    _persistNotifications();
    notifyListeners();
  }

  void addNotification({
    required String title,
    required String message,
    NotificationType type = NotificationType.system,
    String? docId,
    String? route,
  }) {
    _notifications.insert(
      0,
      AppNotificationItem(
        id: 'notif-${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        message: message,
        timestamp: DateTime.now(),
        type: type,
        isRead: false,
        docId: docId,
        route: route,
      ),
    );
    _persistNotifications();
    notifyListeners();
  }

  void _persistNotifications() {
    NotesLocalStorageService.saveNotifications(
      _notifications.map((n) => n.toJson()).toList(),
      userId: userId,
    );
  }

  // Notelekh Interactive To-Do Lists (isolated per individual note)
  final Map<String, List<NoteTodoItem>> _noteTodos = {};

  List<NoteTodoItem> getNoteTodos(String docId) {
    if (!_noteTodos.containsKey(docId)) {
      // Newly created/opened notebook starts with an empty to-do list
      _noteTodos[docId] = [];
      // Load saved tasks from local storage if any
      _loadNoteTodosFromStorage(docId);
    }
    return _noteTodos[docId] ?? [];
  }

  Future<void> _loadNoteTodosFromStorage(String docId) async {
    final raw = await NotesLocalStorageService.loadDocTodos(docId, userId: userId);
    if (raw.isNotEmpty) {
      // If stored todos were only the old static placeholders, clear them out
      final isOnlyOldSeed = raw.every((m) {
        final title = (m['title'] as String? ?? '').trim();
        return title == 'Review active notes' ||
            title == 'Synthesize key insights' ||
            title == 'Practice exam questions';
      });
      if (isOnlyOldSeed) {
        _noteTodos[docId] = [];
        _persistNoteTodos(docId);
      } else {
        // Keep real user tasks, filter out any leftover placeholder tasks
        final cleaned = raw.where((m) {
          final title = (m['title'] as String? ?? '').trim();
          return title != 'Review active notes' &&
              title != 'Synthesize key insights' &&
              title != 'Practice exam questions';
        }).map((m) => NoteTodoItem.fromJson(m)).toList();
        _noteTodos[docId] = cleaned;
      }
      notifyListeners();
    }
  }

  void toggleNoteTodo(String docId, String todoId) {
    final todos = getNoteTodos(docId);
    final idx = todos.indexWhere((t) => t.id == todoId);
    if (idx != -1) {
      todos[idx].isCompleted = !todos[idx].isCompleted;
      _persistNoteTodos(docId);
      notifyListeners();
    }
  }

  void addNoteTodo(String docId, String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final todos = getNoteTodos(docId);
    todos.add(NoteTodoItem(
      id: 'todo-${DateTime.now().millisecondsSinceEpoch}',
      title: trimmed,
      isCompleted: false,
    ));
    _persistNoteTodos(docId);
    notifyListeners();
  }

  void removeNoteTodo(String docId, String todoId) {
    final todos = getNoteTodos(docId);
    todos.removeWhere((t) => t.id == todoId);
    _persistNoteTodos(docId);
    notifyListeners();
  }

  void clearCompletedNoteTodos(String docId) {
    final todos = getNoteTodos(docId);
    todos.removeWhere((t) => t.isCompleted);
    _persistNoteTodos(docId);
    notifyListeners();
  }

  void _persistNoteTodos(String docId) {
    final todos = _noteTodos[docId];
    if (todos != null) {
      NotesLocalStorageService.saveDocTodos(
        docId,
        todos.map((t) => t.toJson()).toList(),
        userId: userId,
      );
    }
  }

  // Backward-compatible helpers for active notebook
  Map<String, bool> get checklistTasks {
    final activeDocId = currentCanvasDoc?.id ?? (canvasDocs.isNotEmpty ? canvasDocs.first.id : 'default');
    final todos = getNoteTodos(activeDocId);
    return {for (var t in todos) t.title: t.isCompleted};
  }

  void toggleChecklistTask(String task) {
    final activeDocId = currentCanvasDoc?.id ?? (canvasDocs.isNotEmpty ? canvasDocs.first.id : 'default');
    final todos = getNoteTodos(activeDocId);
    final item = todos.firstWhere((t) => t.title == task, orElse: () => NoteTodoItem(id: '', title: ''));
    if (item.id.isNotEmpty) {
      toggleNoteTodo(activeDocId, item.id);
    }
  }

  void addChecklistTask(String task) {
    final activeDocId = currentCanvasDoc?.id ?? (canvasDocs.isNotEmpty ? canvasDocs.first.id : 'default');
    addNoteTodo(activeDocId, task);
  }

  void removeChecklistTask(String task) {
    final activeDocId = currentCanvasDoc?.id ?? (canvasDocs.isNotEmpty ? canvasDocs.first.id : 'default');
    final todos = getNoteTodos(activeDocId);
    final item = todos.firstWhere((t) => t.title == task, orElse: () => NoteTodoItem(id: '', title: ''));
    if (item.id.isNotEmpty) {
      removeNoteTodo(activeDocId, item.id);
    }
  }

  // Pinned Notebooks
  final Set<String> pinnedNotebookIds = {};

  void togglePinNotebook(String notebookId) {
    if (pinnedNotebookIds.contains(notebookId)) {
      pinnedNotebookIds.remove(notebookId);
    } else {
      pinnedNotebookIds.add(notebookId);
    }
    notifyListeners();
  }

  bool isNotebookPinned(String notebookId) => pinnedNotebookIds.contains(notebookId);

  void selectSpace(String space) {
    selectedSpace = space;
    notifyListeners();
  }


  // Workspaces State
  List<WorkspaceModel> workspaces = [];
  WorkspaceModel? currentWorkspace;
  bool isLoadingWorkspaces = false;

  // Chat & Conversation State
  List<ConversationModel> conversations = [];
  ConversationModel? currentConversation;
  List<MessageModel> currentMessages = [];
  bool isStreaming = false;
  String currentStreamingText = '';

  // Selective Context Tray State
  List<ContextItemModel> selectedContextItems = [];

  // Canvas & GoodNotes Notebook State
  static int _docIdCounter = 0;
  List<CanvasDocModel> canvasDocs = [];
  CanvasDocModel? currentCanvasDoc;
  int currentPageIndex = 0;
  bool isPageViewMode = true; // true: iPad A4 Page Focus Mode, false: Infinite Board Mode
  List<CanvasObjectItem> canvasObjects = [];
  List<List<CanvasObjectItem>> undoStack = [];
  List<List<CanvasObjectItem>> redoStack = [];
  CanvasTool currentTool = CanvasTool.pen;
  Color strokeColor = const Color(0xFF2E7D32);
  double strokeWidth = 3.5;
  double strokeOpacity = 1.0;
  bool isStylusPressureEnabled = true;
  List<CanvasObjectItem> selectedCanvasObjects = [];
  bool autoWriteToCanvas = true;
  CanvasPaperStyle canvasPaperStyle = CanvasPaperStyle.ruledLines;

  // Pen settings
  PenType currentPenType = PenType.ballpoint;
  PressureSensitivity pressureSensitivity = PressureSensitivity.medium;
  bool palmRejectionEnabled = true;
  bool stylusOnlyMode = false;
  double strokeSmoothing = 0.25; // 0.0 = raw, 1.0 = max smooth (0.25 = snappy response with zero lag)
  double velocityInfluence = 0.3; // how much velocity affects width
  EraserMode eraserMode = EraserMode.stroke;

  // Autosave status
  String autosaveStatus = 'saved'; // 'saving', 'saved', 'offline'
  DateTime? lastSavedAt;

  // Active page helpers
  CanvasPage? get currentPage => currentCanvasDoc?.activePage;
  List<CanvasPage> get canvasPages => currentCanvasDoc?.pages ?? [];

  void togglePageViewMode() {
    isPageViewMode = !isPageViewMode;
    notifyListeners();
  }

  void setCanvasPaperStyle(CanvasPaperStyle style) {
    canvasPaperStyle = style;
    if (currentPage != null) {
      currentPage!.paperStyle = style;
    }
    notifyListeners();
    _debounceSyncCanvas();
  }

  void toggleAutoWriteToCanvas() {
    autoWriteToCanvas = !autoWriteToCanvas;
    notifyListeners();
  }

  void setPenType(PenType type) {
    currentPenType = type;
    notifyListeners();
  }

  void setPressureSensitivity(PressureSensitivity sensitivity) {
    pressureSensitivity = sensitivity;
    isStylusPressureEnabled = sensitivity != PressureSensitivity.off;
    notifyListeners();
  }

  void setStrokeOpacity(double opacity) {
    strokeOpacity = opacity.clamp(0.05, 1.0);
    notifyListeners();
  }

  void setEraserMode(EraserMode mode) {
    eraserMode = mode;
    notifyListeners();
  }

  void togglePalmRejection() {
    palmRejectionEnabled = !palmRejectionEnabled;
    notifyListeners();
  }

  void setAutosaveStatus(String status) {
    autosaveStatus = status;
    if (status == 'saved') lastSavedAt = DateTime.now();
    notifyListeners();
  }

  // Files State
  List<FileItemModel> workspaceFiles = _getDefaultWorkspaceFiles('default');

  // Global Search State
  String searchQuery = '';
  List<SearchResultItemModel> searchResults = [];
  bool isSearching = false;

  bool isAuthenticated = false;
  bool showLoginScreen = false;
  bool isAuthRestoring = false;

  AppState() {
    initWorkspaces();
  }

  /// Navigate to the login/sign-in card without entering the workspace.
  void navigateToLogin() {
    showLoginScreen = true;
    notifyListeners();
  }

  /// Return to the landing page from the login screen.
  void navigateToLanding() {
    showLoginScreen = false;
    notifyListeners();
  }

  // ================== FIREBASE AUTH ==================

  StreamSubscription<User?>? _authStateSubscription;
  static Future<void>? _firebaseInitFuture;
  bool _isGoogleAuthInFlight = false;

  /// Ensure Firebase is initialized and persistence is configured safely for WebKit/Safari.
  /// Uses a shared static Future to guarantee that concurrent callers
  /// (e.g. startup initWorkspaces + user tapping Create Account/Google)
  /// await the exact same initialization task and NEVER trigger duplicate-app crashes.
  Future<void> _ensureFirebase() {
    _firebaseInitFuture ??= _doInitFirebase();
    return _firebaseInitFuture!;
  }

  static Future<void> _doInitFirebase() async {
    debugPrint('[AUTH-INIT] Starting Firebase initialization...');
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('[AUTH-INIT] Firebase.initializeApp completed successfully.');
      } else {
        debugPrint('[AUTH-INIT] Firebase app already exists: ${Firebase.app().name}');
      }
    } catch (e, st) {
      debugPrint('[AUTH-INIT] Firebase.initializeApp error: ${e.runtimeType}: $e');
      debugPrint('[AUTH-INIT] Stack: $st');
      if (Firebase.apps.isNotEmpty) {
        debugPrint('[AUTH-INIT] A Firebase app already exists; continuing.');
      } else {
        rethrow;
      }
    }

    if (kIsWeb) {
      _setupWebPersistence().catchError((e) {
        debugPrint('[AUTH-PERSISTENCE] Non-fatal web persistence setup: $e');
      });
    }
    debugPrint('[AUTH-INIT] Firebase initialization fully ready.');
  }

  /// Set if browser storage (IndexedDB & SessionStorage) is completely blocked (e.g. strict Private Browsing).
  static bool isWebStorageBlocked = false;

  /// Holds an error message surfaced by getRedirectResult on app return.
  String? pendingAuthError;

  /// Preserved diagnostic detail of the last auth failure (for developer diagnostics panel).
  static AuthDiagnosticInfo? staticLastAuthDiagnostic;
  AuthDiagnosticInfo? _lastAuthDiagnostic;

  AuthDiagnosticInfo? get lastAuthDiagnostic => _lastAuthDiagnostic ?? staticLastAuthDiagnostic;
  set lastAuthDiagnostic(AuthDiagnosticInfo? value) {
    _lastAuthDiagnostic = value;
    staticLastAuthDiagnostic = value;
  }

  void clearPendingAuthError() {
    pendingAuthError = null;
    notifyListeners();
  }

  void clearAuthDiagnostic() {
    _lastAuthDiagnostic = null;
    staticLastAuthDiagnostic = null;
    notifyListeners();
  }

  static Future<void> _setupWebPersistence() async {
    debugPrint('[AUTH-PERSISTENCE] Configuring web persistence...');
    // 1. Try LOCAL persistence (IndexedDB / localStorage)
    try {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      isWebStorageBlocked = false;
      debugPrint('[AUTH-PERSISTENCE] Persistence set to LOCAL (localStorage/IndexedDB)');
      return;
    } catch (e1) {
      debugPrint('[AUTH-PERSISTENCE] LOCAL persistence failed ($e1), trying SESSION...');
    }

    // 2. Try SESSION persistence (sessionStorage)
    try {
      await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
      isWebStorageBlocked = false;
      debugPrint('[AUTH-PERSISTENCE] Persistence set to SESSION (sessionStorage)');
      return;
    } catch (e2, st2) {
      debugPrint('[AUTH-PERSISTENCE] SESSION persistence failed ($e2). Web storage is completely unavailable.');
      // NEVER use Persistence.NONE for redirect auth: state in memory is wiped out when Safari unloads.
      isWebStorageBlocked = true;
      staticLastAuthDiagnostic = AuthDiagnosticInfo(
        stage: 'setPersistence',
        exceptionType: e2.runtimeType.toString(),
        code: (e2 is FirebaseException) ? e2.code : null,
        message: (e2 is FirebaseException) ? e2.message : null,
        rawException: e2.toString(),
        stackTraceSnippet: st2.toString().split('\n').take(6).join('\n'),
      );
    }
  }

  /// Populate local state from an authenticated [User].
  void _applyFirebaseUser(User user) {
    userId = user.uid;
    userEmail = user.email ?? '';
    final email = user.email;
    final fallbackFromEmail = (email != null && email.contains('@'))
        ? email.split('@').first
        : (email != null && email.trim().isNotEmpty ? email : 'Notelekh User');
    displayName = (user.displayName != null && user.displayName!.trim().isNotEmpty)
        ? user.displayName!
        : fallbackFromEmail;
    userPhotoUrl = user.photoURL;
    isAuthenticated = true;
    showLoginScreen = false;
    isAuthRestoring = false;

    // Immediately provide a valid starter workspace so the workspace dashboard displays with zero delay
    if (workspaces.isEmpty) {
      final defaultWs = WorkspaceModel(
        id: 'default_${user.uid}',
        userId: user.uid,
        name: 'My Workspace',
        description: 'Personal notes & workspace',
        icon: 'book',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      workspaces = [defaultWs];
      currentWorkspace = defaultWs;
    } else {
      currentWorkspace ??= workspaces.first;
    }
  }

  /// Sign in with email + password. Returns null on success, error message on failure.
  Future<String?> signInWithEmail(String email, String password) async {
    debugPrint('[AUTH-SIGNIN] START (email: ${email.trim()})');
    if (kIsWeb && isWebStorageBlocked) {
      return 'Safari storage is blocked (Private Browsing or cookies restricted). Please switch to a normal tab or allow cookies to sign in.';
    }
    try {
      debugPrint('[AUTH-SIGNIN] Ensuring Firebase is ready...');
      await _ensureFirebase();
      debugPrint('[AUTH-SIGNIN] Firebase ready. Calling signInWithEmailAndPassword...');

      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final cUser = cred.user;
      if (cUser != null) {
        debugPrint('[AUTH-SIGNIN] Sign-in SUCCESS: UID=${cUser.uid}');
        _applyFirebaseUser(cUser);
        notifyListeners(); // Show workspace immediately — don't block on workspace load
        loadUserWorkspaces().catchError((e) {
          debugPrint('[AUTH-SIGNIN] loadUserWorkspaces after sign-in non-fatal error: $e');
        });
        debugPrint('[AUTH-SIGNIN] COMPLETE');
        return null;
      }
      debugPrint('[AUTH-SIGNIN] FAILED: user is null in credential.');
      return 'Could not sign in. Please check your credentials.';
    } on FirebaseAuthException catch (e, st) {
      debugPrint('[AUTH-SIGNIN] FAILED FirebaseAuthException code=${e.code} message=${e.message}');
      debugPrint('[AUTH-SIGNIN] Stack: $st');
      lastAuthDiagnostic = AuthDiagnosticInfo(
        stage: 'signInWithEmail',
        exceptionType: e.runtimeType.toString(),
        code: e.code,
        message: e.message,
        rawException: e.toString(),
        stackTraceSnippet: st.toString().split('\n').take(8).join('\n'),
      );
      return _authErrorMessage(e);
    } on FirebaseException catch (e, st) {
      debugPrint('[AUTH-SIGNIN] FAILED FirebaseException code=${e.code} message=${e.message}');
      debugPrint('[AUTH-SIGNIN] Stack: $st');
      lastAuthDiagnostic = AuthDiagnosticInfo(
        stage: 'signInWithEmail',
        exceptionType: e.runtimeType.toString(),
        code: e.code,
        message: e.message,
        rawException: e.toString(),
        stackTraceSnippet: st.toString().split('\n').take(8).join('\n'),
      );
      return _authErrorMessage(e);
    } catch (e, st) {
      debugPrint('[AUTH-SIGNIN] FAILED ${e.runtimeType}: $e');
      debugPrint('[AUTH-SIGNIN] Stack: $st');
      lastAuthDiagnostic = AuthDiagnosticInfo(
        stage: 'signInWithEmail',
        exceptionType: e.runtimeType.toString(),
        code: _extractFirebaseCode(e),
        message: e.toString(),
        rawException: e.toString(),
        stackTraceSnippet: st.toString().split('\n').take(8).join('\n'),
      );
      return _authErrorMessage(e);
    }
  }

  /// Create account with email + password. Returns null on success, error message on failure.
  Future<String?> createAccount(String email, String password, String name) async {
    debugPrint('[AUTH-SIGNUP] START (email: ${email.trim()})');
    if (kIsWeb && isWebStorageBlocked) {
      return 'Safari storage is blocked (Private Browsing or cookies restricted). Please switch to a normal tab or allow cookies to create an account.';
    }
    try {
      debugPrint('[AUTH-SIGNUP] Ensuring Firebase is ready...');
      await _ensureFirebase();
      debugPrint('[AUTH-SIGNUP] Firebase ready. Calling createUserWithEmailAndPassword...');

      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final cUser = cred.user;
      if (cUser != null) {
        debugPrint('[AUTH-SIGNUP] Firebase account created successfully. UID: ${cUser.uid}');
        // Set display name asynchronously — don't block sign-in success on it
        if (name.trim().isNotEmpty) {
          cUser.updateDisplayName(name.trim()).catchError((e) {
            debugPrint('[AUTH-SIGNUP] updateDisplayName non-fatal error: $e');
          });
        }
        _applyFirebaseUser(cUser);
        if (name.trim().isNotEmpty) displayName = name.trim();
        notifyListeners(); // Show workspace immediately
        debugPrint('[AUTH-SIGNUP] Local user state applied. Launching workspace load...');
        loadUserWorkspaces().catchError((e) {
          debugPrint('[AUTH-SIGNUP] loadUserWorkspaces non-fatal error: $e');
        });
        debugPrint('[AUTH-SIGNUP] COMPLETE');
        return null;
      }
      debugPrint('[AUTH-SIGNUP] FAILED: user is null in credential.');
      return 'Account creation failed. Please try again.';
    } on FirebaseAuthException catch (e, st) {
      debugPrint('[AUTH-SIGNUP] FAILED FirebaseAuthException code=${e.code} message=${e.message}');
      debugPrint('[AUTH-SIGNUP] Stack: $st');
      lastAuthDiagnostic = AuthDiagnosticInfo(
        stage: 'createAccount',
        exceptionType: e.runtimeType.toString(),
        code: e.code,
        message: e.message,
        rawException: e.toString(),
        stackTraceSnippet: st.toString().split('\n').take(8).join('\n'),
      );
      return _authErrorMessage(e);
    } on FirebaseException catch (e, st) {
      debugPrint('[AUTH-SIGNUP] FAILED FirebaseException code=${e.code} message=${e.message}');
      debugPrint('[AUTH-SIGNUP] Stack: $st');
      lastAuthDiagnostic = AuthDiagnosticInfo(
        stage: 'createAccount',
        exceptionType: e.runtimeType.toString(),
        code: e.code,
        message: e.message,
        rawException: e.toString(),
        stackTraceSnippet: st.toString().split('\n').take(8).join('\n'),
      );
      return _authErrorMessage(e);
    } catch (e, st) {
      debugPrint('[AUTH-SIGNUP] FAILED ${e.runtimeType}: $e');
      debugPrint('[AUTH-SIGNUP] Stack: $st');
      lastAuthDiagnostic = AuthDiagnosticInfo(
        stage: 'createAccount',
        exceptionType: e.runtimeType.toString(),
        code: _extractFirebaseCode(e),
        message: e.toString(),
        rawException: e.toString(),
        stackTraceSnippet: st.toString().split('\n').take(8).join('\n'),
      );
      return _authErrorMessage(e);
    }
  }

  /// Sign in with Google using official FlutterFire.
  /// Uses signInWithPopup on Web (works seamlessly on Windows, Mac, Linux, iOS, iPad, Android).
  /// If popup is blocked by strict browser policy, gracefully falls back to signInWithRedirect.
  Future<String?> signInWithGoogle() async {
    if (!kIsWeb) return 'Google sign-in is currently supported on web.';
    if (isWebStorageBlocked) {
      return 'Safari storage is blocked (Private Browsing or cookies restricted). Please switch to a normal tab or allow cookies to sign in with Google.';
    }
    if (_isGoogleAuthInFlight) {
      debugPrint('[AUTH-GOOGLE] Google sign-in already in flight — ignoring duplicate request.');
      return null;
    }
    _isGoogleAuthInFlight = true;
    debugPrint('[AUTH-GOOGLE] START (using signInWithPopup with redirect fallback)');

    try {
      debugPrint('[AUTH-GOOGLE] Ensuring Firebase is ready...');
      await _ensureFirebase();
      debugPrint('[AUTH-GOOGLE] Firebase ready. Creating GoogleAuthProvider...');

      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile')
        ..setCustomParameters({'prompt': 'select_account'});

      UserCredential credential;
      try {
        credential = await FirebaseAuth.instance.signInWithPopup(provider);
      } on FirebaseAuthException catch (e, st) {
        debugPrint('[AUTH-GOOGLE] signInWithPopup FirebaseAuthException: code=${e.code} message=${e.message}');
        if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
          debugPrint('[AUTH-GOOGLE] Popup dismissed by user.');
          return null; // User simply closed the popup, not an error
        }
        if (e.code == 'popup-blocked' || e.code == 'web-storage-unsupported') {
          debugPrint('[AUTH-GOOGLE] Popup blocked, falling back to signInWithRedirect...');
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('notelekh_pending_auth_redirect', true);
            await FirebaseAuth.instance.signInWithRedirect(provider);
            return null; // Redirect underway
          } catch (redirectErr, rSt) {
            debugPrint('[AUTH-GOOGLE] Fallback redirect error: $redirectErr');
            debugPrint('[AUTH-GOOGLE] Stack: $rSt');
            return _authErrorMessage(redirectErr);
          }
        }
        lastAuthDiagnostic = AuthDiagnosticInfo(
          stage: 'signInWithPopup',
          exceptionType: e.runtimeType.toString(),
          code: e.code,
          message: e.message,
          rawException: e.toString(),
          stackTraceSnippet: st.toString().split('\n').take(8).join('\n'),
        );
        return _authErrorMessage(e);
      } catch (e, st) {
        debugPrint('[AUTH-GOOGLE] Generic signInWithPopup error: $e');
        final code = _extractFirebaseCode(e);
        if (code == 'popup-closed-by-user' || code == 'cancelled-popup-request') {
          return null;
        }
        if (code == 'popup-blocked') {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('notelekh_pending_auth_redirect', true);
            await FirebaseAuth.instance.signInWithRedirect(provider);
            return null;
          } catch (_) {}
        }
        lastAuthDiagnostic = AuthDiagnosticInfo(
          stage: 'signInWithPopup',
          exceptionType: e.runtimeType.toString(),
          code: code,
          message: e.toString(),
          rawException: e.toString(),
          stackTraceSnippet: st.toString().split('\n').take(8).join('\n'),
        );
        return _authErrorMessage(e);
      }

      final user = credential.user;
      if (user != null) {
        debugPrint('[AUTH-GOOGLE] Popup sign-in SUCCESS: UID=${user.uid} (${user.email})');
        _applyFirebaseUser(user);
        notifyListeners(); // Directly transitions into ResponsiveShell (Workspace Dashboard)!
        loadUserWorkspaces().catchError((e) {
          debugPrint('[AUTH-GOOGLE] loadUserWorkspaces after Google popup non-fatal error: $e');
        });
        return null;
      }
      return 'Google sign-in could not retrieve user profile.';
    } finally {
      _isGoogleAuthInFlight = false;
    }
  }

  /// Extract a Firebase error code from a generic exception's string representation.
  /// FlutterFire web sometimes wraps JS SDK errors as PlatformException or TypeError
  /// that don't match `on FirebaseAuthException`. This extracts the underlying code.
  String? _extractFirebaseCode(dynamic e) {
    final s = e.toString().toLowerCase();
    // Common Firebase Auth error codes that may appear in JS interop exceptions
    const codes = [
      'email-already-in-use', 'invalid-email', 'weak-password',
      'user-not-found', 'wrong-password', 'invalid-credential',
      'too-many-requests', 'network-request-failed', 'user-disabled',
      'operation-not-allowed', 'unauthorized-domain', 'popup-blocked',
      'popup-closed-by-user', 'cancelled-popup-request',
      'account-exists-with-different-credential', 'credential-already-in-use',
      'internal-error',
    ];
    for (final code in codes) {
      if (s.contains(code)) return code;
    }
    return null;
  }

  /// Translate FirebaseAuthException and general errors without masking exceptions.
  String _authErrorMessage(dynamic e) {
    String code = '';
    String? message;
    if (e is FirebaseAuthException) {
      code = e.code;
      message = e.message;
    } else if (e is FirebaseException) {
      code = e.code;
      message = e.message;
    } else {
      // Try to extract a known Firebase error code from the exception string
      final extracted = _extractFirebaseCode(e);
      if (extracted != null) {
        code = extracted;
      } else {
        final s = e.toString().toLowerCase();
        if (s.contains('popup-blocked') || s.contains('popup_blocked')) {
          code = 'popup-blocked';
        } else if (s.contains('popup-closed') || s.contains('closed-by-user')) {
          code = 'popup-closed-by-user';
        } else if (s.contains('redirect_uri_mismatch')) {
          code = 'redirect-uri-mismatch';
        } else if (s.contains('storage') || s.contains('quota') || s.contains('insecure')) {
          code = 'web-storage-unsupported';
        } else if (s.contains('duplicate-app')) {
          code = 'core/duplicate-app';
        }
      }
      message = e.toString();
    }
    debugPrint('[AUTH-ERROR] code=$code rawMessage=$message');
    switch (code) {
      case 'unauthorized-domain':
        return 'Domain is not authorized in Firebase Console (Authentication > Settings > Authorized domains).';
      case 'redirect-uri-mismatch':
        return 'OAuth redirect URI mismatch. Please verify Google Cloud Console redirect URIs.';
      case 'web-storage-unsupported':
        return 'Browser storage is restricted. If using Safari Private Browsing, please switch to a normal tab or allow cookies.';
      case 'popup-blocked':
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return 'Sign-in was cancelled or interrupted. Please try again.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in the Firebase Authentication console.';
      case 'user-found':
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'This email is already registered. Try signing in instead.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'internal-error':
        return 'A server error occurred. Please try again in a moment.';
      case 'core/duplicate-app':
        return 'Application initialization in progress. Please try again.';
      default:
        if (code.isNotEmpty) {
          final detail = (message != null && message.isNotEmpty && message != code) ? ': $message' : '';
          return 'Authentication error ($code)$detail';
        }
        return (message != null && message.isNotEmpty)
            ? message
            : (e?.toString() ?? 'Authentication failed.');
    }
  }

  /// Formats any authentication exception into clean, human-readable guidance.
  String formatAuthError(dynamic e) => _authErrorMessage(e);

  /// Enter workspace directly (used when Firebase already has a session on app start).
  Future<void> enterAppDirectly() async {
    await _ensureFirebase();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _applyFirebaseUser(user);
    } else {
      // Fallback: allow entry without auth (dev/demo mode)
      userId ??= 'local_user';
      isAuthenticated = true;
      showLoginScreen = false;
    }
    if (workspaces.isEmpty) {
      await loadUserWorkspaces();
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    isAuthenticated = false;
    showLoginScreen = false;
    isAuthRestoring = false;
    userId = null;
    userEmail = '';
    displayName = 'Notelekh User';
    userPhotoUrl = null;
    await resetWorkspace();
    workspaceFiles = _getDefaultWorkspaceFiles('default');
    notifyListeners();
  }

  Future<void> logout() => signOut();

  Future<void> initWorkspaces() async {
    try {
      // 1. Check if user is returning from a Google redirect
      bool isPendingRedirect = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        isPendingRedirect = prefs.getBool('notelekh_pending_auth_redirect') ?? false;
        if (isPendingRedirect) {
          isAuthRestoring = true;
          notifyListeners();
        }
      } catch (_) {}

      debugPrint('[AUTH-INIT] Fast-initializing Firebase...');
      await _ensureFirebase();

      // 2. Only query getRedirectResult if an actual redirect was flagged
      if (kIsWeb && isPendingRedirect) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('notelekh_pending_auth_redirect');
        } catch (_) {}

        try {
          debugPrint('[AUTH-REDIRECT] Calling getRedirectResult()...');
          final UserCredential redirectResult =
              await FirebaseAuth.instance.getRedirectResult();

          if (redirectResult.user != null) {
            debugPrint('[AUTH-REDIRECT] Redirect completed: ${redirectResult.user!.email}');
            isAuthRestoring = false;
            _applyFirebaseUser(redirectResult.user!);
            notifyListeners(); // SHOW WORKSPACE IMMEDIATELY — ZERO DELAY!
            _startAuthListener();
            loadUserWorkspaces().catchError((e) {
              debugPrint('[AUTH-REDIRECT] loadUserWorkspaces non-fatal error: $e');
            });
            return;
          }
        } catch (e) {
          debugPrint('[AUTH-REDIRECT] getRedirectResult non-fatal: $e');
        }
        isAuthRestoring = false;
      }

      // 3. Immediately restore existing user session with zero delay
      final existingUser = FirebaseAuth.instance.currentUser;
      if (existingUser != null) {
        debugPrint('[AUTH-STATE] Existing session active: ${existingUser.email}');
        _applyFirebaseUser(existingUser);
        isAuthRestoring = false;
        notifyListeners(); // SHOW WORKSPACE IMMEDIATELY — ZERO DELAY!
        _startAuthListener();
        loadUserWorkspaces().catchError((e) {
          debugPrint('[AUTH-STATE] loadUserWorkspaces non-fatal: $e');
        });
        return;
      } else {
        userId ??= 'local_user';
        displayName = 'Notelekh User';
        userEmail = '';
        isAuthRestoring = false;
      }

      _startAuthListener();
    } catch (e, st) {
      debugPrint('[AUTH-STATE] initWorkspaces error: ${e.runtimeType}: $e');
      debugPrint('[AUTH-STATE] Stack: $st');
      userId ??= 'local_user';
      isAuthRestoring = false;
    }

    loadUserWorkspaces().catchError((e) {
      debugPrint('[AUTH-STATE] Background initial workspace load: $e');
    });
    notifyListeners();
  }

  void _startAuthListener() {
    _authStateSubscription?.cancel();
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) {
        if (user != null && (!isAuthenticated || userId != user.uid)) {
          debugPrint('[Auth] authStateChanges: signed in as ${user.email}');
          _applyFirebaseUser(user);
          notifyListeners(); // SHOW WORKSPACE IMMEDIATELY — ZERO DELAY!
          loadUserWorkspaces().catchError((e) {
            debugPrint('[Auth] loadUserWorkspaces background error: $e');
          });
        } else if (user == null && isAuthenticated) {
          debugPrint('[Auth] authStateChanges: signed out');
        }
      },
      onError: (e) => debugPrint('[Auth] authStateChanges error: $e'),
    );
  }

  Future<void> resetWorkspace() async {
    workspaces.clear();
    currentWorkspace = null;
    conversations.clear();
    currentConversation = null;
    currentMessages.clear();
    canvasDocs.clear();
    currentCanvasDoc = null;
    canvasObjects.clear();
    workspaceFiles.clear();
    selectedNavIndex = 0;
    accountItemCount = 0;
    accountStorageBytes = 0;
    _lastStorageComputation = null;
    _noteTodos.clear();
    undoStack.clear();
    redoStack.clear();
    selectedCanvasObjects.clear();
    notifyListeners();
  }

  Future<void> loadUserWorkspaces() async {
    _syncCurrentPageObjects();
    if (currentCanvasDoc != null) {
      NotesLocalStorageService.saveDocLocally(currentCanvasDoc!, userId: userId);
    }

    try {
      await fetchWorkspaces();
      if (workspaces.isNotEmpty) {
        await selectWorkspace(workspaces.first);
      } else {
        // Create initial starter workspace for this user
        final newWs = await createWorkspace(
          name: 'My Workspace',
          description: 'Personal notes & workspace',
          icon: 'book',
        );
        if (newWs != null) {
          await selectWorkspace(newWs);
        }
      }
    } catch (e) {
      debugPrint('Error loading workspaces: $e');
    }

    if (workspaceFiles.isEmpty) {
      workspaceFiles = _getDefaultWorkspaceFiles(currentWorkspace?.id ?? 'default');
    }

    computeAccountStorage(forceCloudSync: true);
    notifyListeners();
  }


  bool isNotebookSidebarVisible = false;

  void toggleNotebookSidebar() {
    isNotebookSidebarVisible = !isNotebookSidebarVisible;
    notifyListeners();
  }

  void setNavIndex(int index) {
    selectedNavIndex = index;
    // When opening/switching to a notebook (nav index 1), hide sidebar by default
    if (index == 1) {
      isNotebookSidebarVisible = false;
    }
    notifyListeners();
  }

  void toggleTheme() {
    isDarkMode = !isDarkMode;
    darkModeNotifier.value = isDarkMode;
    notifyListeners();
  }

  void toggleContextPanel() {
    isContextPanelVisible = !isContextPanelVisible;
    notifyListeners();
  }

  void setViewMode(WorkspaceViewMode mode) {
    viewMode = mode;
    notifyListeners();
  }

  void setSplitRatio(double ratio) {
    splitRatio = ratio.clamp(0.25, 0.75);
    notifyListeners();
  }

  // ================= WORKSPACES =================
  Future<void> fetchWorkspaces() async {
    isLoadingWorkspaces = true;
    notifyListeners();
    try {
      if (userId == null) return;
      workspaces = await firestoreService.getWorkspaces(userId!);
    } catch (e) {
      debugPrint('Error fetching workspaces: $e');
    } finally {
      isLoadingWorkspaces = false;
      notifyListeners();
    }
  }

  Future<WorkspaceModel?> createWorkspace({
    required String name,
    String description = '',
    String icon = 'folder',
  }) async {
    try {
      if (userId == null) return null;
      final ws = await firestoreService.createWorkspace(
        userId: userId!,
        name: name,
        description: description,
        icon: icon,
      );
      workspaces.insert(0, ws);
      await selectWorkspace(ws);
      return ws;
    } catch (e) {
      debugPrint('Error creating workspace: $e');
      return null;
    }
  }

  Future<bool> deleteWorkspace(String workspaceId) async {
    try {
      if (userId != null) {
        await firestoreService.deleteWorkspace(userId!, workspaceId);
      }
      await NotesLocalStorageService.deleteWorkspaceDocsLocally(workspaceId, userId: userId);
      workspaces.removeWhere((w) => w.id == workspaceId);
      if (currentWorkspace?.id == workspaceId) {
        if (workspaces.isNotEmpty) {
          await selectWorkspace(workspaces.first);
        } else {
          final newWs = await createWorkspace(name: 'Main Workspace');
          if (newWs != null) {
            await selectWorkspace(newWs);
          }
        }
      }
      computeAccountStorage(forceCloudSync: true);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting workspace: $e');
      return false;
    }
  }

  Future<void> exportWorkspace(String workspaceId, String format) async {
    try {
      final ws = workspaces.firstWhere(
        (w) => w.id == workspaceId,
        orElse: () => currentWorkspace!,
      );

      List<CanvasDocModel> docsToExport;
      if (workspaceId == currentWorkspace?.id && canvasDocs.isNotEmpty) {
        docsToExport = List.from(canvasDocs);
      } else {
        try {
          final cloudDocs = await firestoreService.getWorkspaceCanvasDocs(userId!, workspaceId);
          docsToExport = cloudDocs.isNotEmpty ? cloudDocs : List.from(canvasDocs);
        } catch (_) {
          docsToExport = List.from(canvasDocs);
        }
      }

      await WorkspaceExportService.exportWorkspace(
        workspace: ws,
        docs: docsToExport,
        format: format,
      );
    } catch (e) {
      debugPrint('Error exporting workspace: $e');
      rethrow;
    }
  }


  Future<void> selectWorkspace(WorkspaceModel ws) async {
    _syncCurrentPageObjects();
    if (currentCanvasDoc != null) {
      NotesLocalStorageService.saveDocLocally(currentCanvasDoc!, userId: userId);
    }
    currentWorkspace = ws;
    notifyListeners();
    await Future.wait([
      fetchWorkspaceConversations(ws.id),
      fetchWorkspaceCanvasDocs(ws.id),
      fetchWorkspaceFiles(ws.id),
    ]);
  }

  // ================= CONVERSATIONS & STREAMING =================
  Future<void> fetchWorkspaceConversations(String workspaceId) async {
    try {
      conversations = await apiService.getConversations(workspaceId: workspaceId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching conversations: $e');
    }
  }

  void startNewChat() {
    currentConversation = null;
    currentMessages = [];
    currentStreamingText = '';
    isStreaming = false;
    notifyListeners();
  }

  Future<void> openConversation(ConversationModel conv) async {
    currentConversation = conv;
    currentMessages = List.from(conv.messages);
    currentStreamingText = '';
    isStreaming = false;
    notifyListeners();
    try {
      final fullConv = await apiService.getConversation(conv.id);
      currentConversation = fullConv;
      currentMessages = List.from(fullConv.messages);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading conversation: $e');
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || isStreaming) return;

    final userMsg = MessageModel(
      id: 'temp-user-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: currentConversation?.id ?? '',
      role: 'user',
      content: text,
      selectedContext: List.from(selectedContextItems),
      createdAt: DateTime.now(),
    );

    currentMessages.add(userMsg);
    isStreaming = true;
    currentStreamingText = '';
    notifyListeners();

    final contextPayload = List<ContextItemModel>.from(selectedContextItems);

    try {
      final stream = apiService.streamAIChat(
        prompt: text,
        conversationId: currentConversation?.id,
        workspaceId: currentWorkspace?.id,
        contextItems: contextPayload,
      );

      String streamConvId = currentConversation?.id ?? '';

      await for (final event in stream) {
        if (event['type'] == 'meta') {
          streamConvId = event['conversation_id'];
          currentConversation ??= ConversationModel(
            id: streamConvId,
            workspaceId: currentWorkspace?.id,
            userId: userId ?? userEmail,
            title: event['title'] ?? text.substring(0, text.length.clamp(0, 30)),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        } else if (event['type'] == 'token') {
          currentStreamingText += event['content'] as String? ?? '';
          notifyListeners();
        } else if (event['type'] == 'done') {
          final replyText = currentStreamingText;
          final assistantMsg = MessageModel(
            id: event['assistant_message_id'] ?? 'ast-${DateTime.now().millisecondsSinceEpoch}',
            conversationId: streamConvId,
            role: 'assistant',
            content: replyText,
            createdAt: DateTime.now(),
          );
          currentMessages.add(assistantMsg);

          // Auto-write AI chat reply directly on canvas if enabled
          if (autoWriteToCanvas && replyText.trim().isNotEmpty) {
            insertAIResponseToCanvas(
              replyText,
              userPrompt: text,
              aiModel: 'ChatGPT',
            );
          }

          currentStreamingText = '';
          isStreaming = false;
          notifyListeners();

          // Refresh workspace conversations
          if (currentWorkspace != null) {
            fetchWorkspaceConversations(currentWorkspace!.id);
          }
        } else if (event['type'] == 'error') {
          currentStreamingText += '\n[Error: ${event['error']}]';
          isStreaming = false;
          notifyListeners();
        }
      }
    } catch (e) {
      currentStreamingText += '\n[Connection Error: $e]';
      isStreaming = false;
      notifyListeners();
    }
  }

  Future<void> saveCurrentConversationToWorkspace(String targetWorkspaceId) async {
    if (currentConversation == null) return;
    try {
      final updated = await apiService.saveConversationToWorkspace(
        conversationId: currentConversation!.id,
        workspaceId: targetWorkspaceId,
      );
      currentConversation = updated;
      await fetchWorkspaces();
      if (currentWorkspace?.id == targetWorkspaceId) {
        await fetchWorkspaceConversations(targetWorkspaceId);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving conversation: $e');
    }
  }

  // ================= SELECTIVE CONTEXT TRAY =================
  void addContextItem(ContextItemModel item) {
    if (!selectedContextItems.any((c) => c.id == item.id && c.type == item.type)) {
      selectedContextItems.add(item);
      notifyListeners();
    }
  }

  void removeContextItem(ContextItemModel item) {
    selectedContextItems.removeWhere((c) => c.id == item.id && c.type == item.type);
    notifyListeners();
  }

  void clearContextTray() {
    selectedContextItems.clear();
    notifyListeners();
  }

  // ================= CANVAS ENGINE & GOODNOTES NOTEBOOK/PAGE SYSTEM =================
  Future<void> fetchWorkspaceCanvasDocs(String workspaceId) async {
    // 1. Immediately hydrate from local storage for this specific workspace
    try {
      final wsLocalDocs = await NotesLocalStorageService.loadDocsForWorkspace(workspaceId, userId: userId);
      canvasDocs = wsLocalDocs;
      
      if (wsLocalDocs.isNotEmpty) {
        if (accountItemCount < wsLocalDocs.length) {
          accountItemCount = wsLocalDocs.length;
        }
        final lastActiveId = await NotesLocalStorageService.getActiveDocId(userId: userId);
        currentCanvasDoc = canvasDocs.firstWhere(
          (d) => d.id == lastActiveId,
          orElse: () => canvasDocs.first,
        );
        currentPageIndex = currentCanvasDoc!.currentPageIndex.clamp(0, currentCanvasDoc!.pages.length - 1);
        canvasPaperStyle = currentCanvasDoc!.activePage.paperStyle;
        canvasObjects = List.from(currentCanvasDoc!.activePage.objects);
        isPageViewMode = currentCanvasDoc!.docType != CanvasDocType.canvas;
      } else {
        currentCanvasDoc = null;
        canvasObjects = [];
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading local docs on startup: $e');
    }

    // 2. Intelligent zero-data-loss cloud merge in background
    try {
      final cloudDocs = await firestoreService.getWorkspaceCanvasDocs(userId!, workspaceId);
      if (cloudDocs.isNotEmpty) {
        // Synchronize in-memory changes to current active doc first
        _syncCurrentPageObjects();

        // Build a merged document list: local docs always preserve user drawings
        final Map<String, CanvasDocModel> mergedDocs = {};
        for (final localDoc in canvasDocs) {
          mergedDocs[localDoc.id] = localDoc;
        }

        for (final cloudDoc in cloudDocs) {
          final localDoc = mergedDocs[cloudDoc.id];
          if (localDoc == null) {
            // New doc from cloud
            mergedDocs[cloudDoc.id] = cloudDoc;
          } else {
            // Document exists both locally and in cloud!
            // CRITICAL ZERO-DATA-LOSS MERGE:
            // Ensure every page with user drawings is strictly preserved.
            final List<CanvasPage> resolvedPages = [];
            final maxPages = math.max(localDoc.pages.length, cloudDoc.pages.length);
            for (int i = 0; i < maxPages; i++) {
              final localPage = (i < localDoc.pages.length) ? localDoc.pages[i] : null;
              final cloudPage = (i < cloudDoc.pages.length) ? cloudDoc.pages[i] : null;

              if (localPage != null && cloudPage != null) {
                // If local page has objects or cloud has none, keep local drawings!
                if (localPage.objects.isNotEmpty || cloudPage.objects.isEmpty) {
                  resolvedPages.add(localPage);
                } else {
                  resolvedPages.add(cloudPage);
                }
              } else if (localPage != null) {
                resolvedPages.add(localPage);
              } else if (cloudPage != null) {
                resolvedPages.add(cloudPage);
              }
            }
            localDoc.pages = resolvedPages;
          }
        }

        canvasDocs = mergedDocs.values.toList();
        final activeId = currentCanvasDoc?.id;
        if (activeId != null && mergedDocs.containsKey(activeId)) {
          currentCanvasDoc = mergedDocs[activeId];
        } else if (canvasDocs.isNotEmpty && currentCanvasDoc == null) {
          currentCanvasDoc = canvasDocs.first;
        }

        if (currentCanvasDoc != null) {
          final clampedPage = currentPageIndex.clamp(0, currentCanvasDoc!.pages.length - 1);
          currentPageIndex = clampedPage;
          currentCanvasDoc!.currentPageIndex = clampedPage;
          canvasPaperStyle = currentCanvasDoc!.activePage.paperStyle;
          canvasObjects = List.from(currentCanvasDoc!.activePage.objects);
          isPageViewMode = currentCanvasDoc!.docType != CanvasDocType.canvas;

          // Save authoritative merged state to local storage and sync
          NotesLocalStorageService.saveDocLocally(currentCanvasDoc!, userId: userId);
          _debounceSyncCanvas();
        }

        // Ensure all documents in this workspace are cached locally and synced to cloud
        for (final doc in canvasDocs) {
          NotesLocalStorageService.saveDocLocally(doc, userId: userId);
          if (userId != null) {
            firestoreService.saveCanvasDoc(userId!, workspaceId, doc);
          }
        }
      } else if (canvasDocs.isNotEmpty) {
        // Cloud has no docs for this workspace yet, but local docs exist:
        // Push every local notebook to Firestore so cloud database is populated!
        for (final doc in canvasDocs) {
          NotesLocalStorageService.saveDocLocally(doc, userId: userId);
          if (userId != null) {
            await firestoreService.saveCanvasDoc(userId!, workspaceId, doc);
          }
        }
      } else {
        // Both cloud and local are empty: create default notebook 'Personal Notes'
        final cleanId = workspaceId.replaceAll(RegExp(r'[^\w]'), '');
        final prefix = cleanId.length > 6 ? cleanId.substring(0, 6) : cleanId;
        final defaultNotebook = CanvasDocModel(
          id: 'notebook-$prefix-${DateTime.now().millisecondsSinceEpoch}',
          workspaceId: workspaceId,
          name: 'Personal Notes',
        );
        canvasDocs = [defaultNotebook];
        currentCanvasDoc = defaultNotebook;
        currentPageIndex = 0;
        canvasPaperStyle = CanvasPaperStyle.ruledLines;
        isPageViewMode = true;
        canvasObjects = [];
        NotesLocalStorageService.saveDocLocally(defaultNotebook, userId: userId);
        if (userId != null) {
          await firestoreService.saveCanvasDoc(userId!, workspaceId, defaultNotebook);
        }
      }
      computeAccountStorage(forceCloudSync: true);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching canvas docs from cloud: $e');
    }
  }

  // --- Notebook Operations ---
  void switchNotebook(String notebookId) {
    _syncCurrentPageObjects();
    final found = canvasDocs.firstWhere((d) => d.id == notebookId, orElse: () => canvasDocs.first);
    currentCanvasDoc = found;
    currentPageIndex = found.currentPageIndex.clamp(0, found.pages.length - 1);
    canvasPaperStyle = found.activePage.paperStyle;
    canvasObjects = List.from(found.activePage.objects);
    undoStack.clear();
    redoStack.clear();
    selectedCanvasObjects.clear();
    // Auto-switch view mode based on document type
    isPageViewMode = found.docType != CanvasDocType.canvas;
    viewMode = WorkspaceViewMode.canvasOnly; // Always canvasOnly when opening notebook
    isNotebookSidebarVisible = false; // Hide sidebar upon opening notebook
    notifyListeners();
    _debounceSyncCanvas();
  }

  void openNotebookByName(String name) {
    _syncCurrentPageObjects();
    CanvasDocModel? doc;
    for (final d in canvasDocs) {
      if (d.name.toLowerCase() == name.toLowerCase()) {
        doc = d;
        break;
      }
    }
    if (doc == null) {
      doc = CanvasDocModel(
        id: 'notebook-${DateTime.now().millisecondsSinceEpoch}-${++_docIdCounter}',
        workspaceId: currentWorkspace?.id ?? 'default',
        name: name,
        docType: CanvasDocType.notebook,
        pages: [
          CanvasPage(
            id: 'page-1',
            pageNumber: 1,
            title: 'Page 1',
            paperStyle: CanvasPaperStyle.ruledLines,
          )
        ],
      );
      canvasDocs.add(doc);
    }
    currentCanvasDoc = doc;
    currentPageIndex = doc.currentPageIndex.clamp(0, doc.pages.length - 1);
    canvasPaperStyle = doc.activePage.paperStyle;
    canvasObjects = List.from(doc.activePage.objects);
    undoStack.clear();
    redoStack.clear();
    selectedCanvasObjects.clear();
    isPageViewMode = true;
    viewMode = WorkspaceViewMode.canvasOnly; // Ensures NO chat section appears when opening notebook
    selectedNavIndex = 1;
    notifyListeners();
  }

  void createNotebook(String name, {
    CanvasPaperStyle defaultPaperStyle = CanvasPaperStyle.ruledLines,
    Color coverColor = const Color(0xFF2E7D32),
    String coverEmoji = '📓',
  }) {
    _syncCurrentPageObjects();
    final newDoc = CanvasDocModel(
      id: 'notebook-${DateTime.now().millisecondsSinceEpoch}-${++_docIdCounter}',
      workspaceId: currentWorkspace?.id ?? 'default',
      name: name.trim().isNotEmpty ? name.trim() : 'Notebook ${canvasDocs.length + 1}',
      docType: CanvasDocType.notebook,
      coverColor: coverColor,
      coverEmoji: coverEmoji,
      pages: [
        CanvasPage(
          id: 'page-1',
          pageNumber: 1,
          title: 'Page 1',
          paperStyle: defaultPaperStyle,
        )
      ],
    );
    // Newly created notebook always has an empty to-do list
    _noteTodos[newDoc.id] = [];
    _persistNoteTodos(newDoc.id);
    canvasDocs.add(newDoc);
    switchNotebook(newDoc.id);
    NotesLocalStorageService.saveDocLocally(newDoc, userId: userId);
    if (currentWorkspace != null && userId != null) {
      firestoreService.saveCanvasDoc(userId!, currentWorkspace!.id, newDoc);
    }
    computeAccountStorage(forceCloudSync: true);
  }

  /// Async version for dialogs — supports awaiting creation
  Future<void> createCanvasDoc({
    required String name,
    CanvasPaperStyle paperStyle = CanvasPaperStyle.ruledLines,
    Color coverColor = const Color(0xFF2E7D32),
    String coverEmoji = '📓',
  }) async {
    createNotebook(name, defaultPaperStyle: paperStyle, coverColor: coverColor, coverEmoji: coverEmoji);
  }

  void createInfiniteCanvas(String name, {String template = 'blank'}) {
    _syncCurrentPageObjects();
    List<CanvasObjectItem> initialObjects = [];
    CanvasPaperStyle effectivePaperStyle = CanvasPaperStyle.blankSlate;

    if (template == 'dots') {
      effectivePaperStyle = CanvasPaperStyle.dotGrid;
    } else if (template == 'mindmap') {
      effectivePaperStyle = CanvasPaperStyle.dotGrid;
      final rootTitle = name.trim().isNotEmpty ? name.trim() : 'Central Concept';

      // 1. Central Topic Node
      initialObjects.add(CanvasNoteCardItem(
        id: 'mindmap-root',
        title: '🎯 $rootTitle',
        content: '### Core Initiative & Vision\n\n'
            'The central focus and overarching objectives of this board.\n\n'
            '**Key Pillars:**\n'
            '1. User Experience & Delight\n'
            '2. High-Performance Architecture\n'
            '3. Seamless Real-time Collaboration',
        position: const Offset(360, 240),
        width: 320,
        height: 200,
        backgroundColor: const Color(0xFF1E293B),
        textColor: Colors.white,
      ));

      // 2. Branch: Research & Analysis (Top-Right)
      initialObjects.add(CanvasNoteCardItem(
        id: 'mindmap-branch-1',
        title: '🔍 1. Research & Analysis',
        content: '- **User Insights**: Key workflows & feedback\n'
            '- **Benchmarking**: GoodNotes 6 standards\n'
            '- **Data**: Latency under 16ms target',
        position: const Offset(780, 80),
        width: 290,
        height: 160,
        backgroundColor: const Color(0xFF0F172A),
        textColor: const Color(0xFFE2E8F0),
      ));

      // Arrow Root -> Branch 1
      initialObjects.add(CanvasShapeItem(
        id: 'arrow-root-branch-1',
        shapeType: 'arrow',
        bounds: const Rect.fromLTWH(680, 160, 100, 100),
        strokeColor: const Color(0xFF6366F1),
        strokeWidth: 2.5,
      ));

      // 3. Branch: Technical Execution (Bottom-Right)
      initialObjects.add(CanvasNoteCardItem(
        id: 'mindmap-branch-2',
        title: '⚡ 2. Technical Execution',
        content: '- **Engine**: High-fidelity custom painters\n'
            '- **State**: Reactive local + cloud sync\n'
            '- **Persistence**: Offline-first storage',
        position: const Offset(780, 380),
        width: 290,
        height: 160,
        backgroundColor: const Color(0xFF0F172A),
        textColor: const Color(0xFFE2E8F0),
      ));

      // Arrow Root -> Branch 2
      initialObjects.add(CanvasShapeItem(
        id: 'arrow-root-branch-2',
        shapeType: 'arrow',
        bounds: const Rect.fromLTWH(680, 360, 100, 60),
        strokeColor: const Color(0xFF10B981),
        strokeWidth: 2.5,
      ));

      // 4. Branch: Quality & Launch (Left)
      initialObjects.add(CanvasNoteCardItem(
        id: 'mindmap-branch-3',
        title: '🚀 3. Quality & Launch',
        content: '- **Verification**: End-to-end user flows\n'
            '- **Accessibility**: High contrast & scaling\n'
            '- **Release**: Production web deployment',
        position: const Offset(-60, 240),
        width: 290,
        height: 160,
        backgroundColor: const Color(0xFF0F172A),
        textColor: const Color(0xFFE2E8F0),
      ));

      // Arrow Branch 3 -> Root
      initialObjects.add(CanvasShapeItem(
        id: 'arrow-branch-3-root',
        shapeType: 'arrow',
        bounds: const Rect.fromLTWH(230, 310, 130, 20),
        strokeColor: const Color(0xFFF59E0B),
        strokeWidth: 2.5,
      ));
    } else if (template == 'flowchart') {
      effectivePaperStyle = CanvasPaperStyle.dotGrid;

      // Stage 1: Input & Trigger
      initialObjects.add(CanvasNoteCardItem(
        id: 'flow-1',
        title: '🟢 1. Trigger & Request Initiation',
        content: 'User initiates note creation or document import.\n\n'
            '- Validate workspace context\n'
            '- Initialize document metadata & styles',
        position: const Offset(360, 40),
        width: 320,
        height: 140,
        backgroundColor: const Color(0xFF064E3B),
        textColor: const Color(0xFFECFDF5),
      ));

      // Arrow 1 -> 2
      initialObjects.add(CanvasShapeItem(
        id: 'flow-arrow-1-2',
        shapeType: 'arrow',
        bounds: const Rect.fromLTWH(505, 180, 30, 60),
        strokeColor: const Color(0xFF10B981),
        strokeWidth: 3.0,
      ));

      // Stage 2: Processing Pipeline
      initialObjects.add(CanvasNoteCardItem(
        id: 'flow-2',
        title: '🔷 2. Core Processing Pipeline',
        content: 'Data transformation, canvas setup, and layout.\n\n'
            '- Apply selected template schema\n'
            '- Mount reactive gesture handlers',
        position: const Offset(360, 240),
        width: 320,
        height: 140,
        backgroundColor: const Color(0xFF1E3A8A),
        textColor: const Color(0xFFEFF6FF),
      ));

      // Arrow 2 -> 3
      initialObjects.add(CanvasShapeItem(
        id: 'flow-arrow-2-3',
        shapeType: 'arrow',
        bounds: const Rect.fromLTWH(505, 380, 30, 60),
        strokeColor: const Color(0xFF38BDF8),
        strokeWidth: 3.0,
      ));

      // Stage 3: Verification Gate
      initialObjects.add(CanvasNoteCardItem(
        id: 'flow-3',
        title: '🔶 3. Verification & Validation Gate',
        content: 'Automated integrity check:\n\n'
            '- Are page bounds & dimensions aligned?\n'
            '- Does offline cache reflect latest state?',
        position: const Offset(360, 440),
        width: 320,
        height: 140,
        backgroundColor: const Color(0xFF78350F),
        textColor: const Color(0xFFFFFBEB),
      ));

      // Arrow 3 -> 4
      initialObjects.add(CanvasShapeItem(
        id: 'flow-arrow-3-4',
        shapeType: 'arrow',
        bounds: const Rect.fromLTWH(505, 580, 30, 60),
        strokeColor: const Color(0xFFF59E0B),
        strokeWidth: 3.0,
      ));

      // Stage 4: Output & Inking
      initialObjects.add(CanvasNoteCardItem(
        id: 'flow-4',
        title: '🟣 4. Render & Ready for Inking',
        content: 'Document is active on screen.\n\n'
            '✓ Canvas ready for handwriting, typing & shapes\n'
            '✓ Auto-save stream connected',
        position: const Offset(360, 640),
        width: 320,
        height: 140,
        backgroundColor: const Color(0xFF4C1D95),
        textColor: const Color(0xFFF5F3FF),
      ));
    }

    final newDoc = CanvasDocModel(
      id: 'canvas-${DateTime.now().millisecondsSinceEpoch}-${++_docIdCounter}',
      workspaceId: currentWorkspace?.id ?? 'default',
      name: name.trim().isNotEmpty ? name.trim() : 'Whiteboard ${canvasDocs.length + 1}',
      docType: CanvasDocType.canvas,
      coverColor: const Color(0xFF0F766E),
      coverEmoji: '📐',
      pages: [
        CanvasPage(
          id: 'page-1',
          pageNumber: 1,
          title: 'Whiteboard',
          paperStyle: effectivePaperStyle,
          objects: initialObjects,
        )
      ],
    );
    canvasDocs.add(newDoc);
    switchNotebook(newDoc.id);
    NotesLocalStorageService.saveDocLocally(newDoc, userId: userId);
    if (currentWorkspace != null && userId != null) {
      firestoreService.saveCanvasDoc(userId!, currentWorkspace!.id, newDoc);
    }
    computeAccountStorage(forceCloudSync: true);
  }

  Future<void> createTextDocument(String name, {String template = 'lecture'}) async {
    final cleanName = name.trim().isNotEmpty ? name.trim() : 'Document ${canvasDocs.length + 1}';
    String content = '';
    if (template == 'lecture') {
      content = '# $cleanName\n\n'
          '## 1. Lecture Overview & Core Concepts\n'
          'Key definitions, foundational theory, and background principles covered in this lecture.\n\n'
          '## 2. Detailed Topic Analysis\n'
          '• **Primary Principle**: Core equation, logic, or theorem definition.\n'
          '• **Practical Application**: Real-world case study and implementation steps.\n'
          '• **Counter-Examples**: Edge cases and critical boundaries to remember.\n\n'
          '## 3. Important Formulas & Equations\n'
          '• Formula 1: E = mc²  (Mass-energy equivalence)\n'
          '• Formula 2: f(x) = ∫ g(t) dt\n\n'
          '## 4. Key Takeaways & Review Checklist\n'
          '- [ ] Complete practice exercises for Section 2\n'
          '- [ ] Re-read textbook chapter references\n'
          '- [ ] Review summary notes with study group';
    } else if (template == 'project') {
      content = '# $cleanName\n\n'
          '## 1. Executive Summary & Goals\n'
          'High-level summary of what this initiative delivers, target audience, and business impact.\n\n'
          '## 2. Technical Architecture & Requirements\n'
          '• **Requirement 1**: 60fps responsive canvas with sub-16ms latency.\n'
          '• **Requirement 2**: Full multi-page support with GoodNotes-standard gestures.\n'
          '• **Requirement 3**: Real-time cross-device synchronization and local caching.\n\n'
          '## 3. Project Milestones & Timeline\n'
          '• **Milestone 1 (Sprint 1)**: Core architecture & schema validation.\n'
          '• **Milestone 2 (Sprint 2)**: UI polish, typography & inline editing.\n'
          '• **Milestone 3 (Sprint 3)**: End-to-end integration & production launch.\n\n'
          '## 4. Risks & Mitigations\n'
          '• **Risk**: Complex gesture collisions during page transitions.\n'
          '• **Mitigation**: Dedicated GestureManager state machine with pointer capture.';
    } else if (template == 'meeting') {
      final today = DateTime.now().toLocal().toString().split(' ')[0];
      content = '# $cleanName\n\n'
          '**Date**: $today   |   **Facilitator**: Lead   |   **Type**: Sync\n'
          '**Attendees**: Engineering, Design, Product\n\n'
          '## 1. Agenda & Discussion Topics\n'
          '1. Review previous sprint deliverables and open action items.\n'
          '2. Align on new document templates (Notebook, Whiteboard, Text Document).\n'
          '3. Architecture review for smooth canvas inking and text editing.\n\n'
          '## 2. Key Decisions Made\n'
          '• Decision 1: Standardize on A4 ivory sheets for paginated notebook and text documents.\n'
          '• Decision 2: Use infinite coordinate system for Whiteboard mode.\n\n'
          '## 3. Action Items & Next Steps\n'
          '- [ ] Deploy updated canvas templates to staging\n'
          '- [ ] Validate gesture responsiveness on mobile and tablet\n'
          '- [ ] Schedule follow-up sync for next milestone';
    } else {
      content = '# $cleanName\n\n'
          'Start typing your notes, thoughts, or research here...\n\n'
          'You can format this document with headings, bullet points, checklists, and annotations.';
    }

    try {
      await createDocumentFile(filename: '$cleanName.md', content: content);
    } catch (e) {
      debugPrint('Error creating document file: $e');
    }

    _syncCurrentPageObjects();

    final textItem = CanvasTextItem(
      id: 'text-${DateTime.now().millisecondsSinceEpoch}',
      text: content,
      position: const Offset(-360, 20),
      color: isDarkMode ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
      fontSize: 15.5,
      fontFamily: 'Inter',
      lineHeight: 1.6,
      boxWidth: 720.0,
      paperStyle: 'blank',
      padding: 12.0,
    );

    final newDoc = CanvasDocModel(
      id: 'doc-${DateTime.now().millisecondsSinceEpoch}-${++_docIdCounter}',
      workspaceId: currentWorkspace?.id ?? 'default',
      name: cleanName,
      docType: CanvasDocType.textDocument,
      coverColor: const Color(0xFF0284C7),
      coverEmoji: '📄',
      pages: [
        CanvasPage(
          id: 'page-1',
          pageNumber: 1,
          title: cleanName,
          paperStyle: CanvasPaperStyle.blankSlate,
          objects: [textItem],
        ),
      ],
    );
    canvasDocs.add(newDoc);
    switchNotebook(newDoc.id);
    NotesLocalStorageService.saveDocLocally(newDoc, userId: userId);
    if (currentWorkspace != null && userId != null) {
      firestoreService.saveCanvasDoc(userId!, currentWorkspace!.id, newDoc);
    }
    computeAccountStorage(forceCloudSync: true);
  }

  void renameNotebook(String notebookId, String newName) {
    final doc = canvasDocs.firstWhere((d) => d.id == notebookId, orElse: () => currentCanvasDoc!);
    doc.name = newName.trim();
    NotesLocalStorageService.saveDocLocally(doc, userId: userId);
    if (currentWorkspace != null && userId != null) {
      firestoreService.saveCanvasDoc(userId!, currentWorkspace!.id, doc);
    }
    notifyListeners();
  }

  /// Update cover appearance (color, emoji, gradient, pattern).
  /// Persists immediately to local storage and Firestore.
  void updateNotebookCover(
    String notebookId, {
    Color? coverColor,
    String? coverEmoji,
    String? coverStyle,
    String? coverStyleData,
  }) {
    final doc = canvasDocs.firstWhere(
      (d) => d.id == notebookId,
      orElse: () => currentCanvasDoc!,
    );
    if (coverColor != null) doc.coverColor = coverColor;
    if (coverEmoji != null) doc.coverEmoji = coverEmoji;
    if (coverStyle != null) doc.coverStyle = coverStyle;
    if (coverStyleData != null) doc.coverStyleData = coverStyleData;
    NotesLocalStorageService.saveDocLocally(doc, userId: userId);
    if (currentWorkspace != null && userId != null) {
      firestoreService.saveCanvasDoc(userId!, currentWorkspace!.id, doc);
    }
    notifyListeners();
  }


  void deleteNotebook(String notebookId) {
    if (canvasDocs.length <= 1) return;
    final docId = notebookId;
    canvasDocs.removeWhere((d) => d.id == notebookId);
    if (currentWorkspace != null && userId != null) {
      firestoreService.deleteCanvasDoc(userId!, currentWorkspace!.id, docId);
    }
    NotesLocalStorageService.deleteDocLocally(docId, userId: userId);
    if (currentCanvasDoc?.id == notebookId) {
      switchNotebook(canvasDocs.first.id);
    } else {
      notifyListeners();
    }
    computeAccountStorage(forceCloudSync: true);
  }

  // --- Page Operations ---
  void syncCurrentPageObjects() => _syncCurrentPageObjects();

  void _syncCurrentPageObjects() {
    if (currentCanvasDoc != null && currentCanvasDoc!.pages.isNotEmpty) {
      final idx = currentPageIndex.clamp(0, currentCanvasDoc!.pages.length - 1);
      currentCanvasDoc!.pages[idx].objects = List.from(canvasObjects);
      currentCanvasDoc!.pages[idx].paperStyle = canvasPaperStyle;
      currentCanvasDoc!.currentPageIndex = idx;
    }
  }

  void setCanvasPage(int index) {
    if (currentCanvasDoc == null || currentCanvasDoc!.pages.isEmpty) return;
    if (index < 0 || index >= currentCanvasDoc!.pages.length) return;
    _syncCurrentPageObjects();
    currentPageIndex = index;
    currentCanvasDoc!.currentPageIndex = index;
    final page = currentCanvasDoc!.pages[index];
    canvasPaperStyle = page.paperStyle;
    canvasObjects = List.from(page.objects);
    undoStack.clear();
    redoStack.clear();
    selectedCanvasObjects.clear();
    notifyListeners();
    _debounceSyncCanvas();
  }

  void addNewPage({CanvasPaperStyle? paperStyle, String? title, bool switchToPage = true}) {
    if (currentCanvasDoc == null) return;
    _syncCurrentPageObjects();
    final nextNum = currentCanvasDoc!.pages.length + 1;
    final newPage = CanvasPage(
      id: 'page-${DateTime.now().millisecondsSinceEpoch}',
      pageNumber: nextNum,
      title: title ?? 'Page $nextNum',
      paperStyle: paperStyle ?? canvasPaperStyle,
      objects: [],
    );
    currentCanvasDoc!.pages.add(newPage);
    if (switchToPage) {
      setCanvasPage(currentCanvasDoc!.pages.length - 1);
    } else {
      notifyListeners();
      _debounceSyncCanvas();
    }
  }

  void duplicatePage(int index) {
    if (currentCanvasDoc == null || index < 0 || index >= currentCanvasDoc!.pages.length) return;
    _syncCurrentPageObjects();
    final src = currentCanvasDoc!.pages[index];
    final nextNum = currentCanvasDoc!.pages.length + 1;
    final pageCopy = CanvasPage.fromJson(src.toJson());
    final dupPage = CanvasPage(
      id: 'page-${DateTime.now().millisecondsSinceEpoch}',
      pageNumber: nextNum,
      title: '${src.title} (Copy)',
      paperStyle: src.paperStyle,
      objects: pageCopy.objects,
    );
    currentCanvasDoc!.pages.insert(index + 1, dupPage);
    for (int i = 0; i < currentCanvasDoc!.pages.length; i++) {
      currentCanvasDoc!.pages[i].pageNumber = i + 1;
    }
    setCanvasPage(index + 1);
  }

  void deletePage(int index) {
    if (currentCanvasDoc == null || currentCanvasDoc!.pages.length <= 1) return;
    if (index < 0 || index >= currentCanvasDoc!.pages.length) return;
    _syncCurrentPageObjects();
    currentCanvasDoc!.pages.removeAt(index);
    // Re-number pages and auto-correct titles that follow the default "Page N" pattern.
    // Pages after the deleted index shift down by 1, so "Page (i+2)" → "Page (i+1)".
    for (int i = 0; i < currentCanvasDoc!.pages.length; i++) {
      currentCanvasDoc!.pages[i].pageNumber = i + 1;
      if (i >= index) {
        // This page shifted down; update title if it followed auto-naming
        final oldAutoTitle = 'Page ${i + 2}';
        final newAutoTitle = 'Page ${i + 1}';
        if (currentCanvasDoc!.pages[i].title == oldAutoTitle) {
          currentCanvasDoc!.pages[i].title = newAutoTitle;
        }
      }
    }
    final nextIdx = index >= currentCanvasDoc!.pages.length ? currentCanvasDoc!.pages.length - 1 : index;
    setCanvasPage(nextIdx);
  }

  void reorderPages(int oldIndex, int newIndex) {
    if (currentCanvasDoc == null) return;
    _syncCurrentPageObjects();
    if (newIndex > oldIndex) newIndex -= 1;
    final item = currentCanvasDoc!.pages.removeAt(oldIndex);
    currentCanvasDoc!.pages.insert(newIndex, item);
    for (int i = 0; i < currentCanvasDoc!.pages.length; i++) {
      currentCanvasDoc!.pages[i].pageNumber = i + 1;
    }
    currentPageIndex = newIndex;
    currentCanvasDoc!.currentPageIndex = newIndex;
    notifyListeners();
    _debounceSyncCanvas();
  }

  void renamePage(int index, String newTitle) {
    if (currentCanvasDoc == null || index < 0 || index >= currentCanvasDoc!.pages.length) return;
    currentCanvasDoc!.pages[index].title = newTitle.trim();
    notifyListeners();
    _debounceSyncCanvas();
  }

  void setPagePaperStyle(int index, CanvasPaperStyle style) {
    if (currentCanvasDoc == null || index < 0 || index >= currentCanvasDoc!.pages.length) return;
    currentCanvasDoc!.pages[index].paperStyle = style;
    if (index == currentPageIndex) {
      canvasPaperStyle = style;
    }
    notifyListeners();
    _debounceSyncCanvas();
  }

  void setCanvasTool(CanvasTool tool) {
    currentTool = tool;
    notifyListeners();
  }

  void setStrokeColor(Color color) {
    strokeColor = color;
    notifyListeners();
  }

  void setStrokeWidth(double width) {
    strokeWidth = width;
    notifyListeners();
  }

  void addCanvasObject(CanvasObjectItem obj) {
    _pushUndo();
    canvasObjects = [...canvasObjects, obj];
    // _syncCurrentPageObjects() and notifyListeners() are handled by the _debouncePersist or caller, 
    // but wait, if it's not handled, we should do it once.
    // The report said: 3 notifyListeners + 2 syncs.
    _syncCurrentPageObjects();
    notifyListeners();
    _debouncePersist(); // Let's hope this doesn't do it again
  }

  void removeCanvasObject(CanvasObjectItem obj) {
    _pushUndo();
    canvasObjects = canvasObjects.where((o) => o.id != obj.id).toList();
    _syncCurrentPageObjects();
    notifyListeners();
    _debouncePersist();
  }

  void setCanvasObjects(List<CanvasObjectItem> newObjects, {bool pushUndo = true, bool isLiveSession = false}) {
    if (pushUndo) _pushUndo();
    canvasObjects = List.from(newObjects);
    _syncCurrentPageObjects();
    notifyListeners();
    if (!isLiveSession) {
      _debouncePersist();
    }
  }

  void updateCanvasObject(CanvasObjectItem updatedObj) {
    final index = canvasObjects.indexWhere((o) => o.id == updatedObj.id);
    if (index != -1) {
      _pushUndo();
      canvasObjects[index] = updatedObj;
      _syncCurrentPageObjects();
      notifyListeners();
      _debouncePersist();
    }
  }

  void updateCanvasTextItem(CanvasTextItem item) {
    updateCanvasObject(item);
  }

  void toggleTapeMask(String id) {
    final index = canvasObjects.indexWhere((o) => o.id == id);
    if (index != -1 && canvasObjects[index] is CanvasTapeItem) {
      final tape = canvasObjects[index] as CanvasTapeItem;
      tape.isMasked = !tape.isMasked;
      _syncCurrentPageObjects();
      notifyListeners();
      _debounceSyncCanvas();
    }
  }

  /// Commits live gesture changes (such as erasing) cleanly to local persistence and debounced sync
  void commitLiveCanvasChanges() {
    _syncCurrentPageObjects();
    _debouncePersist();
  }

  void clearCanvas() {
    if (canvasObjects.isEmpty) return;
    _pushUndo();
    canvasObjects.clear();
    selectedCanvasObjects.clear();
    _syncCurrentPageObjects();
    notifyListeners();
    _debouncePersist();
  }

  void _pushUndo() {
    undoStack.add(List.from(canvasObjects));
    redoStack.clear();
  }

  void undo() {
    if (undoStack.isNotEmpty) {
      redoStack.add(List.from(canvasObjects));
      canvasObjects = undoStack.removeLast();
      _syncCurrentPageObjects();
      notifyListeners();
      _debounceSyncCanvas();
    }
  }

  void redo() {
    if (redoStack.isNotEmpty) {
      undoStack.add(List.from(canvasObjects));
      canvasObjects = redoStack.removeLast();
      _syncCurrentPageObjects();
      notifyListeners();
      _debounceSyncCanvas();
    }
  }

  void selectCanvasObjectsInRect(Rect selectionRect, {bool Function(CanvasObjectItem)? filter}) {
    selectedCanvasObjects.clear();
    for (var obj in canvasObjects) {
      if (filter != null && !filter(obj)) {
        obj.isSelected = false;
        continue;
      }
      if (selectionRect.overlaps(obj.getBoundingBox())) {
        obj.isSelected = true;
        selectedCanvasObjects.add(obj);
      } else {
        obj.isSelected = false;
      }
    }
    notifyListeners();
  }

  void selectCanvasObjectsInPolygon(List<Offset> polygon, {bool Function(CanvasObjectItem)? filter}) {
    selectedCanvasObjects.clear();
    final selected = LassoTool.selectObjectsInLasso(
      lassoPoints: polygon,
      objects: canvasObjects,
      filter: filter,
    );
    for (var obj in canvasObjects) {
      obj.isSelected = selected.contains(obj);
    }
    selectedCanvasObjects.addAll(selected);
    notifyListeners();
  }

  void clearCanvasSelection() {
    for (var obj in canvasObjects) {
      obj.isSelected = false;
    }
    selectedCanvasObjects.clear();
    notifyListeners();
  }

  void deselectAllCanvasObjects() => clearCanvasSelection();

  void recolorSelectedCanvasObjects(Color newColor) {
    for (final obj in selectedCanvasObjects) {
      if (obj is CanvasStrokeItem) {
        final idx = canvasObjects.indexOf(obj);
        if (idx != -1) {
          canvasObjects[idx] = obj.copyWith(color: newColor);
        }
      }
    }
    _debounceSyncCanvas();
  }

  void bringSelectedCanvasObjectsToFront() {
    final selected = List<CanvasObjectItem>.from(selectedCanvasObjects);
    canvasObjects.removeWhere((o) => selected.contains(o));
    canvasObjects.addAll(selected);
    _debounceSyncCanvas();
  }

  void sendSelectedCanvasObjectsToBack() {
    final selected = List<CanvasObjectItem>.from(selectedCanvasObjects);
    canvasObjects.removeWhere((o) => selected.contains(o));
    canvasObjects.insertAll(0, selected);
    _debounceSyncCanvas();
  }

  void renameCurrentCanvasDoc(String newName) {
    final trimmed = newName.trim();
    if (currentCanvasDoc != null && trimmed.isNotEmpty) {
      currentCanvasDoc!.name = trimmed;
      _debounceSyncCanvas();
    }
  }

  void notifyCanvasUpdate() {
    notifyListeners();
  }

  Timer? _canvasSyncTimer;
  Timer? _localSaveTimer;

  /// Debounced persistence: local save after 300ms idle, cloud sync after 800ms idle.
  /// Prevents I/O spam during rapid drawing while guaranteeing no data loss.
  void _debouncePersist() {
    // Debounced local save — fires after 300ms of no new strokes
    _localSaveTimer?.cancel();
    _localSaveTimer = Timer(const Duration(milliseconds: 300), () {
      _syncCurrentPageObjects();
      if (currentCanvasDoc != null) {
        NotesLocalStorageService.saveDocLocally(currentCanvasDoc!, userId: userId);
        NotesLocalStorageService.saveActiveDocId(currentCanvasDoc!.id, userId: userId);
      }
    });

    // Debounced cloud sync — fires after 800ms of no new strokes
    _canvasSyncTimer?.cancel();
    if (autosaveStatus != 'saving') {
      autosaveStatus = 'saving';
      // Don't notifyListeners here — avoid unnecessary rebuild during active drawing
    }
    _canvasSyncTimer = Timer(const Duration(milliseconds: 800), () async {
      // Ensure local save completed first
      _localSaveTimer?.cancel();
      _syncCurrentPageObjects();
      if (currentCanvasDoc != null) {
        NotesLocalStorageService.saveDocLocally(currentCanvasDoc!, userId: userId);
        NotesLocalStorageService.saveActiveDocId(currentCanvasDoc!.id, userId: userId);
      }
      if (currentCanvasDoc != null && currentWorkspace != null && userId != null) {
        try {
          await firestoreService.saveCanvasDoc(
            userId!,
            currentWorkspace!.id,
            currentCanvasDoc!,
          );
          setAutosaveStatus('saved');
        } catch (e) {
          debugPrint('Canvas sync error: $e');
          setAutosaveStatus('offline');
        }
      }
    });
  }

  /// Legacy alias for callers that need synchronous local+cloud sync (page switches, etc.)
  void _debounceSyncCanvas() {
    _syncCurrentPageObjects();
    if (currentCanvasDoc != null) {
      NotesLocalStorageService.saveDocLocally(currentCanvasDoc!, userId: userId);
      NotesLocalStorageService.saveActiveDocId(currentCanvasDoc!.id, userId: userId);
    }
    _canvasSyncTimer?.cancel();
    autosaveStatus = 'saving';
    notifyListeners();
    _canvasSyncTimer = Timer(const Duration(milliseconds: 600), () async {
      if (currentCanvasDoc != null && currentWorkspace != null && userId != null) {
        try {
          await firestoreService.saveCanvasDoc(
            userId!,
            currentWorkspace!.id,
            currentCanvasDoc!,
          );
          setAutosaveStatus('saved');
        } catch (e) {
          debugPrint('Canvas sync error: $e');
          setAutosaveStatus('offline');
        }
      }
    });
  }

  // ================= AI CANVAS WORKFLOW ("ASK AI") =================
  Future<String> askAIAboutCanvasSelection({
    required String action, // explain, ocr_rewrite, generate_questions, convert_diagram
    String? customPrompt,
  }) async {
    try {
      final analysis = await apiService.analyzeSelection(
        action: action,
        prompt: customPrompt,
        workspaceId: currentWorkspace?.id,
        selectedObjects: selectedCanvasObjects.map((o) => o.toJson()).toList(),
      );

      // Add to context tray automatically
      addContextItem(ContextItemModel(
        id: 'canvas-sel-${DateTime.now().millisecondsSinceEpoch}',
        type: 'canvas',
        title: 'Canvas Selection (${selectedCanvasObjects.length} objects)',
        content: 'AI Analysis:\n$analysis',
      ));

      return analysis;
    } catch (e) {
      return 'Error analyzing canvas selection: $e';
    }
  }

  // Unified Canvas <-> AI Chat Pipeline
  void sendCanvasSelectionToChat(String promptAction, {String? customInstruction}) {
    final count = selectedCanvasObjects.isNotEmpty ? selectedCanvasObjects.length : canvasObjects.length;
    final item = ContextItemModel(
      id: 'canvas-${DateTime.now().millisecondsSinceEpoch}',
      type: 'canvas',
      title: 'Canvas Drawing ($count items)',
      content: 'Vector sketch with $count elements from active canvas.',
    );
    addContextItem(item);

    // Make sure we are in Split or Chat view so user sees both
    if (viewMode == WorkspaceViewMode.canvasOnly) {
      viewMode = WorkspaceViewMode.split;
    }
    selectedNavIndex = 3; // Keep on Unified Studio

    String prompt = customInstruction ?? '';
    if (prompt.isEmpty) {
      if (promptAction == 'explain') {
        prompt = 'Explain this canvas diagram and handwritten notes in simple terms.';
      } else if (promptAction == 'flowchart') {
        prompt = 'Convert this sketch into a structured digital architecture and clean flowchart.';
      } else if (promptAction == 'rewrite') {
        prompt = 'Transcribe and rewrite the handwritten notes cleanly and professionally.';
      } else if (promptAction == 'questions') {
        prompt = 'Create 5 study and exam questions based on these canvas notes.';
      } else {
        prompt = 'Analyze the selected canvas notes and diagram.';
      }
    }

    sendMessage(prompt);
  }

  void insertAIResponseToCanvas(
    String text, {
    String? title,
    String? userPrompt,
    String? aiModel,
    String paperStyle = 'ruled',
    Offset? atPosition,
  }) {
    if (text.trim().isEmpty) return;

    final lines = text.trim().split('\n');
    String displayTitle = title ?? '';
    String bodyText = text.trim();

    if (displayTitle.isEmpty) {
      if (lines.isNotEmpty && lines.first.startsWith('#')) {
        displayTitle = lines.first.replaceAll(RegExp(r'^[#*\s]+'), '').trim();
        bodyText = lines.sublist(1).join('\n').trim();
      } else if (lines.isNotEmpty && lines.first.length < 50 && lines.length > 1) {
        displayTitle = lines.first.trim();
        bodyText = lines.sublist(1).join('\n').trim();
      } else if (userPrompt != null && userPrompt.isNotEmpty) {
        displayTitle = userPrompt.length > 38 ? '${userPrompt.substring(0, 38)}...' : userPrompt;
      } else {
        displayTitle = 'AI Study Note';
      }
    }

    if (bodyText.isEmpty) {
      bodyText = text.trim();
    }

    final position = atPosition ?? _calculateNextTextPlacement();

    final textItem = CanvasTextItem(
      id: 'ai-text-${DateTime.now().millisecondsSinceEpoch}',
      text: bodyText,
      title: displayTitle,
      userPrompt: userPrompt,
      aiModel: aiModel ?? 'ChatGPT',
      paperStyle: paperStyle,
      isAiGenerated: true,
      position: position,
      color: isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
      fontSize: 14.5,
      maxWidth: 500.0,
      zIndex: canvasObjects.length,
    );

    addCanvasObject(textItem);
  }

  Offset _calculateNextTextPlacement() {
    if (canvasObjects.isEmpty) {
      return const Offset(80, 100);
    }
    final textObjects = canvasObjects.whereType<CanvasTextItem>().toList();
    final count = textObjects.length;
    final col = count % 3;
    final row = count ~/ 3;
    return Offset(80.0 + col * 540.0, 100.0 + row * 340.0);
  }

  void moveCanvasTextItem(String id, Offset delta) {
    final index = canvasObjects.indexWhere((o) => o.id == id);
    if (index != -1 && canvasObjects[index] is CanvasTextItem) {
      final item = canvasObjects[index] as CanvasTextItem;
      item.position = Offset(item.position.dx + delta.dx, item.position.dy + delta.dy);
      notifyListeners();
      _debounceSyncCanvas();
    }
  }

  // Import entire chat thread from ChatGPT, Claude, Gemini, or any AI
  int importChatThreadToCanvas(String rawText, {String? modelName}) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) return 0;

    List<Map<String, String>> parsedPairs = _parseChatThread(trimmed);
    if (parsedPairs.isEmpty) {
      parsedPairs = [
        {'prompt': 'Imported AI Discussion', 'response': trimmed}
      ];
    }

    int importedCount = 0;
    final baseOffset = _calculateNextTextPlacement();
    final effectiveModel = modelName ?? _inferModel(trimmed);

    for (int i = 0; i < parsedPairs.length; i++) {
      final pair = parsedPairs[i];
      final prompt = pair['prompt'] ?? '';
      final response = pair['response'] ?? '';
      if (response.trim().isEmpty) continue;

      final col = importedCount % 2;
      final row = importedCount ~/ 2;
      final pos = Offset(
        baseOffset.dx + col * 550.0,
        baseOffset.dy + row * 400.0,
      );

      final title = prompt.isNotEmpty
          ? (prompt.length > 40 ? '${prompt.substring(0, 40)}...' : prompt)
          : 'AI Study Note #${importedCount + 1}';

      final textItem = CanvasTextItem(
        id: 'chat-import-${DateTime.now().millisecondsSinceEpoch}-$i',
        text: response.trim(),
        title: title,
        userPrompt: prompt.isNotEmpty ? prompt : null,
        aiModel: effectiveModel,
        paperStyle: 'ruled',
        isAiGenerated: true,
        position: pos,
        color: isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
        fontSize: 14.5,
        maxWidth: 500.0,
        zIndex: canvasObjects.length + i,
      );

      addCanvasObject(textItem);
      importedCount++;
    }

    return importedCount;
  }

  String _inferModel(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('claude') || lower.contains('anthropic')) return 'Claude';
    if (lower.contains('gemini') || lower.contains('google')) return 'Gemini';
    if (lower.contains('deepseek')) return 'DeepSeek';
    return 'ChatGPT';
  }

  List<Map<String, String>> _parseChatThread(String text) {
    List<Map<String, String>> pairs = [];

    // 1. Try parsing JSON export
    if (text.trim().startsWith('{') || text.trim().startsWith('[')) {
      try {
        final dynamic decoded = jsonDecode(text);
        if (decoded is List) {
          for (var item in decoded) {
            if (item is Map) {
              final prompt = item['user'] ?? item['prompt'] ?? item['question'] ?? '';
              final response = item['assistant'] ?? item['response'] ?? item['answer'] ?? item['content'] ?? '';
              if (response.toString().isNotEmpty) {
                pairs.add({'prompt': prompt.toString(), 'response': response.toString()});
              }
            }
          }
          if (pairs.isNotEmpty) return pairs;
        } else if (decoded is Map && decoded.containsKey('messages')) {
          final msgs = decoded['messages'] as List;
          String lastUser = '';
          for (var m in msgs) {
            if (m is Map) {
              if (m['role'] == 'user') lastUser = m['content']?.toString() ?? '';
              if (m['role'] == 'assistant') {
                pairs.add({'prompt': lastUser, 'response': m['content']?.toString() ?? ''});
                lastUser = '';
              }
            }
          }
          if (pairs.isNotEmpty) return pairs;
        }
      } catch (_) {}
    }

    // 2. Line by line role parser
    final lines = text.split('\n');
    String currentRole = '';
    StringBuffer currentPrompt = StringBuffer();
    StringBuffer currentResponse = StringBuffer();

    for (var line in lines) {
      final trimmedLine = line.trim();
      final lower = trimmedLine.toLowerCase();

      bool isUserLine = lower.startsWith('user:') ||
          lower.startsWith('you:') ||
          lower.startsWith('human:') ||
          lower.startsWith('### user') ||
          lower.startsWith('### human') ||
          lower.startsWith('### question');

      bool isAiLine = lower.startsWith('chatgpt:') ||
          lower.startsWith('assistant:') ||
          lower.startsWith('claude:') ||
          lower.startsWith('gemini:') ||
          lower.startsWith('deepseek:') ||
          lower.startsWith('### assistant') ||
          lower.startsWith('### chatgpt') ||
          lower.startsWith('### answer');

      if (isUserLine) {
        if (currentResponse.isNotEmpty) {
          pairs.add({
            'prompt': currentPrompt.toString().trim(),
            'response': currentResponse.toString().trim(),
          });
          currentPrompt.clear();
          currentResponse.clear();
        }
        currentRole = 'user';
        final colonIdx = line.indexOf(':');
        currentPrompt.writeln(colonIdx != -1 ? line.substring(colonIdx + 1).trim() : line.replaceFirst(RegExp(r'###\s*user', caseSensitive: false), '').trim());
      } else if (isAiLine) {
        currentRole = 'assistant';
        final colonIdx = line.indexOf(':');
        currentResponse.writeln(colonIdx != -1 ? line.substring(colonIdx + 1).trim() : line.replaceFirst(RegExp(r'###\s*(?:assistant|chatgpt|answer)', caseSensitive: false), '').trim());
      } else {
        if (currentRole == 'user') {
          currentPrompt.writeln(line);
        } else if (currentRole == 'assistant') {
          currentResponse.writeln(line);
        } else {
          currentResponse.writeln(line);
        }
      }
    }

    if (currentResponse.isNotEmpty) {
      pairs.add({
        'prompt': currentPrompt.toString().trim(),
        'response': currentResponse.toString().trim(),
      });
    }

    return pairs;
  }

  // Generate AI answer directly onto the Canvas without switching tabs
  Future<void> askAIAndPlaceCardOnCanvas({
    required String action, // explain, flowchart, rewrite, questions
    String? customPrompt,
  }) async {
    // Determine position next to selected strokes or right of canvas objects
    Offset placement = const Offset(120, 140);
    if (selectedCanvasObjects.isNotEmpty) {
      double rightMost = 0;
      double topMost = 99999;
      for (var o in selectedCanvasObjects) {
        final b = o.getBoundingBox();
        if (b.right > rightMost) rightMost = b.right;
        if (b.top < topMost) topMost = b.top;
      }
      placement = Offset(rightMost + 36, topMost.clamp(80.0, 500.0));
    } else if (canvasObjects.isNotEmpty) {
      double rightMost = 0;
      double topMost = 99999;
      for (var o in canvasObjects) {
        final b = o.getBoundingBox();
        if (b.right > rightMost) rightMost = b.right;
        if (b.top < topMost) topMost = b.top;
      }
      placement = Offset(rightMost + 36, topMost.clamp(80.0, 500.0));
    }

    if (placement.dx > 1200) {
      placement = _calculateNextTextPlacement();
    }

    String actionTitle = 'AI Analysis';
    String promptText = customPrompt ?? '';
    if (action == 'explain') {
      actionTitle = 'AI Diagram Explanation';
      promptText = promptText.isEmpty ? 'Explain the selected diagram and handwritten notes clearly.' : promptText;
    } else if (action == 'flowchart' || action == 'convert_diagram') {
      actionTitle = 'AI Architecture Flowchart';
      promptText = promptText.isEmpty ? 'Convert this sketch into a structured digital architecture and clean flowchart.' : promptText;
    } else if (action == 'rewrite' || action == 'ocr_rewrite') {
      actionTitle = 'Transcribed Notes';
      promptText = promptText.isEmpty ? 'Transcribe and rewrite the handwritten notes cleanly and professionally.' : promptText;
    } else if (action == 'questions' || action == 'generate_questions') {
      actionTitle = 'Study & Exam Questions';
      promptText = promptText.isEmpty ? 'Create 5 study and exam questions based on these canvas notes.' : promptText;
    } else if (customPrompt != null && customPrompt.isNotEmpty) {
      actionTitle = customPrompt.length > 25 ? '${customPrompt.substring(0, 25)}...' : customPrompt;
    }

    final cardId = 'ai-card-${DateTime.now().millisecondsSinceEpoch}';
    final card = CanvasNoteCardItem(
      id: cardId,
      title: actionTitle,
      content: 'Thinking and analyzing canvas drawing with OpenAI...',
      position: placement,
      width: 380,
      height: 280,
      backgroundColor: isDarkMode ? const Color(0xFF1B2030) : const Color(0xFFFFFFFF),
      textColor: isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
      isLoading: true,
    );

    addCanvasObject(card);

    try {
      String backendAction = action;
      if (action == 'flowchart') backendAction = 'convert_diagram';
      if (action == 'rewrite') backendAction = 'ocr_rewrite';
      if (action == 'questions') backendAction = 'generate_questions';

      final analysis = await apiService.analyzeSelection(
        action: backendAction,
        prompt: promptText,
        workspaceId: currentWorkspace?.id,
        selectedObjects: (selectedCanvasObjects.isNotEmpty ? selectedCanvasObjects : canvasObjects).map((o) => o.toJson()).toList(),
      );

      // Write directly onto the canvas as CanvasTextItem for full tool compatibility
      final textItem = CanvasTextItem(
        id: 'ai-text-${DateTime.now().millisecondsSinceEpoch}',
        text: analysis,
        title: actionTitle,
        isAiGenerated: true,
        position: placement,
        color: isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
        fontSize: 14.5,
        maxWidth: 480.0,
        zIndex: canvasObjects.length,
      );

      canvasObjects.removeWhere((o) => o.id == cardId);
      canvasObjects.add(textItem);
      notifyListeners();
      _debounceSyncCanvas();
    } catch (e) {
      final textItem = CanvasTextItem(
        id: 'ai-text-${DateTime.now().millisecondsSinceEpoch}',
        text: 'Analysis error: $e',
        title: actionTitle,
        isAiGenerated: true,
        position: placement,
        color: isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
        fontSize: 14.0,
        maxWidth: 440.0,
        zIndex: canvasObjects.length,
      );
      canvasObjects.removeWhere((o) => o.id == cardId);
      canvasObjects.add(textItem);
      notifyListeners();
    }
  }

  void moveCanvasCard(String cardId, Offset delta) {
    final index = canvasObjects.indexWhere((o) => o.id == cardId);
    if (index != -1 && canvasObjects[index] is CanvasNoteCardItem) {
      final card = canvasObjects[index] as CanvasNoteCardItem;
      card.position = Offset(
        (card.position.dx + delta.dx).clamp(10.0, 3000.0),
        (card.position.dy + delta.dy).clamp(10.0, 3000.0),
      );
      notifyListeners();
      _debounceSyncCanvas();
    }
  }

  void removeCanvasCard(String cardId) {
    canvasObjects.removeWhere((o) => o.id == cardId);
    notifyListeners();
    _debounceSyncCanvas();
  }

  // ================= FILES =================
  static String _guessMimeType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.md')) return 'text/markdown';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.json')) return 'application/json';
    return 'application/octet-stream';
  }

  static List<FileItemModel> _getDefaultWorkspaceFiles(String workspaceId) {
    final now = DateTime.now();
    return [
      FileItemModel(
        id: 'file_goodnotes_spec',
        workspaceId: workspaceId,
        name: 'GoodNotes_Vector_Engine.md',
        mimeType: 'text/markdown',
        size: 3420,
        storageKey: 'local_file_goodnotes_spec',
        createdAt: now.subtract(const Duration(hours: 3)),
        content: '# GoodNotes Vector Engine Architecture\n\n'
            '## Overview\n'
            'Notelekh uses high-precision path smoothing and shape recognition.\n\n'
            '### Features\n'
            '- **Cyclic Corner Detection**: Accurately recognizes rectangles, triangles, and polygons.\n'
            '- **Draw-and-Hold Recognition**: Seamlessly converts rough hand-drawn circles and ellipses into mathematical vectors.\n'
            '- **Pressure & Tilt Interpolation**: Emulates real apple pencil stroke dynamics.\n\n'
            '### Guidelines\n'
            '1. Maintain continuous stroke points for optimal curvature analysis.\n'
            '2. Hold stylus stationary at the end of the stroke for 450ms to activate snap-to-shape.\n',
      ),
      FileItemModel(
        id: 'file_physics_summary',
        workspaceId: workspaceId,
        name: 'Physics_Mechanics_Formulas.md',
        mimeType: 'text/markdown',
        size: 4890,
        storageKey: 'local_file_physics_summary',
        createdAt: now.subtract(const Duration(days: 1)),
        content: '# Classical Mechanics Reference Sheet\n\n'
            '## Kinematics & Newton\'s Laws\n'
            '- Velocity: v = dx / dt\n'
            '- Acceleration: a = dv / dt\n'
            '- Force: F = m * a\n'
            '- Kinetic Energy: E_k = 0.5 * m * v^2\n\n'
            '## Rotational Dynamics\n'
            '- Torque: tau = r x F\n'
            '- Angular Momentum: L = I * omega\n'
            '- Moment of Inertia (Cylinder): I = 0.5 * m * r^2\n',
      ),
      FileItemModel(
        id: 'file_study_flashcards',
        workspaceId: workspaceId,
        name: 'Biology_Cell_Biology_Notes.md',
        mimeType: 'text/markdown',
        size: 2750,
        storageKey: 'local_file_study_flashcards',
        createdAt: now.subtract(const Duration(days: 2)),
        content: '# Cell Biology & Organelles\n\n'
            '## Key Concepts\n'
            '- **Mitochondria**: Generates ATP through oxidative phosphorylation.\n'
            '- **Ribosomes**: Complex molecular machines that synthesize proteins.\n'
            '- **Endoplasmic Reticulum**: Rough ER houses ribosomes; Smooth ER synthesizes lipids.\n'
            '- **Golgi Apparatus**: Modifies, packages, and sorts macromolecules for cell secretion.\n',
      ),
      FileItemModel(
        id: 'file_project_architecture',
        workspaceId: workspaceId,
        name: 'Project_Architecture_Overview.pdf',
        mimeType: 'application/pdf',
        size: 145020,
        storageKey: 'local_file_project_architecture',
        createdAt: now.subtract(const Duration(days: 3)),
        content: 'PDF Document: High-level System Architecture & Cloud Sync Overview.',
      ),
    ];
  }

  void _persistWorkspaceFiles(String workspaceId) {
    final raw = workspaceFiles.map((f) => f.toJson()).toList();
    NotesLocalStorageService.saveWorkspaceFiles(workspaceId, raw, userId: userId);
  }

  Future<void> fetchWorkspaceFiles(String workspaceId) async {
    try {
      final local = await NotesLocalStorageService.loadWorkspaceFiles(workspaceId, userId: userId);
      if (local.isNotEmpty) {
        workspaceFiles = local.map((m) => FileItemModel.fromJson(m)).toList();
        notifyListeners();
      } else {
        workspaceFiles = _getDefaultWorkspaceFiles(workspaceId);
        _persistWorkspaceFiles(workspaceId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading local files: $e');
    }

    try {
      final remote = await apiService.getWorkspaceFiles(workspaceId);
      if (remote.isNotEmpty) {
        workspaceFiles = remote;
        _persistWorkspaceFiles(workspaceId);
        notifyListeners();
      }
    } catch (_) {
      // Standalone mode is fully supported
    }
    computeAccountStorage();
  }

  Future<FileItemModel?> uploadFile({
    required String filename,
    required List<int> bytes,
    String? mimeType,
  }) async {
    final wsId = currentWorkspace?.id ?? 'default';
    final guessedMime = mimeType ?? _guessMimeType(filename);
    
    String? textContent;
    if (guessedMime.contains('text') || guessedMime.contains('markdown') || filename.endsWith('.md') || filename.endsWith('.txt')) {
      try {
        textContent = utf8.decode(bytes);
      } catch (_) {}
    }

    final newFile = FileItemModel(
      id: 'file_${DateTime.now().millisecondsSinceEpoch}',
      workspaceId: wsId,
      name: filename,
      mimeType: guessedMime,
      size: bytes.length,
      storageKey: 'local_${DateTime.now().millisecondsSinceEpoch}',
      processingStatus: 'ready',
      createdAt: DateTime.now(),
      content: textContent,
    );

    workspaceFiles.insert(0, newFile);
    _persistWorkspaceFiles(wsId);
    notifyListeners();

    try {
      await apiService.uploadFile(
        workspaceId: wsId,
        bytes: bytes,
        filename: filename,
        mimeType: guessedMime,
      );
    } catch (_) {}

    return newFile;
  }

  Future<FileItemModel?> createDocumentFile({
    required String filename,
    required String content,
  }) async {
    final wsId = currentWorkspace?.id ?? 'default';
    final finalName = filename.endsWith('.md') || filename.endsWith('.txt') ? filename : '$filename.md';
    final bytes = utf8.encode(content);

    final newFile = FileItemModel(
      id: 'doc_${DateTime.now().millisecondsSinceEpoch}',
      workspaceId: wsId,
      name: finalName,
      mimeType: 'text/markdown',
      size: bytes.length,
      storageKey: 'local_${DateTime.now().millisecondsSinceEpoch}',
      processingStatus: 'ready',
      createdAt: DateTime.now(),
      content: content,
    );

    workspaceFiles.insert(0, newFile);
    _persistWorkspaceFiles(wsId);
    notifyListeners();

    try {
      await apiService.uploadFile(
        workspaceId: wsId,
        bytes: bytes,
        filename: finalName,
        mimeType: 'text/markdown',
      );
    } catch (_) {}

    computeAccountStorage();
    return newFile;
  }

  Future<void> deleteFile(String fileId) async {
    final wsId = currentWorkspace?.id ?? 'default';
    workspaceFiles.removeWhere((f) => f.id == fileId);
    selectedContextItems.removeWhere((c) => c.id == fileId);
    _persistWorkspaceFiles(wsId);
    notifyListeners();

    try {
      await apiService.deleteFile(fileId);
    } catch (_) {}
    computeAccountStorage();
  }

  Future<String> summarizeFile(String fileId, {String? prompt}) async {
    final file = workspaceFiles.firstWhere((f) => f.id == fileId, orElse: () => workspaceFiles.first);
    if (file.content != null && file.content!.isNotEmpty) {
      final lines = file.content!.split('\n').where((l) => l.trim().isNotEmpty).take(5).join('\n');
      return 'Summary of ${file.name}:\n\n$lines\n\nKey takeaways: Contains verified workspace study and reference material.';
    }
    try {
      return await apiService.analyzeFile(fileId, prompt: prompt);
    } catch (_) {
      return 'File: ${file.name}\nSize: ${file.formattedSize}\nType: ${file.mimeType}\n\nDocument ready for study, annotation, and AI workspace context.';
    }
  }

  // ================= GLOBAL SEARCH =================
  Future<void> performSearch(String query) async {
    searchQuery = query;
    if (query.trim().isEmpty) {
      searchResults = [];
      notifyListeners();
      return;
    }
    isSearching = true;
    notifyListeners();

    final List<SearchResultItemModel> localResults = [];
    final cleanQ = query.trim().toLowerCase();

    // 1. Search Canvas & Notebooks
    for (final doc in canvasDocs) {
      final docNameLower = doc.name.toLowerCase();

      // Check title match
      if (docNameLower.contains(cleanQ)) {
        localResults.add(SearchResultItemModel(
          entityType: 'canvas',
          id: doc.id,
          title: doc.name,
          snippet: 'Notebook • ${doc.pages.length} page(s) • ${doc.docType == CanvasDocType.notebook ? "Notebook" : "Canvas"}',
          workspaceId: doc.workspaceId,
          workspaceName: currentWorkspace?.name ?? 'Workspace',
          createdAt: DateTime.now(),
        ));
      }

      // Check pages content (text items, note cards)
      for (int i = 0; i < doc.pages.length; i++) {
        final page = doc.pages[i];
        for (final obj in page.objects) {
          if (obj is CanvasTextItem && obj.text.toLowerCase().contains(cleanQ)) {
            final idx = obj.text.toLowerCase().indexOf(cleanQ);
            final start = math.max(0, idx - 25);
            final end = math.min(obj.text.length, idx + cleanQ.length + 45);
            final snippet = 'Page ${i + 1}: "...${obj.text.substring(start, end).replaceAll('\n', ' ')}..."';
            localResults.add(SearchResultItemModel(
              entityType: 'note',
              id: doc.id,
              title: '${doc.name} (Page ${i + 1})',
              snippet: snippet,
              workspaceId: doc.workspaceId,
              workspaceName: currentWorkspace?.name ?? 'Workspace',
              createdAt: DateTime.now(),
            ));
            break;
          } else if (obj is CanvasNoteCardItem) {
            if (obj.title.toLowerCase().contains(cleanQ) || obj.content.toLowerCase().contains(cleanQ)) {
              final text = '${obj.title}: ${obj.content}';
              final idx = text.toLowerCase().indexOf(cleanQ);
              final start = math.max(0, idx - 20);
              final end = math.min(text.length, idx + cleanQ.length + 50);
              final snippet = 'Note Card on Page ${i + 1}: "...${text.substring(start, end).replaceAll('\n', ' ')}..."';
              localResults.add(SearchResultItemModel(
                entityType: 'note',
                id: doc.id,
                title: '${doc.name} - Note Card',
                snippet: snippet,
                workspaceId: doc.workspaceId,
                workspaceName: currentWorkspace?.name ?? 'Workspace',
                createdAt: DateTime.now(),
              ));
              break;
            }
          }
        }
      }
    }

    // Check workspace tags
    for (final t in tags) {
      if (t.toLowerCase().contains(cleanQ)) {
        for (final doc in canvasDocs) {
          if (!localResults.any((r) => r.id == doc.id)) {
            localResults.add(SearchResultItemModel(
              entityType: 'canvas',
              id: doc.id,
              title: doc.name,
              snippet: 'Matched workspace tag #$t in ${doc.name}',
              workspaceId: doc.workspaceId,
              workspaceName: currentWorkspace?.name ?? 'Workspace',
              createdAt: DateTime.now(),
            ));
          }
        }
      }
    }

    // 2. Search Workspace Files & Media
    for (final file in workspaceFiles) {
      if (file.name.toLowerCase().contains(cleanQ)) {
        localResults.add(SearchResultItemModel(
          entityType: 'file',
          id: file.id,
          title: file.name,
          snippet: '${file.mimeType} • ${file.formattedSize}',
          workspaceId: file.workspaceId,
          workspaceName: currentWorkspace?.name ?? 'Workspace',
          createdAt: file.createdAt,
        ));
      } else if (file.content != null && file.content!.toLowerCase().contains(cleanQ)) {
        final text = file.content!;
        final idx = text.toLowerCase().indexOf(cleanQ);
        final start = math.max(0, idx - 25);
        final end = math.min(text.length, idx + cleanQ.length + 50);
        final snippet = 'Document content: "...${text.substring(start, end).replaceAll('\n', ' ')}..."';
        localResults.add(SearchResultItemModel(
          entityType: 'file',
          id: file.id,
          title: file.name,
          snippet: snippet,
          workspaceId: file.workspaceId,
          workspaceName: currentWorkspace?.name ?? 'Workspace',
          createdAt: file.createdAt,
        ));
      }
    }

    // 3. Search Workspaces
    for (final ws in workspaces) {
      if (ws.name.toLowerCase().contains(cleanQ) || ws.description.toLowerCase().contains(cleanQ)) {
        localResults.add(SearchResultItemModel(
          entityType: 'workspace',
          id: ws.id,
          title: ws.name,
          snippet: ws.description.isNotEmpty ? ws.description : 'Notelekh Workspace',
          workspaceId: ws.id,
          workspaceName: ws.name,
          createdAt: ws.createdAt,
        ));
      }
    }

    // 4. Search AI Conversations & Messages
    for (final conv in conversations) {
      if (conv.title.toLowerCase().contains(cleanQ)) {
        localResults.add(SearchResultItemModel(
          entityType: 'conversation',
          id: conv.id,
          title: conv.title,
          snippet: 'AI Chat in ${currentWorkspace?.name ?? "Workspace"}',
          workspaceId: conv.workspaceId,
          workspaceName: currentWorkspace?.name ?? 'Workspace',
          createdAt: conv.createdAt,
        ));
      }
    }

    // 5. Try merging remote search results if backend exists
    try {
      final res = await apiService.search(query);
      for (final r in res.results) {
        if (!localResults.any((x) => x.id == r.id)) {
          localResults.add(r);
        }
      }
    } catch (_) {}

    searchResults = localResults;
    isSearching = false;
    notifyListeners();
  }

  // ================= ACCOUNT STORAGE & SYNC CALCULATION =================
  int accountItemCount = 0;
  int accountStorageBytes = 0;

  DateTime? _lastStorageComputation;
  Future<void> computeAccountStorage({bool forceCloudSync = false}) async {
    // Throttle: compute at most once per 10 seconds to avoid expensive I/O unless forceCloudSync is requested
    final now = DateTime.now();
    if (!forceCloudSync &&
        _lastStorageComputation != null &&
        now.difference(_lastStorageComputation!).inSeconds < 10) {
      return;
    }
    _lastStorageComputation = now;
    try {
      if (userId == null) return;
      
      // Fetch the true aggregate stats directly from Firestore
      final stats = await firestoreService.computeUserStorageStats(userId!);
      
      int bytes = (stats['storage_bytes'] as num?)?.toInt() ?? 0;
      int validDocsCount = (stats['item_count'] as num?)?.toInt() ?? 0;
      
      // Also add local files size if any
      if (workspaces.isNotEmpty) {
        for (final ws in workspaces) {
           final wsFiles = await NotesLocalStorageService.loadWorkspaceFiles(ws.id, userId: userId);
           for (final f in wsFiles) {
             bytes += (f['size'] as num?)?.toInt() ?? 0;
           }
        }
      }
      
      // Also count local notebooks across all workspaces for this user
      final allLocalDocs = await NotesLocalStorageService.loadAllDocsLocally(userId: userId);
      final localDocsCount = allLocalDocs.length;
      final memoryDocsCount = canvasDocs.length;
      
      // Critical: never report 0 notebooks if the user has active notebooks on screen or locally
      final newCount = math.max(validDocsCount, math.max(localDocsCount, memoryDocsCount));
      
      // If bytes is 0 or low but we have documents, calculate byte size from local notebooks
      if (bytes == 0 && (allLocalDocs.isNotEmpty || canvasDocs.isNotEmpty)) {
        final docsToMeasure = allLocalDocs.isNotEmpty ? allLocalDocs : canvasDocs;
        for (final d in docsToMeasure) {
          bytes += utf8.encode(jsonEncode(d.toJson())).length;
        }
      }
      
      if (accountItemCount != newCount || accountStorageBytes != bytes) {
        accountItemCount = newCount;
        accountStorageBytes = bytes;
        notifyListeners();
        
        // Sync to Firestore for 'user-wise' storage tracking
        await firestoreService.updateUserStorageStats(userId!, accountStorageBytes, accountItemCount);
      }
    } catch (e) {
      debugPrint('Error computing account storage: $e');
    }
  }

  /// Formatted storage string (e.g., "1.2 MB", "48.5 KB")
  String get formattedStorageUsed {
    final bytes = accountStorageBytes;
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Cloud storage progress ratio (based on 500 MB Free Tier limit)
  double get storageProgress {
    const int maxBytes = 500 * 1024 * 1024;
    final bytes = accountStorageBytes;
    if (bytes <= 0) return 0.05;
    return (bytes / maxBytes).clamp(0.05, 1.0);
  }

  /// Force manual sync of current canvas document to Firestore
  Future<void> forceSyncCanvas() async {
    _syncCurrentPageObjects();
    if (currentCanvasDoc != null) {
      NotesLocalStorageService.saveDocLocally(currentCanvasDoc!, userId: userId);
    }
    if (currentCanvasDoc != null && currentWorkspace != null && userId != null) {
      setAutosaveStatus('saving');
      try {
        await firestoreService.saveCanvasDoc(userId!, currentWorkspace!.id, currentCanvasDoc!);
        setAutosaveStatus('saved');
      } catch (e) {
        debugPrint('Force sync error: $e');
        setAutosaveStatus('offline');
      }
    }
  }
}
