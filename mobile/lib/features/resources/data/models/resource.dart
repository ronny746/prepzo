class Resource {
  final String id;
  final String title;
  final String? description;
  final String type;
  final String fileUrl;
  final String folderPath;
  final String createdAt;
  final String? batchId;
  final List<String> batchIds;

  Resource({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    required this.fileUrl,
    required this.folderPath,
    required this.createdAt,
    this.batchId,
    this.batchIds = const [],
  });

  factory Resource.fromJson(Map<String, dynamic> json) {
    String? bId;
    if (json['batchId'] is Map<String, dynamic>) {
      bId =
          json['batchId']['_id']?.toString() ??
          json['batchId']['id']?.toString();
    } else if (json['batchId'] != null) {
      bId = json['batchId'].toString();
    }

    List<String> bIds = [];
    if (json['batchIds'] is List) {
      for (final item in json['batchIds']) {
        if (item is Map<String, dynamic>) {
          final id = item['_id']?.toString() ?? item['id']?.toString();
          if (id != null) bIds.add(id);
        } else if (item != null) {
          bIds.add(item.toString());
        }
      }
    }

    return Resource(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      type: json['type']?.toString() ?? 'UNKNOWN',
      fileUrl: json['fileUrl']?.toString() ?? '',
      folderPath: json['folderPath']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      batchId: bId,
      batchIds: bIds,
    );
  }
}
