class AcademicTask {
  const AcademicTask({
    required this.id,
    required this.taskType,
    required this.title,
    required this.description,
    required this.subjectName,
    required this.dueDate,
    required this.maxMarks,
    required this.attachments,
    required this.isSubmitted,
    this.marksObtained,
    this.submissionStatus,
  });

  final String id;
  final String taskType; // 'Assignment' or 'Homework'
  final String title;
  final String description;
  final String subjectName;
  final DateTime? dueDate;
  final num maxMarks;
  final List<String> attachments;
  final bool isSubmitted;
  final num? marksObtained;
  final String? submissionStatus; // 'graded', 'submitted', 'pending'

  factory AcademicTask.fromJson(Map<String, dynamic> json, String type, Map<String, String> subjectsMap, List<dynamic> submissions) {
    final String id = json['_id'] ?? json['id'] ?? '';
    final String subjectId = json['subjectId'] is Map 
        ? (json['subjectId']['_id'] ?? json['subjectId']['id'] ?? '') 
        : (json['subjectId']?.toString() ?? '');
    
    final String subjectName = json['subjectId'] is Map 
        ? (json['subjectId']['name'] ?? 'Unknown Subject') 
        : (subjectsMap[subjectId] ?? 'Unknown Subject');

    final submission = submissions.firstWhere(
      (s) {
        final aId = s['assignmentId'] is Map 
            ? s['assignmentId']['_id'] 
            : s['assignmentId'];
        return aId == id;
      },
      orElse: () => null,
    );

    return AcademicTask(
      id: id,
      taskType: type,
      title: json['title'] ?? 'Untitled',
      description: json['description'] ?? '',
      subjectName: subjectName,
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate'].toString())?.toLocal() : null,
      maxMarks: json['maxMarks'] ?? 100,
      attachments: List<String>.from(json['attachments'] ?? []),
      isSubmitted: submission != null,
      marksObtained: submission?['marksObtained'],
      submissionStatus: submission != null ? submission['status'] : 'pending',
    );
  }
}
