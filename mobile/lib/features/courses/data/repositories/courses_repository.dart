import 'package:lms/core/network/api_client.dart';
import 'package:lms/features/courses/data/models/batch_model.dart';
import 'package:lms/features/courses/data/models/course_model.dart';
import 'package:lms/features/courses/data/models/course_test_model.dart';

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

  /// Every published test of a course, with this student's attempt status
  /// when a token is sent. Same endpoint the website's course page uses.
  Future<List<CourseTest>> getCourseTests({
    required String token,
    required String courseId,
  }) async {
    final response = await _apiClient.get(
      '/public/courses/$courseId/exams',
      token: token,
    );
    final data = response['data'] as List<dynamic>? ?? [];
    final tests = data
        .whereType<Map<String, dynamic>>()
        .map(CourseTest.fromJson)
        .toList();
    // Free tests first (like the website), each group in schedule order.
    tests.sort((a, b) {
      if (a.isFree != b.isFree) return a.isFree ? -1 : 1;
      final at = a.exam.startTime ?? DateTime(2100);
      final bt = b.exam.startTime ?? DateTime(2100);
      return at.compareTo(bt);
    });
    return tests;
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

  Future<Map<String, dynamic>> initiateRazorpayOrder({
    required String token,
    required String courseId,
  }) async {
    final response = await _apiClient.post(
      '/payments/razorpay/initiate',
      token: token,
      data: {'courseId': courseId},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> verifyRazorpayPayment({
    required String token,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final response = await _apiClient.post(
      '/payments/razorpay/verify',
      token: token,
      data: {
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      },
    );
    return Map<String, dynamic>.from(response as Map);
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
