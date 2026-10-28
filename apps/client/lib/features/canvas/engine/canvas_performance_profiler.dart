import 'dart:math' as math;

/// Lightweight, zero-allocation runtime profiling for Apple Pencil and Canvas inking.
/// Collects high-resolution timestamps for:
/// T0: PointerDown received
/// T1: First point appended
/// T2: Geometry updated
/// T3: Repaint requested
/// T4: CustomPainter executed
/// T5: PointerUp
/// T6: Next PointerDown
class CanvasPerformanceProfiler {
  static final CanvasPerformanceProfiler instance = CanvasPerformanceProfiler._();
  CanvasPerformanceProfiler._();

  bool isEnabled = false;

  int? _t0DownUs;
  int? _t1PointAppendedUs;
  int? _t2GeometryUpdatedUs;
  int? _t3RepaintRequestedUs;
  int? _t4PainterExecutedUs;
  int? _t5UpUs;

  int? get t0DownUs => _t0DownUs;
  int? get t1PointAppendedUs => _t1PointAppendedUs;
  int? get t2GeometryUpdatedUs => _t2GeometryUpdatedUs;
  int? get t3RepaintRequestedUs => _t3RepaintRequestedUs;
  int? get t4PainterExecutedUs => _t4PainterExecutedUs;
  int? get t5UpUs => _t5UpUs;

  /// Duration from point received to appended (microseconds)
  int get appendDurationUs => (_t1PointAppendedUs != null && _t0DownUs != null)
      ? math.max(0, _t1PointAppendedUs! - _t0DownUs!)
      : 0;

  /// Duration for midpoint quadratic geometry computation (microseconds)
  int get geometryDurationUs => (_t2GeometryUpdatedUs != null && _t1PointAppendedUs != null)
      ? math.max(0, _t2GeometryUpdatedUs! - _t1PointAppendedUs!)
      : 0;

  /// Duration for custom painter raster execution (microseconds)
  int get painterDurationUs => (_t4PainterExecutedUs != null && _t3RepaintRequestedUs != null)
      ? math.max(0, _t4PainterExecutedUs! - _t3RepaintRequestedUs!)
      : 0;

  // Running metrics (milliseconds)
  double latestDownToFirstPaintMs = 0.0;
  double latestMoveToPaintMs = 0.0;
  double latestUpToDownGapMs = 0.0;
  double minUpToDownGapMs = double.infinity;
  double maxMoveToPaintMs = 0.0;

  int totalStrokesCompleted = 0;
  int totalMovePointsProcessed = 0;

  // Recent 32-sample ring buffer for moving averages
  final List<double> _recentDownToPaint = [];
  final List<double> _recentMoveToPaint = [];
  final List<double> _recentUpToDown = [];

  double get avgDownToFirstPaintMs => _average(_recentDownToPaint);
  double get avgMoveToPaintMs => _average(_recentMoveToPaint);
  double get avgUpToDownGapMs => _average(_recentUpToDown);

  void markPointerDown() {
    if (!isEnabled) return;
    final now = DateTime.now().microsecondsSinceEpoch;
    if (_t5UpUs != null) {
      final gap = (now - _t5UpUs!) / 1000.0;
      latestUpToDownGapMs = gap;
      minUpToDownGapMs = math.min(minUpToDownGapMs, gap);
      _addToRing(_recentUpToDown, gap);
    }
    _t0DownUs = now;
    _t1PointAppendedUs = null;
    _t2GeometryUpdatedUs = null;
    _t3RepaintRequestedUs = null;
  }

  void markPointAppended() {
    if (!isEnabled) return;
    _t1PointAppendedUs = DateTime.now().microsecondsSinceEpoch;
  }

  void markGeometryUpdated() {
    if (!isEnabled) return;
    _t2GeometryUpdatedUs = DateTime.now().microsecondsSinceEpoch;
  }

  void markRepaintRequested() {
    if (!isEnabled) return;
    _t3RepaintRequestedUs = DateTime.now().microsecondsSinceEpoch;
  }

  void markPainterExecuted() {
    if (!isEnabled) return;
    final now = DateTime.now().microsecondsSinceEpoch;
    _t4PainterExecutedUs = now;

    if (_t0DownUs != null) {
      final downToPaint = (now - _t0DownUs!) / 1000.0;
      latestDownToFirstPaintMs = downToPaint;
      _addToRing(_recentDownToPaint, downToPaint);
      _t0DownUs = null; // Only record once per stroke start
    } else if (_t3RepaintRequestedUs != null) {
      final moveToPaint = (now - _t3RepaintRequestedUs!) / 1000.0;
      latestMoveToPaintMs = moveToPaint;
      maxMoveToPaintMs = math.max(maxMoveToPaintMs, moveToPaint);
      _addToRing(_recentMoveToPaint, moveToPaint);
      totalMovePointsProcessed++;
    }
  }

  void markPointerUp() {
    if (!isEnabled) return;
    _t5UpUs = DateTime.now().microsecondsSinceEpoch;
    totalStrokesCompleted++;
  }

  void reset() {
    isEnabled = true;
    _t0DownUs = null;
    _t1PointAppendedUs = null;
    _t2GeometryUpdatedUs = null;
    _t3RepaintRequestedUs = null;
    _t4PainterExecutedUs = null;
    _t5UpUs = null;
    latestDownToFirstPaintMs = 0.0;
    latestMoveToPaintMs = 0.0;
    latestUpToDownGapMs = 0.0;
    minUpToDownGapMs = double.infinity;
    maxMoveToPaintMs = 0.0;
    totalStrokesCompleted = 0;
    totalMovePointsProcessed = 0;
    _recentDownToPaint.clear();
    _recentMoveToPaint.clear();
    _recentUpToDown.clear();
  }

  void _addToRing(List<double> list, double value) {
    if (list.length >= 32) list.removeAt(0);
    list.add(value);
  }

  double _average(List<double> list) {
    if (list.isEmpty) return 0.0;
    double sum = 0.0;
    for (final v in list) {
      sum += v;
    }
    return sum / list.length;
  }
}
