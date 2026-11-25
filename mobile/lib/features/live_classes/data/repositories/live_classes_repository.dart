import 'package:lms/core/network/api_client.dart';
import 'package:lms/features/live_classes/data/models/live_classes_models.dart';

class LiveClassesRepository {
  final ApiClient _apiClient;

  LiveClassesRepository(this._apiClient);

  Future<List<LiveClass>> getActiveClasses(String token) async {
    try {
      final response = await _apiClient.get(
        '/live-classes?status=ONGOING',
        token: token,
      );
      final data = response['data'] ?? [];
      if (data is List) {
        return data.map((e) => LiveClass.fromJson(e)).toList();
      }
    } catch (e) {
      // Return empty list gracefully if user plan lacks live classes access or on network error
    }
    return [];
  }

  /// Records attendance at the moment the student launches an active class.
  /// Joining is deliberately best-effort so a temporary network failure never
  /// prevents the student from entering a class.
  Future<void> recordLiveClassJoin({
    required String liveClassId,
    required String token,
  }) async {
    if (liveClassId.isEmpty || token.isEmpty || token.startsWith('mock-')) {
      return;
    }
    try {
      await _apiClient.post(
        '/attendance/live-class-checkin',
        data: {'liveClassId': liveClassId},
        token: token,
      );
    } catch (_) {
      // Joining remains available; the user can retry from the live-class list.
    }
  }
}
