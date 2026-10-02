import 'dart:ui';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';
import 'package:ai_workspace_client/features/canvas/models/stroke.dart';

// ================= GOODNOTES MULTI-PAGE NOTEBOOK MODELS =================
class CanvasPage {
  final String id;
  int pageNumber;
  String title;
  CanvasPaperStyle paperStyle;
  List<CanvasObjectItem> objects;
  final DateTime createdAt;
  Offset panOffset;
  double zoomScale;

  CanvasPage({
    required this.id,
    required this.pageNumber,
    String? title,
    this.paperStyle = CanvasPaperStyle.ruledLines,
    List<CanvasObjectItem>? objects,
    DateTime? createdAt,
    this.panOffset = Offset.zero,
    this.zoomScale = 1.0,
  })  : title = title ?? 'Page $pageNumber',
        objects = objects ?? [],
        createdAt = createdAt ?? DateTime.now();

  CanvasPage copyWith({
    String? id,
    int? pageNumber,
    String? title,
    CanvasPaperStyle? paperStyle,
    List<CanvasObjectItem>? objects,
    DateTime? createdAt,
    Offset? panOffset,
    double? zoomScale,
  }) {
    return CanvasPage(
      id: id ?? this.id,
      pageNumber: pageNumber ?? this.pageNumber,
      title: title ?? this.title,
      paperStyle: paperStyle ?? this.paperStyle,
      objects: objects ?? List.from(this.objects),
      createdAt: createdAt ?? this.createdAt,
      panOffset: panOffset ?? this.panOffset,
      zoomScale: zoomScale ?? this.zoomScale,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'page_number': pageNumber,
      'title': title,
      'paper_style': paperStyle.name,
      'created_at': createdAt.toIso8601String(),
      'pan_offset': {'dx': panOffset.dx, 'dy': panOffset.dy},
      'zoom_scale': zoomScale,
      'objects': objects.map((o) => o.toJson()).toList(),
    };
  }

  factory CanvasPage.fromJson(Map<String, dynamic> json) {
    CanvasPaperStyle style = CanvasPaperStyle.ruledLines;
    final styleStr = json['paper_style'] as String?;
    if (styleStr != null) {
      for (var s in CanvasPaperStyle.values) {
        if (s.name == styleStr) {
          style = s;
          break;
        }
      }
    }

    final panJson = json['pan_offset'] as Map<String, dynamic>?;
    final pan = panJson != null
        ? Offset(
            (panJson['dx'] as num?)?.toDouble() ?? 0.0,
            (panJson['dy'] as num?)?.toDouble() ?? 0.0,
          )
        : Offset.zero;

    var rawObjs = json['objects'] as List<dynamic>? ?? [];
    List<CanvasObjectItem> parsed = [];
    for (var o in rawObjs) {
      final map = Map<String, dynamic>.from(o);
      final type = map['object_type'];
      if (type == 'stroke') {
        parsed.add(CanvasStrokeItem.fromJson(map));
      } else if (type == 'note_card') {
        parsed.add(CanvasNoteCardItem.fromJson(map));
      } else if (type == 'text') {
        parsed.add(CanvasTextItem.fromJson(map));
      } else if (type == 'shape') {
        parsed.add(CanvasShapeItem.fromJson(map));
      } else if (type == 'image') {
        parsed.add(CanvasImageItem.fromJson(map));
      } else if (type == 'tape') {
        parsed.add(CanvasTapeItem.fromJson(map));
      }
    }

    return CanvasPage(
      id: json['id'] as String? ?? 'page-1',
      pageNumber: json['page_number'] as int? ?? 1,
      title: json['title'] as String?,
      paperStyle: style,
      objects: parsed,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      panOffset: pan,
      zoomScale: (json['zoom_scale'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class CanvasDocModel {
  final String id;
  final String workspaceId;
  String name;
  final int documentVersion;
  List<CanvasPage> pages;
  int currentPageIndex;
  CanvasDocType docType;
  Color coverColor;
  String coverEmoji;
  /// 'solid' | 'gradient' | 'pattern'
  String coverStyle;
  /// gradient: 'RRGGBB,RRGGBB' (two hex colors)
  /// pattern:  'grid' | 'dots' | 'stripes' | 'waves' | 'linen' | 'leather'
  /// solid:    ''
  String coverStyleData;
  DateTime? updatedAt;

  CanvasDocModel({
    required this.id,
    required this.workspaceId,
    required this.name,
    this.documentVersion = 1,
    List<CanvasPage>? pages,
    this.currentPageIndex = 0,
    List<CanvasObjectItem>? objects,
    this.docType = CanvasDocType.notebook,
    this.coverColor = const Color(0xFF2E7D32),
    this.coverEmoji = '📓',
    this.coverStyle = 'solid',
    this.coverStyleData = '',
    this.updatedAt,
  }) : pages = pages ??
            (objects != null && objects.isNotEmpty
                ? [
                    CanvasPage(
                      id: 'page-1',
                      pageNumber: 1,
                      title: 'Page 1',
                      objects: objects,
                    )
                  ]
                : [
                    CanvasPage(
                      id: 'page-1',
                      pageNumber: 1,
                      title: 'Page 1',
                    )
                  ]);

  // Backward-compatible objects getter for the active page
  List<CanvasObjectItem> get objects {
    if (pages.isEmpty) return const [];
    final idx = currentPageIndex.clamp(0, pages.length - 1);
    return pages[idx].objects;
  }

  // Active page helper
  CanvasPage get activePage {
    if (pages.isEmpty) {
      pages.add(CanvasPage(id: 'page-1', pageNumber: 1, title: 'Page 1'));
    }
    final idx = currentPageIndex.clamp(0, pages.length - 1);
    return pages[idx];
  }

  factory CanvasDocModel.fromJson(Map<String, dynamic> json) {
    List<CanvasPage> parsedPages = [];

    if (json.containsKey('pages') && json['pages'] is List) {
      final rawPages = json['pages'] as List<dynamic>;
      for (var p in rawPages) {
        parsedPages.add(CanvasPage.fromJson(Map<String, dynamic>.from(p)));
      }
    }

    if (parsedPages.isEmpty) {
      var rawObjs = json['objects'] as List<dynamic>? ?? [];
      List<CanvasObjectItem> parsed = [];
      for (var o in rawObjs) {
        final map = Map<String, dynamic>.from(o);
        final type = map['object_type'];
        if (type == 'stroke') {
          parsed.add(CanvasStrokeItem.fromJson(map));
        } else if (type == 'note_card') {
          parsed.add(CanvasNoteCardItem.fromJson(map));
        } else if (type == 'text') {
          parsed.add(CanvasTextItem.fromJson(map));
        } else if (type == 'shape') {
          parsed.add(CanvasShapeItem.fromJson(map));
        } else if (type == 'image') {
          parsed.add(CanvasImageItem.fromJson(map));
        } else if (type == 'tape') {
          parsed.add(CanvasTapeItem.fromJson(map));
        }
      }
      parsedPages.add(CanvasPage(
        id: 'page-1',
        pageNumber: 1,
        title: 'Page 1',
        objects: parsed,
      ));
    }

    final rawDocType = json['doc_type'] as String? ?? 'notebook';
    final CanvasDocType docType;
    if (rawDocType == 'canvas') {
      docType = CanvasDocType.canvas;
    } else if (rawDocType == 'text_document') {
      docType = CanvasDocType.textDocument;
    } else {
      docType = CanvasDocType.notebook;
    }

    // Parse cover color
    Color coverColor = const Color(0xFF2E7D32);
    final coverColorHex = json['cover_color'] as String?;
    if (coverColorHex != null) {
      try {
        coverColor = Color(int.parse(coverColorHex.replaceFirst('#', ''), radix: 16));
      } catch (_) {}
    }

    DateTime? updatedAt;
    final rawUpdatedAt = json['updated_at'];
    if (rawUpdatedAt is String) {
      updatedAt = DateTime.tryParse(rawUpdatedAt);
    }

    return CanvasDocModel(
      id: json['id'] as String,
      workspaceId: json['workspace_id'] as String? ?? 'default',
      name: json['name'] as String? ?? 'Untitled Notebook',
      documentVersion: json['document_version'] as int? ?? 1,
      pages: parsedPages,
      currentPageIndex: (json['current_page_index'] as int?)?.clamp(0, parsedPages.length - 1) ?? 0,
      docType: docType,
      coverColor: coverColor,
      coverEmoji: json['cover_emoji'] as String? ?? '📓',
      coverStyle: json['cover_style'] as String? ?? 'solid',
      coverStyleData: json['cover_style_data'] as String? ?? '',
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workspace_id': workspaceId,
      'name': name,
      'document_version': documentVersion,
      'current_page_index': currentPageIndex,
      'doc_type': docType == CanvasDocType.canvas
          ? 'canvas'
          : (docType == CanvasDocType.textDocument ? 'text_document' : 'notebook'),
      'cover_color': '#${coverColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
      'cover_emoji': coverEmoji,
      'cover_style': coverStyle,
      'cover_style_data': coverStyleData,
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      'pages': pages.map((p) => p.toJson()).toList(),
      'objects': objects.map((o) => o.toJson()).toList(),
    };
  }
}
