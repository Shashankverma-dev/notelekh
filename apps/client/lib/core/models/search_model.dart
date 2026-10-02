class SearchResultItemModel {
  final String entityType; // 'workspace', 'conversation', 'message', 'note', 'file', 'highlight', 'canvas'
  final String id;
  final String title;
  final String snippet;
  final String? workspaceId;
  final String? workspaceName;
  final DateTime createdAt;

  SearchResultItemModel({
    required this.entityType,
    required this.id,
    required this.title,
    required this.snippet,
    this.workspaceId,
    this.workspaceName,
    required this.createdAt,
  });

  factory SearchResultItemModel.fromJson(Map<String, dynamic> json) {
    return SearchResultItemModel(
      entityType: json['entity_type'] as String,
      id: json['id'] as String,
      title: json['title'] as String,
      snippet: json['snippet'] as String? ?? '',
      workspaceId: json['workspace_id'] as String?,
      workspaceName: json['workspace_name'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }
}

class SearchResponseModel {
  final String query;
  final int totalResults;
  final List<SearchResultItemModel> results;

  SearchResponseModel({
    required this.query,
    required this.totalResults,
    required this.results,
  });

  factory SearchResponseModel.fromJson(Map<String, dynamic> json) {
    var rawList = json['results'] as List<dynamic>? ?? [];
    return SearchResponseModel(
      query: json['query'] as String? ?? '',
      totalResults: json['total_results'] as int? ?? 0,
      results: rawList.map((e) => SearchResultItemModel.fromJson(Map<String, dynamic>.from(e))).toList(),
    );
  }
}
