import 'package:flutter/foundation.dart';
import 'package:lms/core/network/api_client.dart';
import 'package:lms/features/notifications/data/models/notification_model.dart';

class NotificationsRepository {
  final ApiClient _apiClient;

  NotificationsRepository(this._apiClient);

  Future<List<AppNotificationModel>> fetchNotifications(String token) async {
    if (token.isNotEmpty && !token.startsWith('mock-')) {
      try {
        final response = await _apiClient.get('/notifications', token: token);
        if (response['success'] == true || response.containsKey('data')) {
          final list =
              response['data'] ??
              response['notifications'] ??
              response['notices'];
          if (list is List) {
            return list
                .whereType<Map<String, dynamic>>()
                .map((e) => AppNotificationModel.fromJson(e))
                .toList();
          }
        }
      } catch (e) {
        debugPrint('Fetch /notifications error: $e');
      }
    }

    return [];
  }

  Future<void> markAsRead(String id, String token) async {
    if (token.isEmpty || token.startsWith('mock-')) return;
    try {
      await _apiClient.post('/notifications/$id/read', token: token);
    } catch (e) {
      debugPrint('Mark notification read error: $e');
    }
  }

  Future<void> markAllAsRead(String token) async {
    if (token.isEmpty || token.startsWith('mock-')) return;
    try {
      await _apiClient.post('/notifications/read-all', token: token);
    } catch (e) {
      debugPrint('Mark all notifications read error: $e');
    }
  }

  Future<void> deleteNotification(String id, String token) async {
    if (token.isEmpty || token.startsWith('mock-')) return;
    try {
      await _apiClient.delete('/notifications/$id', token: token);
    } catch (e) {
      debugPrint('Delete notification error: $e');
    }
  }
}
