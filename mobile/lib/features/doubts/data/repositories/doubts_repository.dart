import 'package:dio/dio.dart';
import 'package:lms/core/network/api_client.dart';
import 'package:lms/features/doubts/data/models/doubt_models.dart';

class DoubtsRepository {
  DoubtsRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<DoubtBatchModel>> getStudentBatches(String token) async {
    try {
      final response = await _apiClient.get('/batches/my-batches', token: token);
      final data = response['data'];
      if (data is List) {
        return data
            .map((json) => DoubtBatchModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Return empty list on failure so caller can handle gracefully
    }
    return [];
  }

  Future<List<TeacherModel>> getTeachers(String token) async {
    try {
      final response = await _apiClient.get(
        '/users',
        token: token,
        queryParameters: {'role': 'teacher'},
      );
      final data = response['data'];
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .where((u) {
              final r = u['role']?.toString().toLowerCase();
              return r == 'teacher';
            })
            .map((json) => TeacherModel.fromJson(json))
            .toList();
      }
    } catch (e) {
      // Fallback or empty list
    }
    return [];
  }

  Future<List<DoubtModel>> getDoubtsByBatch(String token, String batchId) async {
    if (batchId.isEmpty) return [];
    try {
      final response = await _apiClient.get('/doubts/batch/$batchId', token: token);
      final data = response['data'];
      if (data is List) {
        return data
            .map((json) => DoubtModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback
    }
    return [];
  }

  Future<String?> uploadFile(String token, String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final response = await _apiClient.post(
        '/upload',
        token: token,
        data: formData,
      );
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return data['url']?.toString();
      }
      return response['url']?.toString();
    } catch (e) {
      return null;
    }
  }

  Future<DoubtModel?> createDoubt({
    required String token,
    required String batchId,
    required String teacherId,
    required String question,
    List<String> attachments = const [],
  }) async {
    try {
      final response = await _apiClient.post(
        '/doubts',
        token: token,
        data: {
          'batchId': batchId,
          'teacherId': teacherId,
          'question': question,
          'attachments': attachments,
        },
      );
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return DoubtModel.fromJson(data);
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }
}
