import 'package:lms/core/network/api_client.dart';
import 'package:lms/features/academics/data/models/academics_models.dart';

class AcademicsRepository {
  AcademicsRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<AcademicTask>> getStudentTasks(String token) async {
    final futures = await Future.wait([
      _safeGet('/assignments', token: token),
      _safeGet('/homework', token: token),
      _safeGet('/subjects', token: token),
      _safeGet('/assignments/my-submissions', token: token),
    ]);

    final assignmentsData = futures[0];
    final homeworkData = futures[1];
    final subjectsData = futures[2];
    final submissionsData = futures[3];

    final Map<String, String> subjectsMap = {};
    for (var sub in subjectsData) {
      if (sub is Map<String, dynamic>) {
        final id = sub['_id'] ?? sub['id']?.toString() ?? '';
        subjectsMap[id] = sub['name'] ?? 'Unknown Subject';
      }
    }

    final List<AcademicTask> tasks = [];
    for (var a in assignmentsData) {
      if (a is Map<String, dynamic>) {
        tasks.add(
          AcademicTask.fromJson(a, 'Assignment', subjectsMap, submissionsData),
        );
      }
    }
    for (var h in homeworkData) {
      if (h is Map<String, dynamic>) {
        tasks.add(
          AcademicTask.fromJson(h, 'Homework', subjectsMap, submissionsData),
        );
      }
    }

    // Sort by due date
    tasks.sort((a, b) {
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });

    return tasks;
  }

  Future<List<AcademicTask>> getParentTasks(String token) async {
    final futures = await Future.wait([
      _safeGet('/assignments/my-children', token: token),
      _safeGet('/homework/my-children', token: token),
      _safeGet('/subjects', token: token),
      _safeGet('/assignments/my-children-submissions', token: token),
    ]);

    final assignmentsData = futures[0];
    final homeworkData = futures[1];
    final subjectsData = futures[2];
    final submissionsData = futures[3];

    final Map<String, String> subjectsMap = {};
    for (var sub in subjectsData) {
      if (sub is Map<String, dynamic>) {
        final id = sub['_id'] ?? sub['id']?.toString() ?? '';
        subjectsMap[id] = sub['name'] ?? 'Unknown Subject';
      }
    }

    final List<AcademicTask> tasks = [];
    for (var a in assignmentsData) {
      if (a is Map<String, dynamic>) {
        tasks.add(
          AcademicTask.fromJson(a, 'Assignment', subjectsMap, submissionsData),
        );
      }
    }
    for (var h in homeworkData) {
      if (h is Map<String, dynamic>) {
        tasks.add(
          AcademicTask.fromJson(h, 'Homework', subjectsMap, submissionsData),
        );
      }
    }

    // Sort by due date
    tasks.sort((a, b) {
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });

    return tasks;
  }

  Future<void> submitTask({
    required String token,
    required String taskId,
    required String taskType,
    required String content,
    List<String> attachments = const [],
  }) async {
    final endpoint = taskType == 'Assignment'
        ? '/assignments/$taskId/submit'
        : '/homework/$taskId/submit';

    await _apiClient.post(
      endpoint,
      token: token,
      data: {
        'content': content,
        if (attachments.isNotEmpty) 'attachments': attachments,
      },
    );
  }

  Future<List<dynamic>> _safeGet(String path, {required String token}) async {
    try {
      final response = await _apiClient.get(path, token: token);
      final data = response['data'];
      if (data is List) return data;
      if (data is Map<String, dynamic> && data['data'] is List) {
        return data['data'] as List;
      }
      return [];
    } catch (e) {
      print('Error fetching $path: $e');
      return [];
    }
  }
}
