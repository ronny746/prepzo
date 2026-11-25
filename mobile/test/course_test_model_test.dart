import 'package:flutter_test/flutter_test.dart';
import 'package:lms/features/courses/data/models/course_test_model.dart';

void main() {
  test('reads free/paid, kind, short title and attempt status', () {
    final free = CourseTest.fromJson({
      '_id': 'e1',
      'title': 'JEE Main All-India Mock (Free): Full Syllabus',
      'accessMode': 'FREE',
      'totalMarks': 300,
      'totalQuestions': 75,
      'settings': {
        'durationMinutes': 180,
        'startTime': '2026-11-22T18:30:00.000Z',
      },
      'submissionStatus': 'SUBMITTED',
      'score': 12,
    });
    expect(free.isFree, isTrue);
    expect(free.kind, 'Full mock');
    expect(free.shortTitle, 'Full Syllabus');
    expect(free.isAttempted, isTrue);
    expect(free.exam.totalQuestions, 75);

    final paid = CourseTest.fromJson({
      '_id': 'e2',
      'title': 'JEE Main Chapter Test: Limits',
      'accessMode': 'PAID',
      'submissionStatus': 'NOT_STARTED',
    });
    expect(paid.isFree, isFalse);
    expect(paid.kind, 'Chapter test');
    expect(paid.shortTitle, 'Limits');
    expect(paid.isAttempted, isFalse);
  });
}
