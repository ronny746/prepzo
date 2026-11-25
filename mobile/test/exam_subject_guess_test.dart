import 'package:flutter_test/flutter_test.dart';
import 'package:lms/features/dashboard/data/models/dashboard_models.dart';
import 'package:lms/features/exams/data/models/exams_models.dart';

void main() {
  group('guessExamSubject', () {
    test('uses chapter names for JEE chapter tests', () {
      expect(
        guessExamSubject('JEE Main Chapter Test: Vector Algebra'),
        'Mathematics',
      );
      expect(
        guessExamSubject('JEE Main Chapter Test: Units and Measurements'),
        'Physics',
      );
      expect(
        guessExamSubject('JEE Main Chapter Test: Chemical Kinetics'),
        'Chemistry',
      );
      expect(
        guessExamSubject('JEE Main Chapter Test: Haloalkanes and Haloarenes'),
        'Chemistry',
      );
    });

    test('never labels a JEE chemistry chapter as Biology', () {
      expect(
        guessExamSubject('JEE Main Chapter Test: Biomolecules'),
        'Chemistry',
      );
      expect(guessExamSubject('JEE Main Biology Practice'), '');
    });

    test('matches whole words only', () {
      expect(guessExamSubject('Animes Exam'), '');
      expect(guessExamSubject('JM-1 Test'), '');
      expect(guessExamSubject('Physical Chemistry Drill'), 'Chemistry');
    });

    test('mocks and mixed papers have no single subject', () {
      expect(guessExamSubject('All-India Mock Test 1'), '');
      expect(guessExamSubject('Physics and Chemistry Combined'), '');
    });

    test('NEET biology chapters stay Biology', () {
      expect(
        guessExamSubject('NEET Chapter Test: Human Reproduction'),
        'Biology',
      );
      expect(guessExamSubject('NEET Biology Test'), 'Biology');
    });
  });

  group('StudentFeatureAccess.fromBatches', () {
    test('test-series course hides live class, courses and attendance', () {
      final access = StudentFeatureAccess.fromBatches([
        {
          'type': 'offline',
          'courseId': {
            'access': {
              'liveClasses': false,
              'studyMaterials': false,
              'dpps': false,
              'testSeries': true,
            },
          },
        },
      ]);
      expect(access.liveClasses, isFalse);
      expect(access.studyMaterials, isFalse);
      expect(access.attendance, isFalse);
    });

    test('any course granting a feature turns it on', () {
      final access = StudentFeatureAccess.fromBatches([
        {
          'type': 'online',
          'courseId': {
            'access': {'liveClasses': true, 'studyMaterials': true},
          },
        },
      ]);
      expect(access.liveClasses, isTrue);
      expect(access.studyMaterials, isTrue);
      expect(access.attendance, isFalse); // online batch
    });

    test('no batches means no course tools', () {
      final access = StudentFeatureAccess.fromBatches(const []);
      expect(access.liveClasses, isFalse);
      expect(access.studyMaterials, isFalse);
      expect(access.attendance, isFalse);
    });
  });
}
