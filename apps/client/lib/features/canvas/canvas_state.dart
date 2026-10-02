import 'package:flutter/material.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke_point.dart';
import 'package:ai_workspace_client/features/canvas/models/pen_settings.dart';

enum LassoSelectionMode {
  freehand,
  rectangular,
}

/// High-performance live stroke notifier that eliminates list cloning on every 240Hz Apple Pencil event.
class LiveStrokeNotifier extends ValueNotifier<List<StrokePoint>> {
  LiveStrokeNotifier() : super([]);

  void start(StrokePoint point) {
    value = [point];
  }

  void add(StrokePoint point) {
    value.add(point);
    notifyListeners();
  }

  void updateLast(StrokePoint point) {
    if (value.isNotEmpty) {
      value.last = point;
      notifyListeners();
    } else {
      add(point);
    }
  }

  void clear() {
    value = [];
  }
}

/// Performance-optimized state container for the active drawing canvas.
/// Separates live stroke mutations from the main Flutter widget tree
/// so drawing events run at 60/120fps without triggering full-screen rebuilds.
class CanvasDrawingState with ChangeNotifier {
  // Live stroke points (isolated LiveStrokeNotifier for zero-allocation targeted repaint)
  final LiveStrokeNotifier liveStrokeNotifier = LiveStrokeNotifier();
  // Live shape preview notifier for GoodNotes draw-and-hold dynamic adjustments
  final ValueNotifier<CanvasShapeItem?> liveShapeNotifier = ValueNotifier<CanvasShapeItem?>(null);

  // Active Tool Configuration
  CanvasTool _currentTool = CanvasTool.pen;
  PenType _currentPenType = PenType.ballpoint;
  Color _strokeColor = const Color(0xFFE11D48); // Goodnotes signature default red/coral
  double _strokeWidth = 3.0;
  double _strokeOpacity = 1.0;
  EraserMode _eraserMode = EraserMode.stroke;

  // Goodnotes Lasso Tool Configuration
  LassoSelectionMode _lassoMode = LassoSelectionMode.freehand;
  bool _lassoIncludeHandwriting = true;
  bool _lassoIncludeImages = true;
  bool _lassoIncludeShapes = true;
  bool _lassoIncludeArrows = true;
  bool _lassoIncludeTextBox = true;
  bool _lassoIncludeEquations = true;
  bool _lassoIncludeTape = true;
  bool _lassoIncludeStickyNotes = true;

  // Per-Pen Independent Configuration (Fountain, Ball, Brush, etc.)
  final Map<PenType, PenSettings> _penSettings = {
    for (final t in PenType.values) t: PenSettings.defaultFor(t),
  };

  PenSettings get currentPenSettings => _penSettings[_currentPenType] ?? PenSettings.defaultFor(_currentPenType);
  PenSettings penSettingsFor(PenType type) => _penSettings[type] ?? PenSettings.defaultFor(type);

  bool _drawAndHold = true;          // Goodnotes-style draw-and-hold shape recognition enabled by default
  bool _fingerDrawingEnabled = true; // True by default: touch/stylus draws immediately; 2 fingers pinch/pan
  bool _eraseHighlighterOnly = false;
  bool _highlighterStraightLine = true;
  String _laserMode = 'trail';       // 'dot' or 'trail'
  Color _laserColor = const Color(0xFFEF4444);
  Color _tapeColor = const Color(0xFFFDE047);
  double _tapeHeight = 28.0;

  final List<double> _penWidthPresets = [1.5, 3.0, 6.0];
  final List<double> _highlighterWidthPresets = [14.0, 24.0, 36.0];
  final List<double> _eraserWidthPresets = [12.0, 24.0, 48.0];
  int _selectedPresetIndex = 1; // Medium active
  int _selectedEraserPresetIndex = 1;

  // Quick color palette (matching screenshot: active dot + swatches)
  final List<Color> _quickPalette = [
    const Color(0xFFE11D48), // Coral / Red (Active in screenshot)
    const Color(0xFF2563EB), // Royal Blue
    const Color(0xFF0F172A), // Jet Black
    const Color(0xFF64748B), // Slate / Gray
    const Color(0xFF16A34A), // Forest Green
    const Color(0xFF9333EA), // Purple
  ];

  // Viewport navigation
  double _zoomScale = 1.0;
  Offset _panOffset = Offset.zero;

  // Selection state
  final List<CanvasObjectItem> _selectedObjects = [];

  // Drag selection / shape creation
  Offset? _dragStart;
  Offset? _dragCurrent;

  // Getters
  List<StrokePoint> get livePoints => liveStrokeNotifier.value;
  CanvasTool get currentTool => _currentTool;
  PenType get currentPenType => _currentPenType;
  Color get strokeColor => _strokeColor;
  double get strokeWidth => _strokeWidth;
  double get strokeOpacity => _strokeOpacity;
  PressureSensitivity get pressureSensitivity => currentPenSettings.pressureSensitivity;
  EraserMode get eraserMode => _eraserMode;
  double get tipSharpness => currentPenSettings.tipSharpness;
  double get tipFlatness => currentPenSettings.tipFlatness;
  double get strokeStabilization => currentPenSettings.strokeStabilization;
  bool get drawAndHold => _drawAndHold;
  bool get fingerDrawingEnabled => _fingerDrawingEnabled;
  bool get eraseHighlighterOnly => _eraseHighlighterOnly;
  bool get highlighterStraightLine => _highlighterStraightLine;

  void setHighlighterStraightLine(bool val) {
    if (_highlighterStraightLine != val) {
      _highlighterStraightLine = val;
      notifyListeners();
    }
  }

  void setFingerDrawingEnabled(bool val) {
    if (_fingerDrawingEnabled != val) {
      _fingerDrawingEnabled = val;
      notifyListeners();
    }
  }
  String get laserMode => _laserMode;
  Color get laserColor => _laserColor;
  Color get tapeColor => _tapeColor;
  double get tapeHeight => _tapeHeight;

  void setTapeColor(Color color) {
    if (_tapeColor != color) {
      _tapeColor = color;
      notifyListeners();
    }
  }

  void setTapeHeight(double height) {
    if (_tapeHeight != height) {
      _tapeHeight = height;
      notifyListeners();
    }
  }

  List<double> get penWidthPresets => _penWidthPresets;
  List<double> get highlighterWidthPresets => _highlighterWidthPresets;
  List<double> get eraserWidthPresets => _eraserWidthPresets;
  int get selectedPresetIndex => _selectedPresetIndex;
  int get selectedEraserPresetIndex => _selectedEraserPresetIndex;
  List<Color> get quickPalette => _quickPalette;
  double get zoomScale => _zoomScale;
  Offset get panOffset => _panOffset;
  List<CanvasObjectItem> get selectedObjects => _selectedObjects;
  Offset? get dragStart => _dragStart;
  Offset? get dragCurrent => _dragCurrent;

  // Lasso Getters
  LassoSelectionMode get lassoMode => _lassoMode;
  bool get lassoIncludeHandwriting => _lassoIncludeHandwriting;
  bool get lassoIncludeImages => _lassoIncludeImages;
  bool get lassoIncludeShapes => _lassoIncludeShapes;
  bool get lassoIncludeArrows => _lassoIncludeArrows;
  bool get lassoIncludeTextBox => _lassoIncludeTextBox;
  bool get lassoIncludeEquations => _lassoIncludeEquations;
  bool get lassoIncludeTape => _lassoIncludeTape;
  bool get lassoIncludeStickyNotes => _lassoIncludeStickyNotes;

  void setLassoMode(LassoSelectionMode mode) {
    if (_lassoMode != mode) {
      _lassoMode = mode;
      notifyListeners();
    }
  }

  void setLassoIncludeHandwriting(bool val) {
    _lassoIncludeHandwriting = val;
    notifyListeners();
  }

  void setLassoIncludeImages(bool val) {
    _lassoIncludeImages = val;
    notifyListeners();
  }

  void setLassoIncludeShapes(bool val) {
    _lassoIncludeShapes = val;
    notifyListeners();
  }

  void setLassoIncludeArrows(bool val) {
    _lassoIncludeArrows = val;
    notifyListeners();
  }

  void setLassoIncludeTextBox(bool val) {
    _lassoIncludeTextBox = val;
    notifyListeners();
  }

  void setLassoIncludeEquations(bool val) {
    _lassoIncludeEquations = val;
    notifyListeners();
  }

  void setLassoIncludeTape(bool val) {
    _lassoIncludeTape = val;
    notifyListeners();
  }

  void setLassoIncludeStickyNotes(bool val) {
    _lassoIncludeStickyNotes = val;
    notifyListeners();
  }

  void setAllLassoFilters(bool enabled) {
    _lassoIncludeHandwriting = enabled;
    _lassoIncludeImages = enabled;
    _lassoIncludeShapes = enabled;
    _lassoIncludeArrows = enabled;
    _lassoIncludeTextBox = enabled;
    _lassoIncludeEquations = enabled;
    _lassoIncludeTape = enabled;
    _lassoIncludeStickyNotes = enabled;
    notifyListeners();
  }

  bool isObjectEligibleForLasso(CanvasObjectItem obj) {
    if (obj is CanvasStrokeItem) return _lassoIncludeHandwriting;
    if (obj is CanvasImageItem) return _lassoIncludeImages;
    if (obj is CanvasShapeItem) {
      if (obj.shapeType == 'line' || obj.shapeType == 'arrow') {
        return _lassoIncludeArrows;
      }
      return _lassoIncludeShapes;
    }
    if (obj is CanvasTextItem) {
      if (obj.isEquation) return _lassoIncludeEquations;
      return _lassoIncludeTextBox;
    }
    if (obj is CanvasTapeItem) return _lassoIncludeTape;
    if (obj is CanvasNoteCardItem) return _lassoIncludeStickyNotes;
    return true;
  }

  void setTool(CanvasTool tool) {
    if (_currentTool != tool) {
      final wasHighlighter = _currentTool == CanvasTool.highlighter;
      final isHighlighter = tool == CanvasTool.highlighter;
      _currentTool = tool;
      if (tool == CanvasTool.pencil) {
        _currentPenType = PenType.pencil;
        _strokeOpacity = 0.85;
      } else if (tool == CanvasTool.pen && _currentPenType == PenType.pencil) {
        _currentPenType = PenType.fountainPen;
        _strokeOpacity = 1.0;
      }
      if (isHighlighter && !wasHighlighter) {
        _strokeWidth = _highlighterWidthPresets[_selectedPresetIndex];
      } else if (!isHighlighter && wasHighlighter) {
        _strokeWidth = _penWidthPresets[_selectedPresetIndex];
      }
      notifyListeners();
    }
  }

  void setPenType(PenType type) {
    if (_currentPenType != type) {
      _currentPenType = type;
      notifyListeners();
    }
  }

  void setColor(Color color) {
    if (_strokeColor != color) {
      _strokeColor = color;
      if (!_quickPalette.any((c) => c.toARGB32() == color.toARGB32())) {
        _quickPalette[_selectedPresetIndex % _quickPalette.length] = color;
      }
      notifyListeners();
    }
  }

  void setStrokeWidth(double width) {
    if (_strokeWidth != width) {
      _strokeWidth = width;
      notifyListeners();
    }
  }

  void selectWidthPreset(int index) {
    if (_selectedPresetIndex != index) {
      _selectedPresetIndex = index;
      if (_currentTool == CanvasTool.highlighter) {
        _strokeWidth = _highlighterWidthPresets[index];
      } else if (_currentTool == CanvasTool.eraser) {
        _selectedEraserPresetIndex = index;
      } else {
        _strokeWidth = _penWidthPresets[index];
      }
      notifyListeners();
    }
  }

  void selectEraserWidthPreset(int index) {
    if (_selectedEraserPresetIndex != index) {
      _selectedEraserPresetIndex = index;
      notifyListeners();
    }
  }

  void updateWidthPreset(int index, double newWidth) {
    if (index >= 0 && index < 3) {
      if (_currentTool == CanvasTool.highlighter) {
        _highlighterWidthPresets[index] = newWidth;
      } else {
        _penWidthPresets[index] = newWidth;
      }
      if (_selectedPresetIndex == index) {
        _strokeWidth = newWidth;
      }
      notifyListeners();
    }
  }

  void setStrokeOpacity(double opacity) {
    if (_strokeOpacity != opacity) {
      _strokeOpacity = opacity;
      notifyListeners();
    }
  }

  void setPressureSensitivity(PressureSensitivity sensitivity) {
    if (currentPenSettings.pressureSensitivity != sensitivity) {
      currentPenSettings.pressureSensitivity = sensitivity;
      notifyListeners();
    }
  }

  void setEraserMode(EraserMode mode) {
    if (_eraserMode != mode) {
      _eraserMode = mode;
      notifyListeners();
    }
  }

  void setTipSharpness(double val) {
    currentPenSettings.tipSharpness = val.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setTipFlatness(double val) {
    currentPenSettings.tipFlatness = val.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setStrokeStabilization(double val) {
    currentPenSettings.strokeStabilization = val.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setPenSettings(PenType type, PenSettings settings) {
    _penSettings[type] = settings;
    notifyListeners();
  }

  void setDrawAndHold(bool val) {
    _drawAndHold = val;
    notifyListeners();
  }

  void setEraseHighlighterOnly(bool val) {
    _eraseHighlighterOnly = val;
    notifyListeners();
  }

  void setLaserMode(String mode) {
    _laserMode = mode;
    notifyListeners();
  }

  void setLaserColor(Color color) {
    _laserColor = color;
    notifyListeners();
  }

  void setPan(Offset offset) {
    _panOffset = offset;
    notifyListeners();
  }

  void setZoom(double zoom) {
    _zoomScale = zoom.clamp(0.25, 5.0);
    notifyListeners();
  }

  void setDrag(Offset? start, Offset? current) {
    _dragStart = start;
    _dragCurrent = current;
    notifyListeners();
  }

  void setSelectedObjects(List<CanvasObjectItem> objects) {
    _selectedObjects.clear();
    _selectedObjects.addAll(objects);
    notifyListeners();
  }

  void clearSelection() {
    for (final o in _selectedObjects) {
      o.isSelected = false;
    }
    _selectedObjects.clear();
    notifyListeners();
  }

  /// Live stroke point updates do NOT call notifyListeners();
  /// they only mutate the liveStrokeNotifier, driving only the live RepaintBoundary!
  void updateLivePoints(List<StrokePoint> points) {
    liveStrokeNotifier.value = points;
  }

  void clearLivePoints() {
    liveStrokeNotifier.value = [];
  }

  @override
  void dispose() {
    liveStrokeNotifier.dispose();
    liveShapeNotifier.dispose();
    super.dispose();
  }
}
