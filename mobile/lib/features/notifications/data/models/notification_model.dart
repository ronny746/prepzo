class AppNotificationModel {
  const AppNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.createdAt,
    this.isRead = false,
    this.actionUrl,
  });

  final String id;
  final String title;
  final String message;
  final String category;
  final DateTime createdAt;
  final bool isRead;
  final String? actionUrl;

  AppNotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    String? category,
    DateTime? createdAt,
    bool? isRead,
    String? actionUrl,
  }) {
    return AppNotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      actionUrl: actionUrl ?? this.actionUrl,
    );
  }

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    final rawDate = json['createdAt'] ?? json['date'] ?? json['timestamp'];
    final DateTime parsedDate = rawDate != null
        ? (DateTime.tryParse(rawDate.toString())?.toLocal() ?? DateTime.now())
        : DateTime.now();
    final metadata = json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : const <String, dynamic>{};
    final source = metadata['entityType']?.toString();

    return AppNotificationModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: json['title']?.toString() ?? 'Notification',
      message:
          json['message']?.toString() ?? json['description']?.toString() ?? '',
      category:
          _categoryLabel(source) ??
          json['category']?.toString() ??
          json['type']?.toString() ??
          'System',
      createdAt: parsedDate,
      isRead: json['isRead'] == true || json['read'] == true,
      actionUrl:
          json['actionUrl']?.toString() ??
          metadata['actionUrl']?.toString() ??
          metadata['meetingLink']?.toString(),
    );
  }

  static String? _categoryLabel(String? source) => switch (source) {
    'announcement' => 'Announcement',
    'course_enrollment' => 'Course',
    'mentor_session' => 'Mentor Session',
    'attendance_late' || 'attendance_absent' => 'Attendance',
    _ => null,
  };

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'actionUrl': actionUrl,
    };
  }
}
