/// Best guess of an exam's single subject from its title, or '' when it is
/// unclear (mocks, mixed papers, chapters shared by two subjects).
///
/// Matches whole words only: the old substring check turned "Biomolecules"
/// into Biology, "Animes" into Mathematics ("mat") and so on, so JEE tests
/// showed a Biology chip. A JEE test is never labelled Biology.
String guessExamSubject(String title) {
  final t = ' ${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ')} ';
  bool has(String phrase) => t.contains(' $phrase ');
  final isJee = has('jee') || has('jee main') || has('jee advanced');
  final isNeet = has('neet');

  String? found;
  void pick(String subject) {
    // Two different subjects named in one title: a mixed paper.
    if (found != null && found != subject) {
      found = '';
    } else {
      found ??= subject;
    }
  }

  // 1. The subject named in the title.
  const subjectWords = <String, List<String>>{
    'Physics': ['physics', 'phy'],
    'Chemistry': ['chemistry', 'chem'],
    'Mathematics': ['mathematics', 'maths', 'math'],
    'Biology': ['biology', 'bio', 'botany', 'zoology'],
  };
  subjectWords.forEach((subject, words) {
    if (words.any(has)) pick(subject);
  });

  // 2. Otherwise a known chapter name ("Chapter Test: Vector Algebra").
  if (found == null) {
    for (final entry in _chapterSubjects.entries) {
      if (entry.value.any(has)) pick(entry.key);
    }
    // Chapters taught in both Chemistry (Class 12) and Biology (Class 11).
    if (found == null && (has('biomolecules') || has('biomolecule'))) {
      if (isJee || !isNeet) found = 'Chemistry';
    }
  }

  final result = found ?? '';
  if (result == 'Biology' && isJee) return '';
  return result;
}

// NCERT / JEE Main / NEET chapter names that belong to exactly one subject.
// Chapters shared by two subjects (Thermodynamics, Biomolecules) are left out
// on purpose.
const Map<String, List<String>> _chapterSubjects = {
  'Physics': [
    'units and measurements',
    'units and measurement',
    'motion in a straight line',
    'motion in a plane',
    'laws of motion',
    'work energy and power',
    'rotational motion',
    'system of particles',
    'gravitation',
    'mechanical properties of solids',
    'mechanical properties of fluids',
    'thermal properties of matter',
    'kinetic theory',
    'oscillations',
    'waves',
    'electric charges and fields',
    'electrostatics',
    'electrostatic potential and capacitance',
    'current electricity',
    'moving charges and magnetism',
    'magnetism and matter',
    'electromagnetic induction',
    'alternating current',
    'electromagnetic waves',
    'ray optics',
    'wave optics',
    'optics',
    'dual nature of radiation and matter',
    'atoms',
    'nuclei',
    'semiconductor electronics',
    'kinematics',
    'modern physics',
  ],
  'Chemistry': [
    'some basic concepts of chemistry',
    'mole concept',
    'structure of atom',
    'atomic structure',
    'classification of elements',
    'periodicity in properties',
    'chemical bonding',
    'molecular structure',
    'equilibrium',
    'chemical equilibrium',
    'ionic equilibrium',
    'redox reactions',
    'hydrogen',
    's block',
    'p block',
    'd and f block',
    'organic chemistry',
    'general organic chemistry',
    'goc',
    'hydrocarbons',
    'environmental chemistry',
    'solid state',
    'solutions',
    'electrochemistry',
    'chemical kinetics',
    'surface chemistry',
    'coordination compounds',
    'haloalkanes',
    'haloarenes',
    'haloalkanes and haloarenes',
    'alcohols phenols and ethers',
    'alcohols',
    'aldehydes',
    'ketones',
    'aldehydes and ketones',
    'carboxylic acids',
    'amines',
    'polymers',
    'chemistry in everyday life',
    'states of matter',
    'isolation of elements',
    'metallurgy',
  ],
  'Mathematics': [
    'sets',
    'relations and functions',
    'functions',
    'trigonometric functions',
    'trigonometry',
    'inverse trigonometric functions',
    'complex numbers',
    'quadratic equations',
    'linear inequalities',
    'permutations and combinations',
    'permutation and combination',
    'binomial theorem',
    'sequences and series',
    'sequence and series',
    'straight lines',
    'straight line',
    'conic sections',
    'circles',
    'parabola',
    'ellipse',
    'hyperbola',
    'three dimensional geometry',
    '3d geometry',
    'limits and derivatives',
    'limits',
    'continuity and differentiability',
    'differentiability',
    'application of derivatives',
    'applications of derivatives',
    'integrals',
    'definite integrals',
    'indefinite integrals',
    'application of integrals',
    'area under curves',
    'differential equations',
    'vector algebra',
    'vectors',
    'matrices',
    'determinants',
    'probability',
    'statistics',
    'mathematical reasoning',
    'linear programming',
    'coordinate geometry',
  ],
  'Biology': [
    'the living world',
    'biological classification',
    'plant kingdom',
    'animal kingdom',
    'morphology of flowering plants',
    'anatomy of flowering plants',
    'structural organisation in animals',
    'cell the unit of life',
    'cell cycle and cell division',
    'photosynthesis in higher plants',
    'respiration in plants',
    'plant growth and development',
    'breathing and exchange of gases',
    'body fluids and circulation',
    'excretory products',
    'locomotion and movement',
    'neural control and coordination',
    'chemical coordination and integration',
    'sexual reproduction in flowering plants',
    'human reproduction',
    'reproductive health',
    'principles of inheritance and variation',
    'molecular basis of inheritance',
    'evolution',
    'human health and disease',
    'microbes in human welfare',
    'biotechnology',
    'organisms and populations',
    'ecosystem',
    'biodiversity and conservation',
    'genetics',
    'ecology',
  ],
};

class ExamModel {
  const ExamModel({
    required this.id,
    required this.title,
    required this.subjectId,
    required this.subjectName,
    required this.date,
    required this.durationMinutes,
    required this.totalMarks,
    required this.passingMarks,
    required this.status,
    required this.questions,
    required this.submissionStatus,
    this.score,
    this.totalQuestions,
    this.startTime,
    this.endTime,
    this.maxTabSwitchesAllowed,
  });

  final String id;
  final String title;
  final String subjectId;
  final String subjectName;
  final DateTime? date;
  final int durationMinutes;
  final num totalMarks;
  final num passingMarks;
  final String status;
  final List<dynamic> questions;
  final String submissionStatus;
  final num? score;
  final int? totalQuestions;
  final DateTime? startTime;
  final DateTime? endTime;

  /// Proctoring leave limit from `security.maxTabSwitchesAllowed`; null when the
  /// server (older builds) does not send it.
  final int? maxTabSwitchesAllowed;

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    final sId = json['subjectId'] ?? json['subject'];
    final settings = json['settings'] is Map ? json['settings'] : null;
    final security = json['security'] is Map ? json['security'] : null;

    DateTime? parsedStartTime;
    if (settings != null && settings['startTime'] != null) {
      parsedStartTime = DateTime.tryParse(
        settings['startTime'].toString(),
      )?.toLocal();
    } else if (json['startTime'] != null) {
      parsedStartTime = DateTime.tryParse(
        json['startTime'].toString(),
      )?.toLocal();
    }

    DateTime? parsedEndTime;
    if (settings != null && settings['endTime'] != null) {
      parsedEndTime = DateTime.tryParse(
        settings['endTime'].toString(),
      )?.toLocal();
    } else if (json['endTime'] != null) {
      parsedEndTime = DateTime.tryParse(json['endTime'].toString())?.toLocal();
    }

    int parsedTotalQuestions = 0;
    if (json['totalQuestions'] != null) {
      parsedTotalQuestions =
          double.tryParse(json['totalQuestions'].toString())?.toInt() ?? 0;
    } else if (settings != null && settings['totalQuestions'] != null) {
      parsedTotalQuestions =
          double.tryParse(settings['totalQuestions'].toString())?.toInt() ?? 0;
    } else if (json['questions'] is List) {
      parsedTotalQuestions = (json['questions'] as List).length;
    }

    final int durationMinutes =
        settings != null && settings['durationMinutes'] != null
        ? (double.tryParse(settings['durationMinutes'].toString())?.toInt() ??
              60)
        : (double.tryParse(
                (json['durationMinutes'] ?? json['duration'] ?? 60).toString(),
              )?.toInt() ??
              60);

    final num passingMarks =
        settings != null && settings['passingMarks'] != null
        ? (num.tryParse(settings['passingMarks'].toString()) ?? 40)
        : (num.tryParse((json['passingMarks'] ?? 40).toString()) ?? 40);

    final num totalMarks = json['totalMarks'] != null
        ? (num.tryParse(json['totalMarks'].toString()) ?? 100)
        : 100;

    final num? score = json['score'] != null
        ? num.tryParse(json['score'].toString())
        : null;

    // Empty when the exam has no single subject (e.g. a full mock); the UI
    // shows "All subjects" and leaves it out of the subject filter.
    // /exams/student/my-exams sends no subject, so it is guessed from the
    // title (see [guessExamSubject]).
    final String parsedSubjectName = sId is Map && sId['name'] != null
        ? sId['name'].toString()
        : guessExamSubject((json['title'] ?? '').toString());

    final String rawStatus = (json['status'] ?? 'Upcoming').toString();
    final String parsedSubmissionStatus =
        json['submissionStatus']?.toString() ??
        (rawStatus == 'COMPLETED'
            ? 'SUBMITTED'
            : (rawStatus == 'IN_PROGRESS' ? 'IN_PROGRESS' : 'NOT_STARTED'));

    return ExamModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: json['title'] ?? 'Untitled Exam',
      subjectId: sId is Map
          ? (sId['_id'] ?? sId['id'] ?? '').toString()
          : sId?.toString() ?? '',
      subjectName: parsedSubjectName,
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString())?.toLocal()
          : (parsedStartTime ??
                (json['createdAt'] != null
                    ? DateTime.tryParse(json['createdAt'].toString())?.toLocal()
                    : null)),
      durationMinutes: durationMinutes,
      totalMarks: totalMarks,
      passingMarks: passingMarks,
      status: rawStatus,
      questions: json['questions'] ?? [],
      submissionStatus: parsedSubmissionStatus,
      score: score,
      totalQuestions: parsedTotalQuestions,
      startTime: parsedStartTime,
      endTime: parsedEndTime,
      maxTabSwitchesAllowed: int.tryParse(
        // Server stores the limit under `security`; `settings` is a fallback.
        (security?['maxTabSwitchesAllowed'] ??
                    settings?['maxTabSwitchesAllowed'])
                ?.toString() ??
            '',
      ),
    );
  }
}

class ExamResultModel {
  const ExamResultModel({
    required this.id,
    required this.examId,
    required this.examTitle,
    required this.score,
    required this.totalMarks,
    required this.percentage,
    required this.status,
  });

  final String id;
  final String examId;
  final String examTitle;
  final num score;
  final num totalMarks;
  final num percentage;
  final String status;

  factory ExamResultModel.fromJson(Map<String, dynamic> json) {
    final eId = json['examId'] ?? json['exam'];
    String title = 'Untitled Exam';
    if (json['examTitle'] != null && json['examTitle'].toString().isNotEmpty) {
      title = json['examTitle'].toString();
    } else if (json['title'] != null && json['title'].toString().isNotEmpty) {
      title = json['title'].toString();
    } else if (eId is Map && eId['title'] != null) {
      title = eId['title'].toString();
    }

    final String examIdStr = eId is Map
        ? (eId['_id'] ?? eId['id'] ?? '').toString()
        : eId?.toString() ?? '';

    final num score = num.tryParse((json['score'] ?? 0).toString()) ?? 0;
    final num totalMarks =
        num.tryParse(
          (json['totalMarks'] ?? json['maxMarks'] ?? 100).toString(),
        ) ??
        100;
    final rawPercentage = json['accuracy'] ?? json['percentage'];
    final num percentage =
        ((rawPercentage != null
                ? (num.tryParse(rawPercentage.toString()) ?? 0)
                : (totalMarks > 0
                      ? ((score / totalMarks * 100 * 100).round() / 100)
                      : 0))
            .clamp(0, 100));

    return ExamResultModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      examId: examIdStr,
      examTitle: title,
      score: score,
      totalMarks: totalMarks,
      percentage: percentage,
      status: (json['status'] ?? 'graded').toString(),
    );
  }
}

class ParentExamModel {
  const ParentExamModel({
    required this.id,
    required this.title,
    required this.childId,
    required this.childName,
    required this.submissionStatus,
    required this.score,
    required this.totalQuestions,
    required this.totalMarks,
    required this.startTime,
    required this.endTime,
  });

  final String id;
  final String title;
  final String childId;
  final String childName;
  final String submissionStatus;
  final num? score;
  final int totalQuestions;
  final num totalMarks;
  final DateTime? startTime;
  final DateTime? endTime;

  factory ParentExamModel.fromJson(Map<String, dynamic> json) {
    final settings = json['settings'] is Map ? json['settings'] : null;
    return ParentExamModel(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? 'Untitled Exam',
      childId: json['childId'] ?? '',
      childName: json['childName'] ?? 'Unknown',
      submissionStatus: json['submissionStatus'] ?? 'NOT_STARTED',
      score: json['score'],
      totalQuestions: json['totalQuestions'] ?? 0,
      totalMarks: json['totalMarks'] ?? 100,
      startTime: settings != null && settings['startTime'] != null
          ? DateTime.tryParse(settings['startTime'].toString())?.toLocal()
          : null,
      endTime: settings != null && settings['endTime'] != null
          ? DateTime.tryParse(settings['endTime'].toString())?.toLocal()
          : null,
    );
  }
}

class ParentExamAnalysisModel {
  const ParentExamAnalysisModel({
    required this.details,
    required this.score,
    required this.totalTime,
    required this.submittedAt,
    this.totalMarks = 0,
    this.subjectStats = const {},
    this.topicStats = const {},
    this.difficultyStats = const {},
    this.submissionStatus = '',
  });

  final List<ExamAnalysisDetailModel> details;
  final num score;
  final int totalTime;
  final DateTime? submittedAt;
  final num totalMarks;
  final Map<String, ExamAnalysisStatsModel> subjectStats;
  final Map<String, ExamAnalysisStatsModel> topicStats;
  final Map<String, ExamAnalysisStatsModel> difficultyStats;
  final String submissionStatus;

  factory ParentExamAnalysisModel.fromJson(Map<String, dynamic> json) {
    final detailsJson = json['details'] as List? ?? [];
    return ParentExamAnalysisModel(
      details: detailsJson
          .map((d) => ExamAnalysisDetailModel.fromJson(d))
          .toList(),
      score: num.tryParse(json['score']?.toString() ?? '') ?? 0,
      totalTime: int.tryParse(json['totalTime']?.toString() ?? '') ?? 0,
      submittedAt: json['submittedAt'] != null
          ? DateTime.tryParse(json['submittedAt'].toString())
          : null,
      totalMarks: num.tryParse(json['totalMarks']?.toString() ?? '') ?? 0,
      subjectStats: _statsFromJson(json['subjectStats']),
      topicStats: _statsFromJson(json['topicStats']),
      difficultyStats: _statsFromJson(json['difficultyStats']),
      submissionStatus: json['submission'] is Map
          ? json['submission']['status']?.toString() ?? ''
          : '',
    );
  }

  static Map<String, ExamAnalysisStatsModel> _statsFromJson(dynamic value) {
    if (value is! Map) return const {};
    final result = <String, ExamAnalysisStatsModel>{};
    for (final entry in value.entries) {
      result[entry.key.toString()] = ExamAnalysisStatsModel.fromJson(
        entry.value is Map
            ? Map<String, dynamic>.from(entry.value as Map)
            : const <String, dynamic>{},
      );
    }
    return result;
  }
}

class ExamAnalysisStatsModel {
  const ExamAnalysisStatsModel({
    required this.totalQuestions,
    required this.attempted,
    required this.correct,
    required this.wrong,
    required this.totalMarks,
    required this.score,
    required this.accuracy,
  });

  final int totalQuestions, attempted, correct, wrong, accuracy;
  final num totalMarks, score;

  factory ExamAnalysisStatsModel.fromJson(Map<String, dynamic> json) {
    int asInt(String key) => int.tryParse(json[key]?.toString() ?? '') ?? 0;
    num asNum(String key) => num.tryParse(json[key]?.toString() ?? '') ?? 0;
    final total = asInt('totalQuestions');
    final correct = asInt('correct');
    return ExamAnalysisStatsModel(
      totalQuestions: total,
      attempted: asInt('attempted'),
      correct: correct,
      wrong: asInt('wrong'),
      totalMarks: asNum('totalMarks'),
      score: asNum('score'),
      accuracy: json['accuracy'] == null
          ? (total == 0 ? 0 : (correct / total * 100).round())
          : asInt('accuracy'),
    );
  }
}

class ExamAnalysisDetailModel {
  const ExamAnalysisDetailModel({
    required this.questionId,
    required this.questionText,
    required this.marks,
    required this.options,
    required this.userAnswer,
    required this.isCorrect,
    required this.marksObtained,
    required this.subjectName,
    required this.explanation,
    required this.negativeMarks,
    this.questionType = 'MCQ',
    this.questionImageUrl,
    this.correctAnswerText = '',
    this.attempted,
  });

  final String questionId;
  final String questionText;
  final num marks;
  final List<ExamAnalysisOptionModel> options;
  final ExamAnalysisUserAnswerModel? userAnswer;
  final bool isCorrect;
  final num marksObtained;
  final String subjectName;
  final String explanation;
  final num negativeMarks;
  final String questionType;

  /// Separate question picture (Prepzo paper import); may also be in the HTML.
  final String? questionImageUrl;

  /// Expected answer of a typed (integer / numerical / fill-in) question.
  final String correctAnswerText;

  /// Server's verdict on whether the student answered; null on old servers.
  final bool? attempted;

  /// True for questions answered by typing rather than picking an option.
  bool get isTypedAnswer {
    final t = questionType.toUpperCase();
    if (t == 'INTEGER' ||
        t == 'NUMERICAL' ||
        t == 'FILL_BLANKS' ||
        t == 'SUBJECTIVE') {
      return true;
    }
    final realOptions = options.where(
      (o) => o.text.trim().isNotEmpty || (o.imageUrl ?? '').isNotEmpty,
    );
    return realOptions.isEmpty;
  }

  factory ExamAnalysisDetailModel.fromJson(Map<String, dynamic> json) {
    final optionsJson = json['options'] as List? ?? [];

    // Calculate marksObtained if missing
    num calculatedMarksObtained = json['marksObtained'] ?? 0;
    if (json['marksObtained'] == null) {
      final bool isCorrect = json['isCorrect'] ?? false;
      final userAnswer = json['userAnswer'];
      if (userAnswer != null && userAnswer['status'] != 'NOT_ANSWERED') {
        if (isCorrect) {
          calculatedMarksObtained = json['marks'] ?? 0;
        } else {
          // Negative marks might not be available, default to 0
          calculatedMarksObtained = json['negativeMarks'] != null
              ? -(json['negativeMarks'])
              : 0;
        }
      }
    }

    return ExamAnalysisDetailModel(
      questionId: (json['questionId'] ?? json['_id'] ?? '').toString(),
      questionText: json['questionText']?.toString() ?? '',
      marks: num.tryParse(json['marks']?.toString() ?? '') ?? 0,
      options: optionsJson
          .map((o) => ExamAnalysisOptionModel.fromJson(o))
          .toList(),
      userAnswer: json['userAnswer'] != null
          ? ExamAnalysisUserAnswerModel.fromJson(json['userAnswer'])
          : null,
      isCorrect: json['isCorrect'] == true,
      marksObtained: calculatedMarksObtained,
      subjectName: json['subject'] is Map
          ? json['subject']['name']?.toString() ?? 'General'
          : json['subject']?.toString() ??
                json['subjectName']?.toString() ??
                'General',
      explanation: json['explanation']?.toString() ?? '',
      negativeMarks: num.tryParse(json['negativeMarks']?.toString() ?? '') ?? 0,
      questionType: json['type']?.toString() ?? 'MCQ',
      questionImageUrl: _nonEmpty(
        json['questionImageUrl'] ?? json['imageUrl'] ?? json['image'],
      ),
      correctAnswerText: json['correctAnswerText']?.toString() ?? '',
      attempted: json['attempted'] is bool ? json['attempted'] as bool : null,
    );
  }
}

String? _nonEmpty(dynamic v) {
  if (v is! String) return null;
  final s = v.trim();
  return s.isEmpty ? null : s;
}

String? _idString(dynamic v) {
  if (v == null) return null;
  if (v is Map) return (v['_id'] ?? v['id'] ?? v[r'$oid'])?.toString();
  final s = v.toString();
  return s.isEmpty ? null : s;
}

class ExamAnalysisOptionModel {
  const ExamAnalysisOptionModel({
    required this.id,
    required this.text,
    required this.isCorrect,
    this.imageUrl,
  });

  final String id;
  final String text;
  final bool isCorrect;
  final String? imageUrl;

  factory ExamAnalysisOptionModel.fromJson(Map<String, dynamic> json) {
    return ExamAnalysisOptionModel(
      id: _idString(json['_id'] ?? json['id']) ?? '',
      text: json['text']?.toString() ?? '',
      isCorrect: json['isCorrect'] == true,
      imageUrl: _nonEmpty(json['imageUrl'] ?? json['image']),
    );
  }
}

class ExamAnalysisUserAnswerModel {
  const ExamAnalysisUserAnswerModel({
    required this.selectedOptionId,
    required this.status,
    this.selectedOptionIds = const [],
    this.numericAnswer,
    this.subjectiveAnswerText,
  });

  final String? selectedOptionId;
  final String status;
  final List<String> selectedOptionIds;
  final String? numericAnswer;
  final String? subjectiveAnswerText;

  /// The typed answer, whichever field it was saved in.
  String? get typedAnswer => numericAnswer ?? subjectiveAnswerText;

  /// True when the student actually gave an answer (not just a review mark).
  bool get hasValue =>
      (selectedOptionId ?? '').isNotEmpty ||
      selectedOptionIds.isNotEmpty ||
      (typedAnswer ?? '').isNotEmpty;

  /// True only when the student actually gave an answer. `status` alone is
  /// unreliable: a question marked for review but left blank is not
  /// 'NOT_ANSWERED', yet it is a skip, not a wrong answer.
  bool get hasAnswer =>
      (selectedOptionId != null && selectedOptionId!.isNotEmpty) ||
      (subjectiveAnswerText != null && subjectiveAnswerText!.trim().isNotEmpty);

  factory ExamAnalysisUserAnswerModel.fromJson(Map<String, dynamic> json) {
    final ids = json['selectedOptionIds'];
    return ExamAnalysisUserAnswerModel(
      selectedOptionId: _idString(json['selectedOptionId']),
      status: json['status']?.toString() ?? 'NOT_ANSWERED',
      selectedOptionIds: ids is List
          ? ids.map(_idString).whereType<String>().toList()
          : const [],
      numericAnswer: _nonEmpty(json['numericAnswer']?.toString()),
      subjectiveAnswerText: _nonEmpty(json['subjectiveAnswerText']?.toString()),
    );
  }
}
