class LiveClass {
  final String id;
  final String title; // Extracted from classSchedule
  final String subject; // Extracted from classSchedule
  final String courseName;
  final String batchName;
  final String teacherName;
  final String meetingId;
  final String meetingPassword;
  final String status;
  final String? meetingLink;
  final DateTime? startTime;

  LiveClass({
    required this.id,
    required this.title,
    required this.subject,
    required this.courseName,
    required this.batchName,
    required this.teacherName,
    required this.meetingId,
    required this.meetingPassword,
    required this.status,
    this.meetingLink,
    this.startTime,
  });

  factory LiveClass.fromJson(Map<String, dynamic> json) {
    final schedule = json['classScheduleId'] ?? {};
    final classObj = schedule['classId'] ?? {};
    final subjectObj = schedule['subjectId'] ?? {};
    final batchObj = schedule['batchId'] ?? {};
    final courseObj = batchObj is Map ? batchObj['courseId'] : null;
    final teacher = json['teacherId'] ?? {};

    return LiveClass(
      id: json['_id'] ?? '',
      title: classObj['name'] ?? 'Class',
      subject: subjectObj['name'] ?? 'Subject',
      courseName: courseObj is Map ? (courseObj['name']?.toString() ?? '') : '',
      batchName: batchObj is Map
          ? [
              batchObj['name']?.toString() ?? '',
              if ((batchObj['section']?.toString() ?? '').isNotEmpty)
                'Section ${batchObj['section']}',
            ].where((value) => value.isNotEmpty).join(' • ')
          : '',
      teacherName: '${teacher['firstName'] ?? ''} ${teacher['lastName'] ?? ''}'
          .trim(),
      meetingId: json['meetingId']?.toString() ?? '',
      meetingPassword: json['meetingPassword']?.toString() ?? '',
      status: json['status'] ?? 'ONGOING',
      meetingLink: json['meetingLink'],
      startTime: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())?.toLocal()
          : (schedule['startTime'] != null
                ? DateTime.tryParse(schedule['startTime'].toString())?.toLocal()
                : null),
    );
  }
}
