import 'package:flutter_test/flutter_test.dart';
import 'package:lms/features/live_classes/data/models/live_classes_models.dart';

void main() {
  test('maps the subject, course, and batch context for a live class', () {
    final liveClass = LiveClass.fromJson({
      '_id': 'live-1',
      'status': 'ONGOING',
      'meetingId': '12345678901',
      'classScheduleId': {
        'subjectId': {'name': 'Physics'},
        'batchId': {
          'name': 'NEET Morning',
          'section': 'A',
          'courseId': {'name': 'NEET UG 2026'},
        },
      },
      'teacherId': {'firstName': 'Rehan', 'lastName': 'Qureshi'},
    });

    expect(liveClass.subject, 'Physics');
    expect(liveClass.courseName, 'NEET UG 2026');
    expect(liveClass.batchName, 'NEET Morning • Section A');
    expect(liveClass.teacherName, 'Rehan Qureshi');
  });
}
