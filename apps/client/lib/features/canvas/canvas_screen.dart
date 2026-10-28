import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_workspace_client/core/theme/app_theme.dart';
import 'package:ai_workspace_client/core/models/canvas_models.dart';
import 'package:ai_workspace_client/core/services/workspace_export_service.dart';
import 'package:ai_workspace_client/state/app_state.dart';
import 'package:ai_workspace_client/features/canvas/engine/stroke_engine.dart';
import 'package:ai_workspace_client/features/canvas/widgets/contextual_toolbar.dart';
import 'package:ai_workspace_client/features/canvas/tools/shape_tool.dart';
import 'package:ai_workspace_client/features/canvas/canvas_state.dart';
import 'package:ai_workspace_client/features/canvas/widgets/floating_secondary_toolbar.dart';
import 'package:ai_workspace_client/features/canvas/widgets/floating_pen_options_dialog.dart';
import 'package:ai_workspace_client/features/canvas/widgets/floating_lasso_options_dialog.dart';
import 'package:ai_workspace_client/features/canvas/tools/eraser_tool.dart';
import 'package:ai_workspace_client/features/canvas/engine/canvas_gesture_manager.dart';
import 'package:ai_workspace_client/features/canvas/engine/canvas_performance_profiler.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ai_workspace_client/features/canvas/widgets/floating_text_toolbar.dart';
import 'package:ai_workspace_client/features/canvas/widgets/elements_stickers_panel.dart';
import 'package:ai_workspace_client/features/canvas/widgets/canvas_toolbar.dart';
import 'package:ai_workspace_client/features/canvas/widgets/goodnotes_pdf_study_viewer.dart';

// ── GoodNotes Standard A4 Page Dimensions (World Space) ──────────────────────
const double _kPageWidth = 860.0;
const double _kPageHeight = 1200.0;
const double _kPageLeft = -430.0;
const double _kPageTop = -50.0;
const Rect _kPageRect = Rect.fromLTWH(
  _kPageLeft,
  _kPageTop,
  _kPageWidth,
  _kPageHeight,
);

class CanvasScreen extends StatefulWidget {
  final AppState state;

  const CanvasScreen({super.key, required this.state});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen>
    with TickerProviderStateMixin {
  List<StrokePoint> _currentStrokePoints = [];
  Offset? _dragStart;
  Offset? _dragCurrent;
  String? _draggedTextItemId;
  String? _draggedObjectId;
  Offset? _lastDragWorldPos;

  // Freeform lasso points
  final List<Offset> _lassoPoints = [];
  bool _isLassoing = false;

  // GoodNotes Single-Page Slide Transition
  late AnimationController _slideAnimCtrl;
  late Animation<double> _slideAnim;
  bool _isTransitioning = false;
  int? _transitionFromPageIndex;
  int? _transitionToPageIndex;
  double _slideDirection =
      -1.0; // -1.0: next page (slide left), 1.0: prev page (slide right)

  // Infinite Viewport Transform State
  Offset _panOffset = Offset.zero;
  double _zoomScale = 1.0;
  bool _isPanning = false;
  bool _spacePressed = false;
  final FocusNode _canvasFocusNode = FocusNode();

  // Inline text editing (GoodNotes-style: type directly on canvas)
  bool _isInlineTextEditing = false;
  Offset _inlineTextScreenPos = Offset.zero;
  final TextEditingController _inlineTextCtrl = TextEditingController();
  final FocusNode _inlineTextFocusNode = FocusNode();
  String? _editingExistingTextId;
  String? _selectedTextItemId;
  bool _showTextFormatToolbar = false;
  int _lastTextTapTimestamp = 0;
  String? _lastTappedTextId;
  bool _isResizingTextWidth = false;
  String? _resizingTextItemId;
  bool _resizeFromLeft = false;

  // Study Tape drawing state
  bool _isDrawingTape = false;
  Offset? _tapeStartWorld;
  Offset? _tapeCurrentWorld;

  // Elements & Stickers panel state
  bool _showElementsPanel = false;

  // In-memory image decode cache
  static final Map<String, ui.Image> _decodedImagesCache = {};
  static final Set<String> _loadingImages = {};

  // Image selection and resize state
  String? _selectedImageId;
  bool _isResizingImage = false;
  String? _resizingImageCorner; // 'tl', 'tr', 'bl', 'br'
  Rect? _resizingImageInitialBounds;
  double _resizingImageInitialAspect = 1.0;

  CanvasImageItem? _getSelectedImageItem() {
    if (_selectedImageId == null) return null;
    for (final o in widget.state.canvasObjects) {
      if (o.id == _selectedImageId && o is CanvasImageItem) {
        return o;
      }
    }
    return null;
  }

  CanvasTextItem? _getSelectedTextItem() {
    if (_selectedTextItemId == null) return null;
    for (final o in widget.state.canvasObjects) {
      if (o.id == _selectedTextItemId && o is CanvasTextItem) {
        return o;
      }
    }
    return null;
  }

  bool _pageViewCentered = false;
  Size? _canvasSize; // actual canvas drawing area, set by LayoutBuilder
  int _lastKnownPageIndex = 0;
  String? _lastKnownDocId;
  bool _lastKnownPageViewMode = true;

  // Isolated Goodnotes Drawing State
  late final CanvasDrawingState _drawingState;
  final List<List<_LaserPoint>> _laserStrokes = [];
  Offset? _activeLaserPoint;
  double _laserDotAlpha = 1.0;
  double _laserMasterFade = 1.0;
  Timer? _laserDotFadeTimer;
  Timer? _laserHoldTimer;
  Timer? _laserFadeTimer;
  Timer? _laserMaxAgeTimer;
  static const double _laserMaxStrokeAgeMs = 12000.0;
  bool _showPenOptionsDialog = false;
  bool _showLassoOptionsDialog = false;
  bool _isDrawing = false;
  // Ink configuration is captured on PointerDown. Toolbar changes affect the
  // next stroke only, never an already-owned Pencil pointer.
  CanvasTool _activeStrokeTool = CanvasTool.pen;
  Color _activeStrokeColor = const Color(0xFFE11D48);
  double _activeStrokeWidth = 3.0;
  double _activeStrokeOpacity = 1.0;
  PenType _activeStrokePenType = PenType.ballpoint;
  PressureSensitivity _activeStrokeSensitivity = PressureSensitivity.medium;
  double _activeStrokeTipSharpness = 0.75;
  double _activeStrokeTipFlatness = 0.66;
  bool _isErasingActive = false;
  bool _hasErasedInCurrentGesture = false;
  Offset? _lastEraseWorldPos;
  Offset? _lastHoverScreenPos;
  final ValueNotifier<Offset?> _eraserCursorPosNotifier =
      ValueNotifier<Offset?>(null);
  final ValueNotifier<bool> _isErasingActiveNotifier = ValueNotifier<bool>(
    false,
  );

  double get _effectiveEraserWorldRadius {
    final presets = _drawingState.eraserWidthPresets;
    final idx = _drawingState.selectedEraserPresetIndex;
    final preset = (presets.isNotEmpty && idx >= 0 && idx < presets.length)
        ? presets[idx]
        : 24.0;
    return (preset / _zoomScale).clamp(2.0, 200.0);
  }

  double get _effectiveEraserScreenRadius =>
      _effectiveEraserWorldRadius * _zoomScale;
  Offset? _lastPointerMovePos;

  // P1 & P2 Features: Diagnostic HUD, Page Drawer, Lasso Drag
  bool _showDiagnosticHud = false;
  PointerTelemetry? _latestTelemetry;
  bool _showPageThumbnailsDrawer = false;
  bool _isDraggingSelection = false;
  Offset? _lastSelectionDragPos;

  late final CanvasGestureManager _gestureManager;
  final ValueNotifier<Offset?> _stylusHoverPosNotifier = ValueNotifier<Offset?>(
    null,
  );

  // GoodNotes PDF Study Reader & Document Overlay
  bool _isPdfStudyReaderOpen = false;
  PdfDocumentData? _activePdfStudyDoc;
  // ── Right-to-Left Swipe & Pull-to-Add-Page (GoodNotes style) ───────────────
  double _horizontalPullDistance = 0.0;
  double _sheetDragOffset = 0.0;
  bool _isSwipeGestureActive = false;
  Offset? _horizontalSwipeStartPos;
  int? _horizontalSwipePointerId;
  String? _pageSwipeFeedbackText;
  Timer? _pageSwipeFeedbackTimer;
  late final AnimationController _springBackCtrl;
  late Animation<double> _springBackAnim;
  bool _isHoldingToAddPage = false;
  late final AnimationController _addPageHoldCtrl;

  // ── GoodNotes Draw-and-Hold Shape Recognition & Realtime Manipulation ─────
  Timer? _drawAndHoldTimer;
  bool _drawAndHoldRecognitionAttempted = false;
  bool _isHoldingSnappedShape = false;
  CanvasShapeItem? _holdingSnappedShape;
  Offset? _holdingShapeAnchor;
  Offset? _holdStationaryAnchor;
  Rect? _snappedInitialBounds;

  void _startDrawAndHoldTimer() {
    _cancelDrawAndHoldTimer();
    final tool = widget.state.currentTool;
    final isShapeTool =
        tool == CanvasTool.rectangle ||
        tool == CanvasTool.circle ||
        tool == CanvasTool.triangle ||
        tool == CanvasTool.line ||
        tool == CanvasTool.arrow;
    if (!_drawingState.drawAndHold && !isShapeTool) return;
    _drawAndHoldRecognitionAttempted = false;
    _drawAndHoldTimer = Timer(const Duration(milliseconds: 580), () {
      if (!_isDrawing) return;
      _onDrawAndHoldFired();
    });
  }

  void _cancelDrawAndHoldTimer() {
    _drawAndHoldTimer?.cancel();
    _drawAndHoldTimer = null;
    _drawAndHoldRecognitionAttempted = false;
  }

  Offset _snapLineAngle(Offset start, Offset current) {
    final delta = current - start;
    final dist = delta.distance;
    if (dist < 12.0) return current;

    final angle = math.atan2(delta.dy, delta.dx); // radians -pi to pi
    final degrees = angle * 180.0 / math.pi;

    // GoodNotes ruler snap angles: horizontal (0, 180), vertical (90, -90), and 45-degree diagonals
    const snapAngles = [
      0.0,
      45.0,
      90.0,
      135.0,
      180.0,
      -45.0,
      -90.0,
      -135.0,
      -180.0,
    ];
    const snapThreshold = 4.5; // degrees

    for (final target in snapAngles) {
      final diff = (degrees - target).abs();
      final altDiff = (degrees.abs() - 180.0).abs();
      if (diff < snapThreshold ||
          (altDiff < snapThreshold && target.abs() == 180.0)) {
        final rad = target * math.pi / 180.0;
        return start + Offset(dist * math.cos(rad), dist * math.sin(rad));
      }
    }
    return current;
  }

  void _onDrawAndHoldFired() {
    if (_drawAndHoldRecognitionAttempted) return;
    _cancelDrawAndHoldTimer();
    _drawAndHoldRecognitionAttempted = true;
    if (!_isDrawing || _currentStrokePoints.length < 5) return;
    if (!_drawingState.drawAndHold &&
        widget.state.currentTool != CanvasTool.rectangle &&
        widget.state.currentTool != CanvasTool.circle &&
        widget.state.currentTool != CanvasTool.triangle &&
        widget.state.currentTool != CanvasTool.line &&
        widget.state.currentTool != CanvasTool.arrow) {
      return;
    }

    // Verify the pen was actually held stationary when the timer fired.
    // If user was actively handwriting or moving, the recent points will have
    // significant dispersion or be far from the stationary anchor.
    if (_currentStrokePoints.length >= 4) {
      final lastPos = _currentStrokePoints.last.toOffset();
      if (_holdStationaryAnchor != null &&
          (lastPos - _holdStationaryAnchor!).distance > 12.0) {
        return; // Pen moved away from hold anchor; user is still drawing
      }
      final recentPoints = _currentStrokePoints.length > 8
          ? _currentStrokePoints.sublist(_currentStrokePoints.length - 8)
          : _currentStrokePoints;
      final maxRecentDisp = recentPoints.fold<double>(
        0.0,
        (maxD, p) => math.max(maxD, (p.toOffset() - lastPos).distance),
      );
      if (maxRecentDisp > 12.0) {
        return; // Pen was actively moving when timer expired
      }
    }

    final isHighlighter = widget.state.currentTool == CanvasTool.highlighter;
    final processedPoints = StrokeEngine.injectVelocity(_currentStrokePoints);

    if (!isHighlighter) {
      final recognized = ShapeTool.recognizeShape(
        id: 'shape-${DateTime.now().microsecondsSinceEpoch}',
        points: processedPoints,
        strokeColor: widget.state.strokeColor,
        strokeWidth: widget.state.strokeWidth,
      );
      if (recognized != null) {
        _isHoldingSnappedShape = true;
        _holdingSnappedShape = recognized;
        _snappedInitialBounds = recognized.bounds;
        _holdStationaryAnchor = _currentStrokePoints.isNotEmpty
            ? _currentStrokePoints.last.toOffset()
            : recognized.bounds.center;

        if (recognized.shapeType == 'line' || recognized.shapeType == 'arrow') {
          _holdingShapeAnchor =
              recognized.startPoint ?? recognized.bounds.topLeft;
        } else {
          _holdingShapeAnchor = recognized.bounds.center;
        }
        _drawingState.liveShapeNotifier.value = recognized;
        _drawingState.liveStrokeNotifier.clear();
        try {
          HapticFeedback.selectionClick();
        } catch (_) {}
        return;
      }
    } else {
      // Highlighter straight line snap on hold
      if (processedPoints.length >= 4) {
        final start = processedPoints.first.toOffset();
        final end = processedPoints.last.toOffset();
        final totalDist = (end - start).distance;
        if (totalDist >= 50.0) {
          double pathLen = 0.0;
          for (int i = 0; i < processedPoints.length - 1; i++) {
            pathLen +=
                (processedPoints[i + 1].toOffset() - processedPoints[i].toOffset())
                    .distance;
          }
          final isStraight = pathLen > 0 && (totalDist / pathLen) > 0.88;
          if (isStraight) {
            final lineShape = CanvasShapeItem(
              id: 'highlighter-line-${DateTime.now().microsecondsSinceEpoch}',
              shapeType: 'line',
              bounds: Rect.fromPoints(start, end),
              strokeColor: widget.state.strokeColor.withValues(
                alpha: (widget.state.strokeOpacity * 0.45).clamp(0.1, 0.45),
              ),
              strokeWidth: widget.state.strokeWidth * 2.5,
              startPoint: start,
              endPoint: end,
            );
            _isHoldingSnappedShape = true;
            _holdingSnappedShape = lineShape;
            _snappedInitialBounds = lineShape.bounds;
            _holdingShapeAnchor = start;
            _holdStationaryAnchor = end;
            _drawingState.liveShapeNotifier.value = lineShape;
            _drawingState.liveStrokeNotifier.clear();
            try {
              HapticFeedback.selectionClick();
            } catch (_) {}
            return;
          }
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _lastKnownPageIndex = widget.state.currentPageIndex;
    _lastKnownDocId = widget.state.currentCanvasDoc?.id;
    _lastKnownPageViewMode = widget.state.isPageViewMode;
    _drawingState = CanvasDrawingState();
    _drawingState.setTool(widget.state.currentTool);
    _drawingState.setColor(widget.state.strokeColor);
    _drawingState.setStrokeWidth(widget.state.strokeWidth);
    _drawingState.setStrokeOpacity(widget.state.strokeOpacity);
    _drawingState.setPenType(widget.state.currentPenType);
    _drawingState.setPressureSensitivity(widget.state.pressureSensitivity);
    _initGestureManager();

    _slideAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slideAnim = CurvedAnimation(
      parent: _slideAnimCtrl,
      curve: Curves.easeInOutCubic,
    );
    _slideAnimCtrl.addListener(() {
      setState(() {});
    });
    _slideAnimCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_transitionToPageIndex != null) {
          widget.state.setCanvasPage(_transitionToPageIndex!);
        }
        setState(() {
          _isTransitioning = false;
          _transitionFromPageIndex = null;
          _transitionToPageIndex = null;
          _sheetDragOffset = 0.0;
          _horizontalPullDistance = 0.0;
          _slideAnimCtrl.reset();
        });
      }
    });

    _springBackCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _springBackAnim = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(_springBackCtrl);
    _springBackCtrl.addListener(() {
      setState(() {
        _sheetDragOffset = _springBackAnim.value;
        _horizontalPullDistance = _sheetDragOffset.abs();
      });
    });

    _addPageHoldCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _addPageHoldCtrl.addListener(() {
      setState(() {});
    });
    _addPageHoldCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_isHoldingToAddPage) {
          HapticFeedback.mediumImpact();
          _isHoldingToAddPage = false;
          _horizontalSwipeStartPos = null;
          _horizontalSwipePointerId = null;
          _isSwipeGestureActive = false;
          _addPageHoldCtrl.reset();
          _triggerAddPageFromSwipe();
        }
      }
    });

    _drawingState.addListener(() {
      if (widget.state.currentTool != _drawingState.currentTool) {
        widget.state.setCanvasTool(_drawingState.currentTool);
      }
      if (widget.state.strokeColor != _drawingState.strokeColor) {
        widget.state.setStrokeColor(_drawingState.strokeColor);
      }
      if (widget.state.strokeWidth != _drawingState.strokeWidth) {
        widget.state.setStrokeWidth(_drawingState.strokeWidth);
      }
      if (widget.state.strokeOpacity != _drawingState.strokeOpacity) {
        widget.state.setStrokeOpacity(_drawingState.strokeOpacity);
      }
      if (widget.state.currentPenType != _drawingState.currentPenType) {
        widget.state.setPenType(_drawingState.currentPenType);
      }
      if (widget.state.pressureSensitivity !=
          _drawingState.pressureSensitivity) {
        widget.state.setPressureSensitivity(_drawingState.pressureSensitivity);
      }
      _gestureManager.fingerDrawingEnabled = _drawingState.fingerDrawingEnabled;
      _gestureManager.setStabilization(_drawingState.strokeStabilization);
      if (_drawingState.currentTool != CanvasTool.eraser &&
          _eraserCursorPosNotifier.value != null) {
        _eraserCursorPosNotifier.value = null;
        _isErasingActiveNotifier.value = false;
      }
      setState(() {});
    });

    widget.state.addListener(_onAppStateChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.state.isPageViewMode && !_pageViewCentered) {
        _centerPageInView();
      }
    });
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    if (_isTransitioning) return;

    // ── Performance Guard ──────────────────────────────────────────────────
    // Skip a full setState during active drawing. The live stroke layer is
    // driven by its own ValueNotifier (_drawingState.liveStrokeNotifier) and
    // never needs a widget rebuild while the pen is down. Without this guard,
    // every stroke commit (notifyListeners) rebuilds the entire CanvasScreen.
    if (_isDrawing) return;
    // ──────────────────────────────────────────────────────────────────────

    final docChanged = widget.state.currentCanvasDoc?.id != _lastKnownDocId;
    final modeChanged = widget.state.isPageViewMode != _lastKnownPageViewMode;
    final pageChanged = widget.state.currentPageIndex != _lastKnownPageIndex;

    if (docChanged || modeChanged || pageChanged) {
      _lastKnownDocId = widget.state.currentCanvasDoc?.id;
      _lastKnownPageViewMode = widget.state.isPageViewMode;
      _lastKnownPageIndex = widget.state.currentPageIndex;
      if (widget.state.isPageViewMode) {
        _pageViewCentered = false;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _centerPageInView(),
        );
      }
    }

    // Bidirectional sync from AppState to _drawingState
    if (_drawingState.currentTool != widget.state.currentTool) {
      _drawingState.setTool(widget.state.currentTool);
    }
    if (_drawingState.strokeColor != widget.state.strokeColor) {
      _drawingState.setColor(widget.state.strokeColor);
    }
    if (_drawingState.strokeWidth != widget.state.strokeWidth) {
      _drawingState.setStrokeWidth(widget.state.strokeWidth);
    }
    if (_drawingState.strokeOpacity != widget.state.strokeOpacity) {
      _drawingState.setStrokeOpacity(widget.state.strokeOpacity);
    }
    if (_drawingState.currentPenType != widget.state.currentPenType) {
      _drawingState.setPenType(widget.state.currentPenType);
    }
    if (_drawingState.pressureSensitivity !=
        widget.state.pressureSensitivity) {
      _drawingState.setPressureSensitivity(widget.state.pressureSensitivity);
    }

    setState(() {});
  }

  void _initGestureManager() {
    _gestureManager = CanvasGestureManager(
      screenToWorld: _screenToWorld,
      fingerDrawingEnabled: _drawingState.fingerDrawingEnabled,
    );
    _gestureManager.enableTelemetry = _showDiagnosticHud;
    CanvasPerformanceProfiler.instance.isEnabled = _showDiagnosticHud;
    _gestureManager.setStabilization(_drawingState.strokeStabilization);

    _gestureManager.onStrokeStart = (point, isStylus) {
      if (widget.state.isPageViewMode) {
        final clampedX = point.x.clamp(_kPageLeft, _kPageLeft + _kPageWidth);
        final clampedY = point.y.clamp(_kPageTop, _kPageTop + _kPageHeight);
        point = point.copyWith(x: clampedX, y: clampedY);
      }
      _isDrawing = true;
      _activeStrokeTool = widget.state.currentTool;
      _activeStrokeColor = widget.state.strokeColor;
      _activeStrokeWidth = widget.state.strokeWidth;
      _activeStrokeOpacity = widget.state.strokeOpacity;
      _activeStrokePenType = _drawingState.currentPenType;
      _activeStrokeSensitivity = _drawingState.pressureSensitivity;
      _activeStrokeTipSharpness = _drawingState.tipSharpness;
      _activeStrokeTipFlatness = _drawingState.tipFlatness;
      _lastPointerMovePos = Offset(point.x, point.y);
      _currentStrokePoints = [point];
      _drawingState.liveStrokeNotifier.start(point);
      _cancelDrawAndHoldTimer();
      _isHoldingSnappedShape = false;
      _holdingSnappedShape = null;
      _holdingShapeAnchor = null;
      _snappedInitialBounds = null;
      _holdStationaryAnchor = Offset(point.x, point.y);
      _drawingState.liveShapeNotifier.value = null;
      _startDrawAndHoldTimer();
    };

    _gestureManager.onStrokeUpdate = (point) {
      if (!_isDrawing) return;
      if (widget.state.isPageViewMode) {
        final clampedX = point.x.clamp(_kPageLeft, _kPageLeft + _kPageWidth);
        final clampedY = point.y.clamp(_kPageTop, _kPageTop + _kPageHeight);
        point = point.copyWith(x: clampedX, y: clampedY);
      }

      // If shape has already snapped via Draw-and-Hold, adjust position & angle interactively (GoodNotes style)
      if (_isHoldingSnappedShape && _holdingSnappedShape != null) {
        final currentPos = Offset(point.x, point.y);
        final shapeType = _holdingSnappedShape!.shapeType;

        if (shapeType == 'line' || shapeType == 'arrow') {
          final anchor =
              _holdingShapeAnchor ??
              _holdingSnappedShape!.startPoint ??
              _holdingSnappedShape!.bounds.topLeft;
          final snappedPos = _snapLineAngle(anchor, currentPos);
          _holdingSnappedShape = _holdingSnappedShape!.copyWith(
            bounds: Rect.fromPoints(anchor, snappedPos),
            startPoint: anchor,
            endPoint: snappedPos,
          );
        } else if (_snappedInitialBounds != null) {
          // Closed shapes (Rectangle, Square, Circle, Triangle):
          // Maintain the perfect recognized shape and scale smoothly from center if dragged
          final center = _snappedInitialBounds!.center;
          final v0 = (_holdStationaryAnchor != null)
              ? (_holdStationaryAnchor! - center)
              : Offset.zero;
          final v1 = currentPos - center;
          final initialDist = v0.distance;
          final currentDist = v1.distance;

          if (initialDist > 12.0 &&
              (currentPos - (_holdStationaryAnchor ?? currentPos)).distance >
                  6.0) {
            final scale = (currentDist / initialDist).clamp(0.2, 5.0);
            final newWidth = math.max(
              16.0,
              _snappedInitialBounds!.width * scale,
            );
            final newHeight = math.max(
              16.0,
              _snappedInitialBounds!.height * scale,
            );
            final newBounds = Rect.fromCenter(
              center: center,
              width: newWidth,
              height: newHeight,
            );
            _holdingSnappedShape = _holdingSnappedShape!.copyWith(
              bounds: newBounds,
            );
          }
        }
        _drawingState.liveShapeNotifier.value = _holdingSnappedShape;
        return;
      }

      // Raw input is lossless: every browser-delivered sample belongs to the
      // committed stroke, including samples with sub-pixel movement.
      _currentStrokePoints.add(point);
      // Zero-allocation live stroke append — enables 240Hz fast iPad handwriting without GC pauses
      _drawingState.liveStrokeNotifier.add(point);

      // Draw-and-hold timer management:
      // While the user is actively writing or drawing, their pen is continuously moving.
      // Reset the hold timer whenever movement exceeds the stationary jitter threshold (8px).
      // This guarantees the timer NEVER triggers in the middle of active handwriting!
      final currentPos = Offset(point.x, point.y);
      if (_holdStationaryAnchor != null) {
        final dist = (currentPos - _holdStationaryAnchor!).distance;
        if (dist > 8.0) {
          _holdStationaryAnchor = currentPos;
          _startDrawAndHoldTimer();
        }
      } else {
        _holdStationaryAnchor = currentPos;
        _startDrawAndHoldTimer();
      }
    };

    _gestureManager.onStrokeEnd = (point) {
      _cancelDrawAndHoldTimer();
      if (!_isDrawing &&
          _currentStrokePoints.isEmpty &&
          !_isHoldingSnappedShape) {
        return;
      }
      if (widget.state.isPageViewMode) {
        final clampedX = point.x.clamp(_kPageLeft, _kPageLeft + _kPageWidth);
        final clampedY = point.y.clamp(_kPageTop, _kPageTop + _kPageHeight);
        point = point.copyWith(x: clampedX, y: clampedY);
      }
      if (!_isHoldingSnappedShape) {
        _currentStrokePoints.add(point);
      }
      _isDrawing = false;
      // CRITICAL: commit (addCanvasObject → notifyListeners) FIRST so the
      // historical painter layer already contains the stroke before the live
      // layer is cleared. Clearing live before commit creates a visibility
      // gap where neither layer shows the stroke, causing it to disappear.
      _commitCurrentStroke();
      // Live stroke cleared AFTER the committed object is in AppState and
      // the historical layer has been notified. Zero-gap transition.
      _drawingState.liveStrokeNotifier.clear();
    };

    _gestureManager.onStrokeCancel = ({bool discard = false}) {
      _cancelDrawAndHoldTimer();
      if (_isHoldingSnappedShape && _holdingSnappedShape != null) {
        if (!discard) {
          widget.state.addCanvasObject(_holdingSnappedShape!);
        }
        _isHoldingSnappedShape = false;
        _holdingSnappedShape = null;
        _holdingShapeAnchor = null;
        _snappedInitialBounds = null;
        _drawingState.liveShapeNotifier.value = null;
        _drawingState.liveStrokeNotifier.clear();
      } else if (_currentStrokePoints.isNotEmpty) {
        if (discard || _currentStrokePoints.length <= 1) {
          _currentStrokePoints.clear();
          _drawingState.liveStrokeNotifier.clear();
        } else {
          // Commit FIRST (historical layer updated), THEN clear live layer.
          // Same zero-gap ordering as onStrokeEnd.
          _commitCurrentStroke();
          _drawingState.liveStrokeNotifier.clear();
        }
      } else {
        _drawingState.liveStrokeNotifier.clear();
        _drawingState.liveShapeNotifier.value = null;
      }
      _isDrawing = false;
    };

    _gestureManager.onPointerTelemetry = (telemetry) {
      if (_showDiagnosticHud) {
        setState(() {
          _latestTelemetry = telemetry;
        });
      }
    };

    _gestureManager.onTransformUpdate = (newScale, newPan) {
      setState(() {
        _zoomScale = newScale;

        if (widget.state.isPageViewMode) {
          final dx = _clampPanDx(newPan.dx, _zoomScale, _canvasSize);
          final dy = _clampPanDy(newPan.dy, _zoomScale, _canvasSize);
          _panOffset = Offset(dx, dy);
          _updateActivePageFromScrollPosition();
        } else {
          _panOffset = newPan;
        }
      });
    };

    _gestureManager.onPanDelta = (delta) {
      setState(() {
        if (widget.state.isPageViewMode) {
          final dx = _clampPanDx(
            _panOffset.dx + delta.dx,
            _zoomScale,
            _canvasSize,
          );
          final dy = _clampPanDy(
            _panOffset.dy + delta.dy,
            _zoomScale,
            _canvasSize,
          );
          _panOffset = Offset(dx, dy);
          _updateActivePageFromScrollPosition();
        } else {
          _panOffset += delta;
        }
      });
    };

    _gestureManager.onEraseAt = (worldPos) {
      _eraseAt(worldPos);
    };

    _gestureManager.onLassoPoint = (worldPos, isStart) {
      final mode = _drawingState.lassoMode;
      if (isStart) {
        if (mode == LassoSelectionMode.freehand) {
          setState(() {
            _isLassoing = true;
            _lassoPoints.clear();
            _lassoPoints.add(worldPos);
          });
        } else {
          setState(() {
            _isLassoing = false;
            _dragStart = worldPos;
            _dragCurrent = worldPos;
          });
        }
      } else {
        if (mode == LassoSelectionMode.freehand && _isLassoing) {
          if (_lassoPoints.isNotEmpty) {
            final last = _lassoPoints.last;
            final dist = (worldPos - last).distance;
            if (dist > 16.0) {
              final steps = (dist / 12.0).ceil();
              for (int s = 1; s < steps; s++) {
                final t = s / steps;
                _lassoPoints.add(
                  Offset(
                    last.dx + (worldPos.dx - last.dx) * t,
                    last.dy + (worldPos.dy - last.dy) * t,
                  ),
                );
              }
            }
          }
          setState(() => _lassoPoints.add(worldPos));
        } else {
          setState(() => _dragCurrent = worldPos);
        }
      }
    };

    _gestureManager.onShapeDrag = (worldPos, isStart) {
      if (widget.state.isPageViewMode &&
          isStart &&
          !_isWorldPosInsidePaper(worldPos)) {
        return; // Outside paper shape drawing not allowed
      }
      setState(() {
        if (isStart) {
          _dragStart = worldPos;
          _dragCurrent = worldPos;
        } else {
          _dragCurrent = worldPos;
        }
      });
    };

    _gestureManager.onTextTap = (screenPos) {
      _startInlineTextEditing(screenPos);
    };

    _gestureManager.onStylusHover = (worldPos, tilt) {
      _stylusHoverPosNotifier.value = worldPos;
    };
  }

  /// Commits _currentStrokePoints into the document. Separated from _onPointerUp
  /// so that both the legacy pointer path and the new gesture manager can reuse it.
  ///
  /// ORDERING CONTRACT:
  ///   1. Detach immutable point copy from active buffer.
  ///   2. Build CanvasStrokeItem.
  ///   3. Clear active point buffer (mutable buffer is no longer needed).
  ///   4. addCanvasObject → AppState → notifyListeners → historical painter updated.
  ///   5. Caller (onStrokeEnd) clears liveStrokeNotifier AFTER this returns.
  ///
  /// Never clear the live layer inside this function — onStrokeEnd manages that
  /// so there is zero frame-gap between the historical layer receiving the stroke
  /// and the live layer being cleared.
  void _commitCurrentStroke() {
    _cancelDrawAndHoldTimer();

    // 1. If a shape was recognized via GoodNotes Draw-and-Hold, commit it directly.
    if (_isHoldingSnappedShape && _holdingSnappedShape != null) {
      final shape = _holdingSnappedShape!;
      _isHoldingSnappedShape = false;
      _holdingSnappedShape = null;
      _holdingShapeAnchor = null;
      _snappedInitialBounds = null;
      _currentStrokePoints = [];
      _drawingState.liveShapeNotifier.value = null;
      // Commit to AppState — historical layer updated synchronously before caller
      // clears the live stroke notifier.
      widget.state.addCanvasObject(shape);
      return;
    }

    _drawingState.liveShapeNotifier.value = null;

    final tool = _activeStrokeTool;
    if (_currentStrokePoints.isEmpty) return;

    final isHighlighter = tool == CanvasTool.highlighter;
    // Detach an immutable copy of the raw points. The active buffer
    // (_currentStrokePoints) is cleared immediately after to free memory,
    // but the committed stroke owns its own list — no shared-mutable aliasing.
    final pointsToCommit = List<StrokePoint>.of(_currentStrokePoints);
    _currentStrokePoints = []; // active buffer no longer needed

    final stroke = CanvasStrokeItem(
      id: 'stroke-${DateTime.now().microsecondsSinceEpoch}',
      points: pointsToCommit,
      color: _activeStrokeColor,
      strokeWidth: _activeStrokeWidth,
      opacity: isHighlighter
          ? (_activeStrokeOpacity * 0.45).clamp(0.1, 0.45)
          : _activeStrokeOpacity,
      tool: tool.name,
      penType: isHighlighter
          ? PenType.marker
          : (tool == CanvasTool.pencil ? PenType.pencil : _activeStrokePenType),
      pressureSensitivity: _activeStrokeSensitivity,
      tipSharpness: _activeStrokeTipSharpness,
      tipFlatness: _activeStrokeTipFlatness,
    );

    // addCanvasObject calls notifyListeners synchronously inside AppState.
    // The historical CanvasPainter will include this stroke in the SAME frame
    // that the live stroke notifier is cleared by the caller.
    widget.state.addCanvasObject(stroke);
  }

  void _updateActivePageFromScrollPosition() {
    // In single-page mode, page index is strictly driven by swipe navigation and toolbar
  }

  @override
  void didUpdateWidget(CanvasScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final docChanged = widget.state.currentCanvasDoc?.id != _lastKnownDocId;
    final modeChanged = widget.state.isPageViewMode != _lastKnownPageViewMode;
    final pageChanged = widget.state.currentPageIndex != _lastKnownPageIndex;

    _lastKnownDocId = widget.state.currentCanvasDoc?.id;
    _lastKnownPageViewMode = widget.state.isPageViewMode;
    _lastKnownPageIndex = widget.state.currentPageIndex;

    if ((docChanged || modeChanged || pageChanged) &&
        widget.state.isPageViewMode) {
      _pageViewCentered = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerPageInView());
    }

    // Bidirectional sync: keep _drawingState in sync if widget.state changed externally
    if (widget.state.currentTool != _drawingState.currentTool) {
      _drawingState.setTool(widget.state.currentTool);
    }
    if (widget.state.strokeColor != _drawingState.strokeColor) {
      _drawingState.setColor(widget.state.strokeColor);
    }
    if (widget.state.strokeWidth != _drawingState.strokeWidth) {
      _drawingState.setStrokeWidth(widget.state.strokeWidth);
    }
    if (widget.state.strokeOpacity != _drawingState.strokeOpacity) {
      _drawingState.setStrokeOpacity(widget.state.strokeOpacity);
    }
    if (widget.state.currentPenType != _drawingState.currentPenType) {
      _drawingState.setPenType(widget.state.currentPenType);
    }
    if (widget.state.pressureSensitivity != _drawingState.pressureSensitivity) {
      _drawingState.setPressureSensitivity(widget.state.pressureSensitivity);
    }
    if (widget.state.currentTool != CanvasTool.eraser &&
        _eraserCursorPosNotifier.value != null) {
      _eraserCursorPosNotifier.value = null;
      _isErasingActiveNotifier.value = false;
    }
  }

  /// Fit the GoodNotes A4 page horizontally and vertically in view, centering on the target page.
  void _centerPageInView() {
    if (!mounted) return;
    final cs = _canvasSize;
    if (cs == null || cs.width < 100 || cs.height < 100) return;

    // Fit single page so that the full page sheet is comfortably visible and framed nicely
    final studyPanelWidth =
        (_isPdfStudyReaderOpen && _activePdfStudyDoc != null)
        ? math.min(480.0, math.max(340.0, cs.width * 0.38))
        : 0.0;
    final availableWidth = math.max(300.0, cs.width - studyPanelWidth);

    final scaleW = (availableWidth - 64) / _kPageWidth;
    final scaleH = (cs.height - 72) / _kPageHeight;
    final scale = math.min(scaleW, scaleH).clamp(0.35, 1.4);

    final panDx = availableWidth / 2.0;
    final worldPageCenterY = _kPageTop + _kPageHeight / 2.0;
    final panDy = cs.height / 2.0 - worldPageCenterY * scale;

    setState(() {
      _zoomScale = scale;
      _panOffset = Offset(panDx, panDy);
      _pageViewCentered = true;
    });
  }

  @override
  void dispose() {
    _drawAndHoldTimer?.cancel();
    _drawingState.dispose();
    _canvasFocusNode.dispose();
    _inlineTextCtrl.dispose();
    _inlineTextFocusNode.dispose();
    _eraserCursorPosNotifier.dispose();
    _isErasingActiveNotifier.dispose();
    _clearLaser();
    _pageSwipeFeedbackTimer?.cancel();
    _slideAnimCtrl.dispose();
    _springBackCtrl.dispose();
    _addPageHoldCtrl.dispose();
    widget.state.removeListener(_onAppStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.state.isDarkMode;
    final bg = isDark ? const Color(0xFF141721) : const Color(0xFFF8FAFC);
    final currentTool = widget.state.currentTool;
    final liveTool = _isDrawing ? _activeStrokeTool : currentTool;
    final liveColor = _isDrawing
        ? _activeStrokeColor
        : widget.state.strokeColor;
    final liveWidth = _isDrawing
        ? _activeStrokeWidth
        : widget.state.strokeWidth;
    final liveOpacity = _isDrawing
        ? _activeStrokeOpacity
        : widget.state.strokeOpacity;
    final livePenType = _isDrawing
        ? _activeStrokePenType
        : _drawingState.currentPenType;
    final liveSensitivity = _isDrawing
        ? _activeStrokeSensitivity
        : _drawingState.pressureSensitivity;
    final liveTipSharpness = _isDrawing
        ? _activeStrokeTipSharpness
        : _drawingState.tipSharpness;
    final liveTipFlatness = _isDrawing
        ? _activeStrokeTipFlatness
        : _drawingState.tipFlatness;

    return Scaffold(
      backgroundColor: bg,
      appBar: null,
      body: SafeArea(
        bottom: true,
        top:
            true, // ensure toolbar is properly padded on mobile notch / status bar
        child: Focus(
          focusNode: _canvasFocusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            // ESC closes inline text editing or deselects all
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              if (_isInlineTextEditing) {
                _commitInlineText();
                return KeyEventResult.handled;
              }
              if (_showPenOptionsDialog || _showLassoOptionsDialog) {
                setState(() {
                  _showPenOptionsDialog = false;
                  _showLassoOptionsDialog = false;
                });
                return KeyEventResult.handled;
              }
              widget.state.deselectAllCanvasObjects();
              return KeyEventResult.handled;
            }

            // Space = hand pan toggle
            if (event.logicalKey == LogicalKeyboardKey.space) {
              if (event is KeyDownEvent && !_spacePressed) {
                setState(() => _spacePressed = true);
                return KeyEventResult.handled;
              } else if (event is KeyUpEvent && _spacePressed) {
                setState(() => _spacePressed = false);
                return KeyEventResult.handled;
              }
            }

            // Keyboard tool shortcuts
            if (event is KeyDownEvent) {
              final isCtrl =
                  HardwareKeyboard.instance.isControlPressed ||
                  HardwareKeyboard.instance.isMetaPressed;

              // Undo / Redo
              if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyZ) {
                if (HardwareKeyboard.instance.isShiftPressed) {
                  widget.state.redo();
                } else {
                  widget.state.undo();
                }
                return KeyEventResult.handled;
              }
              if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyY) {
                widget.state.redo();
                return KeyEventResult.handled;
              }

              // Delete / Backspace selected canvas items
              if (!_isInlineTextEditing &&
                  (event.logicalKey == LogicalKeyboardKey.delete ||
                      event.logicalKey == LogicalKeyboardKey.backspace)) {
                if (widget.state.selectedCanvasObjects.isNotEmpty) {
                  widget.state.deleteSelectedCanvasObjects();
                  return KeyEventResult.handled;
                }
              }

              // Tool shortcuts (only if no modifier and NOT inline text editing)
              if (!isCtrl &&
                  !HardwareKeyboard.instance.isAltPressed &&
                  !_isInlineTextEditing) {
                if (event.logicalKey == LogicalKeyboardKey.keyP) {
                  widget.state.setCanvasTool(CanvasTool.pen);
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.keyH) {
                  widget.state.setCanvasTool(CanvasTool.highlighter);
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.keyE) {
                  widget.state.setCanvasTool(CanvasTool.eraser);
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.keyL) {
                  widget.state.setCanvasTool(CanvasTool.lasso);
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.keyS) {
                  widget.state.setCanvasTool(CanvasTool.rectangle);
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.keyT) {
                  widget.state.setCanvasTool(CanvasTool.text);
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.keyV) {
                  widget.state.setCanvasTool(CanvasTool.hand);
                  return KeyEventResult.handled;
                }
              }
            }

            return KeyEventResult.ignored;
          },
          child: Column(
            children: [
              // ── Goodnotes Primary Top Bar ─────────────────────────────
              CanvasToolbar(
                currentTool: widget.state.currentTool,
                onToolSelected: (tool) {
                  if (tool == CanvasTool.image) {
                    _showInsertMediaDialog(isDark);
                    return;
                  }
                  if (tool == CanvasTool.elements) {
                    setState(() {
                      _showElementsPanel = !_showElementsPanel;
                      if (_showElementsPanel) {
                        _showPenOptionsDialog = false;
                        _showLassoOptionsDialog = false;
                      }
                    });
                    return;
                  }
                  widget.state.setCanvasTool(tool);
                  _drawingState.setTool(tool);
                },
                onOpenToolSettings: () => _openPenOptionsPopover(context),
                canUndo: widget.state.undoStack.isNotEmpty,
                canRedo: widget.state.redoStack.isNotEmpty,
                onUndo: widget.state.undo,
                onRedo: widget.state.redo,
                currentPageIndex: widget.state.currentPageIndex,
                totalPages: widget.state.canvasPages.isNotEmpty
                    ? widget.state.canvasPages.length
                    : 1,
                onPageChanged: (idx) => _transitionToPage(idx),
                onAddPage: _triggerAddPageFromSwipe,
                onShareExport: () => _showExportDialog(isDark),
                onOpenMoreMenu: () => _showDocumentMenu(isDark),
                onToggleSidebar: () => setState(
                  () => _showPageThumbnailsDrawer = !_showPageThumbnailsDrawer,
                ),
                onOpenSearch: () => _openSearchDialog(isDark),
                onOpenAiAssistant: () {
                  if (widget.state.viewMode == WorkspaceViewMode.canvasOnly) {
                    widget.state.setViewMode(WorkspaceViewMode.split);
                  } else {
                    widget.state.setViewMode(WorkspaceViewMode.canvasOnly);
                  }
                },
                onBack: () => widget.state.setNavIndex(0),
                documentTitle:
                    widget.state.currentCanvasDoc?.name ?? 'Preparing',
                isDark: isDark,
              ),

              // ── Canvas (full width, no left sidebar) ────────────────────────
              Expanded(
                child: ClipRect(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cs = constraints.biggest;
                      if (_canvasSize != cs) {
                        _canvasSize = cs;
                        if (widget.state.isPageViewMode && !_pageViewCentered) {
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _centerPageInView(),
                          );
                        }
                      }
                      return SizedBox.expand(
                        child: Stack(
                          fit: StackFit.expand,
                          clipBehavior: Clip.hardEdge,
                          children: [
                            // Drawing surface
                            Positioned.fill(
                              child: ClipRect(
                                child: ExcludeSemantics(
                                  child: MouseRegion(
                                    cursor: _getCanvasCursor(),
                                    onExit: (_) {
                                      _eraserCursorPosNotifier.value = null;
                                      _isErasingActiveNotifier.value = false;
                                    },
                                    child: Listener(
                                      behavior: HitTestBehavior.opaque,
                                      onPointerDown: _onPointerDown,
                                      onPointerMove: _onPointerMove,
                                      onPointerUp: _onPointerUp,
                                      onPointerCancel: _onPointerCancel,
                                      onPointerSignal: _onPointerSignal,
                                      onPointerHover: _onPointerHover,
                                      onPointerPanZoomStart:
                                          _onPointerPanZoomStart,
                                      onPointerPanZoomUpdate:
                                          _onPointerPanZoomUpdate,
                                      onPointerPanZoomEnd: _onPointerPanZoomEnd,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          // 1. Static committed canvas layer (wrapped in RepaintBoundary for steady 60/120fps)
                                          RepaintBoundary(
                                            child: CustomPaint(
                                              painter: CanvasPainter(
                                                appState: widget.state,
                                                // Use the dedicated canvasObjectsNotifier so this layer ONLY
                                                // repaints when strokes/objects change — NOT on toolbar picks,
                                                // autosave status updates, or any other AppState mutation.
                                                repaint: widget.state.canvasObjectsNotifier,
                                                objects:
                                                    widget.state.canvasObjects,
                                                pages: widget.state.canvasPages,
                                                activePageIndex: widget
                                                    .state
                                                    .currentPageIndex,
                                                currentPoints: const [],
                                                currentTool: currentTool,
                                                currentColor:
                                                    widget.state.strokeColor,
                                                currentWidth:
                                                    widget.state.strokeWidth,
                                                currentOpacity:
                                                    widget.state.strokeOpacity,
                                                currentPenType: _drawingState
                                                    .currentPenType,
                                                pressureSensitivity:
                                                    _drawingState
                                                        .pressureSensitivity,
                                                tipSharpness:
                                                    _drawingState.tipSharpness,
                                                tipFlatness:
                                                    _drawingState.tipFlatness,
                                                strokeStabilization:
                                                    _drawingState
                                                        .strokeStabilization,
                                                dragStart: _dragStart,
                                                dragCurrent: _dragCurrent,
                                                lassoPoints: _lassoPoints,
                                                isDark: isDark,
                                                panOffset: _panOffset,
                                                zoomScale: _zoomScale,
                                                paperStyle: widget
                                                    .state
                                                    .canvasPaperStyle,
                                                isPageViewMode:
                                                    widget.state.isPageViewMode,
                                                pageTitle:
                                                    widget
                                                        .state
                                                        .currentPage
                                                        ?.title ??
                                                    'Page ${widget.state.currentPageIndex + 1}',
                                                pageNumber:
                                                    widget
                                                        .state
                                                        .currentPageIndex +
                                                    1,
                                                totalPages:
                                                    widget
                                                        .state
                                                        .canvasPages
                                                        .isNotEmpty
                                                    ? widget
                                                          .state
                                                          .canvasPages
                                                          .length
                                                    : 1,
                                                selectedTextItemId:
                                                    _selectedTextItemId,
                                                selectedImageId:
                                                    _selectedImageId,
                                                editingExistingTextId:
                                                    _isInlineTextEditing
                                                    ? _editingExistingTextId
                                                    : null,
                                                isDrawingTape: _isDrawingTape,
                                                tapeStartWorld: _tapeStartWorld,
                                                tapeCurrentWorld:
                                                    _tapeCurrentWorld,
                                                tapeColor:
                                                    _drawingState.tapeColor,
                                                tapeHeight:
                                                    _drawingState.tapeHeight,
                                                imageCache: _decodedImagesCache,
                                                loadingImages: _loadingImages,
                                                onImageDecoded: () =>
                                                    setState(() {}),
                                                isTransitioning:
                                                    _isTransitioning,
                                                transitionFromPageIndex:
                                                    _transitionFromPageIndex,
                                                transitionToPageIndex:
                                                    _transitionToPageIndex,
                                                transitionProgress:
                                                    _slideAnim.value,
                                                transitionDirection:
                                                    _slideDirection,
                                                sheetPullOffset:
                                                    _sheetDragOffset,
                                              ),
                                              child: const SizedBox.expand(),
                                            ),
                                          ),

                                          // 2. High-performance isolated live stroke layer (repaints only on pointer events)
                                          RepaintBoundary(
                                            child: CustomPaint(
                                              painter: _LiveStrokePainter(
                                                notifier: _drawingState
                                                    .liveStrokeNotifier,
                                                shapeNotifier: _drawingState
                                                    .liveShapeNotifier,
                                                tool: liveTool,
                                                color: liveColor,
                                                strokeWidth: liveWidth,
                                                opacity: liveOpacity,
                                                penType: livePenType,
                                                sensitivity: liveSensitivity,
                                                tipSharpness: liveTipSharpness,
                                                tipFlatness: liveTipFlatness,
                                                panOffset: _panOffset,
                                                zoomScale: _zoomScale,
                                                isPageViewMode:
                                                    widget.state.isPageViewMode,
                                                pageNumber:
                                                    widget
                                                        .state
                                                        .currentPageIndex +
                                                    1,
                                                highlighterStraightLine:
                                                    _drawingState
                                                        .highlighterStraightLine,
                                              ),
                                              child: const SizedBox.expand(),
                                            ),
                                          ),

                                          // 3. Clean zero-latency eraser reticle (white inner circle + black border)
                                          RepaintBoundary(
                                            child: CustomPaint(
                                              painter: _EraserReticlePainter(
                                                posNotifier:
                                                    _eraserCursorPosNotifier,
                                                radius:
                                                    _effectiveEraserScreenRadius,
                                                isVisible:
                                                    currentTool ==
                                                    CanvasTool.eraser,
                                              ),
                                              child: const SizedBox.expand(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // ── Floating Secondary Toolbar (Top Center) ─────────
                            if (widget.state.selectedCanvasObjects.isEmpty)
                              Positioned(
                                top: 10,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: FloatingSecondaryToolbar(
                                  state: _drawingState,
                                  onOpenPenOptions: () => setState(() {
                                    _showPenOptionsDialog =
                                        !_showPenOptionsDialog;
                                    if (_showPenOptionsDialog) {
                                      _showLassoOptionsDialog = false;
                                      _showElementsPanel = false;
                                    }
                                  }),
                                  onOpenLassoOptions: () => setState(() {
                                    _showLassoOptionsDialog =
                                        !_showLassoOptionsDialog;
                                    if (_showLassoOptionsDialog) {
                                      _showPenOptionsDialog = false;
                                      _showElementsPanel = false;
                                    }
                                  }),
                                  onClearPage: widget.state.clearCanvas,
                                  isDark: isDark,
                                ),
                              ),
                            ),

                            // ── Laser Pointer Overlay ──────────────────────────────
                            if (widget.state.currentTool == CanvasTool.laser &&
                                (_laserStrokes.isNotEmpty ||
                                    _activeLaserPoint != null))
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _LaserPointerPainter(
                                      strokes: _laserStrokes
                                          .map((s) => List<_LaserPoint>.from(s))
                                          .toList(),
                                      color: _drawingState.laserColor,
                                      mode: _drawingState.laserMode,
                                      activePoint: _activeLaserPoint,
                                      isDrawing: _isDrawing,
                                      dotAlpha: _laserDotAlpha,
                                      masterFade: _laserMasterFade,
                                      isPageViewMode:
                                          widget.state.isPageViewMode,
                                      panOffset: _panOffset,
                                      zoomScale: _zoomScale,
                                      totalPages:
                                          widget.state.canvasPages.isNotEmpty
                                          ? widget.state.canvasPages.length
                                          : 1,
                                    ),
                                  ),
                                ),
                              ),

                            // Interactive AI note cards
                            ...widget.state.canvasObjects
                                .whereType<CanvasNoteCardItem>()
                                .map((card) {
                                  final screenPos = _worldToScreen(
                                    card.position,
                                  );
                                  return Positioned(
                                    left: screenPos.dx,
                                    top: screenPos.dy,
                                    child: Transform.scale(
                                      scale: _zoomScale,
                                      alignment: Alignment.topLeft,
                                      child: _buildInteractiveCanvasCard(
                                        card,
                                        isDark,
                                      ),
                                    ),
                                  );
                                }),

                            // ── Inline Text Editor ───────────────────────────────────
                            if (_isInlineTextEditing)
                              Positioned(
                                left: _inlineTextScreenPos.dx,
                                top: _inlineTextScreenPos.dy,
                                child: _buildInlineTextEditor(isDark),
                              ),

                            // ── Floating Text Formatting Toolbar ──────────────────────
                            if (_selectedTextItemId != null &&
                                _showTextFormatToolbar) ...[
                              Builder(
                                builder: (context) {
                                  final textItem = _getSelectedTextItem();
                                  if (textItem == null) {
                                    return const SizedBox.shrink();
                                   }
                                  final screenPos = _worldToScreen(
                                    textItem.position,
                                  );
                                  final maxW = _canvasSize?.width ?? 800;
                                  final maxH = _canvasSize?.height ?? 600;
                                  final left = (screenPos.dx - 40)
                                      .clamp(12.0, math.max(12.0, maxW - 680))
                                      .toDouble();
                                  final top = (screenPos.dy - 78)
                                      .clamp(12.0, math.max(12.0, maxH - 60))
                                      .toDouble();

                                  return Positioned(
                                    left: left,
                                    top: top,
                                    child: FloatingTextToolbar(
                                      textItem: textItem,
                                      isDark: isDark,
                                      onUpdate: (updated) {
                                        widget.state.updateCanvasTextItem(
                                          updated,
                                        );
                                      },
                                      onEditText: () {
                                        _startInlineTextEditing(
                                          screenPos,
                                          existingItem: textItem,
                                        );
                                      },
                                      onDuplicate: () {
                                        final dup = textItem.copyWith(
                                          id: 'text-${DateTime.now().millisecondsSinceEpoch}',
                                          position:
                                              textItem.position +
                                              const Offset(20, 20),
                                        );
                                        widget.state.addCanvasObject(dup);
                                        setState(() {
                                          _selectedTextItemId = dup.id;
                                        });
                                      },
                                      onDelete: () {
                                        widget.state.removeCanvasObject(
                                          textItem,
                                        );
                                        setState(() {
                                          _selectedTextItemId = null;
                                          _showTextFormatToolbar = false;
                                        });
                                      },
                                      onClose: () {
                                        setState(() {
                                          _selectedTextItemId = null;
                                          _showTextFormatToolbar = false;
                                        });
                                      },
                                    ),
                                  );
                                },
                              ),
                            ],

                            // ── Floating Image Toolbar ──────────────────────────────
                            if (_selectedImageId != null) ...[
                              Builder(
                                builder: (context) {
                                  final imgItem = _getSelectedImageItem();
                                  if (imgItem == null) return const SizedBox.shrink();
                                  final screenPos = _worldToScreen(imgItem.bounds.topLeft);
                                  final maxW = _canvasSize?.width ?? 800;
                                  final maxH = _canvasSize?.height ?? 600;
                                  final left = (screenPos.dx)
                                      .clamp(12.0, math.max(12.0, maxW - 320))
                                      .toDouble();
                                  final top = (screenPos.dy - 56)
                                      .clamp(12.0, math.max(12.0, maxH - 60))
                                      .toDouble();

                                  return Positioned(
                                    left: left,
                                    top: top,
                                    child: Material(
                                      elevation: 6,
                                      borderRadius: BorderRadius.circular(12),
                                      color: isDark ? const Color(0xFF1E2436) : Colors.white,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 6),
                                              child: Text(
                                                '🖼️ ${imgItem.bounds.width.toInt()}×${imgItem.bounds.height.toInt()}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                                                ),
                                              ),
                                            ),
                                            Container(
                                              height: 16,
                                              width: 1,
                                              color: isDark ? Colors.white24 : Colors.black12,
                                              margin: const EdgeInsets.symmetric(horizontal: 4),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.copy_rounded, size: 16),
                                              tooltip: 'Duplicate Image',
                                              onPressed: () {
                                                final dup = imgItem.copyWith(
                                                  id: 'img-${DateTime.now().millisecondsSinceEpoch}',
                                                  bounds: imgItem.bounds.shift(const Offset(30, 30)),
                                                );
                                                if (_decodedImagesCache.containsKey(imgItem.id)) {
                                                  _decodedImagesCache[dup.id] = _decodedImagesCache[imgItem.id]!;
                                                }
                                                widget.state.addCanvasObject(dup);
                                                setState(() {
                                                  _selectedImageId = dup.id;
                                                });
                                              },
                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                              padding: EdgeInsets.zero,
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Color(0xFFEF4444)),
                                              tooltip: 'Delete Image',
                                              onPressed: () {
                                                widget.state.removeCanvasObject(imgItem);
                                                setState(() {
                                                  _selectedImageId = null;
                                                });
                                              },
                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                              padding: EdgeInsets.zero,
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.check_rounded, size: 16, color: Color(0xFF10B981)),
                                              tooltip: 'Done',
                                              onPressed: () {
                                                setState(() {
                                                  _selectedImageId = null;
                                                });
                                              },
                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                              padding: EdgeInsets.zero,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],


                            // ── Zoom / Pan Controls (bottom right) ─────────────────
                            Builder(
                              builder: (context) {
                                final isMobile =
                                    MediaQuery.of(context).size.width < 640;
                                // In mobile page view mode, zoom controls are integrated into the bottom floating page bar to prevent overlap
                                if (isMobile && widget.state.isPageViewMode) {
                                  return const SizedBox.shrink();
                                }
                                if (isMobile) {
                                  return Positioned(
                                    bottom: 14,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: _buildTravelControls(isDark),
                                    ),
                                  );
                                }
                                return Positioned(
                                  bottom: 14,
                                  right: 14,
                                  child: _buildTravelControls(isDark),
                                );
                              },
                            ),

                            // ── Page Thumbnails Drawer (Left side) ─────────────────
                            if (_showPageThumbnailsDrawer)
                              Positioned(
                                top: 0,
                                bottom: 0,
                                left: 0,
                                child: _buildPageThumbnailsDrawer(isDark),
                              ),

                            // ── Apple Pencil Telemetry HUD (Bottom Left) ───────────
                            if (_showDiagnosticHud)
                              Positioned(
                                bottom: 20,
                                left: _showPageThumbnailsDrawer ? 336 : 20,
                                child: _buildDiagnosticHud(isDark),
                              ),

                            // ── Floating Contextual Toolbar for Selection ────────────
                            if (widget.state.selectedCanvasObjects.isNotEmpty)
                              Positioned(
                                top: 10,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: ContextualToolbar(
                                    selectedObjects:
                                        widget.state.selectedCanvasObjects,
                                    isDark: isDark,
                                    onDuplicate: widget
                                        .state
                                        .duplicateSelectedCanvasObjects,
                                    onDelete: widget
                                        .state
                                        .deleteSelectedCanvasObjects,
                                    onRecolor: (newColor) => widget.state
                                        .recolorSelectedCanvasObjects(newColor),
                                    onBringToFront: widget
                                        .state
                                        .bringSelectedCanvasObjectsToFront,
                                    onSendToBack: widget
                                        .state
                                        .sendSelectedCanvasObjectsToBack,
                                    onDeselect:
                                        widget.state.deselectAllCanvasObjects,
                                  ),
                                ),
                              ),
                            // ── GoodNotes Right-to-Left Pull to Add Page Indicator & Page Controls ───
                            if (widget.state.isPageViewMode) ...[
                              _buildPullToAddPageIndicator(isDark),
                              _buildPullToPrevPageIndicator(isDark),
                              _buildBottomFloatingPageBar(isDark),
                              _buildPageSwipeToast(isDark),
                            ],

                            // ── Goodnotes Floating Popovers with Tap-Outside Dismiss Barrier (Always on Top) ──
                            if (_showPenOptionsDialog ||
                                _showLassoOptionsDialog ||
                                _showElementsPanel) ...[
                              Positioned.fill(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => setState(() {
                                    _showPenOptionsDialog = false;
                                    _showLassoOptionsDialog = false;
                                    _showElementsPanel = false;
                                  }),
                                  child: Container(
                                    color: Colors.black.withValues(alpha: 0.12),
                                  ),
                                ),
                              ),
                              if (_showPenOptionsDialog)
                                Positioned(
                                  top: 60,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: FloatingPenOptionsDialog(
                                      drawingState: _drawingState,
                                      isDark: isDark,
                                      onClose: () => setState(
                                        () => _showPenOptionsDialog = false,
                                      ),
                                    ),
                                  ),
                                ),
                              if (_showLassoOptionsDialog)
                                Positioned(
                                  top: 60,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: FloatingLassoOptionsDialog(
                                      drawingState: _drawingState,
                                      isDark: isDark,
                                      onClose: () => setState(
                                        () => _showLassoOptionsDialog = false,
                                      ),
                                    ),
                                  ),
                                ),
                              if (_showElementsPanel)
                                Positioned(
                                  top: 60,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: ElementsStickersPanel(
                                      isDark: isDark,
                                      onSelectElement: _onSelectCanvasElement,
                                      onClose: () => setState(
                                        () => _showElementsPanel = false,
                                      ),
                                    ),
                                  ),
                                ),
                            ],

                            // ── GoodNotes Side-by-Side PDF Study Split-Screen Panel ───
                            if (_isPdfStudyReaderOpen &&
                                _activePdfStudyDoc != null)
                              Positioned(
                                top: 0,
                                bottom: 0,
                                right: 0,
                                child: GoodNotesPdfStudyPanel(
                                  document: _activePdfStudyDoc!,
                                  isDark: isDark,
                                  onClose: () {
                                    setState(() {
                                      _isPdfStudyReaderOpen = false;
                                    });
                                    _centerPageInView();
                                  },
                                  onInsertPageToNotebook: (pageNum, text) {
                                    _insertPdfPageContentToNotebook(
                                      _activePdfStudyDoc!,
                                      pageNum,
                                      text,
                                    );
                                  },
                                  onCopyTextToCanvas: (text) {
                                    _addPdfExcerptNoteCard(text);
                                  },
                                  onImportAllToNotebook: () {
                                    _importPdfPagesToNotebook(
                                      _activePdfStudyDoc!,
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ), // Focus
      ), // SafeArea
    );
  } // end build()

  // ── GoodNotes Right-to-Left Swipe & Pull to Add Page Helpers ─────────────────
  void _transitionToPage(int targetIndex) {
    if (_isTransitioning || !mounted) return;
    final currentIdx = widget.state.currentPageIndex;
    if (targetIndex == currentIdx) return;
    if (targetIndex < 0 || targetIndex >= widget.state.canvasPages.length) {
      return;
    }

    // 1. Synchronously commit any live drawing in-flight
    if (_currentStrokePoints.isNotEmpty) {
      _commitCurrentStroke();
    }
    // 2. Synchronously save the exiting page objects into currentCanvasDoc
    widget.state.syncCurrentPageObjects();

    final goingForward = targetIndex > currentIdx;
    setState(() {
      _isTransitioning = true;
      _transitionFromPageIndex = currentIdx;
      _transitionToPageIndex = targetIndex;
      _slideDirection = goingForward ? -1.0 : 1.0;
      _sheetDragOffset = 0.0;
      _horizontalPullDistance = 0.0;
    });

    _slideAnimCtrl.forward(from: 0.0);
    _showSwipeToast('Page ${targetIndex + 1}');
  }

  void _triggerAddPageFromSwipe() {
    if (_isTransitioning || !mounted) return;
    if (_currentStrokePoints.isNotEmpty) {
      _commitCurrentStroke();
    }
    widget.state.syncCurrentPageObjects();

    final fromIdx = widget.state.currentPageIndex;
    widget.state.addNewPage(switchToPage: false);
    final toIdx = widget.state.canvasPages.length - 1;
    if (toIdx != fromIdx) {
      setState(() {
        _isTransitioning = true;
        _transitionFromPageIndex = fromIdx;
        _transitionToPageIndex = toIdx;
        _slideDirection = -1.0;
        _sheetDragOffset = 0.0;
        _horizontalPullDistance = 0.0;
      });
      _slideAnimCtrl.forward(from: 0.0);
      _showSwipeToast('Added Page ${toIdx + 1}');
    }
  }

  void _springBack() {
    if (_sheetDragOffset == 0.0) return;
    _springBackAnim = Tween<double>(begin: _sheetDragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _springBackCtrl, curve: Curves.easeOutCubic),
    );
    _springBackCtrl.forward(from: 0.0);
  }

  void _navigateToNextPage() {
    if (widget.state.currentPageIndex < widget.state.canvasPages.length - 1) {
      _transitionToPage(widget.state.currentPageIndex + 1);
    }
  }

  void _navigateToPrevPage() {
    if (widget.state.currentPageIndex > 0) {
      _transitionToPage(widget.state.currentPageIndex - 1);
    }
  }

  void _showSwipeToast(String message) {
    _pageSwipeFeedbackTimer?.cancel();
    setState(() {
      _pageSwipeFeedbackText = message;
    });
    _pageSwipeFeedbackTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _pageSwipeFeedbackText = null;
        });
      }
    });
  }

  Widget _buildPullToAddPageIndicator(bool isDark) {
    final isLastPage =
        widget.state.currentPageIndex >= (widget.state.canvasPages.length - 1);
    final isPulling = _horizontalPullDistance > 5.0;

    if (!isLastPage && _sheetDragOffset >= -5.0) {
      return const SizedBox.shrink();
    }

    final isTriggerReady =
        _isHoldingToAddPage || (_horizontalPullDistance >= 65.0 && !isLastPage);

    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(
            isPulling
                ? math.max(0.0, 68.0 - _horizontalPullDistance * 0.85)
                : 60.0,
            0.0,
            0.0,
          ),
          child: Container(
            margin: const EdgeInsets.only(right: 14),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isTriggerReady
                  ? const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    )
                  : (isDark
                        ? const LinearGradient(
                            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          )
                        : const LinearGradient(
                            colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
                          )),
              border: Border.all(
                color: isTriggerReady
                    ? const Color(0xFF93C5FD)
                    : (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1)),
                width: isTriggerReady ? 1.6 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isTriggerReady
                      ? const Color(0xFF2563EB).withValues(alpha: 0.40)
                      : Colors.black.withValues(alpha: 0.12),
                  blurRadius: isTriggerReady ? 16 : 8,
                  offset: const Offset(-2, 3),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    value: isLastPage
                        ? (_isHoldingToAddPage
                              ? _addPageHoldCtrl.value
                              : (_horizontalPullDistance / 65.0).clamp(
                                  0.0,
                                  0.95,
                                ))
                        : (_horizontalPullDistance / 60.0).clamp(0.0, 1.0),
                    strokeWidth: 2.6,
                    backgroundColor: isTriggerReady
                        ? Colors.white.withValues(alpha: 0.25)
                        : (isDark ? Colors.white12 : Colors.black12),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isTriggerReady
                          ? Colors.white
                          : (isDark
                                ? const Color(0xFF60A5FA)
                                : const Color(0xFF2563EB)),
                    ),
                  ),
                ),
                AnimatedScale(
                  scale: _isHoldingToAddPage ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 160),
                  child: Icon(
                    isLastPage ? Icons.add_rounded : Icons.chevron_left_rounded,
                    size: 20,
                    color: isTriggerReady
                        ? Colors.white
                        : (isDark ? Colors.white : const Color(0xFF1E3A5F)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPullToPrevPageIndicator(bool isDark) {
    if (_sheetDragOffset <= 5.0 || widget.state.currentPageIndex <= 0) {
      return const SizedBox.shrink();
    }
    final isTriggerReady = _sheetDragOffset >= 60.0;
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(
            math.min(0.0, -68.0 + _sheetDragOffset * 0.85),
            0.0,
            0.0,
          ),
          child: Container(
            margin: const EdgeInsets.only(left: 14),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isTriggerReady
                  ? const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    )
                  : (isDark
                        ? const LinearGradient(
                            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          )
                        : const LinearGradient(
                            colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
                          )),
              border: Border.all(
                color: isTriggerReady
                    ? const Color(0xFF93C5FD)
                    : (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1)),
                width: isTriggerReady ? 1.6 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isTriggerReady
                      ? const Color(0xFF2563EB).withValues(alpha: 0.40)
                      : Colors.black.withValues(alpha: 0.12),
                  blurRadius: isTriggerReady ? 16 : 8,
                  offset: const Offset(2, 3),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    value: (_sheetDragOffset / 60.0).clamp(0.0, 1.0),
                    strokeWidth: 2.6,
                    backgroundColor: isTriggerReady
                        ? Colors.white.withValues(alpha: 0.25)
                        : (isDark ? Colors.white12 : Colors.black12),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isTriggerReady
                          ? Colors.white
                          : (isDark
                                ? const Color(0xFF60A5FA)
                                : const Color(0xFF2563EB)),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isTriggerReady
                      ? Colors.white
                      : (isDark ? Colors.white : const Color(0xFF1E3A5F)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomFloatingPageBar(bool isDark) {
    if (!widget.state.isPageViewMode) return const SizedBox.shrink();
    if (_showPenOptionsDialog ||
        _showLassoOptionsDialog ||
        _showElementsPanel) {
      return const SizedBox.shrink();
    }
    final total = widget.state.canvasPages.isNotEmpty
        ? widget.state.canvasPages.length
        : 1;
    final current = widget.state.currentPageIndex + 1;
    final canPrev = widget.state.currentPageIndex > 0;
    final canNext = widget.state.currentPageIndex < total - 1;

    return Builder(
      builder: (context) {
        final isMobile = MediaQuery.of(context).size.width < 640;
        return Positioned(
          bottom: isMobile ? 12 : 18,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 4 : 6,
                vertical: isMobile ? 3 : 4,
              ),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF1E293B) : Colors.white)
                    .withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: isMobile ? 28 : 32,
                      minHeight: isMobile ? 28 : 32,
                    ),
                    color: canPrev
                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                        : Colors.grey.shade400,
                    onPressed: canPrev ? _navigateToPrevPage : null,
                    tooltip: 'Previous Page',
                  ),
                  InkWell(
                    onTap: () => setState(
                      () => _showPageThumbnailsDrawer =
                          !_showPageThumbnailsDrawer,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 5 : 8,
                        vertical: 4,
                      ),
                      child: Text(
                        '$current / $total',
                        style: GoogleFonts.inter(
                          fontSize: isMobile ? 11.5 : 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: isMobile ? 28 : 32,
                      minHeight: isMobile ? 28 : 32,
                    ),
                    color: canNext
                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                        : Colors.grey.shade400,
                    onPressed: canNext ? _navigateToNextPage : null,
                    tooltip: 'Next Page',
                  ),
                  Container(
                    height: 16,
                    width: 1,
                    color: isDark ? Colors.white12 : Colors.black12,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_rounded, size: 19),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: isMobile ? 28 : 32,
                      minHeight: isMobile ? 28 : 32,
                    ),
                    color: const Color(0xFF2563EB),
                    onPressed: _triggerAddPageFromSwipe,
                    tooltip: 'Add Page',
                  ),

                  // Integrated Zoom & Reset controls on Mobile
                  if (isMobile) ...[
                    Container(
                      height: 16,
                      width: 1,
                      color: isDark ? Colors.white12 : Colors.black12,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_rounded, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 26,
                        minHeight: 28,
                      ),
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      onPressed: () {
                        setState(() {
                          _zoomScale = (_zoomScale * 0.85).clamp(0.2, 5.0);
                        });
                      },
                      tooltip: 'Zoom Out',
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _panOffset = Offset.zero;
                          _zoomScale = 1.0;
                        });
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 4,
                        ),
                        child: Text(
                          '${(_zoomScale * 100).round()}%',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 26,
                        minHeight: 28,
                      ),
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      onPressed: () {
                        setState(() {
                          _zoomScale = (_zoomScale * 1.15).clamp(0.2, 5.0);
                        });
                      },
                      tooltip: 'Zoom In',
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.center_focus_strong_rounded,
                        size: 15,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 26,
                        minHeight: 28,
                      ),
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      onPressed: () {
                        setState(() {
                          _panOffset = Offset.zero;
                          _zoomScale = 1.0;
                        });
                      },
                      tooltip: 'Reset View / Center',
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageSwipeToast(bool isDark) {
    if (_pageSwipeFeedbackText == null) return const SizedBox.shrink();
    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF38659B),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.note_add_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                _pageSwipeFeedbackText!,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Coordinate transforms & Paper boundaries ────────────────────────────────
  /// Returns the page index (0-based) if [screenPos] is directly over the active paper sheet, or null if outside.
  int? _getPageIndexAtScreenPos(Offset screenPos) {
    if (!widget.state.isPageViewMode) return widget.state.currentPageIndex;
    final worldPos = _screenToWorld(screenPos);
    return _isWorldPosInsidePaper(worldPos)
        ? widget.state.currentPageIndex
        : null;
  }

  /// Returns true if [screenPos] is within the active paper sheet.
  bool _isScreenPosInsidePaper(Offset screenPos) {
    if (!widget.state.isPageViewMode) return true;
    final worldPos = _screenToWorld(screenPos);
    return _isWorldPosInsidePaper(worldPos);
  }

  /// Returns true if [worldPos] is inside the active paper bounds.
  bool _isWorldPosInsidePaper(Offset worldPos) {
    if (!widget.state.isPageViewMode) return true;
    return _kPageRect.inflate(4.0).contains(worldPos);
  }

  Offset _screenToWorld(Offset screenPos) {
    return (screenPos - _panOffset) / _zoomScale;
  }

  Offset _worldToScreen(Offset worldPos) {
    return (worldPos * _zoomScale) + _panOffset;
  }

  MouseCursor _getCanvasCursor() {
    if (widget.state.currentTool == CanvasTool.hand || _spacePressed) {
      return _isPanning ? SystemMouseCursors.grabbing : SystemMouseCursors.grab;
    }
    if (widget.state.currentTool == CanvasTool.eraser) {
      return SystemMouseCursors.none;
    }
    if (widget.state.currentTool == CanvasTool.laser) {
      if (widget.state.isPageViewMode &&
          _lastHoverScreenPos != null &&
          !_isScreenPosInsidePaper(_lastHoverScreenPos!)) {
        return SystemMouseCursors.basic;
      }
      return (_isDrawing || _laserStrokes.isNotEmpty)
          ? SystemMouseCursors.none
          : SystemMouseCursors.precise;
    }
    if (widget.state.currentTool == CanvasTool.text) {
      return SystemMouseCursors.text;
    }
    return SystemMouseCursors.precise;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Pointer events — routed through CanvasGestureManager for:
  //   • Apple Pencil first-class priority
  //   • Temporal palm rejection (1200ms cooldown)
  //   • Zero-ink two-finger pinch/pan
  //   • EMA pressure smoothing
  //   • Invariant focal-point zoom (50%–500%)
  // ──────────────────────────────────────────────────────────────────────────

  double _clampPanDx(double targetDx, double currentZoom, Size? cs) {
    // Generous, unconstrained horizontal panning across infinite workspace
    return targetDx.clamp(-40000.0, 40000.0);
  }

  double _clampPanDy(double targetDy, double currentZoom, Size? cs) {
    // Generous, unconstrained vertical panning across multi-page notebooks
    return targetDy.clamp(-120000.0, 120000.0);
  }

  // ──────────────────────────────────────────────────────────────────────────
  void _onPointerDown(PointerDownEvent event) {
    if (_isInlineTextEditing) {
      _commitInlineText();
    }

    if (_showPenOptionsDialog ||
        _showLassoOptionsDialog ||
        _showElementsPanel) {
      setState(() {
        _showPenOptionsDialog = false;
        _showLassoOptionsDialog = false;
        _showElementsPanel = false;
      });
    }

    // Direct middle-mouse or secondary/right-mouse button drag pan across all tools
    final isMousePan = event.kind == PointerDeviceKind.mouse &&
        (event.buttons == kMiddleMouseButton || event.buttons == kSecondaryMouseButton);
    if (isMousePan) {
      setState(() {
        _isPanning = true;
      });
      return;
    }

    // ── GoodNotes Swipe & Pull-to-Add-Page (Isolated from Inking) ─────────────
    final csWidth = _canvasSize?.width ?? 800.0;
    final paperScreenLeft = (_kPageLeft * _zoomScale) + _panOffset.dx;
    final paperScreenRight =
        ((_kPageLeft + _kPageWidth) * _zoomScale) + _panOffset.dx;

    final isOutsidePaper = !_isScreenPosInsidePaper(event.localPosition);
    final isRightEdgeZone =
        event.localPosition.dx >= (csWidth - 90.0) ||
        (event.localPosition.dx >= paperScreenRight - 90.0 &&
            event.localPosition.dx >= paperScreenLeft);
    final isLeftEdgeZone =
        event.localPosition.dx <= 90.0 ||
        (event.localPosition.dx <= paperScreenLeft + 90.0 &&
            event.localPosition.dx <= paperScreenRight);
    final isHandTool =
        widget.state.currentTool == CanvasTool.hand || _spacePressed;

    // Device ownership comes from Flutter's pointer kind. Inferring a Pencil
    // from pressure or tilt can misclassify touch input on WebKit.
    final isStylus =
        event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus;
    final isDrawingTool =
        widget.state.currentTool == CanvasTool.pen ||
        widget.state.currentTool == CanvasTool.pencil ||
        widget.state.currentTool == CanvasTool.highlighter ||
        widget.state.currentTool == CanvasTool.eraser ||
        widget.state.currentTool == CanvasTool.brush;

    // Stylus touches NEVER trigger page swipe — stylus is strictly for writing.
    // Drawing/erasing tools also have 100% priority over swipes to allow writing seamlessly.
    // Hand tool is for 2D canvas navigation and pinch-to-zoom — NEVER hijacked into horizontal page swiping!
    final canTriggerSwipe =
        !isStylus &&
        !isDrawingTool &&
        !isHandTool &&
        (isOutsidePaper || isRightEdgeZone || isLeftEdgeZone);

    if (widget.state.isPageViewMode && canTriggerSwipe) {
      _horizontalSwipeStartPos = event.localPosition;
      _horizontalSwipePointerId = event.pointer;
      _isSwipeGestureActive = true;
      return;
    }

    // ── Laser Pointer: Priority #1 presentation tool ─────────────────────────
    if (widget.state.currentTool == CanvasTool.laser) {
      if (widget.state.isPageViewMode &&
          !_isScreenPosInsidePaper(event.localPosition)) {
        // Outside paper: do not activate laser pointer
        return;
      }
      _isDrawing = true;
      _activeLaserPoint = event.localPosition;
      if (_drawingState.laserMode == 'dot') {
        _laserDotFadeTimer?.cancel();
        _laserDotFadeTimer = null;
        _laserDotAlpha = 1.0;
      } else {
        // Cancel any pending inactivity fade or hold timer
        _laserHoldTimer?.cancel();
        _laserHoldTimer = null;
        _laserFadeTimer?.cancel();
        _laserFadeTimer = null;
        _laserMasterFade = 1.0;

        final now = DateTime.now().millisecondsSinceEpoch;
        _laserStrokes.add([_LaserPoint(event.localPosition, now)]);
        _startLaserMaxAgeTimer();
      }
      setState(() {});
      return;
    }

    final worldPos = _screenToWorld(event.localPosition);

    // ── Selected Image Corner Resize Handles & Drag ─────────────────────────
    if (_selectedImageId != null) {
      final selImg = _getSelectedImageItem();
      if (selImg != null) {
        final b = selImg.bounds;
        final handleRadius = 26.0 / _zoomScale;
        if ((worldPos - b.bottomRight).distance <= handleRadius) {
          setState(() {
            _isResizingImage = true;
            _resizingImageCorner = 'br';
            _resizingImageInitialBounds = b;
            _resizingImageInitialAspect = b.width / math.max(1.0, b.height);
          });
          return;
        } else if ((worldPos - b.bottomLeft).distance <= handleRadius) {
          setState(() {
            _isResizingImage = true;
            _resizingImageCorner = 'bl';
            _resizingImageInitialBounds = b;
            _resizingImageInitialAspect = b.width / math.max(1.0, b.height);
          });
          return;
        } else if ((worldPos - b.topRight).distance <= handleRadius) {
          setState(() {
            _isResizingImage = true;
            _resizingImageCorner = 'tr';
            _resizingImageInitialBounds = b;
            _resizingImageInitialAspect = b.width / math.max(1.0, b.height);
          });
          return;
        } else if ((worldPos - b.topLeft).distance <= handleRadius) {
          setState(() {
            _isResizingImage = true;
            _resizingImageCorner = 'tl';
            _resizingImageInitialBounds = b;
            _resizingImageInitialAspect = b.width / math.max(1.0, b.height);
          });
          return;
        } else if (b.contains(worldPos) &&
            (!isDrawingTool ||
                widget.state.currentTool == CanvasTool.image ||
                widget.state.currentTool == CanvasTool.lasso ||
                event.kind == PointerDeviceKind.mouse)) {
          setState(() {
            _draggedObjectId = selImg.id;
            _lastDragWorldPos = worldPos;
          });
          return;
        }
      }
    }

    // Fast-path: When Pen, Pencil, Highlighter, Eraser, Brush, or Stylus is active,
    // establish ownership and begin writing in O(1) immediately.
    // Deselect any active text box or image without returning so the first pencil point is never dropped.
    if (isDrawingTool || isStylus) {
      if (_selectedImageId != null) {
        _selectedImageId = null;
      }
      if (_selectedTextItemId != null) {
        _selectedTextItemId = null;
        _showTextFormatToolbar = false;
      }
      if (widget.state.isPageViewMode) {
        final hitPageIdx = _getPageIndexAtScreenPos(event.localPosition);
        if (hitPageIdx != null && hitPageIdx != widget.state.currentPageIndex) {
          _lastKnownPageIndex = hitPageIdx;
          widget.state.setCanvasPage(hitPageIdx);
        }
      }
      _gestureManager.setPinchStartGeometry(_zoomScale, _panOffset);
      if (widget.state.currentTool == CanvasTool.eraser) {
        _eraserCursorPosNotifier.value = event.localPosition;
        _isErasingActiveNotifier.value = true;
      }
      CanvasPerformanceProfiler.instance.markPointerDown();
      _gestureManager.onPointerDown(
        event,
        widget.state.currentTool.name,
        currentZoom: _zoomScale,
        currentPan: _panOffset,
      );
      return;
    }

    // 1. Study Tape tap-to-reveal: Tapping any tape strip flips mask state instantly
    for (final obj in widget.state.canvasObjects.reversed) {
      if (obj is CanvasTapeItem && obj.hits(worldPos)) {
        widget.state.toggleTapeMask(obj.id);
        return;
      }
    }

    // 2. Study Tape tool: Start drawing tape strip
    if (widget.state.currentTool == CanvasTool.tape) {
      setState(() {
        _isDrawingTape = true;
        _tapeStartWorld = worldPos;
        _tapeCurrentWorld = worldPos;
      });
      return;
    }

    // Hand tool / space-bar pan
    if (widget.state.currentTool == CanvasTool.hand || _spacePressed) {
      setState(() {
        _isPanning = true;
      });
      return;
    }

    // 3. Move/resize existing objects (Text box, Element, Sticker, Badge, Image, Shape)
    final now = DateTime.now().millisecondsSinceEpoch;
    final handleTouchRadius = 24.0 / _zoomScale;

    // Check if user tapped a resize handle or move handle on the currently selected text box
    if (_selectedTextItemId != null) {
      final selItem = _getSelectedTextItem();
      if (selItem != null) {
        final bbox = selItem.getBoundingBox();
        final rightHandle = Offset(bbox.right, bbox.center.dy);
        final leftHandle = Offset(bbox.left, bbox.center.dy);
        final topHandle = Offset(
          bbox.center.dx,
          bbox.top - (14.0 / _zoomScale),
        );

        if ((worldPos - rightHandle).distance <= handleTouchRadius) {
          setState(() {
            _isResizingTextWidth = true;
            _resizingTextItemId = selItem.id;
            _resizeFromLeft = false;
          });
          return;
        } else if ((worldPos - leftHandle).distance <= handleTouchRadius) {
          setState(() {
            _isResizingTextWidth = true;
            _resizingTextItemId = selItem.id;
            _resizeFromLeft = true;
          });
          return;
        } else if ((worldPos - topHandle).distance <= handleTouchRadius ||
            bbox.inflate(6.0).contains(worldPos)) {
          // Check for double tap to edit
          final isDoubleTap =
              (_lastTappedTextId == selItem.id) &&
              (now - _lastTextTapTimestamp < 380);
          _lastTappedTextId = selItem.id;
          _lastTextTapTimestamp = now;
          if (isDoubleTap) {
            final screenPos = _worldToScreen(selItem.position);
            _startInlineTextEditing(screenPos, existingItem: selItem);
            return;
          }
          // Enable dragging immediately
          setState(() {
            _draggedObjectId = selItem.id;
            _lastDragWorldPos = worldPos;
          });
          return;
        }
      }
    }

    // Check if user tapped on ANY canvas object to select or drag it
    CanvasObjectItem? foundObj;
    for (final obj in widget.state.canvasObjects.reversed) {
      if (obj.hits(worldPos, padding: 10.0)) {
        foundObj = obj;
        break;
      }
    }

    if (foundObj != null) {
      final hit = foundObj;
      if (hit is CanvasTextItem) {
        final textItem = hit;
        final isDoubleTap =
            (_lastTappedTextId == textItem.id) &&
            (now - _lastTextTapTimestamp < 380);
        _lastTappedTextId = textItem.id;
        _lastTextTapTimestamp = now;

        if (isDoubleTap) {
          final screenPos = _worldToScreen(textItem.position);
          _startInlineTextEditing(screenPos, existingItem: textItem);
          return;
        }

        setState(() {
          _selectedTextItemId = textItem.id;
          _showTextFormatToolbar = true;
          _draggedObjectId = textItem.id;
          _lastDragWorldPos = worldPos;
        });
        return;
      } else if (hit is CanvasNoteCardItem) {
        setState(() {
          _selectedTextItemId = null;
          _showTextFormatToolbar = false;
          _draggedObjectId = hit.id;
          _lastDragWorldPos = worldPos;
        });
        return;
      } else if (hit is CanvasImageItem) {
        setState(() {
          _selectedTextItemId = null;
          _showTextFormatToolbar = false;
          _selectedImageId = hit.id;
          _draggedObjectId = hit.id;
          _lastDragWorldPos = worldPos;
        });
        return;
      } else if (hit is CanvasShapeItem &&
          widget.state.currentTool != CanvasTool.rectangle &&
          widget.state.currentTool != CanvasTool.circle &&
          widget.state.currentTool != CanvasTool.triangle &&
          widget.state.currentTool != CanvasTool.line &&
          widget.state.currentTool != CanvasTool.arrow &&
          widget.state.currentTool != CanvasTool.star) {
        setState(() {
          _selectedTextItemId = null;
          _showTextFormatToolbar = false;
          _draggedObjectId = hit.id;
          _lastDragWorldPos = worldPos;
        });
        return;
      }
    } else {
      _lastTappedTextId = null;
      if (_selectedImageId != null) {
        setState(() {
          _selectedImageId = null;
        });
      }
      if (_selectedTextItemId != null) {
        setState(() {
          _selectedTextItemId = null;
          _showTextFormatToolbar = false;
        });
        return;
      }

      if (widget.state.currentTool == CanvasTool.text) {
        _startInlineTextEditing(event.localPosition);
        return;
      }
    }

    // Lasso selection drag-to-move check (world space)
    if (widget.state.currentTool == CanvasTool.lasso &&
        widget.state.selectedCanvasObjects.isNotEmpty) {
      final worldPos = _screenToWorld(event.localPosition);
      Rect? combinedBBox;
      for (final obj in widget.state.selectedCanvasObjects) {
        final box = obj.getBoundingBox();
        combinedBBox = combinedBBox == null
            ? box
            : combinedBBox.expandToInclude(box);
      }
      if (combinedBBox != null &&
          combinedBBox.inflate(24.0).contains(worldPos)) {
        setState(() {
          _isDraggingSelection = true;
          _lastSelectionDragPos = worldPos;
        });
        return;
      }
    }

    // Text item drag check (world space) — active when Lasso or Text tool is selected
    if (widget.state.currentTool == CanvasTool.lasso ||
        widget.state.currentTool == CanvasTool.text) {
      final worldPos = _screenToWorld(event.localPosition);
      for (final obj in widget.state.canvasObjects.reversed) {
        if (obj is CanvasTextItem) {
          final bbox = obj.getBoundingBox();
          if (bbox.contains(worldPos)) {
            setState(() {
              _draggedTextItemId = obj.id;
            });
            return;
          }
        }
      }
    }

    // In page view mode, check if tapped another page to switch
    if (widget.state.isPageViewMode) {
      final hitPageIdx = _getPageIndexAtScreenPos(event.localPosition);
      if (hitPageIdx != null && hitPageIdx != widget.state.currentPageIndex) {
        _lastKnownPageIndex = hitPageIdx;
        widget.state.setCanvasPage(hitPageIdx);
      }
    }

    // Record initial pinch geometry so invariant zoom knows the starting state
    _gestureManager.setPinchStartGeometry(_zoomScale, _panOffset);

    if (widget.state.currentTool == CanvasTool.eraser) {
      _eraserCursorPosNotifier.value = event.localPosition;
      _isErasingActiveNotifier.value = true;
    }

    // Delegate to gesture manager (handles palm rejection, Pencil priority, 2-finger check)
    _gestureManager.onPointerDown(
      event,
      widget.state.currentTool.name,
      currentZoom: _zoomScale,
      currentPan: _panOffset,
    );
  }

  void _onPointerMove(PointerMoveEvent event) {
    // Fast-path: In active drawing stroke, route directly to gesture manager in O(1)
    if (_isDrawing) {
      final worldPos = _screenToWorld(event.localPosition);
      if (_lastPointerMovePos != null &&
          (worldPos - _lastPointerMovePos!).distance > 5.0) {
        _lastPointerMovePos = worldPos;
      }
      _lastHoverScreenPos = event.localPosition;
      if (widget.state.currentTool == CanvasTool.eraser) {
        _eraserCursorPosNotifier.value = event.localPosition;
      }
      _gestureManager.onPointerMove(
        event,
        currentZoom: _zoomScale,
        currentPan: _panOffset,
        currentTool: widget.state.currentTool.name,
      );
      return;
    }

    // ── Track GoodNotes Pull / Swipe Between Pages ─────────────────────────
    if (widget.state.isPageViewMode &&
        _isSwipeGestureActive &&
        _horizontalSwipePointerId == event.pointer &&
        _horizontalSwipeStartPos != null) {
      final deltaX = event.localPosition.dx - _horizontalSwipeStartPos!.dx;
      final isLastPage =
          widget.state.currentPageIndex >=
          (widget.state.canvasPages.length - 1);

      if (deltaX < 0) {
        // Dragging left -> Pulling next page or pulling to add new page
        final pullDist = -deltaX;
        if (isLastPage) {
          // Rubber-band resistance curve like GoodNotes
          final resisted = pullDist <= 60.0
              ? pullDist
              : 60.0 + (pullDist - 60.0) * 0.45;
          _sheetDragOffset = -resisted.clamp(0.0, 140.0);
          _horizontalPullDistance = pullDist.clamp(0.0, 160.0);

          // GoodNotes: Slide and Hold logic to add a new page
          if (pullDist >= 65.0) {
            if (!_isHoldingToAddPage &&
                !_addPageHoldCtrl.isAnimating &&
                _addPageHoldCtrl.value < 1.0) {
              _isHoldingToAddPage = true;
              _addPageHoldCtrl.forward(from: 0.0);
            }
          } else {
            if (_isHoldingToAddPage) {
              _isHoldingToAddPage = false;
              _addPageHoldCtrl.reset();
            }
          }
        } else {
          _sheetDragOffset = deltaX.clamp(-300.0, 0.0);
          _horizontalPullDistance = pullDist.clamp(0.0, 160.0);
        }
      } else {
        // Dragging right -> Pulling previous page
        if (_isHoldingToAddPage) {
          _isHoldingToAddPage = false;
          _addPageHoldCtrl.reset();
        }
        if (widget.state.currentPageIndex > 0) {
          _sheetDragOffset = deltaX.clamp(0.0, 300.0);
          _horizontalPullDistance = deltaX.clamp(0.0, 160.0);
        } else {
          // Page 1 rubber-band resistance
          _sheetDragOffset = (deltaX * 0.3).clamp(0.0, 50.0);
          _horizontalPullDistance = 0.0;
        }
      }
      setState(() {});
      return;
    }

    // ── Laser Pointer: Priority #1 presentation tool ─────────────────────────
    if (widget.state.currentTool == CanvasTool.laser) {
      final insidePaper = _isScreenPosInsidePaper(event.localPosition);
      if (widget.state.isPageViewMode && !insidePaper) {
        if (_activeLaserPoint != null) {
          _activeLaserPoint = null;
          setState(() {});
        }
        return;
      }

      final wasOutside = _activeLaserPoint == null;
      _activeLaserPoint = event.localPosition;
      if (_drawingState.laserMode == 'dot') {
        _laserDotAlpha = 1.0;
      } else if (_isDrawing) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final pt = _LaserPoint(event.localPosition, now);
        if (_laserStrokes.isNotEmpty && !wasOutside) {
          _laserStrokes.last.add(pt);
        } else {
          _laserStrokes.add([pt]);
        }
      }
      setState(() {});
      return;
    }

    // Study Tape live drag update
    if (_isDrawingTape && _tapeStartWorld != null) {
      final currentWorldPos = _screenToWorld(event.localPosition);
      setState(() {
        _tapeCurrentWorld = currentWorldPos;
      });
      return;
    }

    // Lasso selection drag (bypasses gesture manager)
    if (_isDraggingSelection && _lastSelectionDragPos != null) {
      final currentWorldPos = _screenToWorld(event.localPosition);
      final delta = currentWorldPos - _lastSelectionDragPos!;
      _lastSelectionDragPos = currentWorldPos;

      for (final obj in widget.state.selectedCanvasObjects) {
        if (obj is CanvasStrokeItem) {
          for (int i = 0; i < obj.points.length; i++) {
            final pt = obj.points[i];
            obj.points[i] = StrokePoint(
              x: pt.x + delta.dx,
              y: pt.y + delta.dy,
              pressure: pt.pressure,
              tilt: pt.tilt,
              velocity: pt.velocity,
              timestamp: pt.timestamp,
              isStylus: pt.isStylus,
            );
          }
          obj.invalidateCache();
        } else if (obj is CanvasShapeItem) {
          obj.bounds = obj.bounds.shift(delta);
          if (obj.startPoint != null) {
            obj.startPoint = obj.startPoint! + delta;
          }
          if (obj.endPoint != null) {
            obj.endPoint = obj.endPoint! + delta;
          }
        } else if (obj is CanvasTextItem) {
          obj.position += delta;
        } else if (obj is CanvasNoteCardItem) {
          obj.position += delta;
        } else if (obj is CanvasImageItem) {
          obj.bounds = obj.bounds.shift(delta);
        } else if (obj is CanvasTapeItem) {
          obj.rect = obj.rect.shift(delta);
        }
      }
      widget.state.notifyCanvasObjects();
      return;
    }

    // Image corner resize (live aspect-locked corner scaling)
    if (_isResizingImage &&
        _selectedImageId != null &&
        _resizingImageInitialBounds != null) {
      final selImg = _getSelectedImageItem();
      if (selImg != null) {
        final currentWorldPos = _screenToWorld(event.localPosition);
        final init = _resizingImageInitialBounds!;
        final aspect = _resizingImageInitialAspect > 0
            ? _resizingImageInitialAspect
            : 1.0;
        Rect newBounds = init;
        if (_resizingImageCorner == 'br') {
          final newW = math.max(60.0, currentWorldPos.dx - init.left);
          final newH = math.max(40.0, newW / aspect);
          newBounds = Rect.fromLTWH(init.left, init.top, newW, newH);
        } else if (_resizingImageCorner == 'bl') {
          final newW = math.max(60.0, init.right - currentWorldPos.dx);
          final newH = math.max(40.0, newW / aspect);
          newBounds = Rect.fromLTWH(init.right - newW, init.top, newW, newH);
        } else if (_resizingImageCorner == 'tr') {
          final newW = math.max(60.0, currentWorldPos.dx - init.left);
          final newH = math.max(40.0, newW / aspect);
          newBounds = Rect.fromLTWH(init.left, init.bottom - newH, newW, newH);
        } else if (_resizingImageCorner == 'tl') {
          final newW = math.max(60.0, init.right - currentWorldPos.dx);
          final newH = math.max(40.0, newW / aspect);
          newBounds = Rect.fromLTWH(init.right - newW, init.bottom - newH, newW, newH);
        }
        widget.state.resizeCanvasImageItem(
          selImg.id,
          newBounds,
          isLiveDrag: true,
        );
        setState(() {});
      }
      return;
    }

    // Text item width resize (live width adjustment with text wrapping)
    if (_isResizingTextWidth && _resizingTextItemId != null) {
      final idx = widget.state.canvasObjects.indexWhere(
        (o) => o.id == _resizingTextItemId,
      );
      if (idx != -1 && widget.state.canvasObjects[idx] is CanvasTextItem) {
        final item = widget.state.canvasObjects[idx] as CanvasTextItem;
        final currentW = item.boxWidth ?? item.getBoundingBox().width;
        final deltaW =
            (event.delta.dx / _zoomScale) * (_resizeFromLeft ? -1.0 : 1.0);
        final newW = (currentW + deltaW).clamp(80.0, 2400.0);
        Offset newPos = item.position;
        if (_resizeFromLeft) {
          newPos = Offset(
            item.position.dx + (event.delta.dx / _zoomScale),
            item.position.dy,
          );
        }
        widget.state.updateCanvasTextItem(
          item.copyWith(boxWidth: newW, position: newPos),
        );
      }
      setState(() {});
      return;
    }

    // Object live drag (bypasses gesture manager, 60/120fps direct repaint)
    if (_draggedObjectId != null && _lastDragWorldPos != null) {
      final currentWorldPos = _screenToWorld(event.localPosition);
      final delta = currentWorldPos - _lastDragWorldPos!;
      _lastDragWorldPos = currentWorldPos;

      widget.state.moveCanvasObject(
        _draggedObjectId!,
        delta,
        isLiveDrag: true,
      );
      return;
    }

    // Hand tool / space-bar / middle-mouse / right-mouse pan
    if (_isPanning) {
      setState(() {
        if (widget.state.isPageViewMode) {
          final dx = _clampPanDx(
            _panOffset.dx + event.delta.dx,
            _zoomScale,
            _canvasSize,
          );
          final dy = _clampPanDy(
            _panOffset.dy + event.delta.dy,
            _zoomScale,
            _canvasSize,
          );
          _panOffset = Offset(dx, dy);
        } else {
          _panOffset += event.delta;
        }
      });
      return;
    }

    // All other tools: delegate to gesture manager
    // Update last-move tracking for draw-and-hold shape recognition
    final worldPos = _screenToWorld(event.localPosition);
    if (_lastPointerMovePos != null &&
        (worldPos - _lastPointerMovePos!).distance > 5.0) {
      _lastPointerMovePos = worldPos;
    }

    _lastHoverScreenPos = event.localPosition;
    if (widget.state.currentTool == CanvasTool.eraser) {
      _eraserCursorPosNotifier.value = event.localPosition;
    }

    _gestureManager.onPointerMove(
      event,
      currentZoom: _zoomScale,
      currentPan: _panOffset,
      currentTool: widget.state.currentTool.name,
    );
  }

  void _onPointerUp(PointerUpEvent event) {
    // Fast-path: When drawing stroke concludes, route directly to gesture manager in O(1)
    if (_isDrawing) {
      _lastEraseWorldPos = null;
      _isErasingActive = false;
      _isErasingActiveNotifier.value = false;
      _eraserCursorPosNotifier.value = null;
      CanvasPerformanceProfiler.instance.markPointerUp();
      _gestureManager.onPointerUp(event);
      _isDrawing = false;
      return;
    }

    // ── Complete GoodNotes Page Swipe & Pull to Add Page ─────────────────────
    if (_horizontalSwipePointerId == event.pointer) {
      final isLastPage =
          widget.state.currentPageIndex >=
          (widget.state.canvasPages.length - 1);
      final deltaX = _horizontalSwipeStartPos != null
          ? (event.localPosition.dx - _horizontalSwipeStartPos!.dx)
          : 0.0;

      // Cancel any incomplete hold
      if (_isHoldingToAddPage) {
        _isHoldingToAddPage = false;
        _addPageHoldCtrl.reset();
      }

      if (_isSwipeGestureActive) {
        if (deltaX <= -50.0) {
          // Dragged Left -> Next page or spring back if on last page (page creation requires slide-and-hold)
          if (isLastPage) {
            _springBack();
          } else {
            _navigateToNextPage();
          }
        } else if (deltaX >= 50.0 && widget.state.currentPageIndex > 0) {
          // Dragged Right -> Previous page
          _navigateToPrevPage();
        } else {
          _springBack();
        }
      }

      setState(() {
        _horizontalPullDistance = 0.0;
        _horizontalSwipeStartPos = null;
        _horizontalSwipePointerId = null;
        _isSwipeGestureActive = false;
      });
      return;
    }

    // ── Laser Pointer: Priority #1 presentation tool ─────────────────────────
    if (widget.state.currentTool == CanvasTool.laser) {
      _isDrawing = false;
      _activeLaserPoint = null;
      if (_drawingState.laserMode == 'dot') {
        _startLaserDotFade();
      } else {
        // GoodNotes: on pen lift, wait for inactivity before dissolving
        _scheduleLaserInactivityFade();
      }
      setState(() {});
      return;
    }

    _lastEraseWorldPos = null;
    _isErasingActive = false;
    _isErasingActiveNotifier.value = false;
    if (_hasErasedInCurrentGesture) {
      _hasErasedInCurrentGesture = false;
      widget.state.commitLiveCanvasChanges();
    }
    if (event.kind == PointerDeviceKind.touch ||
        event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus) {
      _eraserCursorPosNotifier.value = null;
    }

    // Study Tape creation commit
    if (_isDrawingTape &&
        _tapeStartWorld != null &&
        _tapeCurrentWorld != null) {
      final left = math.min(_tapeStartWorld!.dx, _tapeCurrentWorld!.dx);
      final top = math.min(_tapeStartWorld!.dy, _tapeCurrentWorld!.dy);
      final width = (_tapeCurrentWorld!.dx - _tapeStartWorld!.dx).abs();
      final height = _drawingState.tapeHeight;
      if (width > 8.0) {
        final tapeRect = Rect.fromLTWH(left, top - (height / 2), width, height);
        final tape = CanvasTapeItem(
          id: 'tape-${DateTime.now().microsecondsSinceEpoch}',
          rect: tapeRect,
          color: _drawingState.tapeColor,
          isMasked: true,
        );
        widget.state.addCanvasObject(tape);
      }

      setState(() {
        _isDrawingTape = false;
        _tapeStartWorld = null;
        _tapeCurrentWorld = null;
      });
      return;
    }

    // Lasso selection drag completion
    if (_isDraggingSelection) {
      setState(() {
        _isDraggingSelection = false;
        _lastSelectionDragPos = null;
      });
      widget.state.notifyCanvasUpdate();
      return;
    }

    // Image resize completion
    if (_isResizingImage) {
      setState(() {
        _isResizingImage = false;
        _resizingImageCorner = null;
        _resizingImageInitialBounds = null;
      });
      widget.state.commitLiveCanvasChanges();
      return;
    }

    // Text item width resize completion
    if (_isResizingTextWidth) {
      setState(() {
        _isResizingTextWidth = false;
        _resizingTextItemId = null;
      });
      widget.state.commitLiveCanvasChanges();
      return;
    }

    // Object drag completion (text, badge, stamp, sticker, image, shape)
    if (_draggedObjectId != null || _draggedTextItemId != null) {
      _draggedObjectId = null;
      _draggedTextItemId = null;
      _lastDragWorldPos = null;
      widget.state.commitLiveCanvasChanges();
      return;
    }

    // Hand tool pan completion
    if (_isPanning) {
      setState(() {
        _isPanning = false;
      });
      return;
    }

    // Lasso commit (driven directly by state, not gesture manager stroke)
    final tool = widget.state.currentTool;
    if (tool == CanvasTool.lasso) {
      if (_drawingState.lassoMode == LassoSelectionMode.freehand) {
        if (_lassoPoints.length > 2) {
          widget.state.selectCanvasObjectsInPolygon(
            _lassoPoints,
            filter: _drawingState.isObjectEligibleForLasso,
          );
        } else {
          widget.state.clearCanvasSelection();
        }
        setState(() {
          _isLassoing = false;
          _lassoPoints.clear();
        });
      } else if (_dragStart != null && _dragCurrent != null) {
        final rect = Rect.fromPoints(_dragStart!, _dragCurrent!);
        if (rect.width > 5 || rect.height > 5) {
          widget.state.selectCanvasObjectsInRect(
            rect,
            filter: _drawingState.isObjectEligibleForLasso,
          );
        } else {
          widget.state.clearCanvasSelection();
        }
        setState(() {
          _dragStart = null;
          _dragCurrent = null;
        });
      } else {
        widget.state.clearCanvasSelection();
      }
      _gestureManager.onPointerUp(event);
      return;
    }

    // Shape commit
    if (_dragStart != null && _dragCurrent != null) {
      if (tool == CanvasTool.rectangle ||
          tool == CanvasTool.circle ||
          tool == CanvasTool.triangle ||
          tool == CanvasTool.line ||
          tool == CanvasTool.arrow) {
        final rect = Rect.fromPoints(_dragStart!, _dragCurrent!);
        final clampedRect = widget.state.isPageViewMode
            ? rect.intersect(_kPageRect)
            : rect;
        if (!clampedRect.isEmpty &&
            (clampedRect.width > 5 || clampedRect.height > 5)) {
          final shape = CanvasShapeItem(
            id: 'shape-${DateTime.now().microsecondsSinceEpoch}',
            shapeType: tool.name,
            bounds: clampedRect,
            strokeColor: widget.state.strokeColor,
            strokeWidth: widget.state.strokeWidth,
            startPoint: _dragStart,
            endPoint: _dragCurrent,
          );
          widget.state.addCanvasObject(shape);
        }
      }
      setState(() {
        _dragStart = null;
        _dragCurrent = null;
      });
      _gestureManager.onPointerUp(event);
      return;
    }

    // All other tools (pen, pencil, highlighter, eraser) — delegate for stroke commit
    _gestureManager.onPointerUp(event);
    _isDrawing = false;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _lastEraseWorldPos = null;
    _isErasingActive = false;
    _isErasingActiveNotifier.value = false;
    if (event.kind == PointerDeviceKind.touch ||
        event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus) {
      _eraserCursorPosNotifier.value = null;
    }
    if (_hasErasedInCurrentGesture) {
      _hasErasedInCurrentGesture = false;
      widget.state.commitLiveCanvasChanges();
    }
    if (_isSwipeGestureActive) {
      _springBack();
      setState(() {
        _horizontalPullDistance = 0.0;
        _horizontalSwipeStartPos = null;
        _horizontalSwipePointerId = null;
        _isSwipeGestureActive = false;
      });
    }

    _gestureManager.onPointerCancel(event);
    // Only finalize/clear stroke if the gesture manager actually ended the drawing state
    if (_gestureManager.state == CanvasInputState.idle) {
      _currentStrokePoints.clear();
      _drawingState.liveStrokeNotifier.clear();
      setState(() {
        _isDrawing = false;
        _isLassoing = false;
        _lassoPoints.clear();
        _dragStart = null;
        _dragCurrent = null;
        _laserStrokes.clear();
        _activeLaserPoint = null;
        _isPanning = false;
        _isDrawingTape = false;
        _tapeStartWorld = null;
        _tapeCurrentWorld = null;
      });
    }
  }

  /// GoodNotes: on pen lift, wait 1.3 seconds of inactivity before dissolving.
  /// If user writes another word within 1.3s, the timer cancels and all words stay!
  void _scheduleLaserInactivityFade() {
    _laserHoldTimer?.cancel();
    _laserFadeTimer?.cancel();
    _laserMasterFade = 1.0;

    _laserHoldTimer = Timer(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      _startLaserMasterFadeOut();
    });
  }

  /// Smoothly dissolves all written laser strokes over 1000ms.
  void _startLaserMasterFadeOut() {
    _laserFadeTimer?.cancel();
    const totalMs = 1000;
    const stepMs = 16;
    final steps = totalMs ~/ stepMs;
    int step = 0;

    _laserFadeTimer = Timer.periodic(const Duration(milliseconds: stepMs), (
      timer,
    ) {
      step++;
      if (step >= steps || !mounted) {
        timer.cancel();
        _laserFadeTimer = null;
        if (mounted) {
          setState(() {
            _laserStrokes.clear();
            _laserMasterFade = 1.0;
            _activeLaserPoint = null;
          });
        }
      } else {
        if (mounted) {
          final progress = step / steps;
          final eased = 1.0 - math.pow(progress, 2.0).toDouble();
          setState(() {
            _laserMasterFade = eased.clamp(0.0, 1.0);
          });
        }
      }
    });
  }

  /// While writing continuously for an extended time (e.g. > 12s),
  /// gently prune very old strokes so the screen doesn't accumulate indefinitely.
  void _startLaserMaxAgeTimer() {
    if (_laserMaxAgeTimer != null && _laserMaxAgeTimer!.isActive) return;
    _laserMaxAgeTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        _laserMaxAgeTimer = null;
        return;
      }
      if (_laserStrokes.isEmpty && !_isDrawing) {
        timer.cancel();
        _laserMaxAgeTimer = null;
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      bool changed = false;

      // Only prune strokes if older than 12 seconds
      for (int s = _laserStrokes.length - 1; s >= 0; s--) {
        final stroke = _laserStrokes[s];
        if (stroke.isNotEmpty &&
            (now - stroke.first.timestamp > _laserMaxStrokeAgeMs)) {
          _laserStrokes.removeAt(s);
          changed = true;
        }
      }

      if (changed && mounted) {
        setState(() {});
      }
    });
  }

  void _startLaserDotFade() {
    _laserDotFadeTimer?.cancel();
    const totalMs = 250;
    const stepMs = 16;
    final steps = totalMs ~/ stepMs;
    int step = 0;
    _laserDotFadeTimer = Timer.periodic(const Duration(milliseconds: stepMs), (
      timer,
    ) {
      step++;
      if (step >= steps || !mounted) {
        timer.cancel();
        _laserDotFadeTimer = null;
        if (mounted) {
          setState(() {
            _laserDotAlpha = 0.0;
            _activeLaserPoint = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _laserDotAlpha = (1.0 - (step / steps)).clamp(0.0, 1.0);
          });
        }
      }
    });
  }

  void _clearLaser() {
    _laserHoldTimer?.cancel();
    _laserHoldTimer = null;
    _laserFadeTimer?.cancel();
    _laserFadeTimer = null;
    _laserMaxAgeTimer?.cancel();
    _laserMaxAgeTimer = null;
    _laserDotFadeTimer?.cancel();
    _laserDotFadeTimer = null;
    _laserStrokes.clear();
    _activeLaserPoint = null;
    _laserDotAlpha = 1.0;
    _laserMasterFade = 1.0;
  }

  void _onPointerHover(PointerHoverEvent event) {
    _lastHoverScreenPos = event.localPosition;
    _gestureManager.onPointerHover(event);
    if (widget.state.currentTool == CanvasTool.laser) {
      if (widget.state.isPageViewMode &&
          !_isScreenPosInsidePaper(event.localPosition)) {
        if (_activeLaserPoint != null) {
          setState(() {
            _activeLaserPoint = null;
          });
        }
      }
    }
    if (widget.state.currentTool == CanvasTool.eraser) {
      _eraserCursorPosNotifier.value = event.localPosition;
    } else if (_eraserCursorPosNotifier.value != null) {
      _eraserCursorPosNotifier.value = null;
      _isErasingActiveNotifier.value = false;
    }
  }

  // ── iPadOS Trackpad / Magic Keyboard Pinch-to-Zoom & Pan ────────────────────
  // Flutter sends PointerPanZoomStart/Update/End for trackpad gestures.
  // These are essential for iPadOS with Magic Keyboard / trackpad.
  double _trackpadStartScale = 1.0;
  Offset _trackpadStartPan = Offset.zero;
  Offset _trackpadFocalPoint = Offset.zero;

  void _onPointerPanZoomStart(PointerPanZoomStartEvent event) {
    _trackpadStartScale = _zoomScale;
    _trackpadStartPan = _panOffset;
    _trackpadFocalPoint = event.localPosition;
  }

  void _onPointerPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    setState(() {
      // Trackpad pinch-to-zoom with invariant focal-point
      final newScale = (_trackpadStartScale * event.scale).clamp(0.20, 5.0);
      final newPan =
          event.localPosition -
          (_trackpadFocalPoint - _trackpadStartPan) *
              (newScale / _trackpadStartScale) +
          event.panDelta;

      _zoomScale = newScale;
      if (widget.state.isPageViewMode) {
        final dx = _clampPanDx(newPan.dx, _zoomScale, _canvasSize);
        final dy = _clampPanDy(newPan.dy, _zoomScale, _canvasSize);
        _panOffset = Offset(dx, dy);
      } else {
        _panOffset = newPan;
      }
    });
  }

  void _onPointerPanZoomEnd(PointerPanZoomEndEvent event) {
    // No-op: trackpad gesture completed, state is already updated
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final isCtrl =
          HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;
      if (isCtrl) {
        final zoomDelta = -event.scrollDelta.dy * 0.0015;
        final oldScale = _zoomScale;
        final newScale = (oldScale + zoomDelta).clamp(0.2, 5.0);
        final focal = event.localPosition;
        final newOffset = focal - (focal - _panOffset) * (newScale / oldScale);
        setState(() {
          _zoomScale = newScale;
          if (widget.state.isPageViewMode) {
            final dx = _clampPanDx(newOffset.dx, _zoomScale, _canvasSize);
            final dy = _clampPanDy(newOffset.dy, _zoomScale, _canvasSize);
            _panOffset = Offset(dx, dy);
          } else {
            _panOffset = newOffset;
          }
        });
      } else {
        setState(() {
          if (widget.state.isPageViewMode) {
            final dx = _clampPanDx(
              _panOffset.dx - event.scrollDelta.dx,
              _zoomScale,
              _canvasSize,
            );
            final dy = _clampPanDy(
              _panOffset.dy - event.scrollDelta.dy,
              _zoomScale,
              _canvasSize,
            );
            _panOffset = Offset(dx, dy);
            _updateActivePageFromScrollPosition();
          } else {
            _panOffset -= event.scrollDelta;
          }
        });
      }
    }
  }

  void _eraseAt(Offset worldPos) {
    if (widget.state.isPageViewMode && !_isWorldPosInsidePaper(worldPos)) {
      return; // Do not erase outside paper
    }
    final mode = _drawingState.eraserMode;
    const eraserTool = EraserTool();
    final effectiveRadius = _effectiveEraserWorldRadius;

    // Fast path interpolation: if mouse/stylus moved rapidly between frames, erase along the line
    final List<Offset> pointsToErase = [];
    if (_lastEraseWorldPos != null) {
      final dist = (worldPos - _lastEraseWorldPos!).distance;
      final step = (effectiveRadius * 0.4).clamp(4.0, 16.0);
      if (dist > step) {
        final steps = (dist / step).floor();
        for (int i = 1; i <= steps; i++) {
          final t = i / (steps + 1);
          pointsToErase.add(Offset.lerp(_lastEraseWorldPos!, worldPos, t)!);
        }
      }
    }
    pointsToErase.add(worldPos);
    _lastEraseWorldPos = worldPos;

    var currentObjects = widget.state.canvasObjects;
    bool anyChanged = false;

    for (final pt in pointsToErase) {
      final updated = eraserTool.eraseAt(
        point: pt,
        objects: currentObjects,
        overrideRadius: effectiveRadius,
        overrideMode: mode,
        eraseHighlighterOnly: _drawingState.eraseHighlighterOnly,
      );
      if (!identical(updated, currentObjects)) {
        currentObjects = updated;
        anyChanged = true;
      }
    }

    if (anyChanged) {
      final shouldPushUndo = !_isErasingActive;
      _isErasingActive = true;
      _isErasingActiveNotifier.value = true;
      _hasErasedInCurrentGesture = true;
      widget.state.setCanvasObjects(
        currentObjects,
        pushUndo: shouldPushUndo,
        isLiveSession: true,
      );
    }
  }

  // ── Inline Text Editing (GoodNotes-style) ────────────────────────────────────

  void _startInlineTextEditing(
    Offset screenPos, {
    CanvasTextItem? existingItem,
  }) {
    if (existingItem == null &&
        widget.state.isPageViewMode &&
        !_isScreenPosInsidePaper(screenPos)) {
      return; // Outside paper writing not allowed for new items
    }
    _editingExistingTextId = existingItem?.id;
    if (existingItem != null) {
      _inlineTextCtrl.text = existingItem.text;
    } else {
      _inlineTextCtrl.clear();
    }
    setState(() {
      _isInlineTextEditing = true;
      _showTextFormatToolbar = false;
      _inlineTextScreenPos = screenPos;
    });
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) {
        _inlineTextFocusNode.requestFocus();
        _inlineTextCtrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _inlineTextCtrl.text.length,
        );
      }
    });
  }

  void _commitInlineText() {
    final text = _inlineTextCtrl.text.trim();
    if (text.isNotEmpty) {
      if (_editingExistingTextId != null) {
        final idx = widget.state.canvasObjects.indexWhere(
          (o) => o.id == _editingExistingTextId,
        );
        if (idx != -1 && widget.state.canvasObjects[idx] is CanvasTextItem) {
          final existing = widget.state.canvasObjects[idx] as CanvasTextItem;
          final updated = existing.copyWith(text: text);
          widget.state.updateCanvasTextItem(updated);
          _selectedTextItemId = updated.id;
          _showTextFormatToolbar = true;
        }
      } else {
        final worldPos = _screenToWorld(_inlineTextScreenPos);
        if (!widget.state.isPageViewMode || _isWorldPosInsidePaper(worldPos)) {
          final textItem = CanvasTextItem(
            id: 'text-${DateTime.now().millisecondsSinceEpoch}',
            text: text,
            position: worldPos,
            color: widget.state.strokeColor,
            fontSize: 18.0,
            padding: 8.0,
          );
          widget.state.addCanvasObject(textItem);
          _selectedTextItemId = textItem.id;
          _showTextFormatToolbar = true;
        }
      }
    } else if (_editingExistingTextId != null) {
      // Empty text commits as delete in GoodNotes
      final idx = widget.state.canvasObjects.indexWhere(
        (o) => o.id == _editingExistingTextId,
      );
      if (idx != -1) {
        widget.state.removeCanvasObject(widget.state.canvasObjects[idx]);
      }
      _selectedTextItemId = null;
      _showTextFormatToolbar = false;
    }
    setState(() {
      _isInlineTextEditing = false;
      _editingExistingTextId = null;
      _inlineTextCtrl.clear();
    });
    _canvasFocusNode.requestFocus();
  }

  Widget _buildInlineTextEditor(bool isDark) {
    CanvasTextItem? existing;
    if (_editingExistingTextId != null) {
      for (final o in widget.state.canvasObjects) {
        if (o.id == _editingExistingTextId && o is CanvasTextItem) {
          existing = o;
          break;
        }
      }
    }

    final fontFamily = existing?.fontFamily ?? 'Inter';
    final fontSize = (existing?.fontSize ?? 18.0) * _zoomScale;
    final isBold = existing?.isBold ?? false;
    final isItalic = existing?.isItalic ?? false;
    final isUnderline = existing?.isUnderline ?? false;
    final isStrikethrough = existing?.isStrikethrough ?? false;
    final alignment = existing?.alignment ?? TextAlign.left;
    final textColor = existing?.color ?? widget.state.strokeColor;
    final bgColor =
        existing?.backgroundColor ??
        (isDark ? const Color(0xEE1E2436) : Colors.white);
    final borderColor = existing?.borderColor ?? const Color(0xFF6366F1);
    final borderWidth = existing?.borderColor != null
        ? (existing!.borderWidth > 0 ? existing.borderWidth : 1.5)
        : 1.5;
    final borderRadius = existing?.borderRadius ?? 8.0;
    final paddingVal = (existing?.padding ?? 10.0) * _zoomScale;
    final boxWidth = existing?.boxWidth != null
        ? (existing!.boxWidth! * _zoomScale)
        : null;

    TextDecoration decoration = TextDecoration.none;
    if (isUnderline && isStrikethrough) {
      decoration = TextDecoration.combine([
        TextDecoration.underline,
        TextDecoration.lineThrough,
      ]);
    } else if (isUnderline) {
      decoration = TextDecoration.underline;
    } else if (isStrikethrough) {
      decoration = TextDecoration.lineThrough;
    }

    TextStyle textStyle;
    try {
      textStyle = GoogleFonts.getFont(
        fontFamily,
        color: textColor,
        fontSize: fontSize.clamp(12.0, 72.0),
        fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
        fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: decoration,
        height: existing?.lineHeight ?? 1.35,
      );
    } catch (_) {
      textStyle = TextStyle(
        fontFamily: fontFamily,
        color: textColor,
        fontSize: fontSize.clamp(12.0, 72.0),
        fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
        fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: decoration,
        height: existing?.lineHeight ?? 1.35,
      );
    }

    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Floating Mini Action Bar above the active text box
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2436) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF2E3852)
                    : const Color(0xFFCBD5E1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.edit_note_rounded,
                  size: 16,
                  color: Color(0xFF6366F1),
                ),
                const SizedBox(width: 4),
                Text(
                  fontFamily,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${(existing?.fontSize ?? 18.0).toInt()}pt',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 14,
                  color: isDark ? Colors.white24 : Colors.black12,
                ),
                const SizedBox(width: 6),
                // Commit Done Button
                InkWell(
                  onTap: _commitInlineText,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'Done',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Cancel Button
                InkWell(
                  onTap: () {
                    setState(() {
                      _isInlineTextEditing = false;
                      _editingExistingTextId = null;
                      _inlineTextCtrl.clear();
                    });
                    _canvasFocusNode.requestFocus();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Text Box Editor Container
          Container(
            width: boxWidth,
            constraints: BoxConstraints(
              minWidth: 160.0 * _zoomScale,
              maxWidth: math.max(380.0 * _zoomScale, (boxWidth ?? 400.0)),
            ),
            padding: EdgeInsets.all(paddingVal.clamp(6.0, 24.0)),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderColor,
                width: borderWidth.clamp(1.0, 3.0),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IntrinsicWidth(
              child: TextField(
                controller: _inlineTextCtrl,
                focusNode: _inlineTextFocusNode,
                autofocus: true,
                minLines: 1,
                maxLines: null,
                textAlign: alignment,
                style: textStyle,
                cursorColor: const Color(0xFF6366F1),
                decoration: InputDecoration(
                  hintText: 'Type your note…',
                  hintStyle: textStyle.copyWith(
                    color: textColor.withValues(alpha: 0.38),
                  ),
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotebookPagesOverviewDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) =>
          _NotebookPagesOverviewDialog(state: widget.state, isDark: isDark),
    );
  }

  Widget _buildTravelControls(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceGlass
            : AppColors.lightSurfaceGlass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorderAccent
              : AppColors.lightBorderAccent,
        ),
        boxShadow: isDark
            ? AppColors.cardShadowDark
            : AppColors.cardShadowLight,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hand tool quick toggle
          Tooltip(
            message: 'Hand tool (Pan/Travel) [Space]',
            child: InkWell(
              onTap: () {
                widget.state.setCanvasTool(
                  widget.state.currentTool == CanvasTool.hand
                      ? CanvasTool.pen
                      : CanvasTool.hand,
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: widget.state.currentTool == CanvasTool.hand
                      ? AppColors.primary.withValues(alpha: 0.25)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.pan_tool_rounded,
                  size: 16,
                  color: widget.state.currentTool == CanvasTool.hand
                      ? AppColors.primary
                      : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 1,
            height: 16,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          const SizedBox(width: 4),

          // Zoom out [-]
          Tooltip(
            message: 'Zoom Out',
            child: InkWell(
              onTap: () {
                setState(() {
                  _zoomScale = (_zoomScale * 0.85).clamp(0.2, 5.0);
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.remove_rounded,
                  size: 16,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ),
          ),

          // Zoom % readout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '${(_zoomScale * 100).round()}%',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          ),

          // Zoom in [+]
          Tooltip(
            message: 'Zoom In',
            child: InkWell(
              onTap: () {
                setState(() {
                  _zoomScale = (_zoomScale * 1.15).clamp(0.2, 5.0);
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ),
          ),

          const SizedBox(width: 4),
          Container(
            width: 1,
            height: 16,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          const SizedBox(width: 4),

          // Reset to Center / Home
          Tooltip(
            message: 'Reset View / Center Canvas',
            child: InkWell(
              onTap: () {
                setState(() {
                  _panOffset = Offset.zero;
                  _zoomScale = 1.0;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.center_focus_strong_rounded,
                  size: 16,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getPaperStyleLabel(CanvasPaperStyle style) {
    switch (style) {
      case CanvasPaperStyle.ruledLines:
        return 'Ruled Lines';
      case CanvasPaperStyle.narrowRuled:
        return 'Narrow Ruled';
      case CanvasPaperStyle.cornell:
        return 'Cornell Notes';
      case CanvasPaperStyle.dotGrid:
        return 'Dot Grid';
      case CanvasPaperStyle.graphGrid:
        return 'Graph Grid';
      case CanvasPaperStyle.blankSlate:
        return 'Blank Slate';
      case CanvasPaperStyle.planner:
        return 'Daily Planner';
    }
  }

  void _openPenOptionsPopover(BuildContext context) {
    setState(() {
      if (widget.state.currentTool == CanvasTool.lasso) {
        _showLassoOptionsDialog = !_showLassoOptionsDialog;
        if (_showLassoOptionsDialog) {
          _showPenOptionsDialog = false;
          _showElementsPanel = false;
        }
      } else {
        _showPenOptionsDialog = !_showPenOptionsDialog;
        if (_showPenOptionsDialog) {
          _showLassoOptionsDialog = false;
          _showElementsPanel = false;
        }
      }
    });
  }

  void _showExportDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2333) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.ios_share_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Share & Export',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.picture_as_pdf_outlined,
                color: Colors.redAccent,
              ),
              title: const Text('Export as PDF (.pdf)'),
              subtitle: const Text(
                'All notebook pages in formatted PDF document',
              ),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                await widget.state.forceSyncCanvas();
                final doc = widget.state.currentCanvasDoc;
                if (doc != null) {
                  try {
                    await WorkspaceExportService.exportNotebook(
                      doc: doc,
                      format: 'pdf',
                    );
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF10B981),
                        content: Text(
                          'Notebook "${doc.name}" exported to PDF (.pdf) successfully!',
                        ),
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFFEF4444),
                        content: Text('Failed to export PDF: $e'),
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.description_outlined,
                color: Colors.blueAccent,
              ),
              title: const Text('Export as Word (.docx)'),
              subtitle: const Text(
                'Microsoft Word document with pages & notes',
              ),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                await widget.state.forceSyncCanvas();
                final doc = widget.state.currentCanvasDoc;
                if (doc != null) {
                  try {
                    await WorkspaceExportService.exportNotebook(
                      doc: doc,
                      format: 'docx',
                    );
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF10B981),
                        content: Text(
                          'Notebook "${doc.name}" exported to Word (.docx) successfully!',
                        ),
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFFEF4444),
                        content: Text('Failed to export Word document: $e'),
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.code_rounded, color: Colors.teal),
              title: const Text('Export as Markdown (.md)'),
              subtitle: const Text(
                'Structured markdown with note cards & pages',
              ),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                await widget.state.forceSyncCanvas();
                final doc = widget.state.currentCanvasDoc;
                if (doc != null) {
                  try {
                    await WorkspaceExportService.exportNotebook(
                      doc: doc,
                      format: 'md',
                    );
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF10B981),
                        content: Text(
                          'Notebook "${doc.name}" exported to Markdown (.md) successfully!',
                        ),
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFFEF4444),
                        content: Text('Failed to export Markdown: $e'),
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.image_outlined,
                color: Colors.blueAccent,
              ),
              title: const Text('Export Active Page as PNG'),
              subtitle: const Text('High fidelity lossless image'),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                await widget.state.forceSyncCanvas();
                final doc = widget.state.currentCanvasDoc;
                if (doc != null) {
                  try {
                    await WorkspaceExportService.exportActivePageAsPng(
                      doc: doc,
                      pageIndex: widget.state.currentPageIndex,
                    );
                    messenger.showSnackBar(
                      const SnackBar(
                        backgroundColor: Color(0xFF10B981),
                        content: Text(
                          'Active page exported as PNG successfully!',
                        ),
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFFEF4444),
                        content: Text('Failed to export PNG: $e'),
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded, color: Colors.green),
              title: const Text('Copy Collaborative Link'),
              subtitle: const Text('Share read/write access with teammates'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(
                  ClipboardData(
                    text:
                        'https://notes.workspace/doc/${widget.state.currentCanvasDoc?.id ?? "1"}',
                  ),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Collaboration link copied to clipboard!'),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatPdfPageContent(PdfPageData pageData) {
    if (pageData.rawContent != null && pageData.rawContent!.trim().isNotEmpty) {
      return pageData.rawContent!.trim();
    }
    final buffer = StringBuffer();
    buffer.writeln(pageData.sectionTitle);
    buffer.writeln('');
    buffer.writeln(pageData.summary);
    if (pageData.bulletPoints.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Key Points:');
      for (final bp in pageData.bulletPoints) {
        buffer.writeln('• $bp');
      }
    }
    if (pageData.keyTakeaway.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('💡 Takeaway: ${pageData.keyTakeaway}');
    }
    return buffer.toString();
  }

  Future<void> _pickAndInsertImage() async {
    try {
      Uint8List? bytes;
      String? filePath;

      // 1. Try FilePicker first - robust across Web, Windows Desktop and Mobile
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: true,
        );
        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;
          bytes = file.bytes;
          filePath = file.path;
        }
      } catch (pickerErr) {
        debugPrint('FilePicker image error: $pickerErr');
      }

      // 2. Fallback to ImagePicker if FilePicker had no result or failed
      if (bytes == null) {
        final picker = ImagePicker();
        final XFile? file = await picker.pickImage(source: ImageSource.gallery);
        if (file != null) {
          bytes = await file.readAsBytes();
          filePath = file.path;
        }
      }

      if (bytes != null) {
        // Downsample and decode directly to avoid massive texture memory & canvas lag
        ui.Codec codec;
        try {
          codec = await ui.instantiateImageCodec(
            bytes,
            targetWidth: 1600, // Downscale ultra-high-res images cleanly
          );
        } catch (_) {
          codec = await ui.instantiateImageCodec(bytes);
        }
        final frameInfo = await codec.getNextFrame();
        final ui.Image decodedUiImage = frameInfo.image;
        final double naturalW = decodedUiImage.width.toDouble();
        final double naturalH = decodedUiImage.height.toDouble();
        final double aspect = (naturalW > 0 && naturalH > 0)
            ? (naturalW / naturalH)
            : (4.0 / 3.0);

        // Compress downsampled image to lightweight PNG bytes for persistence
        String base64String;
        try {
          final byteData =
              await decodedUiImage.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            base64String = base64Encode(byteData.buffer.asUint8List());
          } else {
            base64String = base64Encode(bytes);
          }
        } catch (_) {
          base64String = base64Encode(bytes);
        }

        // Calculate proportional display size (standard GoodNotes initial width ~360)
        double initialW = 360.0;
        double initialH = initialW / aspect;
        if (initialH > 500.0) {
          initialH = 500.0;
          initialW = initialH * aspect;
        }

        final centerScreen =
            Offset(_canvasSize?.width ?? 600, _canvasSize?.height ?? 600) / 2;
        Offset worldCenter = _screenToWorld(centerScreen);
        if (widget.state.isPageViewMode) {
          final clampedX = worldCenter.dx.clamp(
            _kPageLeft + initialW / 2 + 20,
            _kPageLeft + _kPageWidth - initialW / 2 - 20,
          );
          final clampedY = worldCenter.dy.clamp(
            _kPageTop + initialH / 2 + 20,
            _kPageTop + _kPageHeight - initialH / 2 - 20,
          );
          worldCenter = Offset(clampedX, clampedY);
        }

        final imageId = 'img-${DateTime.now().millisecondsSinceEpoch}';
        final imageItem = CanvasImageItem(
          id: imageId,
          bounds: Rect.fromCenter(
            center: worldCenter,
            width: initialW,
            height: initialH,
          ),
          localFilePath: filePath,
          base64Data: base64String,
        );

        // Pre-cache decoded ui.Image immediately so frame 0 has ZERO decode lag
        _decodedImagesCache[imageId] = decodedUiImage;

        widget.state.addCanvasObject(imageItem);
        setState(() {
          _selectedImageId = imageId;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image inserted onto canvas'),
              backgroundColor: Color(0xFF10B981),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _pickAndInsertPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final Uint8List? bytes = file.bytes;

        if (!mounted) return;
        await showGoodNotesPdfImportDialog(
          context: context,
          state: widget.state,
          fileName: file.name,
          sizeBytes: file.size,
          fileBytes: bytes,
          onImportAsNotebookPages: (doc) {
            _importPdfPagesToNotebook(doc);
          },
          onSelectStudyCard: (doc) {
            _insertPdfStudyCardOnCanvas(doc);
          },
        );
      }
    } catch (e) {
      debugPrint('Error picking PDF: $e');
    }
  }

  void _importPdfPagesToNotebook(PdfDocumentData doc) {
    final existingPages = widget.state.canvasPages;
    final isInitialBlankPage =
        existingPages.length == 1 && existingPages.first.objects.isEmpty;

    int startIdx = 0;
    if (isInitialBlankPage && doc.pages.isNotEmpty) {
      final p1 = doc.pages.first;
      final textContent = _formatPdfPageContent(p1);

      final textItem = CanvasTextItem(
        id: 'pdf-text-${doc.id}-${p1.pageNumber}',
        text: textContent,
        position: const Offset(-370, 20),
        color: widget.state.isDarkMode
            ? const Color(0xFFF1F5F9)
            : const Color(0xFF0F172A),
        fontSize: 15.0,
        fontFamily: 'Inter',
        lineHeight: 1.55,
        boxWidth: 740.0,
        paperStyle: 'blank',
        padding: 20.0,
        backgroundColor: widget.state.isDarkMode
            ? const Color(0xFF1E2436)
            : const Color(0xFFFAFBFC),
        borderColor: widget.state.isDarkMode
            ? const Color(0xFF334155)
            : const Color(0xFFE2E8F0),
        borderWidth: 1.2,
        borderRadius: 14.0,
      );

      final p1Doc = CanvasPage(
        id: 'pdf-page-${doc.id}-1-${DateTime.now().millisecondsSinceEpoch}',
        pageNumber: 1,
        title: '${doc.title} (p.1)',
        paperStyle: CanvasPaperStyle.blankSlate,
        objects: [textItem],
      );
      widget.state.currentCanvasDoc?.pages[0] = p1Doc;
      startIdx = 0;

      for (int i = 1; i < doc.pages.length; i++) {
        final pageData = doc.pages[i];
        final pageTitle = '${doc.title} (p.${pageData.pageNumber})';
        final itemText = _formatPdfPageContent(pageData);

        final item = CanvasTextItem(
          id: 'pdf-text-${doc.id}-${pageData.pageNumber}',
          text: itemText,
          position: const Offset(-370, 20),
          color: widget.state.isDarkMode
            ? const Color(0xFFF1F5F9)
            : const Color(0xFF0F172A),
          fontSize: 15.0,
          fontFamily: 'Inter',
          lineHeight: 1.55,
          boxWidth: 740.0,
          paperStyle: 'blank',
          padding: 20.0,
          backgroundColor: widget.state.isDarkMode
              ? const Color(0xFF1E2436)
              : const Color(0xFFFAFBFC),
          borderColor: widget.state.isDarkMode
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0),
          borderWidth: 1.2,
          borderRadius: 14.0,
        );

        final newPage = CanvasPage(
          id: 'pdf-page-${doc.id}-${pageData.pageNumber}-${DateTime.now().millisecondsSinceEpoch}',
          pageNumber: i + 1,
          title: pageTitle,
          paperStyle: CanvasPaperStyle.blankSlate,
          objects: [item],
        );
        widget.state.currentCanvasDoc?.pages.add(newPage);
      }
    } else {
      startIdx = existingPages.length;
      for (int i = 0; i < doc.pages.length; i++) {
        final pageData = doc.pages[i];
        final pageTitle = '${doc.title} (p.${pageData.pageNumber})';
        final bufferText = _formatPdfPageContent(pageData);

        final textItem = CanvasTextItem(
          id: 'pdf-text-${doc.id}-${pageData.pageNumber}',
          text: bufferText,
          position: const Offset(-370, 20),
          color: widget.state.isDarkMode
              ? const Color(0xFFF1F5F9)
              : const Color(0xFF0F172A),
          fontSize: 15.0,
          fontFamily: 'Inter',
          lineHeight: 1.55,
          boxWidth: 740.0,
          paperStyle: 'blank',
          padding: 20.0,
          backgroundColor: widget.state.isDarkMode
              ? const Color(0xFF1E2436)
              : const Color(0xFFFAFBFC),
          borderColor: widget.state.isDarkMode
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0),
          borderWidth: 1.2,
          borderRadius: 14.0,
        );

        final newPage = CanvasPage(
          id: 'pdf-page-${doc.id}-${pageData.pageNumber}-${DateTime.now().millisecondsSinceEpoch}',
          pageNumber: startIdx + i + 1,
          title: pageTitle,
          paperStyle: CanvasPaperStyle.blankSlate,
          objects: [textItem],
        );
        widget.state.currentCanvasDoc?.pages.add(newPage);
      }
    }

    widget.state.setCanvasPage(startIdx);
    setState(() {
      _centerPageInView();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${doc.totalPages} PDF pages into notebook for direct annotation!',
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _insertPdfStudyCardOnCanvas(PdfDocumentData doc) {
    final studyPanelWidth = math.min(
      480.0,
      math.max(340.0, (_canvasSize?.width ?? 1000) * 0.38),
    );
    final visibleWidth = math.max(
      300.0,
      (_canvasSize?.width ?? 600) - studyPanelWidth,
    );
    final centerScreen = Offset(
      visibleWidth / 2,
      (_canvasSize?.height ?? 600) / 2,
    );
    Offset worldCenter = _screenToWorld(centerScreen);
    if (widget.state.isPageViewMode) {
      final clampedX = worldCenter.dx.clamp(_kPageLeft + 190.0, _kPageLeft + _kPageWidth - 190.0);
      final clampedY = worldCenter.dy.clamp(_kPageTop + 135.0, _kPageTop + _kPageHeight - 135.0);
      worldCenter = Offset(clampedX, clampedY);
    }

    final card = CanvasNoteCardItem(
      id: 'pdf-doc-${doc.id}',
      position: worldCenter - const Offset(180, 125),
      width: 360,
      height: 250,
      title: '📄 ${doc.title}',
      content: 'PDF Document (${doc.formattedSize}, ${doc.totalPages} pages)',
      backgroundColor: widget.state.isDarkMode
          ? const Color(0xFF161B2E)
          : const Color(0xFFF8FAFC),
      textColor: widget.state.isDarkMode
          ? const Color(0xFFF1F5F9)
          : const Color(0xFF0F172A),
    );

    widget.state.addCanvasObject(card);

    setState(() {
      _activePdfStudyDoc = doc;
      _isPdfStudyReaderOpen = true;
      _centerPageInView();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Inserted PDF Card & Opened Split-Screen Study Reader: ${doc.title}',
          ),
          backgroundColor: const Color(0xFF2563EB),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _insertPdfPageContentToNotebook(
    PdfDocumentData doc,
    int pageNumber,
    String text,
  ) {
    final textItem = CanvasTextItem(
      id: 'pdf-page-insert-${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      position: const Offset(-370, 20),
      color: widget.state.isDarkMode
          ? const Color(0xFFF1F5F9)
          : const Color(0xFF0F172A),
      fontSize: 15.0,
      fontFamily: 'Inter',
      lineHeight: 1.55,
      boxWidth: 740.0,
      paperStyle: 'blank',
      padding: 20.0,
      backgroundColor: widget.state.isDarkMode
          ? const Color(0xFF1E2436)
          : const Color(0xFFFAFBFC),
      borderColor: widget.state.isDarkMode
          ? const Color(0xFF334155)
          : const Color(0xFFE2E8F0),
      borderWidth: 1.2,
      borderRadius: 14.0,
    );

    final nextNum = (widget.state.currentCanvasDoc?.pages.length ?? 0) + 1;
    final newPage = CanvasPage(
      id: 'page-${DateTime.now().millisecondsSinceEpoch}',
      pageNumber: nextNum,
      title: '${doc.title} (Page $pageNumber)',
      paperStyle: CanvasPaperStyle.blankSlate,
      objects: [textItem],
    );
    widget.state.currentCanvasDoc?.pages.add(newPage);
    widget.state.setCanvasPage(nextNum - 1);
    setState(() {
      _centerPageInView();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added Page $pageNumber to notebook!'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _addPdfExcerptNoteCard(String text) {
    final studyPanelWidth =
        (_isPdfStudyReaderOpen && _activePdfStudyDoc != null)
        ? math.min(480.0, math.max(340.0, (_canvasSize?.width ?? 1000) * 0.38))
        : 0.0;
    final visibleWidth = math.max(
      300.0,
      (_canvasSize?.width ?? 600) - studyPanelWidth,
    );
    final centerScreen = Offset(
      visibleWidth / 2,
      (_canvasSize?.height ?? 600) / 2,
    );
    final worldCenter = _screenToWorld(centerScreen);

    final noteCard = CanvasNoteCardItem(
      id: 'note-card-${DateTime.now().millisecondsSinceEpoch}',
      position: worldCenter - const Offset(170, 90),
      width: 340,
      height: 180,
      title: '📌 Study Excerpt',
      content: text,
      backgroundColor: widget.state.isDarkMode
          ? const Color(0xFF1E2436)
          : const Color(0xFFFEF3C7),
      textColor: widget.state.isDarkMode
          ? const Color(0xFFF1F5F9)
          : const Color(0xFF78350F),
    );

    widget.state.addCanvasObject(noteCard);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added excerpt note card to active page!'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showInsertMediaDialog(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E2333) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: Color(0xFF6366F1),
                  ),
                ),
                title: Text(
                  'Insert Image / Photo',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                subtitle: Text(
                  'Choose from device gallery or files',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndInsertImage();
                },
              ),
              const SizedBox(height: 6),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Color(0xFFEF4444),
                  ),
                ),
                title: Text(
                  'Insert PDF Document',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                subtitle: Text(
                  'Select a PDF file to study alongside your notes',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndInsertPdf();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onSelectCanvasElement(CanvasElementItemData item) {
    final centerScreen =
        Offset(_canvasSize?.width ?? 600, _canvasSize?.height ?? 600) / 2;
    Offset worldCenter = _screenToWorld(centerScreen);
    if (widget.state.isPageViewMode) {
      final clampedX = worldCenter.dx.clamp(_kPageLeft + 50.0, _kPageLeft + _kPageWidth - 50.0);
      final clampedY = worldCenter.dy.clamp(_kPageTop + 50.0, _kPageTop + _kPageHeight - 50.0);
      worldCenter = Offset(clampedX, clampedY);
    }

    if (item.type == ElementItemType.emoji) {
      final textItem = CanvasTextItem(
        id: 'element-${DateTime.now().millisecondsSinceEpoch}',
        text: item.content,
        position: worldCenter - const Offset(24, 24),
        fontSize: 38.0,
        color: Colors.black,
      );
      widget.state.addCanvasObject(textItem);
    } else if (item.type == ElementItemType.badge) {
      final card = CanvasNoteCardItem(
        id: 'badge-${DateTime.now().millisecondsSinceEpoch}',
        position: worldCenter - const Offset(90, 25),
        width: 180,
        height: 50,
        title: item.content,
        content: '',
        backgroundColor: item.color ?? const Color(0xFFEDE9FE),
        textColor: item.textColor ?? const Color(0xFF7C3AED),
      );
      widget.state.addCanvasObject(card);
    } else if (item.type == ElementItemType.shape) {
      final shapeItem = CanvasShapeItem(
        id: 'stamp-${DateTime.now().microsecondsSinceEpoch}',
        shapeType: item.content,
        bounds: Rect.fromLTWH(worldCenter.dx - 40, worldCenter.dy - 40, 80, 80),
        strokeColor: item.color ?? const Color(0xFFF59E0B),
        strokeWidth: 3.0,
        fillColor: (item.color ?? const Color(0xFFF59E0B)).withValues(
          alpha: 0.15,
        ),
      );
      widget.state.addCanvasObject(shapeItem);
    }

    setState(() {
      _showElementsPanel = false;
    });
  }

  void _showDocumentMenu(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2333) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.auto_stories_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              widget.state.currentCanvasDoc?.name ?? 'Preparing',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline_rounded),
              title: const Text('Rename Notebook'),
              onTap: () {
                Navigator.pop(ctx);
                final ctrl = TextEditingController(
                  text: widget.state.currentCanvasDoc?.name ?? '',
                );
                showDialog(
                  context: context,
                  builder: (rCtx) => AlertDialog(
                    title: const Text('Rename Notebook'),
                    content: TextField(
                      controller: ctrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Notebook Title',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(rCtx),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          final newName = ctrl.text.trim();
                          if (newName.isNotEmpty) {
                            widget.state.renameCurrentCanvasDoc(newName);
                          }
                          Navigator.pop(rCtx);
                        },
                        child: const Text('Rename'),
                      ),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.analytics_outlined,
                color: _showDiagnosticHud
                    ? AppColors.primary
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
              title: const Text('Apple Pencil Telemetry HUD'),
              subtitle: Text(
                _showDiagnosticHud
                    ? 'Showing real-time iPad input metrics'
                    : 'Tap to enable diagnostic telemetry overlay',
              ),
              trailing: Switch(
                value: _showDiagnosticHud,
                activeThumbColor: AppColors.primary,
                onChanged: (val) {
                  Navigator.pop(ctx);
                  setState(() {
                    _showDiagnosticHud = val;
                    _gestureManager.enableTelemetry = val;
                  });
                },
              ),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _showDiagnosticHud = !_showDiagnosticHud;
                  _gestureManager.enableTelemetry = _showDiagnosticHud;
                  CanvasPerformanceProfiler.instance.isEnabled = _showDiagnosticHud;
                });
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_sweep_outlined,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Clear Active Page',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(ctx);
                widget.state.clearCanvas();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _openSearchDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => _DocumentSearchDialog(
        state: widget.state,
        isDark: isDark,
        onNavigate: (notebookId, pageIndex) {
          Navigator.pop(ctx);
          if (widget.state.currentCanvasDoc?.id != notebookId) {
            widget.state.switchNotebook(notebookId);
          }
          widget.state.setCanvasPage(pageIndex);
          setState(() {
            _centerPageInView();
          });
        },
      ),
    );
  }

  Widget _buildDiagnosticHud(bool isDark) {
    final t = _latestTelemetry;
    final bg = isDark ? const Color(0xDD111827) : const Color(0xEEFFFFFF);
    final textCol = isDark ? Colors.white : Colors.black87;
    final mutedCol = isDark ? Colors.white60 : Colors.black54;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.edit_note_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Pencil Telemetry (HUD)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textCol,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => setState(() {
                    _showDiagnosticHud = false;
                    _gestureManager.enableTelemetry = false;
                  }),
                  child: const Icon(Icons.close, size: 15, color: Colors.grey),
                ),
              ],
            ),
            const Divider(height: 12),
            _telemetryRow(
              'Device',
              t?.deviceKind.toUpperCase() ?? 'NONE',
              t?.deviceKind == 'stylus' ? Colors.greenAccent : textCol,
            ),
            _telemetryRow('Pointer ID', '#${t?.pointerId ?? 0}', textCol),
            _telemetryRow(
              'Event',
              t?.eventType.toUpperCase() ?? 'IDLE',
              textCol,
            ),
            _telemetryRow(
              'Pressure',
              '${((t?.pressure ?? 0) * 100).toStringAsFixed(1)}%',
              textCol,
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: t?.pressure ?? 0.0,
                minHeight: 4,
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            const SizedBox(height: 4),
            _telemetryRow(
              'Tilt',
              '${((t?.tilt ?? 0) * 57.2958).toStringAsFixed(1)}°',
              textCol,
            ),
            _telemetryRow('Buttons', '${t?.buttons ?? 0}', textCol),
            _telemetryRow(
              'Screen X,Y',
              '${t?.screenPosition.dx.toStringAsFixed(0)}, ${t?.screenPosition.dy.toStringAsFixed(0)}',
              mutedCol,
            ),
            _telemetryRow(
              'World X,Y',
              '${t?.worldPosition.dx.toStringAsFixed(0)}, ${t?.worldPosition.dy.toStringAsFixed(0)}',
              mutedCol,
            ),
            const Divider(height: 12),
            _telemetryRow(
              'Down->1st Paint',
              '${CanvasPerformanceProfiler.instance.latestDownToFirstPaintMs.toStringAsFixed(1)} ms',
              Colors.greenAccent,
            ),
            _telemetryRow(
              'Move Repaint',
              '${CanvasPerformanceProfiler.instance.latestMoveToPaintMs.toStringAsFixed(1)} ms',
              Colors.greenAccent,
            ),
            _telemetryRow(
              'A->B Gap (Lift)',
              '${CanvasPerformanceProfiler.instance.latestUpToDownGapMs.toStringAsFixed(1)} ms',
              Colors.orangeAccent,
            ),
            _telemetryRow(
              'Strokes Done',
              '#${CanvasPerformanceProfiler.instance.totalStrokesCompleted}',
              textCol,
            ),
          ],
        ),
      ),
    );
  }

  Widget _telemetryRow(String label, String value, Color valColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey),
          ),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: valColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageThumbnailsDrawer(bool isDark) {
    final bg = isDark ? const Color(0xFF131722) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF242B3D) : const Color(0xFFE2E8F0);
    final textPri = isDark ? Colors.white : Colors.black87;
    final pages = widget.state.canvasPages;
    final curIdx = widget.state.currentPageIndex;

    return Material(
      color: Colors.transparent,
      elevation: 16,
      child: Container(
        width: math.min(320.0, MediaQuery.of(context).size.width * 0.85),
        height: double.infinity,
        decoration: BoxDecoration(
          color: bg,
          border: Border(right: BorderSide(color: border, width: 1.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(4, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
                border: Border(bottom: BorderSide(color: border, width: 1.0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_stories_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.state.currentCanvasDoc?.name ?? "Notebook"} (${pages.length} Pages)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textPri,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.grid_view_rounded, size: 18),
                    onPressed: () => _showNotebookPagesOverviewDialog(isDark),
                    tooltip: 'All Pages Grid Overview',
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.download_for_offline_rounded,
                      size: 18,
                    ),
                    onPressed: () => _showImportChatDialog(isDark),
                    tooltip: 'Import AI Chat',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () =>
                        setState(() => _showPageThumbnailsDrawer = false),
                    tooltip: 'Close Drawer',
                  ),
                ],
              ),
            ),

            // Action row: Add Page, Duplicate, Delete
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: isDark ? const Color(0xFF161A26) : const Color(0xFFF1F5F9),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text(
                        'Add Page',
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        widget.state.addNewPage();
                        setState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    tooltip: 'Duplicate Active Page',
                    onPressed: () {
                      widget.state.duplicatePage(curIdx);
                      setState(() {});
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    tooltip: 'Delete Active Page',
                    color: Colors.redAccent,
                    onPressed: pages.length > 1
                        ? () {
                            widget.state.deletePage(curIdx);
                            setState(() {});
                          }
                        : null,
                  ),
                ],
              ),
            ),

            // Thumbnails List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: pages.length,
                itemBuilder: (ctx, idx) {
                  final page = pages[idx];
                  final isSelected = idx == curIdx;
                  return _buildThumbnailCard(page, idx, isSelected, isDark);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailCard(
    CanvasPage page,
    int idx,
    bool isSelected,
    bool isDark,
  ) {
    final pages = widget.state.canvasPages;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? const Color(0xFF222B42) : const Color(0xFFEBF3FE))
            : (isDark ? const Color(0xFF1B2030) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppColors.primary
              : (isDark ? const Color(0xFF2C354C) : const Color(0xFFE2E8F0)),
          width: isSelected ? 2.0 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          widget.state.setCanvasPage(idx);
          setState(() {
            _centerPageInView();
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              // Mini Sheet Preview with page number
              Container(
                width: 48,
                height: 64,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF12151F)
                      : const Color(0xFFFFFDF8),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    '${idx + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? AppColors.primary : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      page.title.isNotEmpty ? page.title : 'Page ${idx + 1}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${page.objects.length} elements • ${_getPaperStyleLabel(page.paperStyle)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              if (pages.length > 1) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    widget.state.deletePage(idx);
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 15,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showImportChatDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => _ImportChatDialog(state: widget.state, isDark: isDark),
    );
  }

  Widget _buildInteractiveCanvasCard(CanvasNoteCardItem card, bool isDark) {
    if (card.id.startsWith('pdf-doc-') ||
        card.id.startsWith('pdf-card-') ||
        card.title.contains('📄')) {
      return GoodNotesPdfCanvasCard(
        card: card,
        isDark: isDark,
        onOpenStudyReader: () {
          setState(() {
            _activePdfStudyDoc = PdfDocumentData.createDefault(
              card.title.replaceAll('📄', '').trim(),
            );
            _isPdfStudyReaderOpen = true;
            _centerPageInView();
          });
        },
        onImportToNotebook: () {
          final doc = PdfDocumentData.createDefault(
            card.title.replaceAll('📄', '').trim(),
          );
          _importPdfPagesToNotebook(doc);
        },
        onRemove: () {
          widget.state.removeCanvasObject(card);
        },
        onMove: (delta) {
          widget.state.moveCanvasCard(card.id, delta / _zoomScale);
        },
      );
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        width: card.width,
        height: card.height,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: card.isLoading
                ? AppColors.accent
                : AppColors.primary.withValues(alpha: 0.3),
            width: card.isLoading ? 1.5 : 1,
          ),
          boxShadow: card.isLoading
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ]
              : (isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight),
        ),
        child: Column(
          children: [
            // Draggable Header Bar
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) {
                widget.state.moveCanvasCard(
                  card.id,
                  details.delta / _zoomScale,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF22283C)
                      : const Color(0xFFF1F5F9),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(13),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        card.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                    if (card.isLoading) ...[
                      const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 15),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 26,
                        minHeight: 26,
                      ),
                      tooltip: 'Copy Answer',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: card.content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied AI answer to clipboard'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 26,
                        minHeight: 26,
                      ),
                      tooltip: 'Remove Card',
                      onPressed: () => widget.state.removeCanvasCard(card.id),
                    ),
                  ],
                ),
              ),
            ),

            // Card Content (Loading or Scrollable Text)
            Expanded(
              child: card.isLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'AI analyzing canvas drawing...',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          child: SelectableText(
                            card.content,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.5,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),

            // Card Action Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF141721)
                    : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(13),
                ),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? AppColors.darkBorder.withValues(alpha: 0.5)
                        : AppColors.lightBorder,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.layers_outlined,
                    size: 12,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Canvas AI Card',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      widget.state.askAIAndPlaceCardOnCanvas(
                        action: 'explain',
                        customPrompt:
                            'Expand and drill deeper into this insight: ${card.title}',
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 11,
                            color: AppColors.accent,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Expand',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= IMPORT AI CHAT DIALOG (GOODNOTES & IPAD STYLE) =================
class _ImportChatDialog extends StatefulWidget {
  final AppState state;
  final bool isDark;

  const _ImportChatDialog({required this.state, required this.isDark});

  @override
  State<_ImportChatDialog> createState() => _ImportChatDialogState();
}

class _ImportChatDialogState extends State<_ImportChatDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _pasteController = TextEditingController();
  String _selectedModel = 'ChatGPT';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pasteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final surfaceColor = isDark ? const Color(0xFF1E2235) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF2D354E)
        : const Color(0xFFE2E8F0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 720,
        height: 620,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: isDark
              ? AppColors.cardShadowDark
              : AppColors.cardShadowLight,
        ),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.download_for_offline_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import AI Conversation onto Canvas',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Render your chat transcript into iPad GoodNotes digital notebook pages',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
                color: isDark
                    ? const Color(0xFF181C2B)
                    : const Color(0xFFF8FAFC),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelColor: AppColors.primary,
                unselectedLabelColor: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
                labelStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.content_paste_rounded, size: 16),
                    text: 'Paste Chat',
                  ),
                  Tab(
                    icon: Icon(Icons.auto_awesome_motion_rounded, size: 16),
                    text: '1-Click Sample Threads',
                  ),
                  Tab(
                    icon: Icon(Icons.file_present_rounded, size: 16),
                    text: 'JSON / File Guide',
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPasteTab(isDark),
                  _buildSamplesTab(isDark),
                  _buildGuideTab(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasteTab(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Select AI Model Styling:',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(width: 12),
              _modelChip('ChatGPT', const Color(0xFF10B981)),
              const SizedBox(width: 8),
              _modelChip('Claude', const Color(0xFF8B5CF6)),
              const SizedBox(width: 8),
              _modelChip('Gemini', const Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              _modelChip('DeepSeek', const Color(0xFF0EA5E9)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Paste your conversation (Supports "User: ... \\n Assistant: ..." or raw copied AI responses):',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _pasteController,
              maxLines: null,
              expands: true,
              style: GoogleFonts.firaCode(
                fontSize: 12.5,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
              decoration: InputDecoration(
                hintText:
                    'User: How does quantum superposition work in quantum algorithms?\n\nChatGPT: Quantum superposition is a fundamental principle of quantum mechanics where a quantum system can exist in a linear combination of multiple states simultaneously until a measurement is made...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextMuted.withValues(alpha: 0.6)
                      : AppColors.lightTextMuted.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF141722)
                    : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark
                        ? const Color(0xFF2D354E)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _pasteController.clear(),
                child: const Text('Clear'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () {
                  final text = _pasteController.text.trim();
                  if (text.isEmpty) return;
                  widget.state.importChatThreadToCanvas(
                    text,
                    modelName: _selectedModel,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '✨ Imported conversation onto Canvas as $_selectedModel notebook cards!',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: const Text('Place onto Canvas as Notebook Pages'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modelChip(String model, Color brandColor) {
    final isSelected = _selectedModel == model;
    return InkWell(
      onTap: () => setState(() => _selectedModel = model),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? brandColor.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? brandColor
                : (widget.isDark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: brandColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              model,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? brandColor
                    : (widget.isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSamplesTab(bool isDark) {
    final samples = [
      {
        'title': 'Quantum Computing & Qubits',
        'model': 'ChatGPT',
        'color': const Color(0xFF10B981),
        'icon': '⚛️',
        'prompt':
            'Explain quantum superposition and how qubits differ from classical bits.',
        'content':
            '''User: Explain quantum superposition and how qubits differ from classical bits.

ChatGPT: Quantum superposition is a foundational principle of quantum physics where a qubit exists in a linear superposition of basic states:
|ψ⟩ = α|0⟩ + β|1⟩, where |α|² + |β|² = 1.

Key Differences:
1. State Space: Whereas n classical bits represent only 1 of 2ⁿ states at any moment, n entangled qubits simultaneously span a 2ⁿ-dimensional complex Hilbert space.
2. Quantum Parallelism: Unitary transformations (like Hadamard H-gates) evaluate mathematical problems across all possible inputs simultaneously.
3. Measurement Collapse: Observing the qubit instantaneously collapses the wave function into a deterministic classical bit (0 or 1) with probability given by Born's rule.''',
      },
      {
        'title': 'Modular Monolith vs Microservices',
        'model': 'Claude',
        'color': const Color(0xFF8B5CF6),
        'icon': '🏗️',
        'prompt':
            'When should an engineering team switch from a modular monolith to event-driven microservices?',
        'content':
            '''User: When should an engineering team switch from a modular monolith to event-driven microservices?

Claude: The decision to adopt microservices is primarily an organizational scaling decision rather than a purely technical one.

Strategic Guidelines:
• Keep a Modular Monolith if: Team has < 35 engineers, domain boundaries are rapidly pivoting, or cross-entity ACID transactions are critical.
• Migrate to Microservices when:
  - Independent Deployment Pipelines: Teams are blocking each other during deployment cadences.
  - Heterogeneous Resource Profiles: Ingestion worker services require high RAM/GPU while API gateways require low-latency asynchronous IO.
  - Fault Isolation: A failure in non-critical reporting shouldn't take down the checkout engine.

Rule of Thumb: Build clean in-process module boundaries first before breaking network boundaries.''',
      },
      {
        'title': 'Transformer Multi-Head Self-Attention',
        'model': 'Gemini',
        'color': const Color(0xFF3B82F6),
        'icon': '🧠',
        'prompt':
            'Explain Multi-Head Self-Attention with Query, Key, and Value matrices.',
        'content':
            '''User: Explain Multi-Head Self-Attention with Query, Key, and Value matrices.

Gemini: Self-Attention allows language models to dynamically assign attention weights across all tokens in a sequence regardless of distance.

Mathematical Formulation:
Attention(Q, K, V) = softmax(Q · Kᵀ / √dₖ) · V

Core Vector Components:
• Q (Query): What the current token is seeking context on.
• K (Key): What context each other token has to offer.
• V (Value): The actual semantic vector payload of each token.
• √dₖ: Temperature normalization factor to avoid small gradients in high-dimensional dot products.

Multi-Head Attention projects Q, K, V across h subspace heads, empowering the model to attend to syntactic, positional, and semantic relations in parallel.''',
      },
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: samples.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        final sample = samples[i];
        final brandColor = sample['color'] as Color;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161A28) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF2B334B) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    sample['icon'] as String,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          sample['title'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: brandColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            sample['model'] as String,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: brandColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Prompt: "${sample['prompt']}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  widget.state.importChatThreadToCanvas(
                    sample['content'] as String,
                    modelName: sample['model'] as String,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '✨ Loaded "${sample['title']}" onto Canvas as GoodNotes notebook cards!',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.file_download_done_rounded, size: 15),
                label: const Text('Load to Canvas'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuideTab(bool isDark) {
    const sampleJson = '''[
  {
    "role": "user",
    "content": "What are the core pillars of modern web architecture?"
  },
  {
    "role": "assistant",
    "content": "Modern web architecture rests on three pillars: 1) Stateless API layers with horizontal auto-scaling, 2) Edge CDN caching and SSR for sub-100ms LCP, and 3) Observability with distributed tracing."
  }
]''';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Supported Formats for Direct Import:',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '1. ChatGPT / Claude copy-paste: "User: ... \\n ChatGPT: ..."\n'
            '2. Markdown chat formats: "### User \\n ... \\n ### Assistant \\n ..."\n'
            '3. Official JSON export formats (e.g. conversations.json from ChatGPT data export):',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              height: 1.5,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF141722)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2D354E)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  sampleJson,
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  widget.state.importChatThreadToCanvas(
                    sampleJson,
                    modelName: 'ChatGPT',
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '✨ Loaded JSON conversation onto canvas as notebook cards!',
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.playlist_add_check_rounded, size: 16),
                label: const Text('Import Sample JSON to Canvas'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ================= NOTEBOOK PAGES OVERVIEW DIALOG (GOODNOTES THUMBNAIL GRID) =================
class _NotebookPagesOverviewDialog extends StatefulWidget {
  final AppState state;
  final bool isDark;

  const _NotebookPagesOverviewDialog({
    required this.state,
    required this.isDark,
  });

  @override
  State<_NotebookPagesOverviewDialog> createState() =>
      _NotebookPagesOverviewDialogState();
}

class _NotebookPagesOverviewDialogState
    extends State<_NotebookPagesOverviewDialog> {
  void _promptRenamePage(BuildContext context, int index, String currentTitle) {
    final ctrl = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E2235) : Colors.white,
        title: const Text(
          'Rename Page',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Page Title',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newTitle = ctrl.text.trim();
              if (newTitle.isNotEmpty) {
                widget.state.renamePage(index, newTitle);
                setState(() {});
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final pages = widget.state.canvasPages;
    final currentIdx = widget.state.currentPageIndex.clamp(
      0,
      pages.isNotEmpty ? pages.length - 1 : 0,
    );
    final doc = widget.state.currentCanvasDoc;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF141724) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? const Color(0xFF2C3550) : const Color(0xFFE2E8F0),
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Container(
        width: 880,
        height: 640,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title, Notebook name, Action buttons
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc?.name ?? 'Notebook Overview',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${pages.length} ${pages.length == 1 ? "page" : "pages"} • Click any page thumbnail to navigate',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Add Page with template picker
                PopupMenuButton<CanvasPaperStyle>(
                  tooltip: 'Add Page with Template',
                  offset: const Offset(0, 38),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                  color: isDark ? const Color(0xFF1E2235) : Colors.white,
                  onSelected: (style) {
                    widget.state.addNewPage(paperStyle: style);
                    setState(() {});
                  },
                  itemBuilder: (ctx) => [
                    _buildTemplateMenuItem(
                      CanvasPaperStyle.ruledLines,
                      'Ruled Lines (Notebook)',
                      Icons.format_align_left_rounded,
                      isDark,
                    ),
                    _buildTemplateMenuItem(
                      CanvasPaperStyle.dotGrid,
                      'Dot Grid (Journal)',
                      Icons.apps_rounded,
                      isDark,
                    ),
                    _buildTemplateMenuItem(
                      CanvasPaperStyle.graphGrid,
                      'Graph Grid (Math/Eng)',
                      Icons.grid_4x4_rounded,
                      isDark,
                    ),
                    _buildTemplateMenuItem(
                      CanvasPaperStyle.blankSlate,
                      'Blank Slate (Plain)',
                      Icons.crop_portrait_rounded,
                      isDark,
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Add Page',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              height: 1,
              color: isDark ? const Color(0xFF262C40) : const Color(0xFFF1F5F9),
            ),
            const SizedBox(height: 16),

            // Grid of Pages
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(4),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 18,
                  childAspectRatio: 0.72,
                ),
                itemCount: pages.length + 1,
                itemBuilder: (context, index) {
                  if (index == pages.length) {
                    return _buildAddPageCard(isDark);
                  }
                  final page = pages[index];
                  final isCurrent = index == currentIdx;
                  return _buildPageCard(
                    context,
                    page,
                    index,
                    isCurrent,
                    isDark,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<CanvasPaperStyle> _buildTemplateMenuItem(
    CanvasPaperStyle style,
    String label,
    IconData icon,
    bool isDark,
  ) {
    return PopupMenuItem<CanvasPaperStyle>(
      value: style,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildPageCard(
    BuildContext context,
    CanvasPage page,
    int index,
    bool isCurrent,
    bool isDark,
  ) {
    String paperName = 'Blank';
    if (page.paperStyle == CanvasPaperStyle.ruledLines) paperName = 'Ruled';
    if (page.paperStyle == CanvasPaperStyle.dotGrid) paperName = 'Dot Grid';
    if (page.paperStyle == CanvasPaperStyle.graphGrid) paperName = 'Graph';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2032) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent
              ? AppColors.primary
              : (isDark ? const Color(0xFF2A334E) : const Color(0xFFE2E8F0)),
          width: isCurrent ? 2.2 : 1.0,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(
                    alpha: isDark ? 0.35 : 0.2,
                  ),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            widget.state.setCanvasPage(index);
            Navigator.pop(context);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top card header: Page label & Options popup
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? AppColors.primary.withValues(alpha: 0.18)
                            : (isDark
                                  ? const Color(0xFF252D44)
                                  : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Page ${index + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isCurrent
                              ? AppColors.primary
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF10B981,
                          ).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    PopupMenuButton<String>(
                      tooltip: 'Page Actions',
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 16,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      color: isDark ? const Color(0xFF1E2235) : Colors.white,
                      onSelected: (action) {
                        if (action == 'duplicate') {
                          widget.state.duplicatePage(index);
                          setState(() {});
                        } else if (action == 'rename') {
                          _promptRenamePage(context, index, page.title);
                        } else if (action == 'ruled') {
                          widget.state.setPagePaperStyle(
                            index,
                            CanvasPaperStyle.ruledLines,
                          );
                          setState(() {});
                        } else if (action == 'dot') {
                          widget.state.setPagePaperStyle(
                            index,
                            CanvasPaperStyle.dotGrid,
                          );
                          setState(() {});
                        } else if (action == 'graph') {
                          widget.state.setPagePaperStyle(
                            index,
                            CanvasPaperStyle.graphGrid,
                          );
                          setState(() {});
                        } else if (action == 'blank') {
                          widget.state.setPagePaperStyle(
                            index,
                            CanvasPaperStyle.blankSlate,
                          );
                          setState(() {});
                        } else if (action == 'delete') {
                          widget.state.deletePage(index);
                          setState(() {});
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'duplicate',
                          height: 36,
                          child: Row(
                            children: [
                              Icon(Icons.copy_rounded, size: 15),
                              SizedBox(width: 8),
                              Text(
                                'Duplicate Page',
                                style: TextStyle(fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'rename',
                          height: 36,
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 15),
                              SizedBox(width: 8),
                              Text(
                                'Rename Page',
                                style: TextStyle(fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(height: 6),
                        const PopupMenuItem(
                          value: 'ruled',
                          height: 34,
                          child: Text(
                            'Template: Ruled Lines',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'dot',
                          height: 34,
                          child: Text(
                            'Template: Dot Grid',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'graph',
                          height: 34,
                          child: Text(
                            'Template: Graph Grid',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'blank',
                          height: 34,
                          child: Text(
                            'Template: Blank Slate',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        if (widget.state.canvasPages.length > 1) ...[
                          const PopupMenuDivider(height: 6),
                          const PopupMenuItem(
                            value: 'delete',
                            height: 36,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 15,
                                  color: Colors.redAccent,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Delete Page',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Simulated Mini Paper Page Sheet (GoodNotes realistic paper preview)
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF141724)
                          : const Color(0xFFFFFDF8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF28314B)
                            : const Color(0xFFE5DFD5),
                        width: 1.0,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Background paper pattern illustration
                        Positioned.fill(
                          child: ClipRect(
                            child: CustomPaint(
                              painter: _PageThumbnailPainter(
                                paperStyle: page.paperStyle,
                                isDark: isDark,
                              ),
                            ),
                          ),
                        ),
                        // Mini page header ribbon
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 16,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1C2236)
                                  : const Color(0xFFF7F4EE),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(7),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              page.title.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                        // Objects / Content Badge in center
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (isDark
                                          ? const Color(0xFF1E2438)
                                          : Colors.white)
                                      .withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF333E5D)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  page.objects.isNotEmpty
                                      ? Icons.draw_rounded
                                      : Icons.crop_portrait_rounded,
                                  size: 13,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${page.objects.length} ${page.objects.length == 1 ? "item" : "items"}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Card Footer: Title & paper template badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        page.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                    Text(
                      paperName,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddPageCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF181D2E) : const Color(0xFFF8FAFC))
            .withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2C3550) : const Color(0xFFCBD5E1),
          style: BorderStyle.solid,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            widget.state.addNewPage();
            setState(() {});
          },
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 24,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Add New Page',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ruled / Dot / Graph',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Mini painter for thumbnail preview in GoodNotes page overview grid
class _PageThumbnailPainter extends CustomPainter {
  final CanvasPaperStyle paperStyle;
  final bool isDark;

  _PageThumbnailPainter({required this.paperStyle, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (paperStyle == CanvasPaperStyle.blankSlate) return;

    if (paperStyle == CanvasPaperStyle.ruledLines) {
      final linePaint = Paint()
        ..color = isDark
            ? const Color(0xFF28324C).withValues(alpha: 0.6)
            : const Color(0xFFD8E1F0).withValues(alpha: 0.8)
        ..strokeWidth = 0.8;

      for (double y = 24.0; y < size.height - 4.0; y += 12.0) {
        canvas.drawLine(Offset(4, y), Offset(size.width - 4, y), linePaint);
      }

      // Vertical pink margin
      final marginPaint = Paint()
        ..color = const Color(0xFFF43F5E).withValues(alpha: isDark ? 0.35 : 0.4)
        ..strokeWidth = 1.0;
      canvas.drawLine(
        const Offset(18, 16),
        Offset(18, size.height),
        marginPaint,
      );
      return;
    }

    if (paperStyle == CanvasPaperStyle.graphGrid) {
      final gridPaint = Paint()
        ..color = isDark
            ? const Color(0xFF263048).withValues(alpha: 0.6)
            : const Color(0xFFE2E8F0)
        ..strokeWidth = 0.7;

      for (double x = 4; x < size.width; x += 12.0) {
        canvas.drawLine(Offset(x, 16), Offset(x, size.height), gridPaint);
      }
      for (double y = 16; y < size.height; y += 12.0) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
      return;
    }

    // Dot Grid
    final dotPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.black.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    for (double x = 8; x < size.width - 4; x += 12.0) {
      for (double y = 22; y < size.height - 4; y += 12.0) {
        canvas.drawCircle(Offset(x, y), 0.8, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PageThumbnailPainter oldDelegate) =>
      oldDelegate.paperStyle != paperStyle || oldDelegate.isDark != isDark;
}

// ================= CUSTOM CANVAS PAINTER (GOODNOTES IPAD NOTEBOOK STYLE) =================
class CanvasPainter extends CustomPainter {
  final AppState? appState;
  final List<CanvasObjectItem> objects;
  final List<StrokePoint> currentPoints;
  final CanvasTool currentTool;
  final Color currentColor;
  final double currentWidth;
  final double currentOpacity;
  final PenType currentPenType;
  final PressureSensitivity pressureSensitivity;
  final double tipSharpness;
  final double tipFlatness;
  final double strokeStabilization;
  final Offset? dragStart;
  final Offset? dragCurrent;
  final List<Offset> lassoPoints;
  final bool isDark;
  final Offset panOffset;
  final double zoomScale;
  final CanvasPaperStyle paperStyle;
  final bool isPageViewMode;
  final String pageTitle;
  final int pageNumber;
  final int totalPages;
  final List<CanvasPage> pages;
  final int activePageIndex;
  final String? selectedTextItemId;
  final String? selectedImageId;
  final bool isDrawingTape;
  final Offset? tapeStartWorld;
  final Offset? tapeCurrentWorld;
  final Color tapeColor;
  final double tapeHeight;
  final Map<String, ui.Image>? imageCache;
  final Set<String>? loadingImages;
  final VoidCallback? onImageDecoded;
  final bool isTransitioning;
  final int? transitionFromPageIndex;
  final int? transitionToPageIndex;
  final double transitionProgress;
  final double transitionDirection;
  final double sheetPullOffset;
  final String? editingExistingTextId;

  CanvasPainter({
    this.appState,
    super.repaint,
    required this.objects,
    this.pages = const [],
    this.activePageIndex = 0,
    required this.currentPoints,
    required this.currentTool,
    required this.currentColor,
    required this.currentWidth,
    this.currentOpacity = 1.0,
    this.currentPenType = PenType.fountainPen,
    this.pressureSensitivity = PressureSensitivity.medium,
    this.tipSharpness = 0.75,
    this.tipFlatness = 0.66,
    this.strokeStabilization = 0.0,
    this.dragStart,
    this.dragCurrent,
    this.lassoPoints = const [],
    required this.isDark,
    required this.panOffset,
    required this.zoomScale,
    required this.paperStyle,
    required this.isPageViewMode,
    required this.pageTitle,
    required this.pageNumber,
    required this.totalPages,
    this.selectedTextItemId,
    this.selectedImageId,
    this.editingExistingTextId,
    this.isDrawingTape = false,
    this.tapeStartWorld,
    this.tapeCurrentWorld,
    this.tapeColor = const Color(0xFFFDE047),
    this.tapeHeight = 28.0,
    this.imageCache,
    this.loadingImages,
    this.onImageDecoded,
    this.isTransitioning = false,
    this.transitionFromPageIndex,
    this.transitionToPageIndex,
    this.transitionProgress = 0.0,
    this.transitionDirection = -1.0,
    this.sheetPullOffset = 0.0,
  });

  List<CanvasObjectItem> get effectiveObjects => appState?.canvasObjects ?? objects;
  List<CanvasPage> get effectivePages => appState?.canvasPages ?? pages;
  int get effectiveActivePageIndex => appState?.currentPageIndex ?? activePageIndex;
  CanvasPaperStyle get effectivePaperStyle => appState?.canvasPaperStyle ?? paperStyle;
  bool get effectiveIsPageViewMode => appState?.isPageViewMode ?? isPageViewMode;
  int get effectivePageNumber => (appState?.currentPageIndex != null ? appState!.currentPageIndex + 1 : pageNumber);
  int get effectiveTotalPages => (appState?.canvasPages.isNotEmpty == true ? appState!.canvasPages.length : totalPages);
  String get effectivePageTitle => appState?.currentPage?.title ?? (appState != null ? 'Page ${appState!.currentPageIndex + 1}' : pageTitle);

  @override
  void paint(Canvas canvas, Size size) {
    // 0. Strict viewport clip: prevent canvas and page from ever painting outside widget bounds
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    const pageWidth = _kPageWidth;
    const pageRect = Rect.fromLTWH(
      _kPageLeft,
      _kPageTop,
      _kPageWidth,
      _kPageHeight,
    );

    if (effectiveIsPageViewMode) {
      // 1. Deep GoodNotes desk backdrop
      _drawDeskBackground(canvas, size);

      // 2. Enter world-space transform
      canvas.save();
      canvas.translate(panOffset.dx, panOffset.dy);
      canvas.scale(zoomScale);

      // 3. Strictly ONLY ONE PAGE visible on screen at one time!
      // If user swipes, animate smooth slide transition between exiting page and entering page.
      if (isTransitioning &&
          transitionFromPageIndex != null &&
          transitionToPageIndex != null) {
        final fromIdx = transitionFromPageIndex!;
        final toIdx = transitionToPageIndex!;
        final step = pageWidth + 40.0;

        // transitionDirection: -1.0 means moving forward (next page), 1.0 means moving backward (previous page)
        final exitOffset = transitionDirection * transitionProgress * step;
        final enterOffset = exitOffset - (transitionDirection * step);

        // A. Draw exiting page
        final fromStyle = (fromIdx >= 0 && fromIdx < effectivePages.length)
            ? effectivePages[fromIdx].paperStyle
            : effectivePaperStyle;
        _drawGoodNotesPageSheet(
          canvas,
          xOffset: exitOffset,
          pageNum: fromIdx + 1,
          pageStyle: fromStyle,
        );
        canvas.save();
        canvas.translate(exitOffset, 0);
        canvas.clipRRect(
          RRect.fromRectAndRadius(pageRect, const Radius.circular(4)),
        );
        final fromObjs = (fromIdx == effectiveActivePageIndex)
            ? effectiveObjects
            : (fromIdx >= 0 && fromIdx < effectivePages.length
                  ? effectivePages[fromIdx].objects
                  : const <CanvasObjectItem>[]);
        _drawObjectsList(canvas, fromObjs);
        canvas.restore();

        // B. Draw entering page
        final toStyle = (toIdx >= 0 && toIdx < effectivePages.length)
            ? effectivePages[toIdx].paperStyle
            : effectivePaperStyle;
        _drawGoodNotesPageSheet(
          canvas,
          xOffset: enterOffset,
          pageNum: toIdx + 1,
          pageStyle: toStyle,
        );
        canvas.save();
        canvas.translate(enterOffset, 0);
        canvas.clipRRect(
          RRect.fromRectAndRadius(pageRect, const Radius.circular(4)),
        );
        final toObjs = (toIdx == effectiveActivePageIndex)
            ? effectiveObjects
            : (toIdx >= 0 && toIdx < effectivePages.length
                  ? effectivePages[toIdx].objects
                  : const <CanvasObjectItem>[]);
        _drawObjectsList(canvas, toObjs);
        canvas.restore();
      } else {
        // Steady State: Render active page with dynamic sheetPullOffset (1:1 GoodNotes touch tracking)
        final style = (effectiveActivePageIndex >= 0 && effectiveActivePageIndex < effectivePages.length)
            ? effectivePages[effectiveActivePageIndex].paperStyle
            : effectivePaperStyle;

        // 1. Draw peeking adjacent page when user pulls sheet
        if (sheetPullOffset < -2.0) {
          // Pulling to the left: peek NEXT page from right
          final nextIdx = effectiveActivePageIndex + 1;
          final peekOffset = sheetPullOffset + pageWidth + 40.0;
          final nextStyle = (nextIdx < effectivePages.length)
              ? effectivePages[nextIdx].paperStyle
              : style;
          _drawGoodNotesPageSheet(
            canvas,
            xOffset: peekOffset,
            pageNum: nextIdx + 1,
            pageStyle: nextStyle,
          );
          if (nextIdx < effectivePages.length) {
            canvas.save();
            canvas.translate(peekOffset, 0);
            canvas.clipRRect(
              RRect.fromRectAndRadius(pageRect, const Radius.circular(4)),
            );
            _drawObjectsList(canvas, effectivePages[nextIdx].objects);
            canvas.restore();
          }
        } else if (sheetPullOffset > 2.0 && effectiveActivePageIndex > 0) {
          // Pulling to the right: peek PREVIOUS page from left
          final prevIdx = effectiveActivePageIndex - 1;
          final peekOffset = sheetPullOffset - (pageWidth + 40.0);
          final prevStyle = effectivePages[prevIdx].paperStyle;
          _drawGoodNotesPageSheet(
            canvas,
            xOffset: peekOffset,
            pageNum: prevIdx + 1,
            pageStyle: prevStyle,
          );
          canvas.save();
          canvas.translate(peekOffset, 0);
          canvas.clipRRect(
            RRect.fromRectAndRadius(pageRect, const Radius.circular(4)),
          );
          _drawObjectsList(canvas, effectivePages[prevIdx].objects);
          canvas.restore();
        }

        // 2. Draw Active page translated by sheetPullOffset
        _drawGoodNotesPageSheet(
          canvas,
          xOffset: sheetPullOffset,
          pageNum: effectivePageNumber,
          pageStyle: style,
        );

        // Render page objects inside clipped sheet bounds
        canvas.save();
        canvas.translate(sheetPullOffset, 0);
        canvas.clipRRect(
          RRect.fromRectAndRadius(pageRect, const Radius.circular(4)),
        );
        _drawObjectsList(canvas, effectiveObjects);

        // Live overlays (drag shape / lasso) on the active page
        _drawLiveOverlays(canvas);
        canvas.restore();
      }
    } else {
      // 1. Crisp Whiteboard Canvas Backdrop
      final boardBg = isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFFBFBFC);
      canvas.drawRect(Offset.zero & size, Paint()..color = boardBg);

      // 2. Infinite Whiteboard Grid
      _drawInfiniteGrid(canvas, size);
      canvas.save();
      canvas.translate(panOffset.dx, panOffset.dy);
      canvas.scale(zoomScale);

      final visibleBounds = Rect.fromLTWH(
        -panOffset.dx / zoomScale,
        -panOffset.dy / zoomScale,
        size.width / zoomScale,
        size.height / zoomScale,
      ).inflate(64.0);
      _drawObjectsList(canvas, effectiveObjects, visibleBounds: visibleBounds);
      _drawLiveOverlays(canvas);
    }

    canvas.restore(); // restore world-space transform
    canvas.restore(); // restore viewport clip
  }

  void _drawObjectsList(
    Canvas canvas,
    List<CanvasObjectItem> objs, {
    Rect? visibleBounds,
  }) {
    // Highlighters first (underneath all ink strokes and shapes)
    for (var obj in objs) {
      if (visibleBounds != null && !visibleBounds.overlaps(obj.getBoundingBox())) {
        continue;
      }
      if (obj is CanvasStrokeItem && obj.tool == 'highlighter') {
        StrokeEngine.drawVariableWidthStroke(
          canvas,
          obj,
          obj.pressureSensitivity,
          tipSharpness: obj.tipSharpness,
          tipFlatness: obj.tipFlatness,
        );
      }
    }

    // Opaque pen strokes, shapes, and text
    for (var obj in objs) {
      if (visibleBounds != null && !visibleBounds.overlaps(obj.getBoundingBox())) {
        continue;
      }
      if (obj is CanvasStrokeItem && obj.tool != 'highlighter') {
        StrokeEngine.drawVariableWidthStroke(
          canvas,
          obj,
          obj.pressureSensitivity,
          tipSharpness: obj.tipSharpness,
          tipFlatness: obj.tipFlatness,
        );
      } else if (obj is CanvasShapeItem) {
        _drawShape(canvas, obj);
      } else if (obj is CanvasTextItem) {
        _drawText(canvas, obj);
      } else if (obj is CanvasImageItem) {
        _drawImage(canvas, obj);
      } else if (obj is CanvasTapeItem) {
        _drawTape(canvas, obj);
      }

      // Draw selection bounding box if selected
      if (obj.isSelected) {
        final bbox = obj.getBoundingBox().inflate(4);
        final selectPaint = Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8 / zoomScale;
        canvas.drawRect(bbox, selectPaint);
      }
    }
  }

  void _drawLiveOverlays(Canvas canvas) {
    // Draw live drag shape / lasso selection box
    if (dragStart != null && dragCurrent != null) {
      final rect = Rect.fromPoints(dragStart!, dragCurrent!);
      if (currentTool == CanvasTool.lasso) {
        final lassoPaint = Paint()
          ..color = AppColors.primary.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill;
        final borderPaint = Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / zoomScale;
        canvas.drawRect(rect, lassoPaint);
        canvas.drawRect(rect, borderPaint);
      } else if (currentTool == CanvasTool.rectangle) {
        final paint = Paint()
          ..color = currentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = currentWidth;
        canvas.drawRect(rect, paint);
      } else if (currentTool == CanvasTool.circle) {
        final paint = Paint()
          ..color = currentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = currentWidth;
        canvas.drawOval(rect, paint);
      } else if (currentTool == CanvasTool.triangle) {
        final paint = Paint()
          ..color = currentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = currentWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        final triPath = Path()
          ..moveTo(rect.topCenter.dx, rect.topCenter.dy)
          ..lineTo(rect.bottomRight.dx, rect.bottomRight.dy)
          ..lineTo(rect.bottomLeft.dx, rect.bottomLeft.dy)
          ..close();
        canvas.drawPath(triPath, paint);
      } else if (currentTool == CanvasTool.line ||
          currentTool == CanvasTool.arrow) {
        final paint = Paint()
          ..color = currentColor
          ..strokeWidth = currentWidth
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(dragStart!, dragCurrent!, paint);
      }
    }

    // Draw live freehand lasso loop
    if (currentTool == CanvasTool.lasso && lassoPoints.length > 1) {
      final lassoPath = Path()
        ..moveTo(lassoPoints.first.dx, lassoPoints.first.dy);
      for (int i = 1; i < lassoPoints.length; i++) {
        lassoPath.lineTo(lassoPoints[i].dx, lassoPoints[i].dy);
      }
      final lassoFillPaint = Paint()
        ..color = AppColors.primary.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;
      canvas.drawPath(lassoPath, lassoFillPaint);

      final lassoBorderPaint = Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 / zoomScale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(lassoPath, lassoBorderPaint);
    }

    // Draw live tape drag preview
    if (isDrawingTape && tapeStartWorld != null && tapeCurrentWorld != null) {
      final left = math.min(tapeStartWorld!.dx, tapeCurrentWorld!.dx);
      final top = math.min(tapeStartWorld!.dy, tapeCurrentWorld!.dy);
      final width = (tapeCurrentWorld!.dx - tapeStartWorld!.dx).abs();
      final previewRect = Rect.fromLTWH(
        left,
        top,
        math.max(width, 24.0),
        tapeHeight,
      );
      final rrect = RRect.fromRectAndRadius(
        previewRect,
        const Radius.circular(4),
      );

      final liveTapePaint = Paint()
        ..color = tapeColor.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rrect, liveTapePaint);

      final liveBorderPaint = Paint()
        ..color = const Color(0xFF6366F1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRRect(rrect, liveBorderPaint);
    }
  }

  void _drawDeskBackground(Canvas canvas, Size size) {
    // GoodNotes signature backdrop: near-black in dark mode, warm linen in light
    final bg = isDark ? const Color(0xFF0D0D0D) : const Color(0xFFEFEAE0);
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);
  }

  /// Draw a single GoodNotes-style A4 page at the given horizontal offset.
  void _drawGoodNotesPageSheet(
    Canvas canvas, {
    double xOffset = 0.0,
    int pageNum = 1,
    CanvasPaperStyle? pageStyle,
  }) {
    final effectiveStyle = pageStyle ?? effectivePaperStyle;
    // GoodNotes Standard iPad A4 Page Dimensions (World coordinates)
    const pageWidth = _kPageWidth;
    const pageHeight = _kPageHeight;
    final pageLeft =
        _kPageLeft +
        xOffset; // shifted horizontally by xOffset for side-by-side pages
    const pageTop = _kPageTop;
    final pageRect = Rect.fromLTWH(pageLeft, pageTop, pageWidth, pageHeight);
    final pageRRect = RRect.fromRectAndRadius(
      pageRect,
      const Radius.circular(4),
    );

    // A. Dual Drop Shadows (Ambient + Key)
    final ambientShadow = Paint()
      ..color = Colors.black.withValues(alpha: isDark ? 0.45 : 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawRRect(pageRRect.shift(const Offset(0, 14)), ambientShadow);

    final keyShadow = Paint()
      ..color = Colors.black.withValues(alpha: isDark ? 0.25 : 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(pageRRect.shift(const Offset(0, 4)), keyShadow);

    // B. Cream Ivory Paper Fill (GoodNotes signature paper tone)
    final paperBg = isDark ? const Color(0xFF171B2A) : const Color(0xFFFFFDF8);
    final paperPaint = Paint()
      ..color = paperBg
      ..style = PaintingStyle.fill;
    canvas.drawRRect(pageRRect, paperPaint);

    // C. Clip to page sheet for inner paper texture & styling
    canvas.save();
    canvas.clipRRect(pageRRect);

    // D. Inner Paper Style (Ruled, Narrow, Dot, Graph, Cornell, Planner, Blank)
    if (effectiveStyle == CanvasPaperStyle.ruledLines) {
      final linePaint = Paint()
        ..color = isDark
            ? const Color(0xFF28324C).withValues(alpha: 0.7)
            : const Color(0xFFD8E1F0).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      const lineHeight = 32.0;
      final startY = pageTop + 48.0 + 28.0;
      final endY = pageTop + pageHeight - 20.0;
      for (double y = startY; y < endY; y += lineHeight) {
        canvas.drawLine(
          Offset(pageLeft, y),
          Offset(pageLeft + pageWidth, y),
          linePaint,
        );
      }

      // Vertical rose notebook margin line (iPad GoodNotes style)
      final marginX = pageLeft + 72.0;
      final marginPaint = Paint()
        ..color = const Color(
          0xFFF43F5E,
        ).withValues(alpha: isDark ? 0.35 : 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(marginX, pageTop + 48.0),
        Offset(marginX, pageTop + pageHeight),
        marginPaint,
      );
    } else if (effectiveStyle == CanvasPaperStyle.narrowRuled) {
      final linePaint = Paint()
        ..color = isDark
            ? const Color(0xFF28324C).withValues(alpha: 0.7)
            : const Color(0xFFD8E1F0).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9;

      const lineHeight = 22.0;
      final startY = pageTop + 48.0 + 22.0;
      final endY = pageTop + pageHeight - 20.0;
      for (double y = startY; y < endY; y += lineHeight) {
        canvas.drawLine(
          Offset(pageLeft, y),
          Offset(pageLeft + pageWidth, y),
          linePaint,
        );
      }

      final marginX = pageLeft + 72.0;
      final marginPaint = Paint()
        ..color = const Color(
          0xFFF43F5E,
        ).withValues(alpha: isDark ? 0.35 : 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(marginX, pageTop + 48.0),
        Offset(marginX, pageTop + pageHeight),
        marginPaint,
      );
    } else if (effectiveStyle == CanvasPaperStyle.graphGrid) {
      final gridPaint = Paint()
        ..color = isDark
            ? const Color(0xFF252C40).withValues(alpha: 0.65)
            : const Color(0xFFE2E8F0).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;

      const step = 28.0;
      for (double x = pageLeft; x <= pageLeft + pageWidth; x += step) {
        canvas.drawLine(
          Offset(x, pageTop + 48.0),
          Offset(x, pageTop + pageHeight),
          gridPaint,
        );
      }
      for (double y = pageTop + 48.0; y <= pageTop + pageHeight; y += step) {
        canvas.drawLine(
          Offset(pageLeft, y),
          Offset(pageLeft + pageWidth, y),
          gridPaint,
        );
      }
    } else if (effectiveStyle == CanvasPaperStyle.dotGrid) {
      final dotPaint = Paint()
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;

      const step = 28.0;
      for (double x = pageLeft + 20.0; x < pageLeft + pageWidth; x += step) {
        for (
          double y = pageTop + 48.0 + 20.0;
          y < pageTop + pageHeight - 10.0;
          y += step
        ) {
          canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
        }
      }
    } else if (effectiveStyle == CanvasPaperStyle.cornell) {
      final linePaint = Paint()
        ..color = isDark
            ? const Color(0xFF28324C).withValues(alpha: 0.7)
            : const Color(0xFFD8E1F0).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      const lineHeight = 32.0;
      final startY = pageTop + 48.0 + 28.0;
      final summaryY = pageTop + pageHeight - 160.0;
      final cueX = pageLeft + 210.0;

      // Right-hand notes area ruled lines
      for (double y = startY; y < summaryY; y += lineHeight) {
        canvas.drawLine(
          Offset(cueX, y),
          Offset(pageLeft + pageWidth, y),
          linePaint,
        );
      }

      final borderPaint = Paint()
        ..color = isDark ? const Color(0xFF384364) : const Color(0xFFC8D3E6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      // Vertical cue column divider
      canvas.drawLine(
        Offset(cueX, pageTop + 48.0),
        Offset(cueX, summaryY),
        borderPaint,
      );

      // Horizontal summary section divider
      canvas.drawLine(
        Offset(pageLeft, summaryY),
        Offset(pageLeft + pageWidth, summaryY),
        borderPaint,
      );

      // Summary section ruled lines
      for (
        double y = summaryY + 36.0;
        y < pageTop + pageHeight - 10.0;
        y += lineHeight
      ) {
        canvas.drawLine(
          Offset(pageLeft, y),
          Offset(pageLeft + pageWidth, y),
          linePaint,
        );
      }

      // Column Labels
      final cuePainter = TextPainter(
        text: TextSpan(
          text: 'CUES & QUESTIONS',
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      cuePainter.paint(canvas, Offset(pageLeft + 14, pageTop + 54));

      final notesPainter = TextPainter(
        text: TextSpan(
          text: 'NOTES & LECTURE OUTLINE',
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      notesPainter.paint(canvas, Offset(cueX + 16, pageTop + 54));

      final sumPainter = TextPainter(
        text: TextSpan(
          text: 'SUMMARY',
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      sumPainter.paint(canvas, Offset(pageLeft + 14, summaryY + 10));
    } else if (effectiveStyle == CanvasPaperStyle.planner) {
      final linePaint = Paint()
        ..color = isDark
            ? const Color(0xFF28324C).withValues(alpha: 0.7)
            : const Color(0xFFD8E1F0).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      const lineHeight = 32.0;
      final startY = pageTop + 48.0 + 28.0;
      final endY = pageTop + pageHeight - 20.0;
      final splitX = pageLeft + 140.0;

      // Vertical schedule divider
      canvas.drawLine(
        Offset(splitX, pageTop + 48.0),
        Offset(splitX, pageTop + pageHeight),
        linePaint..strokeWidth = 1.4,
      );

      // Time slots on left, ruled notes on right
      for (double y = startY; y < endY; y += lineHeight) {
        canvas.drawLine(
          Offset(splitX, y),
          Offset(pageLeft + pageWidth, y),
          linePaint..strokeWidth = 1.0,
        );
      }

      // Schedule column header
      final schedPainter = TextPainter(
        text: TextSpan(
          text: 'SCHEDULE',
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      schedPainter.paint(canvas, Offset(pageLeft + 16, pageTop + 54));
    }

    // E. Page Header Ribbon Section (Top of Sheet)
    const headerHeight = 48.0;
    final headerRect = Rect.fromLTWH(
      pageLeft,
      pageTop,
      pageWidth,
      headerHeight,
    );
    final headerBgPaint = Paint()
      ..color = isDark ? const Color(0xFF1F2539) : const Color(0xFFF7F4EE)
      ..style = PaintingStyle.fill;
    canvas.drawRect(headerRect, headerBgPaint);

    // Header bottom divider line
    final headerBorderColor = isDark
        ? const Color(0xFF2D354E)
        : const Color(0xFFE5DFD5);
    canvas.drawLine(
      Offset(pageLeft, pageTop + headerHeight),
      Offset(pageLeft + pageWidth, pageTop + headerHeight),
      Paint()
        ..color = headerBorderColor
        ..strokeWidth = 1.0,
    );

    // Small subtle tab number (not the loud PAGE X OF Y)
    if (pageNum == pageNumber) {
      final numPainter = TextPainter(
        text: TextSpan(
          text: '$pageNum',
          style: TextStyle(
            color: isDark
                ? const Color(0xFF6366F1).withValues(alpha: 0.5)
                : const Color(0xFF6366F1).withValues(alpha: 0.4),
            fontWeight: FontWeight.w800,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      numPainter.layout();
      numPainter.paint(
        canvas,
        Offset(pageLeft + pageWidth - numPainter.width - 16, pageTop + 16.0),
      );
    }

    // Hanging Bookmark Ribbon on Top Right (only current page)
    if (pageNum == pageNumber) {
      final ribbonLeft = pageLeft + pageWidth - 48.0;
      const ribbonWidth = 24.0;
      const ribbonHeight = 56.0;
      final ribbonPath = Path()
        ..moveTo(ribbonLeft, pageTop)
        ..lineTo(ribbonLeft + ribbonWidth, pageTop)
        ..lineTo(ribbonLeft + ribbonWidth, pageTop + ribbonHeight)
        ..lineTo(ribbonLeft + (ribbonWidth / 2), pageTop + ribbonHeight - 10)
        ..lineTo(ribbonLeft, pageTop + ribbonHeight)
        ..close();
      canvas.drawPath(ribbonPath, Paint()..color = const Color(0xFF6366F1));
    }

    canvas.restore(); // Exit clipped area

    // Outer Sheet Border
    canvas.drawRRect(
      pageRRect,
      Paint()
        ..color = isDark ? const Color(0xFF2E3750) : const Color(0xFFD4CFC7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  void _drawInfiniteGrid(Canvas canvas, Size size) {
    if (effectivePaperStyle == CanvasPaperStyle.blankSlate) return;

    if (effectivePaperStyle == CanvasPaperStyle.ruledLines) {
      // Authentic iPad Ruled Notebook Paper
      final rulePaint = Paint()
        ..color = isDark
            ? const Color(0xFF283046).withValues(alpha: 0.7)
            : const Color(0xFFD8E1F0).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (1.0 * zoomScale.clamp(0.8, 1.2)).clamp(0.8, 1.5);

      const baseLineHeight = 32.0;
      final stepY = baseLineHeight * zoomScale;
      if (stepY >= 8.0) {
        final startY = panOffset.dy % stepY;
        for (double y = startY - stepY; y <= size.height + stepY; y += stepY) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), rulePaint);
        }
      }

      // Vertical rose notebook margin line (iPad GoodNotes style)
      final marginX = panOffset.dx + (72.0 * zoomScale);
      if (marginX >= 0 && marginX <= size.width) {
        final marginPaint = Paint()
          ..color = const Color(
            0xFFF43F5E,
          ).withValues(alpha: isDark ? 0.35 : 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (1.5 * zoomScale.clamp(0.8, 1.2)).clamp(1.0, 2.0);
        canvas.drawLine(
          Offset(marginX, 0),
          Offset(marginX, size.height),
          marginPaint,
        );
      }
      return;
    }

    if (effectivePaperStyle == CanvasPaperStyle.graphGrid) {
      // Engineering Graph Grid
      final gridPaint = Paint()
        ..color = isDark
            ? const Color(0xFF252C40).withValues(alpha: 0.65)
            : const Color(0xFFE2E8F0).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (0.8 * zoomScale.clamp(0.7, 1.2)).clamp(0.6, 1.2);

      const baseStep = 28.0;
      final step = baseStep * zoomScale;
      if (step >= 8.0) {
        final startX = panOffset.dx % step;
        final startY = panOffset.dy % step;
        for (double x = startX - step; x <= size.width + step; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
        }
        for (double y = startY - step; y <= size.height + step; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
        }
      }
      return;
    }

    // Default Dot Grid
    final dotPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.055)
          : Colors.black.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    const baseStep = 28.0;
    final step = baseStep * zoomScale;
    if (step < 7.0) return;

    final startX = panOffset.dx % step;
    final startY = panOffset.dy % step;
    final dotRadius = (1.2 * zoomScale.clamp(0.6, 1.4)).clamp(0.8, 1.8);

    for (double x = startX - step; x <= size.width + step; x += step) {
      for (double y = startY - step; y <= size.height + step; y += step) {
        canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
      }
    }
  }

  void _drawShape(Canvas canvas, CanvasShapeItem shape) {
    final paint = Paint()
      ..color = shape.strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = shape.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = shape.fillColor != null
        ? (Paint()
            ..color = shape.fillColor!
            ..style = PaintingStyle.fill)
        : null;

    if (shape.rotation != 0) {
      canvas.save();
      canvas.translate(shape.bounds.center.dx, shape.bounds.center.dy);
      canvas.rotate(shape.rotation);
      canvas.translate(-shape.bounds.center.dx, -shape.bounds.center.dy);
    }

    if (shape.shapeType == 'rectangle') {
      if (fillPaint != null) canvas.drawRect(shape.bounds, fillPaint);
      canvas.drawRect(shape.bounds, paint);
    } else if (shape.shapeType == 'circle') {
      if (fillPaint != null) canvas.drawOval(shape.bounds, fillPaint);
      canvas.drawOval(shape.bounds, paint);
    } else if (shape.shapeType == 'arrow') {
      final p1 = shape.startPoint ?? shape.bounds.topLeft;
      final p2 = shape.endPoint ?? shape.bounds.bottomRight;
      canvas.drawLine(p1, p2, paint);

      // Render crisp directional arrowhead at target endpoint
      final angle = math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);
      final arrowSize = (shape.strokeWidth * 3.5).clamp(10.0, 24.0);
      const arrowAngle = 26.0 * math.pi / 180.0;

      final tipPath = Path()
        ..moveTo(p2.dx, p2.dy)
        ..lineTo(
          p2.dx - arrowSize * math.cos(angle - arrowAngle),
          p2.dy - arrowSize * math.sin(angle - arrowAngle),
        )
        ..lineTo(
          p2.dx - arrowSize * math.cos(angle + arrowAngle),
          p2.dy - arrowSize * math.sin(angle + arrowAngle),
        )
        ..close();

      final arrowHeadPaint = Paint()
        ..color = shape.strokeColor
        ..style = PaintingStyle.fill;
      canvas.drawPath(tipPath, arrowHeadPaint);
    } else if (shape.shapeType == 'line') {
      final p1 = shape.startPoint ?? shape.bounds.topLeft;
      final p2 = shape.endPoint ?? shape.bounds.bottomRight;
      canvas.drawLine(p1, p2, paint);
    } else if (shape.shapeType == 'triangle') {
      final path = Path()
        ..moveTo(shape.bounds.topCenter.dx, shape.bounds.topCenter.dy)
        ..lineTo(shape.bounds.bottomRight.dx, shape.bounds.bottomRight.dy)
        ..lineTo(shape.bounds.bottomLeft.dx, shape.bounds.bottomLeft.dy)
        ..close();
      if (fillPaint != null) canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, paint);
    }

    if (shape.rotation != 0) {
      canvas.restore();
    }
  }

  void _drawTape(Canvas canvas, CanvasTapeItem tape) {
    final rrect = RRect.fromRectAndRadius(tape.rect, const Radius.circular(4));

    if (tape.isMasked) {
      // GoodNotes Masked Tape: Opaque pastel tape with shadow and dashed fold
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawRRect(rrect.shift(const Offset(0, 1.5)), shadowPaint);

      final tapePaint = Paint()
        ..color = tape.color.withValues(alpha: 0.96)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rrect, tapePaint);

      final borderPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(rrect, borderPaint);

      // Subtle dashed center fold line
      final centerPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      final midY = tape.rect.center.dy;
      double startX = tape.rect.left + 8;
      final endX = tape.rect.right - 8;
      while (startX < endX) {
        canvas.drawLine(
          Offset(startX, midY),
          Offset(math.min(startX + 6, endX), midY),
          centerPaint,
        );
        startX += 10;
      }
    } else {
      // GoodNotes Revealed Tape: Translucent color with clear border (text below is readable)
      final revealBgPaint = Paint()
        ..color = tape.color.withValues(alpha: 0.16)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rrect, revealBgPaint);

      final revealBorderPaint = Paint()
        ..color = tape.color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawRRect(rrect, revealBorderPaint);

      final notchPaint = Paint()
        ..color = tape.color.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(tape.rect.left + 4, tape.rect.top + 3),
        Offset(tape.rect.left + 4, tape.rect.bottom - 3),
        notchPaint,
      );
      canvas.drawLine(
        Offset(tape.rect.right - 4, tape.rect.top + 3),
        Offset(tape.rect.right - 4, tape.rect.bottom - 3),
        notchPaint,
      );
    }
  }

  void _drawImage(Canvas canvas, CanvasImageItem image) {
    final rrect = RRect.fromRectAndRadius(
      image.bounds,
      const Radius.circular(12),
    );

    final cachedImg = imageCache?[image.id];
    if (cachedImg != null) {
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawImageRect(
        cachedImg,
        Rect.fromLTWH(
          0,
          0,
          cachedImg.width.toDouble(),
          cachedImg.height.toDouble(),
        ),
        image.bounds,
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();

      final borderPaint = Paint()
        ..color = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawRRect(rrect, borderPaint);
    } else {
      // Asynchronously decode base64 off the paint cycle so rendering never hitches/lags
      if (image.base64Data != null &&
          onImageDecoded != null &&
          !(loadingImages?.contains(image.id) ?? false)) {
        loadingImages?.add(image.id);
        final rawBase64 = image.base64Data!;
        final imgId = image.id;
        final callback = onImageDecoded;
        Future.microtask(() async {
          try {
            final bytes = base64Decode(rawBase64);
            final codec =
                await ui.instantiateImageCodec(bytes, targetWidth: 1600);
            final frame = await codec.getNextFrame();
            imageCache?[imgId] = frame.image;
            callback?.call();
          } catch (_) {
            try {
              final bytes = base64Decode(rawBase64);
              ui.decodeImageFromList(bytes, (ui.Image img) {
                imageCache?[imgId] = img;
                callback?.call();
              });
            } catch (_) {}
          }
        });
      }

      final bgPaint = Paint()
        ..color = (isDark ? const Color(0xFF1E2436) : const Color(0xFFF8FAFC))
            .withValues(alpha: 0.95)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rrect, bgPaint);

      final borderPaint = Paint()
        ..color = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawRRect(rrect, borderPaint);

      final iconPainter = TextPainter(
        text: TextSpan(
          text: '🖼️ Image',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      iconPainter.layout();
      iconPainter.paint(
        canvas,
        Offset(image.bounds.left + 12, image.bounds.top + 12),
      );
    }

    // GoodNotes style selection border & 4 corner resize handles
    if (selectedImageId == image.id) {
      final selPaint = Paint()
        ..color = const Color(0xFF3B82F6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 / zoomScale;
      canvas.drawRRect(rrect, selPaint);

      final handleFill = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final handleStroke = Paint()
        ..color = const Color(0xFF3B82F6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 / zoomScale;

      final handleRadius = 6.0 / zoomScale;
      final corners = [
        image.bounds.topLeft,
        image.bounds.topRight,
        image.bounds.bottomLeft,
        image.bounds.bottomRight,
      ];

      for (final corner in corners) {
        canvas.drawCircle(corner, handleRadius, handleFill);
        canvas.drawCircle(corner, handleRadius, handleStroke);
      }
    }
  }

  void _drawText(Canvas canvas, CanvasTextItem textItem) {
    final isAi = textItem.isAiGenerated;
    final maxWidth = textItem.maxWidth;

    if (isAi) {
      final modelName = textItem.aiModel ?? 'ChatGPT';
      final modelLower = modelName.toLowerCase();

      // Determine model accent color and badge text
      Color modelAccent = const Color(0xFF10B981); // ChatGPT emerald default
      String badgeLabel = '🤖 ChatGPT';
      if (modelLower.contains('claude')) {
        modelAccent = const Color(0xFF8B5CF6); // Claude violet
        badgeLabel = '✦ Claude';
      } else if (modelLower.contains('gemini')) {
        modelAccent = const Color(0xFF3B82F6); // Gemini blue
        badgeLabel = '✨ Gemini';
      } else if (modelLower.contains('deepseek')) {
        modelAccent = const Color(0xFF0EA5E9); // DeepSeek cyan
        badgeLabel = '⚡ DeepSeek';
      }

      final contentWidth = maxWidth - 36.0;

      // 1. Measure Model & Title Header
      final headerPainter = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: badgeLabel.toUpperCase(),
              style: TextStyle(
                color: modelAccent,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
                letterSpacing: 0.8,
              ),
            ),
            if (textItem.title != null && textItem.title!.isNotEmpty) ...[
              TextSpan(
                text: '  •  ${textItem.title}',
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF475569),
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        textDirection: TextDirection.ltr,
      );
      headerPainter.layout(maxWidth: contentWidth - 80);

      // Date stamp & Drag Handle indicator
      final metaPainter = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${textItem.formattedDate}  ',
              style: TextStyle(
                color: isDark
                    ? const Color(0xFF64748B)
                    : const Color(0xFF94A3B8),
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const TextSpan(
              text: '⠿',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        textDirection: TextDirection.ltr,
      );
      metaPainter.layout();

      // 2. Measure User Prompt Box (if present)
      TextPainter? promptPainter;
      double promptBoxHeight = 0.0;
      if (textItem.userPrompt != null && textItem.userPrompt!.isNotEmpty) {
        promptPainter = TextPainter(
          text: TextSpan(
            children: [
              const TextSpan(
                text: 'Q: ',
                style: TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
              TextSpan(
                text: textItem.userPrompt!,
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFFE2E8F0)
                      : const Color(0xFF334155),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          textDirection: TextDirection.ltr,
        );
        promptPainter.layout(maxWidth: contentWidth - 24.0);
        promptBoxHeight = promptPainter.height + 16.0;
      }

      // 3. Measure Body Text
      final bodyPainter = TextPainter(
        text: TextSpan(
          text: textItem.text,
          style: TextStyle(
            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
            fontSize: textItem.fontSize,
            height: 1.55,
            fontWeight: FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      bodyPainter.layout(maxWidth: contentWidth);

      // Compute Total Dimensions
      final cardW = maxWidth;
      final topSectionH = 40.0;
      final cardH =
          topSectionH +
          (promptBoxHeight > 0 ? promptBoxHeight + 10.0 : 0.0) +
          bodyPainter.height +
          36.0;

      final cardRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(textItem.position.dx, textItem.position.dy, cardW, cardH),
        const Radius.circular(16),
      );

      // 4. Draw Multi-Layer Drop Shadow (GoodNotes iPad aesthetic)
      final ambientShadow = Paint()
        ..color = Colors.black.withValues(alpha: isDark ? 0.38 : 0.09)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawRRect(cardRect.shift(const Offset(0, 7)), ambientShadow);

      final sharpShadow = Paint()
        ..color = Colors.black.withValues(alpha: isDark ? 0.22 : 0.05)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawRRect(cardRect.shift(const Offset(0, 2)), sharpShadow);

      // 5. Draw Paper Card Background Fill (Cream Ivory in light mode, Obsidian in dark mode)
      final paperBgColor = isDark
          ? const Color(0xFF181C2B)
          : const Color(0xFFFFFDF8);
      final bgPaint = Paint()
        ..color = paperBgColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(cardRect, bgPaint);

      // 6. Draw Subtle Faint Interior Ruled Lines across the body (notebook feel)
      final noteRulePaint = Paint()
        ..color = isDark
            ? const Color(0xFF232B40).withValues(alpha: 0.6)
            : const Color(0xFFEDE7DC).withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;

      final bodyStartY =
          textItem.position.dy +
          topSectionH +
          (promptBoxHeight > 0 ? promptBoxHeight + 10.0 : 0.0) +
          16.0;
      final bodyEndY = textItem.position.dy + cardH - 16.0;
      for (double y = bodyStartY; y < bodyEndY; y += 24.0) {
        canvas.drawLine(
          Offset(textItem.position.dx + 16.0, y),
          Offset(textItem.position.dx + cardW - 16.0, y),
          noteRulePaint,
        );
      }

      // 7. Draw Card Border
      final borderColor = isDark
          ? const Color(0xFF2E3750)
          : const Color(0xFFE5DFD5);
      final borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawRRect(cardRect, borderPaint);

      // 8. Draw Header Background & Top Accent Ribbon
      final headerRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(
          textItem.position.dx,
          textItem.position.dy,
          cardW,
          topSectionH,
        ),
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
      );
      final headerBgPaint = Paint()
        ..color = isDark ? const Color(0xFF20263A) : const Color(0xFFF7F4EE)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(headerRect, headerBgPaint);

      // Top colored ribbon stripe
      final stripeRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(textItem.position.dx, textItem.position.dy, cardW, 3.5),
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
      );
      final stripePaint = Paint()
        ..color = modelAccent
        ..style = PaintingStyle.fill;
      canvas.drawRRect(stripeRect, stripePaint);

      // Header bottom divider line
      canvas.drawLine(
        Offset(textItem.position.dx, textItem.position.dy + topSectionH),
        Offset(
          textItem.position.dx + cardW,
          textItem.position.dy + topSectionH,
        ),
        Paint()
          ..color = borderColor
          ..strokeWidth = 1.0,
      );

      // Paint Header Texts
      headerPainter.paint(
        canvas,
        Offset(textItem.position.dx + 18.0, textItem.position.dy + 12.0),
      );
      metaPainter.paint(
        canvas,
        Offset(
          textItem.position.dx + cardW - metaPainter.width - 18.0,
          textItem.position.dy + 12.0,
        ),
      );

      // 9. Paint User Prompt Box (if present)
      double currentY = textItem.position.dy + topSectionH + 10.0;
      if (promptPainter != null) {
        final promptBoxRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            textItem.position.dx + 16.0,
            currentY,
            cardW - 32.0,
            promptBoxHeight,
          ),
          const Radius.circular(8),
        );
        final promptBgPaint = Paint()
          ..color = isDark ? const Color(0xFF1E2436) : const Color(0xFFF0F4FA)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(promptBoxRect, promptBgPaint);

        final promptBorderPaint = Paint()
          ..color = const Color(0xFF6366F1).withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawRRect(promptBoxRect, promptBorderPaint);

        promptPainter.paint(
          canvas,
          Offset(textItem.position.dx + 26.0, currentY + 8.0),
        );
        currentY += promptBoxHeight + 10.0;
      }

      // 10. Paint Body Text
      bodyPainter.paint(
        canvas,
        Offset(textItem.position.dx + 18.0, currentY + 4.0),
      );
    } else {
      // If actively editing this item inline, hide static drawing to avoid ghosting/text doubling
      if (editingExistingTextId != null &&
          editingExistingTextId == textItem.id) {
        return;
      }

      // User typed notes on canvas with GoodNotes typography & styling
      TextDecoration decoration = TextDecoration.none;
      if (textItem.isUnderline && textItem.isStrikethrough) {
        decoration = TextDecoration.combine([
          TextDecoration.underline,
          TextDecoration.lineThrough,
        ]);
      } else if (textItem.isUnderline) {
        decoration = TextDecoration.underline;
      } else if (textItem.isStrikethrough) {
        decoration = TextDecoration.lineThrough;
      }

      TextStyle textStyle;
      try {
        textStyle = GoogleFonts.getFont(
          textItem.fontFamily,
          color: textItem.color,
          fontSize: textItem.fontSize,
          fontWeight: textItem.isBold ? FontWeight.bold : FontWeight.w500,
          fontStyle: textItem.isItalic ? FontStyle.italic : FontStyle.normal,
          decoration: decoration,
          height: textItem.lineHeight,
        );
      } catch (_) {
        textStyle = TextStyle(
          fontFamily: textItem.fontFamily,
          color: textItem.color,
          fontSize: textItem.fontSize,
          fontWeight: textItem.isBold ? FontWeight.bold : FontWeight.w500,
          fontStyle: textItem.isItalic ? FontStyle.italic : FontStyle.normal,
          decoration: decoration,
          height: textItem.lineHeight,
        );
      }

      final layoutWidth = (textItem.boxWidth ?? maxWidth).clamp(60.0, 2400.0);
      final textPainter = TextPainter(
        text: TextSpan(text: textItem.text, style: textStyle),
        textAlign: textItem.alignment,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(maxWidth: layoutWidth);

      final pad = textItem.padding;
      final contentWidth = textItem.boxWidth != null
          ? math.max(textItem.boxWidth!, textPainter.width)
          : textPainter.width;
      final contentHeight = textItem.boxHeight != null
          ? math.max(textItem.boxHeight!, textPainter.height)
          : textPainter.height;

      final boxRect = Rect.fromLTWH(
        textItem.position.dx - pad,
        textItem.position.dy - pad,
        contentWidth + pad * 2,
        contentHeight + pad * 2,
      );
      final boxRRect = RRect.fromRectAndRadius(
        boxRect,
        Radius.circular(textItem.borderRadius),
      );

      // 1. Draw Text Box Background (Sticky notes, Note cards, Pastels)
      if (textItem.backgroundColor != null && textItem.backgroundColor!.a > 0) {
        // Drop shadow for card feel
        canvas.drawRRect(
          boxRRect.shift(Offset(0, 3.0 / zoomScale)),
          Paint()
            ..color = Colors.black.withValues(alpha: isDark ? 0.28 : 0.08)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5.0 / zoomScale),
        );
        canvas.drawRRect(
          boxRRect,
          Paint()
            ..color = textItem.backgroundColor!
            ..style = PaintingStyle.fill,
        );
      }

      // 2. Draw Text Box Border (if specified)
      if (textItem.borderColor != null && textItem.borderWidth > 0) {
        canvas.drawRRect(
          boxRRect,
          Paint()
            ..color = textItem.borderColor!
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.0, textItem.borderWidth) / zoomScale,
        );
      }

      // 3. GoodNotes Selection Box & Grips
      final isSelected =
          (selectedTextItemId == textItem.id) || textItem.isSelected;

      if (isSelected) {
        // Selection subtle fill tint
        final selBgPaint = Paint()
          ..color = const Color(0xFF6366F1).withValues(alpha: 0.06)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(boxRRect, selBgPaint);

        // GoodNotes signature fine bounding outline
        final borderPaint = Paint()
          ..color = const Color(0xFF6366F1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 / zoomScale;
        canvas.drawRRect(boxRRect, borderPaint);

        // 4 Circular corner handles (white fill with indigo border, classic iPad GoodNotes)
        final handleRadius = 5.0 / zoomScale;
        final cornerPoints = [
          boxRect.topLeft,
          boxRect.topRight,
          boxRect.bottomLeft,
          boxRect.bottomRight,
        ];

        final handleBgPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        final handleStrokePaint = Paint()
          ..color = const Color(0xFF6366F1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / zoomScale;

        for (final pt in cornerPoints) {
          canvas.drawCircle(pt, handleRadius, handleBgPaint);
          canvas.drawCircle(pt, handleRadius, handleStrokePaint);
        }

        // 2 Side width resize pill handles (left & right edge centers)
        final sidePillW = 5.0 / zoomScale;
        final sidePillH = 15.0 / zoomScale;

        final leftCenter = Offset(boxRect.left, boxRect.center.dy);
        final rightCenter = Offset(boxRect.right, boxRect.center.dy);

        final sidePillPaint = Paint()
          ..color = const Color(0xFF6366F1)
          ..style = PaintingStyle.fill;

        for (final center in [leftCenter, rightCenter]) {
          final pillRect = RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: center,
              width: sidePillW,
              height: sidePillH,
            ),
            Radius.circular(sidePillW / 2),
          );
          canvas.drawRRect(pillRect, handleBgPaint);
          canvas.drawRRect(pillRect, sidePillPaint);
        }

        // Top Drag/Move Bar ("⠿ Move")
        final moveCenter = Offset(
          boxRect.center.dx,
          boxRect.top - (14.0 / zoomScale),
        );
        final movePillRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: moveCenter,
            width: 44.0 / zoomScale,
            height: 16.0 / zoomScale,
          ),
          Radius.circular(8.0 / zoomScale),
        );
        canvas.drawRRect(
          movePillRect,
          Paint()
            ..color = const Color(0xFF6366F1)
            ..style = PaintingStyle.fill,
        );
        final moveIconPainter = TextPainter(
          text: TextSpan(
            text: '⠿ Move',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9.0 / zoomScale,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        moveIconPainter.layout();
        moveIconPainter.paint(
          canvas,
          Offset(
            moveCenter.dx - (moveIconPainter.width / 2),
            moveCenter.dy - (moveIconPainter.height / 2),
          ),
        );
      }

      textPainter.paint(canvas, textItem.position);
    }
  }

  @override
  bool shouldRepaint(covariant CanvasPainter old) {
    return true;
  }
}

class _LaserPoint {
  final Offset position;
  final int timestamp;
  _LaserPoint(this.position, this.timestamp);
}

/// GoodNotes-accurate laser pointer painter.
///
/// Features:
/// - Multi-stroke persistent trail: allows writing multiple words and sentences.
/// - Inactivity-based hold: while writing, all strokes stay 100% visible ("jab tak likhte ha vo rukta ha").
/// - When user pauses/stops writing, all strokes smoothly dissolve together over 1000ms.
/// - Ultra-fast Catmull-Rom cubic Bezier path per stroke (exactly 4 draw calls per stroke for 120 FPS).
/// - Multi-layer laser radiance with pure white coherent core filament.
/// - Active glowing tip beacon while pen is down; cleanly hides on lift.
/// - Distinct concentric halo dot for Dot Mode.
/// - Single-point tap rendering for 'i' dots and punctuation marks.
class _LaserPointerPainter extends CustomPainter {
  final List<List<_LaserPoint>> strokes;
  final Color color;
  final String mode;
  final Offset? activePoint;
  final bool isDrawing;
  final double dotAlpha;
  final double
  masterFade; // 1.0 when active/holding, fades to 0.0 during dissolution
  final bool isPageViewMode;
  final Offset panOffset;
  final double zoomScale;
  final int totalPages;

  _LaserPointerPainter({
    required this.strokes,
    required this.color,
    required this.mode,
    this.activePoint,
    this.isDrawing = false,
    this.dotAlpha = 1.0,
    this.masterFade = 1.0,
    this.isPageViewMode = false,
    this.panOffset = Offset.zero,
    this.zoomScale = 1.0,
    this.totalPages = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    if (isPageViewMode) {
      final clipPath = Path();
      const pageLeft = _kPageLeft;
      const pageTop = _kPageTop;
      const pageWidth = _kPageWidth;
      const pageHeight = _kPageHeight;

      final screenLeft = pageLeft * zoomScale + panOffset.dx;
      final screenTop = pageTop * zoomScale + panOffset.dy;
      final screenRight = (pageLeft + pageWidth) * zoomScale + panOffset.dx;
      final screenBottom = (pageTop + pageHeight) * zoomScale + panOffset.dy;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTRB(screenLeft, screenTop, screenRight, screenBottom),
        const Radius.circular(4),
      );
      clipPath.addRRect(rrect);
      canvas.clipPath(clipPath);
    }

    if (mode == 'dot') {
      if (activePoint != null && dotAlpha > 0.0) {
        _paintDot(canvas, activePoint!, dotAlpha);
      }
      canvas.restore();
      return;
    }

    // ── Trail mode ───────────────────────────────────────────────────────────
    final alpha = masterFade.clamp(0.0, 1.0);
    if (alpha <= 0.001 && !isDrawing) {
      canvas.restore();
      return;
    }

    for (final stroke in strokes) {
      final count = stroke.length;
      if (count == 0) continue;

      if (count == 1) {
        // Single tap / dot on 'i' / punctuation
        _paintTapDot(canvas, stroke[0].position, alpha);
        continue;
      }

      // Build smooth Catmull-Rom path for the entire stroke
      final path = _buildSmoothStrokePath(stroke);
      final beamWidth = 3.6;

      // Layer 1: Outer glowing aura
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.25 * alpha)
          ..strokeWidth = beamWidth + 14.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      // Layer 2: Mid vibrant glow
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.55 * alpha)
          ..strokeWidth = beamWidth + 5.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );

      // Layer 3: Solid beam core
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.95 * alpha)
          ..strokeWidth = beamWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      // Layer 4: Hot pure-white filament (coherent laser center)
      if (alpha > 0.15) {
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.85 * alpha)
            ..strokeWidth = (beamWidth * 0.45).clamp(1.0, 2.0)
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }

    // Active glowing emitter head at pen tip
    if (isDrawing && activePoint != null) {
      _paintActiveHead(canvas, activePoint!);
    }
    canvas.restore();
  }

  Path _buildSmoothStrokePath(List<_LaserPoint> points) {
    final path = Path();
    final len = points.length;
    if (len == 0) return path;
    if (len == 1) {
      path.addOval(Rect.fromCircle(center: points[0].position, radius: 1.5));
      return path;
    }
    if (len == 2) {
      path.moveTo(points[0].position.dx, points[0].position.dy);
      path.lineTo(points[1].position.dx, points[1].position.dy);
      return path;
    }

    path.moveTo(points[0].position.dx, points[0].position.dy);
    for (int i = 0; i < len - 1; i++) {
      final p0 = (i == 0) ? points[0].position : points[i - 1].position;
      final p1 = points[i].position;
      final p2 = points[i + 1].position;
      final p3 = (i + 2 < len) ? points[i + 2].position : p2;

      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6.0,
        p1.dy + (p2.dy - p0.dy) / 6.0,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6.0,
        p2.dy - (p3.dy - p1.dy) / 6.0,
      );
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  void _paintTapDot(Canvas canvas, Offset pos, double a) {
    final eased = a * a;
    canvas.drawCircle(
      pos,
      10.0,
      Paint()
        ..color = color.withValues(alpha: 0.3 * eased)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      pos,
      3.5,
      Paint()..color = color.withValues(alpha: 0.95 * eased),
    );
    canvas.drawCircle(
      pos,
      1.8,
      Paint()..color = Colors.white.withValues(alpha: 0.9 * eased),
    );
  }

  void _paintActiveHead(Canvas canvas, Offset pos) {
    canvas.drawCircle(
      pos,
      18.0,
      Paint()
        ..color = color.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(pos, 7.0, Paint()..color = color.withValues(alpha: 0.95));
    canvas.drawCircle(pos, 3.5, Paint()..color = Colors.white);
    canvas.drawCircle(
      pos + const Offset(-1.2, -1.2),
      1.5,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  void _paintDot(Canvas canvas, Offset pos, double a) {
    canvas.drawCircle(
      pos,
      26.0,
      Paint()
        ..color = color.withValues(alpha: 0.18 * a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );
    canvas.drawCircle(
      pos,
      14.0,
      Paint()
        ..color = color.withValues(alpha: 0.40 * a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      pos,
      9.0,
      Paint()
        ..color = color.withValues(alpha: 0.92 * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(
      pos,
      4.5,
      Paint()..color = Colors.white.withValues(alpha: a),
    );
    canvas.drawCircle(
      pos + const Offset(-1.5, -1.5),
      1.8,
      Paint()..color = Colors.white.withValues(alpha: 0.75 * a),
    );
  }

  @override
  bool shouldRepaint(covariant _LaserPointerPainter oldDelegate) => true;
}

class _LiveStrokePainter extends CustomPainter {
  final LiveStrokeNotifier notifier;
  final ValueNotifier<CanvasShapeItem?>? shapeNotifier;
  final CanvasTool tool;
  final Color color;
  final double strokeWidth;
  final double opacity;
  final PenType penType;
  final PressureSensitivity sensitivity;
  final double tipSharpness;
  final double tipFlatness;
  final Offset panOffset;
  final double zoomScale;
  final bool isPageViewMode;
  final int pageNumber;
  final bool highlighterStraightLine;
  static final Paint _incrementalPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  _LiveStrokePainter({
    required this.notifier,
    this.shapeNotifier,
    required this.tool,
    required this.color,
    required this.strokeWidth,
    required this.opacity,
    required this.penType,
    required this.sensitivity,
    required this.tipSharpness,
    required this.tipFlatness,
    required this.panOffset,
    required this.zoomScale,
    required this.isPageViewMode,
    required this.pageNumber,
    this.highlighterStraightLine = false,
  }) : super(
         repaint: shapeNotifier != null
             ? Listenable.merge([notifier, shapeNotifier])
             : notifier,
       );

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Live Snapped Geometric Shape (GoodNotes Draw-and-Hold dynamic preview)
    final shape = shapeNotifier?.value;
    if (shape != null) {
      canvas.save();
      canvas.clipRect(Offset.zero & size);
      canvas.translate(panOffset.dx, panOffset.dy);
      canvas.scale(zoomScale);

      if (isPageViewMode) {
        const pageRect = Rect.fromLTWH(
          _kPageLeft,
          _kPageTop,
          _kPageWidth,
          _kPageHeight,
        );
        canvas.clipRRect(
          RRect.fromRectAndRadius(pageRect, const Radius.circular(4)),
        );
      }

      final shapePaint = Paint()
        ..color = shape.strokeColor
        ..strokeWidth = shape.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      if (shape.shapeType == 'line') {
        final p1 = shape.startPoint ?? shape.bounds.topLeft;
        final p2 = shape.endPoint ?? shape.bounds.bottomRight;
        canvas.drawLine(p1, p2, shapePaint);
      } else if (shape.shapeType == 'arrow') {
        final p1 = shape.startPoint ?? shape.bounds.topLeft;
        final p2 = shape.endPoint ?? shape.bounds.bottomRight;
        canvas.drawLine(p1, p2, shapePaint);

        // Directional arrowhead at p2
        final angle = math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);
        final arrowSize = (shape.strokeWidth * 3.5).clamp(10.0, 24.0);
        const arrowAngle = 26.0 * math.pi / 180.0;
        final arrowHeadPaint = Paint()
          ..color = shape.strokeColor
          ..style = PaintingStyle.fill;
        final tipPath = Path()
          ..moveTo(p2.dx, p2.dy)
          ..lineTo(
            p2.dx - arrowSize * math.cos(angle - arrowAngle),
            p2.dy - arrowSize * math.sin(angle - arrowAngle),
          )
          ..lineTo(
            p2.dx - arrowSize * math.cos(angle + arrowAngle),
            p2.dy - arrowSize * math.sin(angle + arrowAngle),
          )
          ..close();
        canvas.drawPath(tipPath, arrowHeadPaint);
      } else if (shape.shapeType == 'rectangle') {
        canvas.drawRect(shape.bounds, shapePaint);
      } else if (shape.shapeType == 'circle') {
        canvas.drawOval(shape.bounds, shapePaint);
      } else if (shape.shapeType == 'triangle') {
        final path = Path()
          ..moveTo(shape.bounds.topCenter.dx, shape.bounds.topCenter.dy)
          ..lineTo(shape.bounds.bottomRight.dx, shape.bounds.bottomRight.dy)
          ..lineTo(shape.bounds.bottomLeft.dx, shape.bounds.bottomLeft.dy)
          ..close();
        canvas.drawPath(path, shapePaint);
      }

      canvas.restore();
      return;
    }

    // 2. Freehand live handwriting points
    final points = notifier.value;
    if (points.isEmpty) return;

    CanvasPerformanceProfiler.instance.markPainterExecuted();

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    canvas.translate(panOffset.dx, panOffset.dy);
    canvas.scale(zoomScale);

    if (isPageViewMode) {
      // Strictly clip live stroke to the paper sheet
      const pageRect = Rect.fromLTWH(
        _kPageLeft,
        _kPageTop,
        _kPageWidth,
        _kPageHeight,
      );
      canvas.clipRRect(
        RRect.fromRectAndRadius(pageRect, const Radius.circular(4)),
      );
    }

    final isHighlighter = tool == CanvasTool.highlighter;
    final isPencil = tool == CanvasTool.pencil;
    if (points.length >= 2) {
      _incrementalPaint
        ..color = color.withValues(
          alpha: isHighlighter
              ? (opacity * 0.45).clamp(0.1, 0.45)
              : opacity.clamp(0.0, 1.0),
        )
        ..strokeWidth = (isHighlighter ? strokeWidth * 3.0 : strokeWidth).clamp(
          0.6,
          120.0,
        )
        ..strokeCap = isHighlighter ? StrokeCap.square : StrokeCap.round;
      canvas.drawPath(notifier.livePath, _incrementalPaint);
      if (notifier.lastMid != null && notifier.currentTip != null) {
        canvas.drawLine(
          notifier.lastMid!,
          notifier.currentTip!,
          _incrementalPaint,
        );
      }
    } else {
      StrokeRenderer.drawStroke(
        canvas: canvas,
        points: points,
        color: color,
        baseWidth: strokeWidth,
        penType: isHighlighter
            ? PenType.marker
            : (isPencil ? PenType.pencil : penType),
        opacity: isHighlighter ? (opacity * 0.45).clamp(0.1, 0.45) : opacity,
        sensitivity: sensitivity,
        tool: isHighlighter ? 'highlighter' : (isPencil ? 'pencil' : 'pen'),
        tipSharpness: tipSharpness,
        tipFlatness: tipFlatness,
        isLive: true,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LiveStrokePainter old) {
    return old.panOffset != panOffset ||
        old.zoomScale != zoomScale ||
        old.color != color ||
        old.strokeWidth != strokeWidth ||
        old.opacity != opacity ||
        old.tool != tool ||
        old.penType != penType ||
        old.isPageViewMode != isPageViewMode ||
        old.highlighterStraightLine != highlighterStraightLine;
  }
}

/// Clean, zero-latency eraser reticle: white inner circle with black border
class _EraserReticlePainter extends CustomPainter {
  final ValueNotifier<Offset?> posNotifier;
  final double radius;
  final bool isVisible;

  _EraserReticlePainter({
    required this.posNotifier,
    required this.radius,
    required this.isVisible,
  }) : super(repaint: posNotifier);

  static final Paint _fillPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.55)
    ..style = PaintingStyle.fill;

  static final Paint _borderPaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    if (!isVisible) return;
    final pos = posNotifier.value;
    if (pos == null) return;

    final r = radius.clamp(4.0, 180.0);

    // 1. White inner circle
    canvas.drawCircle(pos, r, _fillPaint);

    // 2. Black border cover
    canvas.drawCircle(pos, r, _borderPaint);
  }

  @override
  bool shouldRepaint(covariant _EraserReticlePainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.isVisible != isVisible;
}

class _DocumentSearchDialog extends StatefulWidget {
  final AppState state;
  final bool isDark;
  final void Function(String notebookId, int pageIndex) onNavigate;

  const _DocumentSearchDialog({
    required this.state,
    required this.isDark,
    required this.onNavigate,
  });

  @override
  State<_DocumentSearchDialog> createState() => _DocumentSearchDialogState();
}

class _DocumentSearchDialogState extends State<_DocumentSearchDialog> {
  final TextEditingController _ctrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      setState(() {
        _query = _ctrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? const Color(0xFF161B2B) : Colors.white;
    final textCol = isDark ? Colors.white : Colors.black87;
    final mutedCol = isDark ? Colors.white60 : Colors.black54;

    final results = <Map<String, dynamic>>[];
    if (_query.isNotEmpty) {
      final curDoc = widget.state.currentCanvasDoc;
      if (curDoc != null) {
        for (int i = 0; i < curDoc.pages.length; i++) {
          final page = curDoc.pages[i];
          if (page.title.toLowerCase().contains(_query)) {
            results.add({
              'type': 'Page Title',
              'title': page.title,
              'subtitle': '${curDoc.name} • Page ${i + 1}',
              'notebookId': curDoc.id,
              'pageIndex': i,
              'icon': Icons.description_outlined,
            });
          }
          for (final obj in page.objects) {
            if (obj is CanvasTextItem &&
                obj.text.toLowerCase().contains(_query)) {
              results.add({
                'type': 'Note Text',
                'title': obj.text.length > 50
                    ? '${obj.text.substring(0, 50)}…'
                    : obj.text,
                'subtitle': '${curDoc.name} • Page ${i + 1}',
                'notebookId': curDoc.id,
                'pageIndex': i,
                'icon': Icons.text_snippet_outlined,
              });
            } else if (obj is CanvasNoteCardItem &&
                (obj.title.toLowerCase().contains(_query) ||
                    obj.content.toLowerCase().contains(_query))) {
              results.add({
                'type': 'Card Note',
                'title': obj.title,
                'subtitle': '${curDoc.name} • Page ${i + 1}',
                'notebookId': curDoc.id,
                'pageIndex': i,
                'icon': Icons.sticky_note_2_outlined,
              });
            }
          }
        }
      }

      for (final doc in widget.state.canvasDocs) {
        if (doc.name.toLowerCase().contains(_query)) {
          results.add({
            'type': 'Notebook',
            'title': doc.name,
            'subtitle': '${doc.pages.length} Pages • Workspace Notebook',
            'notebookId': doc.id,
            'pageIndex': 0,
            'icon': Icons.auto_stories_rounded,
          });
        }
      }
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF2C354C) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
              blurRadius: 36,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? const Color(0xFF2C354C)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      style: TextStyle(color: textCol, fontSize: 15),
                      decoration: InputDecoration(
                        hintText:
                            'Search notebook titles, page names, or notes…',
                        hintStyle: TextStyle(color: mutedCol, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_ctrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _ctrl.clear(),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _query.isEmpty
                  ? Center(
                      child: Text(
                        'Type keywords to search across notebooks and pages',
                        style: TextStyle(color: mutedCol, fontSize: 13),
                      ),
                    )
                  : (results.isEmpty
                        ? Center(
                            child: Text(
                              'No matches found for "$_query"',
                              style: TextStyle(color: mutedCol, fontSize: 13),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: results.length,
                            separatorBuilder: (_, _) => Divider(
                              height: 1,
                              color: isDark
                                  ? const Color(0xFF22283A)
                                  : const Color(0xFFF1F5F9),
                            ),
                            itemBuilder: (ctx, idx) {
                              final r = results[idx];
                              return ListTile(
                                dense: true,
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    r['icon'] as IconData,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                ),
                                title: Text(
                                  r['title'] as String,
                                  style: TextStyle(
                                    color: textCol,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: Text(
                                  r['subtitle'] as String,
                                  style: TextStyle(
                                    color: mutedCol,
                                    fontSize: 11,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF242C40)
                                        : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    r['type'] as String,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: mutedCol,
                                    ),
                                  ),
                                ),
                                onTap: () => widget.onNavigate(
                                  r['notebookId'] as String,
                                  r['pageIndex'] as int,
                                ),
                              );
                            },
                          )),
            ),
          ],
        ),
      ),
    );
  }
}
