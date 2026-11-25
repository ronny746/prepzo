import 'package:lms/core/network/api_client.dart';

class OperationsRepository {
  OperationsRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<void> requestTeacherLeave({
    required String token,
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    await _apiClient.post(
      '/operations/leave',
      token: token,
      data: {
        'leaveType': leaveType,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'reason': reason.trim(),
      },
    );
  }
}
