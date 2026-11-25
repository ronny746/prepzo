class BatchModel {
  final String id;
  final String name;
  final String? section;
  final String? courseId;
  final String? courseName;
  final String? courseTag;
  final String? startDate;
  final String? endDate;
  final String? status;

  const BatchModel({
    required this.id,
    required this.name,
    this.section,
    this.courseId,
    this.courseName,
    this.courseTag,
    this.startDate,
    this.endDate,
    this.status,
  });

  factory BatchModel.fromJson(Map<String, dynamic> json) {
    String? extractedCourseId;
    String? extractedCourseName;
    String? extractedCourseTag;

    if (json['courseId'] is Map<String, dynamic>) {
      extractedCourseId = json['courseId']['_id']?.toString() ?? json['courseId']['id']?.toString();
      extractedCourseName = json['courseId']['name']?.toString();
      extractedCourseTag = json['courseId']['tag']?.toString();
    } else if (json['courseId'] != null) {
      extractedCourseId = json['courseId'].toString();
    }

    return BatchModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      section: json['section']?.toString(),
      courseId: extractedCourseId,
      courseName: extractedCourseName,
      courseTag: extractedCourseTag,
      startDate: json['startDate']?.toString(),
      endDate: json['endDate']?.toString(),
      status: json['status']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'section': section,
        'courseId': courseId,
        'courseName': courseName,
        'courseTag': courseTag,
        'startDate': startDate,
        'endDate': endDate,
        'status': status,
      };
}
