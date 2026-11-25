import 'package:flutter_test/flutter_test.dart';
import 'package:lms/core/utils/question_html.dart';
import 'package:lms/features/exams/data/answer_payload.dart';

void main() {
  group('buildAnswerFields', () {
    test('single option -> selectedOptionId', () {
      expect(
        buildAnswerFields(type: 'MCQ', hasOptions: true, answer: 'abc123'),
        {'selectedOptionId': 'abc123'},
      );
      expect(
        buildAnswerFields(
          type: 'ASSERTION_REASON',
          hasOptions: true,
          answer: 'x1',
        ),
        {'selectedOptionId': 'x1'},
      );
    });

    test('multiple correct -> selectedOptionIds list', () {
      expect(
        buildAnswerFields(
          type: 'MULTIPLE_CORRECT',
          hasOptions: true,
          answer: 'a,b',
        ),
        {
          'selectedOptionIds': ['a', 'b'],
        },
      );
    });

    test('integer/numerical -> numeric number', () {
      expect(
        buildAnswerFields(type: 'INTEGER', hasOptions: false, answer: '42'),
        {'numericAnswer': 42},
      );
      expect(
        buildAnswerFields(type: 'NUMERICAL', hasOptions: false, answer: '-3.5'),
        {'numericAnswer': -3.5},
      );
    });

    test('half-typed number sends no numeric key', () {
      expect(
        buildAnswerFields(type: 'INTEGER', hasOptions: false, answer: '-'),
        isEmpty,
      );
    });

    test('subjective / fill blanks -> subjectiveAnswerText', () {
      expect(
        buildAnswerFields(
          type: 'SUBJECTIVE',
          hasOptions: false,
          answer: 'hello',
        ),
        {'subjectiveAnswerText': 'hello'},
      );
      expect(
        buildAnswerFields(type: 'FILL_BLANKS', hasOptions: false, answer: 'x'),
        {'subjectiveAnswerText': 'x'},
      );
    });

    test('options win over type when the question has options', () {
      expect(
        buildAnswerFields(type: 'INTEGER', hasOptions: true, answer: 'o1'),
        {'selectedOptionId': 'o1'},
      );
    });

    test('cleared answers reset the matching key', () {
      expect(buildAnswerFields(type: 'MCQ', hasOptions: true, answer: null), {
        'selectedOptionId': null,
      });
      expect(
        buildAnswerFields(
          type: 'MULTIPLE_CORRECT',
          hasOptions: true,
          answer: '',
        ),
        {'selectedOptionIds': <String>[]},
      );
      expect(
        buildAnswerFields(type: 'INTEGER', hasOptions: false, answer: null),
        {'numericAnswer': null},
      );
    });

    test('synthetic option ids are never sent', () {
      expect(
        buildAnswerFields(type: 'MCQ', hasOptions: true, answer: 'opt_B_1'),
        isEmpty,
      );
      expect(
        buildAnswerFields(type: 'MCQ', hasOptions: true, answer: 'opt_2'),
        isEmpty,
      );
      expect(
        buildAnswerFields(
          type: 'MULTIPLE_CORRECT',
          hasOptions: true,
          answer: 'real1,opt_A_0',
        ),
        {
          'selectedOptionIds': ['real1'],
        },
      );
    });
  });

  group('restoreAnswerString', () {
    test('restores every answer type', () {
      expect(restoreAnswerString({'selectedOptionId': 'a'}), 'a');
      expect(
        restoreAnswerString({
          'selectedOptionIds': ['a', 'b'],
        }),
        'a,b',
      );
      expect(restoreAnswerString({'numericAnswer': 7}), '7');
      expect(restoreAnswerString({'numericAnswer': 7.0}), '7');
      expect(restoreAnswerString({'numericAnswer': 2.5}), '2.5');
      expect(restoreAnswerString({'subjectiveAnswerText': 'hi'}), 'hi');
      expect(restoreAnswerString({'answerText': 'legacy'}), 'legacy');
      expect(restoreAnswerString({'selectedOptionIds': []}), isNull);
    });
  });

  group('practiceSessionType', () {
    test('uses sessionType, not the title', () {
      expect(
        practiceSessionType({'sessionType': 'DPP'}, title: 'Practice - X'),
        'DPP',
      );
      expect(
        practiceSessionType({'sessionType': 'PRACTICE'}, title: 'DPP - X'),
        'PRACTICE',
      );
      expect(practiceSessionType({'sessionType': 'practice'}), 'PRACTICE');
    });

    test('falls back to title only when sessionType is missing', () {
      expect(practiceSessionType({}, title: 'Practice - Y'), 'PRACTICE');
      expect(practiceSessionType(null, title: 'Anything'), 'DPP');
    });
  });

  group('text-split MCQ and status resolution', () {
    test('synthetic-only option answer yields no key and is not ANSWERED', () {
      final fields = buildAnswerFields(
        type: 'MCQ',
        hasOptions: true,
        answer: 'opt_A_0',
      );
      expect(fields, isEmpty);
      expect(
        resolveAnswerStatus(
          status: 'ANSWERED',
          answer: 'opt_A_0',
          fields: fields,
        ),
        'NOT_ANSWERED',
      );
      expect(
        resolveAnswerStatus(
          status: 'ANSWERED_AND_MARKED_FOR_REVIEW',
          answer: 'opt_A_0',
          fields: fields,
        ),
        'MARKED_FOR_REVIEW',
      );
    });

    test('real answers keep their status', () {
      final fields = buildAnswerFields(
        type: 'MCQ',
        hasOptions: true,
        answer: 'abc',
      );
      expect(
        resolveAnswerStatus(status: 'ANSWERED', answer: 'abc', fields: fields),
        'ANSWERED',
      );
    });

    test('free text that looks like opt_1 is kept for typed questions', () {
      expect(
        buildAnswerFields(
          type: 'SUBJECTIVE',
          hasOptions: false,
          answer: 'opt_1',
        ),
        {'subjectiveAnswerText': 'opt_1'},
      );
    });

    test('non-finite numbers are not sent nor ANSWERED', () {
      for (final bad in ['Infinity', '-Infinity', 'NaN', '-']) {
        final f = buildAnswerFields(
          type: 'NUMERICAL',
          hasOptions: false,
          answer: bad,
        );
        expect(f, isEmpty, reason: bad);
        expect(
          resolveAnswerStatus(status: 'ANSWERED', answer: bad, fields: f),
          'NOT_ANSWERED',
        );
      }
    });
  });

  group('PendingAnswerSaves', () {
    test('keeps one pending save per question', () async {
      final ran = <int>[];
      final saves = PendingAnswerSaves();
      const d = Duration(milliseconds: 30);
      saves.schedule(1, () async => ran.add(1), delay: d);
      saves.schedule(2, () async => ran.add(2), delay: d);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(ran..sort(), [1, 2]);
    });

    test('flushAll runs pending saves immediately and only once', () async {
      var count = 0;
      final saves = PendingAnswerSaves();
      saves.schedule(1, () async => count++, delay: const Duration(seconds: 5));
      saves.flushAll();
      saves.flushAll();
      await Future<void>.delayed(Duration.zero);
      expect(count, 1);
    });

    test('cancel drops a superseded save', () async {
      var count = 0;
      final saves = PendingAnswerSaves();
      saves.schedule(
        1,
        () async => count++,
        delay: const Duration(milliseconds: 20),
      );
      saves.cancel(1);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(count, 0);
    });
  });

  // QA retest 4.1: typing 2 on an INTEGER question and tapping Save & Next
  // was graded "Skipped". The player decides "has options" from the parsed
  // options; an INTEGER question must always send numericAnswer.
  group('integer answer path (player -> payload)', () {
    Map<String, dynamic> payloadFor(
      String type,
      String text,
      List<Map<String, dynamic>> options,
      String answer,
    ) {
      final parsed = parseQuestionTextAndOptions(text, options, type: type);
      return buildAnswerFields(
        type: type,
        hasOptions: (parsed['options'] as List).isNotEmpty,
        answer: answer,
      );
    }

    test('INTEGER with no options sends numericAnswer', () {
      expect(
        payloadFor(
          'INTEGER',
          'If a = 2i + j, the projection is ____.',
          const [],
          '2',
        ),
        {'numericAnswer': 2},
      );
    });

    test('INTEGER with placeholder options still sends numericAnswer', () {
      expect(
        payloadFor('INTEGER', 'Find x. (A) (B) (C) (D)', [
          {'_id': '1', 'text': ''},
          {'_id': '2', 'text': 'B'},
        ], '2'),
        {'numericAnswer': 2},
      );
    });

    test('INTEGER text with decimals is never split into options', () {
      expect(
        payloadFor(
          'NUMERICAL',
          'Error of 1.25% and 2.5) units',
          const [],
          '3.75',
        ),
        {'numericAnswer': 3.75},
      );
    });
  });
}
