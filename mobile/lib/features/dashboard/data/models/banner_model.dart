class BannerModel {
  final String id;
  final String title;
  final String imageUrl;
  final String? linkUrl;
  final bool isActive;
  final int order;

  BannerModel({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.linkUrl,
    required this.isActive,
    required this.order,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: json['_id'] as String,
      title: json['title'] as String,
      imageUrl: json['imageUrl'] as String,
      linkUrl: json['linkUrl'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      order: json['order'] as int? ?? 0,
    );
  }
}
