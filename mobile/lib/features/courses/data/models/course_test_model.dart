import 'package:lms/features/exams/data/models/exams_models.dart';

/// A test listed inside a course. FREE tests can be taken by any signed-in
/// student; PAID ones need the course (the server enforces the same rule in
/// `contentAccess.middleware.js`).
class CourseTest {
  const CourseTest({required this.exam, required this.isFree});

  factory CourseTest.fromJson(Map<String, dynamic> json) => CourseTest(
    exam: ExamModel.fromJson(json),
    isFree: json['accessMode']?.toString().toUpperCase() == 'FREE',
  );

  final ExamModel exam;
  final bool isFree;

  bool get isAttempted =>
      exam.submissionStatus == 'SUBMITTED' ||
      exam.submissionStatus == 'AUTO_SUBMITTED';

  bool get isInProgress => exam.submissionStatus == 'IN_PROGRESS';

  /// Chapter / part / full-mock label read from the title, e.g.
  /// "JEE Main Chapter Test: Limits" -> "Chapter test".
  String get kind {
    final t = exam.title.toLowerCase();
    if (t.contains('chapter')) return 'Chapter test';
    if (t.contains('part test') || RegExp(r'\bpt\d').hasMatch(t)) {
      return 'Part test';
    }
    if (t.contains('mock') || t.contains('full')) return 'Full mock';
    return 'Test';
  }

  /// "Structure of Atom" out of "JEE Main Chapter Test: Structure of Atom".
  String get shortTitle {
    final i = exam.title.indexOf(':');
    if (i > 0 && i < exam.title.length - 1) {
      return exam.title.substring(i + 1).trim();
    }
    return exam.title;
  }
}
