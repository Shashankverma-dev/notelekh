import 'dart:math' as math;
import 'package:flutter/material.dart';

enum CanvasTool {
  hand,
  pen,
  pencil,
  brush,
  highlighter,
  eraser,
  lasso,
  rectangle,
  circle,
  triangle,
  star,
  line,
  arrow,
  text,
  image,
  elements,
  tape,
  laser,
}

enum CanvasPaperStyle {
  dotGrid,
  ruledLines,
  narrowRuled,
  graphGrid,
  blankSlate,
  cornell,
  planner,
}

enum EraserMode {
  stroke,   // removes full strokes touched
  segment,  // removes only the touched segment of a stroke
  area,     // drag to erase a rectangular area
}

enum PressureSensitivity {
  off,
  low,
  medium,
  high,
  custom,
}

enum CanvasDocType {
  notebook,     // Goodnotes-style paginated A4 pages
  canvas,       // Infinite whiteboard / freeform drawing board
  textDocument, // Markdown / structured rich text document
}

/// Abstract base class for all persistent items on the canvas
abstract class CanvasObjectItem {
  final String id;
  final String objectType; // 'stroke', 'shape', 'text', 'note_card'
  final int zIndex;
  bool isSelected;

  CanvasObjectItem({
    required this.id,
    required this.objectType,
    this.zIndex = 0,
    this.isSelected = false,
  });

  Map<String, dynamic> toJson();
  Rect getBoundingBox();
  bool hits(Offset point, {double padding = 8.0});
}

class CanvasShapeItem extends CanvasObjectItem {
  final String shapeType; // 'rectangle', 'circle', 'triangle', 'star', 'line', 'arrow'
  Rect bounds;
  final Color strokeColor;
  final double strokeWidth;
  final Color? fillColor;
  double rotation; // radians
  Offset? startPoint;
  Offset? endPoint;

  CanvasShapeItem({
    required super.id,
    required this.shapeType,
    required this.bounds,
    required this.strokeColor,
    this.strokeWidth = 2.5,
    this.fillColor,
    this.rotation = 0.0,
    this.startPoint,
    this.endPoint,
    super.zIndex = 0,
    super.isSelected = false,
  }) : super(objectType: 'shape');

  CanvasShapeItem copyWith({
    String? id,
    String? shapeType,
    Rect? bounds,
    Color? strokeColor,
    double? strokeWidth,
    Color? fillColor,
    double? rotation,
    Offset? startPoint,
    Offset? endPoint,
    int? zIndex,
    bool? isSelected,
  }) {
    return CanvasShapeItem(
      id: id ?? this.id,
      shapeType: shapeType ?? this.shapeType,
      bounds: bounds ?? this.bounds,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      fillColor: fillColor ?? this.fillColor,
      rotation: rotation ?? this.rotation,
      startPoint: startPoint ?? this.startPoint,
      endPoint: endPoint ?? this.endPoint,
      zIndex: zIndex ?? this.zIndex,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  Rect getBoundingBox() {
    if ((shapeType == 'line' || shapeType == 'arrow') && startPoint != null && endPoint != null) {
      return Rect.fromPoints(startPoint!, endPoint!).inflate(strokeWidth + 4);
    }
    return bounds.inflate(strokeWidth);
  }

  @override
  bool hits(Offset point, {double padding = 8.0}) {
    if (shapeType == 'line' || shapeType == 'arrow') {
      final p1 = startPoint ?? bounds.topLeft;
      final p2 = endPoint ?? bounds.bottomRight;
      final dist = _distToSegment(point, p1, p2);
      return dist <= (strokeWidth / 2 + padding + 4.0);
    }

    final hasFill = fillColor != null && fillColor!.a > 0.05;
    final totalPad = strokeWidth / 2 + padding;

    if (shapeType == 'circle') {
      final center = bounds.center;
      final radius = math.min(bounds.width, bounds.height) / 2.0;
      final dist = (point - center).distance;
      if (hasFill) {
        return dist <= (radius + totalPad);
      } else {
        // Hollow circle: must be near the perimeter ring
        return (dist - radius).abs() <= totalPad;
      }
    }

    if (shapeType == 'rectangle') {
      if (hasFill) {
        return bounds.inflate(totalPad).contains(point);
      }
      // Hollow rectangle: must be near one of the 4 perimeter edges
      final nearTop = _distToSegment(point, bounds.topLeft, bounds.topRight) <= totalPad;
      final nearBottom = _distToSegment(point, bounds.bottomLeft, bounds.bottomRight) <= totalPad;
      final nearLeft = _distToSegment(point, bounds.topLeft, bounds.bottomLeft) <= totalPad;
      final nearRight = _distToSegment(point, bounds.topRight, bounds.bottomRight) <= totalPad;
      return nearTop || nearBottom || nearLeft || nearRight;
    }

    return getBoundingBox().inflate(padding).contains(point);
  }

  static double _distToSegment(Offset p, Offset v, Offset w) {
    final l2 = (v - w).distanceSquared;
    if (l2 == 0) return (p - v).distance;
    final t = (((p.dx - v.dx) * (w.dx - v.dx) + (p.dy - v.dy) * (w.dy - v.dy)) / l2).clamp(0.0, 1.0);
    final projection = Offset(v.dx + t * (w.dx - v.dx), v.dy + t * (w.dy - v.dy));
    return (p - projection).distance;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'object_type': 'shape',
      'z_index': zIndex,
      'bounds': {
        'x': bounds.left,
        'y': bounds.top,
        'width': bounds.width,
        'height': bounds.height,
      },
      'data': {
        'shape_type': shapeType,
        'stroke_color': '#${strokeColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
        'stroke_width': strokeWidth,
        'fill_color': fillColor != null ? '#${fillColor!.toARGB32().toRadixString(16).padLeft(8, '0')}' : null,
        'rotation': rotation,
        if (startPoint != null) ...{
          'start_x': startPoint!.dx,
          'start_y': startPoint!.dy,
        },
        if (endPoint != null) ...{
          'end_x': endPoint!.dx,
          'end_y': endPoint!.dy,
        },
      }
    };
  }

  factory CanvasShapeItem.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final bounds = json['bounds'] as Map<String, dynamic>? ?? {};
    final x = (bounds['x'] as num?)?.toDouble() ?? 0.0;
    final y = (bounds['y'] as num?)?.toDouble() ?? 0.0;
    final w = (bounds['width'] as num?)?.toDouble() ?? 100.0;
    final h = (bounds['height'] as num?)?.toDouble() ?? 100.0;

    final colorHex = data['stroke_color'] as String? ?? '#FF6366F1';
    final parsedColor = Color(int.parse(colorHex.replaceFirst('#', ''), radix: 16));

    Color? parsedFill;
    if (data['fill_color'] != null) {
      final fillHex = data['fill_color'] as String;
      parsedFill = Color(int.parse(fillHex.replaceFirst('#', ''), radix: 16));
    }

    Offset? startPt;
    Offset? endPt;
    if (data['start_x'] != null && data['start_y'] != null) {
      startPt = Offset((data['start_x'] as num).toDouble(), (data['start_y'] as num).toDouble());
    }
    if (data['end_x'] != null && data['end_y'] != null) {
      endPt = Offset((data['end_x'] as num).toDouble(), (data['end_y'] as num).toDouble());
    }

    return CanvasShapeItem(
      id: json['id'] as String,
      shapeType: data['shape_type'] as String? ?? 'rectangle',
      bounds: Rect.fromLTWH(x, y, w, h),
      strokeColor: parsedColor,
      strokeWidth: (data['stroke_width'] as num?)?.toDouble() ?? 2.5,
      fillColor: parsedFill,
      rotation: (data['rotation'] as num?)?.toDouble() ?? 0.0,
      startPoint: startPt,
      endPoint: endPt,
      zIndex: json['z_index'] as int? ?? 0,
    );
  }
}

class CanvasTextItem extends CanvasObjectItem {
  final String text;
  Offset position;
  final Color color;
  final double fontSize;
  final String? title;
  final bool isAiGenerated;
  final double maxWidth;
  final String? userPrompt;
  final String? aiModel;
  final String paperStyle;
  final DateTime createdAt;
  // Text formatting
  final String fontFamily;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final bool isStrikethrough;
  final TextAlign alignment;
  final double lineHeight;
  // GoodNotes Text Box styling
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final double borderRadius;
  final double padding;
  double? boxWidth;
  double? boxHeight;

  CanvasTextItem({
    required super.id,
    required this.text,
    required this.position,
    required this.color,
    this.fontSize = 15.0,
    this.title,
    this.isAiGenerated = false,
    this.maxWidth = 500.0,
    this.userPrompt,
    this.aiModel,
    this.paperStyle = 'ruled',
    DateTime? createdAt,
    this.fontFamily = 'Inter',
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrikethrough = false,
    this.alignment = TextAlign.left,
    this.lineHeight = 1.35,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 0.0,
    this.borderRadius = 8.0,
    this.padding = 8.0,
    this.boxWidth,
    this.boxHeight,
    super.zIndex = 0,
    super.isSelected = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       super(objectType: 'text');

  CanvasTextItem copyWith({
    String? id,
    String? text,
    Offset? position,
    Color? color,
    double? fontSize,
    String? title,
    bool? isAiGenerated,
    double? maxWidth,
    String? userPrompt,
    String? aiModel,
    String? paperStyle,
    DateTime? createdAt,
    String? fontFamily,
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
    bool? isStrikethrough,
    TextAlign? alignment,
    double? lineHeight,
    Color? backgroundColor,
    bool clearBackgroundColor = false,
    Color? borderColor,
    bool clearBorderColor = false,
    double? borderWidth,
    double? borderRadius,
    double? padding,
    double? boxWidth,
    double? boxHeight,
    int? zIndex,
    bool? isSelected,
  }) {
    return CanvasTextItem(
      id: id ?? this.id,
      text: text ?? this.text,
      position: position ?? this.position,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
      title: title ?? this.title,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      maxWidth: maxWidth ?? this.maxWidth,
      userPrompt: userPrompt ?? this.userPrompt,
      aiModel: aiModel ?? this.aiModel,
      paperStyle: paperStyle ?? this.paperStyle,
      createdAt: createdAt ?? this.createdAt,
      fontFamily: fontFamily ?? this.fontFamily,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      isStrikethrough: isStrikethrough ?? this.isStrikethrough,
      alignment: alignment ?? this.alignment,
      lineHeight: lineHeight ?? this.lineHeight,
      backgroundColor: clearBackgroundColor ? null : (backgroundColor ?? this.backgroundColor),
      borderColor: clearBorderColor ? null : (borderColor ?? this.borderColor),
      borderWidth: borderWidth ?? this.borderWidth,
      borderRadius: borderRadius ?? this.borderRadius,
      padding: padding ?? this.padding,
      boxWidth: boxWidth ?? this.boxWidth,
      boxHeight: boxHeight ?? this.boxHeight,
      zIndex: zIndex ?? this.zIndex,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  String get formattedDate {
    final h = createdAt.hour.toString().padLeft(2, '0');
    final m = createdAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  bool get isEquation =>
      title?.toLowerCase().contains('equation') == true ||
      text.contains(r'\frac') ||
      text.contains(r'$$') ||
      text.contains(r'\sqrt') ||
      (text.contains('=') && (text.contains('x') || text.contains('y') || text.contains('^')));

  @override
  Rect getBoundingBox() {
    if (isAiGenerated) {
      final lines = text.split('\n');
      int lineCount = 0;
      double maxLineLen = 0;
      for (var l in lines) {
        if (l.length > maxLineLen) maxLineLen = l.length.toDouble();
        final wrappedLines = (l.length * fontSize * 0.55 / maxWidth).ceil();
        lineCount += wrappedLines > 0 ? wrappedLines : 1;
      }
      if (title != null && title!.isNotEmpty) {
        lineCount += 2;
      }
      if (userPrompt != null && userPrompt!.isNotEmpty) {
        lineCount += 2;
      }
      final estimatedWidth = boxWidth ?? (maxLineLen * fontSize * 0.55).clamp(240.0, maxWidth) + 44.0;
      final estimatedHeight = boxHeight ?? (lineCount * fontSize * 1.55).clamp(80.0, 3600.0) + 48.0;
      return Rect.fromLTWH(position.dx - 12, position.dy - 10, estimatedWidth, estimatedHeight);
    }

    final pad = padding;
    final effectiveWidth = (boxWidth ?? maxWidth).clamp(60.0, 2400.0);
    final textPainter = TextPainter(
      text: TextSpan(
        text: text.isEmpty ? ' ' : text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          height: lineHeight,
        ),
      ),
      textAlign: alignment,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: effectiveWidth);
    final contentW = boxWidth != null ? math.max(boxWidth!, textPainter.width) : textPainter.width;
    final contentH = boxHeight != null ? math.max(boxHeight!, textPainter.height) : textPainter.height;
    return Rect.fromLTWH(
      position.dx - pad,
      position.dy - pad,
      contentW + pad * 2,
      contentH + pad * 2,
    );
  }

  @override
  bool hits(Offset point, {double padding = 8.0}) {
    return getBoundingBox().inflate(padding).contains(point);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'object_type': 'text',
      'z_index': zIndex,
      'data': {
        'text': text,
        'x': position.dx,
        'y': position.dy,
        'color': '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}',
        'font_size': fontSize,
        'title': title,
        'is_ai_generated': isAiGenerated,
        'max_width': maxWidth,
        'user_prompt': userPrompt,
        'ai_model': aiModel,
        'paper_style': paperStyle,
        'created_at': createdAt.toIso8601String(),
        'font_family': fontFamily,
        'is_bold': isBold,
        'is_italic': isItalic,
        'is_underline': isUnderline,
        'is_strikethrough': isStrikethrough,
        'alignment': alignment.name,
        'line_height': lineHeight,
        'background_color': backgroundColor != null ? '#${backgroundColor!.toARGB32().toRadixString(16).padLeft(8, '0')}' : null,
        'border_color': borderColor != null ? '#${borderColor!.toARGB32().toRadixString(16).padLeft(8, '0')}' : null,
        'border_width': borderWidth,
        'border_radius': borderRadius,
        'padding': padding,
        'box_width': boxWidth,
        'box_height': boxHeight,
      }
    };
  }

  factory CanvasTextItem.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final colorHex = data['color'] as String? ?? '#FFFFFFFF';
    final parsedColor = Color(int.parse(colorHex.replaceFirst('#', ''), radix: 16));
    final dateStr = data['created_at'] as String?;

    TextAlign alignment = TextAlign.left;
    final alignStr = data['alignment'] as String?;
    if (alignStr == 'center') alignment = TextAlign.center;
    if (alignStr == 'right') alignment = TextAlign.right;
    if (alignStr == 'justify') alignment = TextAlign.justify;

    final bgHex = data['background_color'] as String?;
    final bgColor = bgHex != null ? Color(int.parse(bgHex.replaceFirst('#', ''), radix: 16)) : null;

    final borderHex = data['border_color'] as String?;
    final borderColor = borderHex != null ? Color(int.parse(borderHex.replaceFirst('#', ''), radix: 16)) : null;

    return CanvasTextItem(
      id: json['id'] as String,
      text: data['text'] as String? ?? '',
      position: Offset(
        (data['x'] as num?)?.toDouble() ?? 50.0,
        (data['y'] as num?)?.toDouble() ?? 50.0,
      ),
      color: parsedColor,
      fontSize: (data['font_size'] as num?)?.toDouble() ?? 15.0,
      title: data['title'] as String?,
      isAiGenerated: data['is_ai_generated'] as bool? ?? false,
      maxWidth: (data['max_width'] as num?)?.toDouble() ?? 500.0,
      userPrompt: data['user_prompt'] as String?,
      aiModel: data['ai_model'] as String?,
      paperStyle: data['paper_style'] as String? ?? 'ruled',
      createdAt: dateStr != null ? DateTime.tryParse(dateStr) : null,
      fontFamily: data['font_family'] as String? ?? 'Inter',
      isBold: data['is_bold'] as bool? ?? false,
      isItalic: data['is_italic'] as bool? ?? false,
      isUnderline: data['is_underline'] as bool? ?? false,
      isStrikethrough: data['is_strikethrough'] as bool? ?? false,
      alignment: alignment,
      lineHeight: (data['line_height'] as num?)?.toDouble() ?? 1.35,
      backgroundColor: bgColor,
      borderColor: borderColor,
      borderWidth: (data['border_width'] as num?)?.toDouble() ?? 0.0,
      borderRadius: (data['border_radius'] as num?)?.toDouble() ?? 8.0,
      padding: (data['padding'] as num?)?.toDouble() ?? 8.0,
      boxWidth: (data['box_width'] as num?)?.toDouble(),
      boxHeight: (data['box_height'] as num?)?.toDouble(),
      zIndex: json['z_index'] as int? ?? 0,
    );
  }
}

class CanvasNoteCardItem extends CanvasObjectItem {
  final String title;
  final String content;
  Offset position;
  final double width;
  final double height;
  final Color backgroundColor;
  final Color textColor;
  final bool isLoading;

  CanvasNoteCardItem({
    required super.id,
    required this.title,
    required this.content,
    required this.position,
    this.width = 340,
    this.height = 220,
    this.backgroundColor = const Color(0xFF1B2030),
    this.textColor = const Color(0xFFF1F5F9),
    this.isLoading = false,
    super.zIndex = 0,
    super.isSelected = false,
  }) : super(objectType: 'note_card');

  CanvasNoteCardItem copyWith({
    String? id,
    String? title,
    String? content,
    Offset? position,
    double? width,
    double? height,
    bool? isLoading,
    int? zIndex,
    bool? isSelected,
  }) {
    return CanvasNoteCardItem(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      position: position ?? this.position,
      width: width ?? this.width,
      height: height ?? this.height,
      backgroundColor: backgroundColor,
      textColor: textColor,
      isLoading: isLoading ?? this.isLoading,
      zIndex: zIndex ?? this.zIndex,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  Rect getBoundingBox() => Rect.fromLTWH(position.dx, position.dy, width, height);

  @override
  bool hits(Offset point, {double padding = 8.0}) => getBoundingBox().inflate(padding).contains(point);

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'object_type': 'note_card',
      'z_index': zIndex,
      'bounds': {
        'x': position.dx,
        'y': position.dy,
        'width': width,
        'height': height,
      },
      'data': {
        'title': title,
        'content': content,
        'bg_color': '#${backgroundColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
        'text_color': '#${textColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
      }
    };
  }

  factory CanvasNoteCardItem.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final bounds = json['bounds'] as Map<String, dynamic>? ?? {};
    final x = (bounds['x'] as num?)?.toDouble() ?? 50.0;
    final y = (bounds['y'] as num?)?.toDouble() ?? 50.0;
    final w = (bounds['width'] as num?)?.toDouble() ?? 340.0;
    final h = (bounds['height'] as num?)?.toDouble() ?? 220.0;

    final bgHex = data['bg_color'] as String? ?? '#FF1B2030';
    final textHex = data['text_color'] as String? ?? '#FFF1F5F9';

    return CanvasNoteCardItem(
      id: json['id'] as String,
      title: data['title'] as String? ?? 'AI Note',
      content: data['content'] as String? ?? '',
      position: Offset(x, y),
      width: w,
      height: h,
      backgroundColor: Color(int.parse(bgHex.replaceFirst('#', ''), radix: 16)),
      textColor: Color(int.parse(textHex.replaceFirst('#', ''), radix: 16)),
      zIndex: json['z_index'] as int? ?? 0,
    );
  }
}

class CanvasImageItem extends CanvasObjectItem {
  Rect bounds;
  final String? imageUrl;
  final String? assetPath;
  final String? localFilePath;
  final String? base64Data;
  double rotation;

  CanvasImageItem({
    required super.id,
    required this.bounds,
    this.imageUrl,
    this.assetPath,
    this.localFilePath,
    this.base64Data,
    this.rotation = 0.0,
    super.zIndex = 0,
    super.isSelected = false,
  }) : super(objectType: 'image');

  CanvasImageItem copyWith({
    String? id,
    Rect? bounds,
    String? imageUrl,
    String? assetPath,
    String? localFilePath,
    String? base64Data,
    double? rotation,
    int? zIndex,
    bool? isSelected,
  }) {
    return CanvasImageItem(
      id: id ?? this.id,
      bounds: bounds ?? this.bounds,
      imageUrl: imageUrl ?? this.imageUrl,
      assetPath: assetPath ?? this.assetPath,
      localFilePath: localFilePath ?? this.localFilePath,
      base64Data: base64Data ?? this.base64Data,
      rotation: rotation ?? this.rotation,
      zIndex: zIndex ?? this.zIndex,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  Rect getBoundingBox() => bounds;

  @override
  bool hits(Offset point, {double padding = 8.0}) => bounds.inflate(padding).contains(point);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'object_type': 'image',
    'z_index': zIndex,
    'bounds': {'x': bounds.left, 'y': bounds.top, 'width': bounds.width, 'height': bounds.height},
    'data': {
      'image_url': imageUrl,
      'asset_path': assetPath,
      'local_file_path': localFilePath,
      'base64_data': base64Data,
      'rotation': rotation,
    },
  };

  factory CanvasImageItem.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final bounds = json['bounds'] as Map<String, dynamic>? ?? {};
    final x = (bounds['x'] as num?)?.toDouble() ?? 0.0;
    final y = (bounds['y'] as num?)?.toDouble() ?? 0.0;
    final w = (bounds['width'] as num?)?.toDouble() ?? 200.0;
    final h = (bounds['height'] as num?)?.toDouble() ?? 200.0;

    return CanvasImageItem(
      id: json['id'] as String,
      bounds: Rect.fromLTWH(x, y, w, h),
      imageUrl: data['image_url'] as String?,
      assetPath: data['asset_path'] as String?,
      localFilePath: data['local_file_path'] as String?,
      base64Data: data['base64_data'] as String?,
      rotation: (data['rotation'] as num?)?.toDouble() ?? 0.0,
      zIndex: json['z_index'] as int? ?? 0,
    );
  }
}

class CanvasTapeItem extends CanvasObjectItem {
  Rect rect;
  Color color;
  bool isMasked;

  CanvasTapeItem({
    required super.id,
    required this.rect,
    this.color = const Color(0xFFFDE047),
    this.isMasked = true,
    super.zIndex = 0,
    super.isSelected = false,
  }) : super(objectType: 'tape');

  CanvasTapeItem copyWith({
    String? id,
    Rect? rect,
    Color? color,
    bool? isMasked,
    int? zIndex,
    bool? isSelected,
  }) {
    return CanvasTapeItem(
      id: id ?? this.id,
      rect: rect ?? this.rect,
      color: color ?? this.color,
      isMasked: isMasked ?? this.isMasked,
      zIndex: zIndex ?? this.zIndex,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  Rect getBoundingBox() => rect;

  @override
  bool hits(Offset point, {double padding = 8.0}) => rect.inflate(padding).contains(point);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'object_type': 'tape',
    'z_index': zIndex,
    'bounds': {'x': rect.left, 'y': rect.top, 'width': rect.width, 'height': rect.height},
    'data': {
      'color': '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}',
      'is_masked': isMasked,
    },
  };

  factory CanvasTapeItem.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final bounds = json['bounds'] as Map<String, dynamic>? ?? {};
    final x = (bounds['x'] as num?)?.toDouble() ?? 0.0;
    final y = (bounds['y'] as num?)?.toDouble() ?? 0.0;
    final w = (bounds['width'] as num?)?.toDouble() ?? 100.0;
    final h = (bounds['height'] as num?)?.toDouble() ?? 28.0;

    final colorHex = data['color'] as String? ?? '#FFFDE047';
    final parsedColor = Color(int.parse(colorHex.replaceFirst('#', ''), radix: 16));

    return CanvasTapeItem(
      id: json['id'] as String,
      rect: Rect.fromLTWH(x, y, w, h),
      color: parsedColor,
      isMasked: data['is_masked'] as bool? ?? true,
      zIndex: json['z_index'] as int? ?? 0,
    );
  }
}


