import 'package:flutter_test/flutter_test.dart';
import 'package:lms/features/exams/data/models/exams_models.dart';

void main() {
  test('typed answer, correct answer, image and attempted are read', () {
    final d = ExamAnalysisDetailModel.fromJson({
      '_id': 'q21',
      'type': 'INTEGER',
      'questionText': 'Find the projection.',
      'questionImageUrl': '/uploads/g.png',
      'correctAnswerText': '2',
      'options': [],
      'attempted': true,
      'isCorrect': true,
      'marksObtained': 4,
      'userAnswer': {'numericAnswer': '2', 'status': 'ANSWERED'},
    });
    expect(d.isTypedAnswer, isTrue);
    expect(d.userAnswer!.typedAnswer, '2');
    expect(d.correctAnswerText, '2');
    expect(d.questionImageUrl, '/uploads/g.png');
    expect(d.attempted, isTrue);
  });

  test('marked for review with no value has no answer value', () {
    final d = ExamAnalysisDetailModel.fromJson({
      'type': 'MCQ',
      'options': [
        {
          '_id': 'a',
          'text': 'x',
          'isCorrect': true,
          'imageUrl': 'https://s3/a.png',
        },
      ],
      'userAnswer': {'status': 'MARKED_FOR_REVIEW'},
    });
    expect(d.userAnswer!.hasValue, isFalse);
    expect(d.attempted, isNull);
    expect(d.options.first.imageUrl, 'https://s3/a.png');
    expect(d.isTypedAnswer, isFalse);
  });
}
