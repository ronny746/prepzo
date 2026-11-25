import 'package:lms/core/network/api_client.dart';
import 'package:lms/features/authentication/data/models/auth_session.dart';

/// Push notifications and analytics placeholder.
///
/// Why: Firebase was removed because no google-services.json exists yet for
/// the new package id com.app.prepzo. This keeps the same public API so the
/// rest of the app is unchanged; every method is a no-op. Restore the original
/// implementation from `.firebase_backup/` once Firebase is configured.
class PushNotificationService {
  PushNotificationService(this._apiClient);

  // ignore: unused_field
  final ApiClient _apiClient;

  /// No-op until Firebase is restored.
  Future<void> initialize() async {}

  /// No-op until Firebase is restored (no device token is registered).
  Future<void> startForSession(AuthSession session) async {}

  /// No-op until Firebase is restored.
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {}

  /// No-op until Firebase is restored.
  Future<void> dispose() async {}
}
