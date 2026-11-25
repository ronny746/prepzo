import 'package:dio/dio.dart';
import 'package:lms/core/network/api_client.dart';
import 'package:lms/features/exams/data/models/exams_models.dart';

class ExamsRepository {
  ExamsRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<ExamModel>> getStudentExams(String token) async {
    if (token.startsWith('mock-')) {
      return [
        ExamModel(
          id: 'exam-1',
          title: 'NEET Organic Chemistry Mock',
          subjectId: 'sub-1',
          subjectName: 'Organic Chemistry',
          date: DateTime.now().add(const Duration(days: 1)),
          durationMinutes: 60,
          totalMarks: 120,
          passingMarks: 50,
          status: 'Available',
          questions: const [],
          submissionStatus: 'NOT_STARTED',
        ),
        ExamModel(
          id: 'exam-2',
          title: 'NEET Human Physiology Final',
          subjectId: 'sub-2',
          subjectName: 'Zoology',
          date: DateTime.now().add(const Duration(days: 3)),
          durationMinutes: 90,
          totalMarks: 180,
          passingMarks: 90,
          status: 'Available',
          questions: const [],
          submissionStatus: 'NOT_STARTED',
        ),
      ];
    }
    final response = await _apiClient.get(
      '/exams/student/my-exams',
      token: token,
    );
    final data = response['data'] ?? response['exams'] ?? [];
    if (data is List) {
      return data.map((e) => ExamModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<ParentExamModel>> getParentChildrenExams(String token) async {
    final response = await _apiClient.get(
      '/exams/parent/children-exams',
      token: token,
    );
    final data = response['data'] ?? response['exams'] ?? [];
    if (data is List) {
      return data.map((e) => ParentExamModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getPerformanceData(String token) async {
    if (token.startsWith('mock-')) {
      return {
        'overall': {
          'totalExamsTaken': 3,
          'averageScore': '66.00',
          'overallPercentage': '86.00',
        },
        'subjectWise': [
          {
            'subject': 'Physics',
            'totalQuestions': 10,
            'attempted': 8,
            'correct': 6,
            'wrong': 2,
            'marksObtained': 24,
            'totalPossibleMarks': 40,
            'percentage': 60.00,
            'accuracy': 75.00,
          },
          {
            'subject': 'Chemistry',
            'totalQuestions': 10,
            'attempted': 9,
            'correct': 8,
            'wrong': 1,
            'marksObtained': 32,
            'totalPossibleMarks': 40,
            'percentage': 80.00,
            'accuracy': 88.89,
          },
        ],
        'recentExams': [
          {
            'submissionId': 'res-1',
            'examId': 'exam-3',
            'examTitle': 'NEET Electrochemistry Quiz 1',
            'score': 44,
            'totalMarks': 50,
            'percentage': '88.00',
            'status': 'graded',
          },
          {
            'submissionId': 'res-2',
            'examId': 'exam-4',
            'examTitle': 'NEET Genetics Unit Test',
            'score': 92,
            'totalMarks': 100,
            'percentage': '92.00',
            'status': 'graded',
          },
        ],
      };
    }
    try {
      final response = await _apiClient.get(
        '/analytics-reports/student/me/performance',
        token: token,
      );
      return response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : <String, dynamic>{};
    } catch (e) {
      print('Error fetching performance analytics: $e');
      return <String, dynamic>{};
    }
  }

  Future<List<ExamResultModel>> getResults(String token) async {
    if (token.startsWith('mock-')) {
      return [
        const ExamResultModel(
          id: 'res-1',
          examId: 'exam-3',
          examTitle: 'NEET Electrochemistry Quiz 1',
          score: 44,
          totalMarks: 50,
          percentage: 88,
          status: 'graded',
        ),
        const ExamResultModel(
          id: 'res-2',
          examId: 'exam-4',
          examTitle: 'NEET Genetics Unit Test',
          score: 92,
          totalMarks: 100,
          percentage: 92,
          status: 'graded',
        ),
      ];
    }
    try {
      final performanceData = await getPerformanceData(token);
      if (performanceData['recentExams'] is List) {
        final List<dynamic> recentExams = performanceData['recentExams'];
        return recentExams.map((e) => ExamResultModel.fromJson(e)).toList();
      }
    } catch (e) {
      print('Fallback to results endpoint due to error: $e');
    }
    final response = await _apiClient.get('/results', token: token);
    final data = response['data'] ?? response['results'] ?? [];
    if (data is List) {
      return data.map((e) => ExamResultModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> startExam(String token, String examId) async {
    final response = await _apiClient.post(
      '/exams/$examId/start',
      token: token,
    );
    return response['data'] ?? {};
  }

  /// The test rules (proctoring, warning limit) without starting the clock.
  /// Throws on a server that does not have this endpoint yet.
  Future<Map<String, dynamic>> getExamRules(String token, String examId) async {
    final response = await _apiClient.get('/exams/$examId/rules', token: token);
    final data = response['data'];
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<void> saveAnswer(
    String token,
    String examId,
    Map<String, dynamic> data,
  ) async {
    await _apiClient.post(
      '/exams/$examId/save-answer',
      token: token,
      data: data,
    );
  }

  Future<void> submitExam(
    String token,
    String examId,
    Map<String, dynamic> data,
  ) async {
    await _apiClient.post('/exams/$examId/submit', token: token, data: data);
  }

  Future<void> uploadSnapshot(
    String token,
    String examId,
    List<int> imageBytes,
    String filename,
  ) async {
    final formData = FormData.fromMap({
      'snapshot': MultipartFile.fromBytes(imageBytes, filename: filename),
    });
    await _apiClient.post(
      '/exams/$examId/snapshot',
      token: token,
      data: formData,
    );
  }

  Future<ParentExamAnalysisModel> getParentExamAnalysis(
    String token,
    String examId,
    String childId,
  ) async {
    final response = await _apiClient.get(
      '/exams/parent/children-exams/$examId/analysis/$childId',
      token: token,
    );
    final data = response['data'];
    return ParentExamAnalysisModel.fromJson(data);
  }

  Future<ParentExamAnalysisModel> getStudentExamAnalysis(
    String token,
    String examId,
  ) async {
    if (token.startsWith('mock-')) {
      return ParentExamAnalysisModel(
        score: 44,
        totalTime: 120,
        submittedAt: DateTime.now().subtract(const Duration(days: 2)),
        details: const [],
      );
    }
    final response = await _apiClient.get(
      '/exams/$examId/analysis',
      token: token,
    );
    final data = response['data'];
    return ParentExamAnalysisModel.fromJson(data);
  }

  Future<List<String>> getSubjects(String token) async {
    if (token.startsWith('mock-')) {
      return ['Physics', 'Chemistry', 'Biology', 'Mathematics'];
    }
    try {
      final response = await _apiClient.get('/subjects', token: token);
      final data = response['data'] ?? [];
      final List<String> subjects = [];
      if (data is List) {
        for (var item in data) {
          if (item is Map) {
            final name = item['name']?.toString() ?? '';
            if (name.isNotEmpty && !subjects.contains(name)) {
              subjects.add(name);
            }
          }
        }
      }
      return subjects;
    } catch (e) {
      // Subjects are institute data. An unavailable API must not make the
      // student appear enrolled in a generic, unrelated syllabus.
      return const [];
    }
  }

  Future<List<dynamic>> getQuestionsByHierarchy({
    required String token,
    String? subject,
    String? chapter,
    String? topic,
    String? difficulty,
    int limit = 10,
  }) async {
    if (token.startsWith('mock-')) {
      return [];
    }
    try {
      final queryParams = <String, dynamic>{'limit': limit, 'random': 'true'};
      if (subject != null && subject.isNotEmpty && subject != 'All')
        queryParams['subject'] = subject;
      if (chapter != null && chapter.isNotEmpty && chapter != 'All')
        queryParams['chapter'] = chapter;
      if (topic != null && topic.isNotEmpty && topic != 'All')
        queryParams['topic'] = topic;
      if (difficulty != null && difficulty.isNotEmpty && difficulty != 'All')
        queryParams['difficulty'] = difficulty;

      final response = await _apiClient.get(
        '/question-banks/questions',
        token: token,
        queryParameters: queryParams,
      );
      final data = response['data'];
      return data is List ? data : [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getPracticeFilters(String token) async {
    if (token.startsWith('mock-')) return {};
    try {
      final response = await _apiClient.get(
        '/student/practice/filters',
        token: token,
      );
      return response;
    } catch (e) {
      return {};
    }
  }

  Future<List<dynamic>> getPracticeHistory(
    String token,
    String sessionType,
  ) async {
    if (token.startsWith('mock-')) return [];
    try {
      final response = await _apiClient.get(
        '/student/practice/history',
        token: token,
        queryParameters: {'sessionType': sessionType},
      );
      final data = response['data'];
      return data is List ? data : [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> generatePracticeSession(
    String token,
    Map<String, dynamic> body,
  ) async {
    final response = await _apiClient.post(
      '/student/practice/generate',
      token: token,
      data: body,
    );
    return response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getPracticeSession(
    String token,
    String sessionId,
  ) async {
    final response = await _apiClient.get(
      '/student/practice/$sessionId',
      token: token,
    );
    return response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> savePracticeProgress(
    String token,
    String sessionId,
    Map<String, dynamic> body,
  ) async {
    final response = await _apiClient.put(
      '/student/practice/$sessionId/progress',
      token: token,
      data: body,
    );
    return response;
  }

  Future<Map<String, dynamic>> submitPracticeSession(
    String token,
    String sessionId, [
    Map<String, dynamic>? body,
  ]) async {
    final response = await _apiClient.post(
      '/student/practice/$sessionId/submit',
      token: token,
      data: body,
    );
    return response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : <String, dynamic>{};
  }

  Future<List<dynamic>> getRemedialDpps(String token, String examId) async {
    if (token.startsWith('mock-')) return [];
    try {
      final response = await _apiClient.get(
        '/student/practice/remedial/$examId',
        token: token,
      );
      final data = response['data'];
      return data is List ? data : [];
    } catch (e) {
      return [];
    }
  }
}
