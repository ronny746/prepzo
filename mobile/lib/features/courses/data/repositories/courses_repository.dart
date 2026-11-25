import 'package:lms/core/network/api_client.dart';
import 'package:lms/features/courses/data/models/batch_model.dart';
import 'package:lms/features/courses/data/models/course_model.dart';

class CoursesRepository {
  final ApiClient _apiClient;

  CoursesRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<List<CourseModel>> getCourses(String token) async {
    final path = token.isNotEmpty ? '/courses' : '/public/courses';
    final response = await _apiClient.get(path, token: token);
    final data = response['data'] as List<dynamic>? ?? [];
    return data
        .map((item) => CourseModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<CourseModel> getCourseById({
    required String token,
    required String id,
  }) async {
    final path = token.isNotEmpty ? '/courses/$id' : '/public/courses/$id';
    final response = await _apiClient.get(path, token: token);
    final data = response['data'] as Map<String, dynamic>? ?? response;
    return CourseModel.fromJson(data);
  }

  Future<void> enrollCourse({
    required String token,
    required String courseId,
    String paymentMethod = 'UPI',
  }) async {
    await _apiClient.post(
      '/courses/$courseId/enroll',
      token: token,
      data: {'paymentMethod': paymentMethod},
    );
  }

  Future<Map<String, dynamic>> initiateCoursePayment({
    required String token,
    required String courseId,
  }) async {
    final response = await _apiClient.post(
      '/payments/easebuzz/initiate',
      token: token,
      data: {'courseId': courseId},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<List<BatchModel>> getMyBatches(String token) async {
    final response = await _apiClient.get('/batches/my-batches', token: token);
    final data = response['data'] as List<dynamic>? ?? [];
    return data
        .map((item) => BatchModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
