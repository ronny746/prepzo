import 'package:flutter/foundation.dart';
import 'package:lms/core/network/api_client.dart';
import 'package:lms/core/network/api_exception.dart';
import 'package:lms/core/storage/session_storage.dart';
import 'package:lms/features/authentication/data/models/auth_session.dart';

class AuthRepository {
  AuthRepository({
    required ApiClient apiClient,
    required SessionStorage sessionStorage,
  }) : _apiClient = apiClient,
       _sessionStorage = sessionStorage;

  final ApiClient _apiClient;
  final SessionStorage _sessionStorage;

  List<String> getRecentInstituteIds() {
    return _sessionStorage.getRecentInstituteIds();
  }

  Future<AuthSession?> getStoredSession() async {
    final accessToken = _sessionStorage.getAccessToken();
    final userJson = _sessionStorage.getStoredUser();

    if (accessToken == null || accessToken.isEmpty || userJson == null) {
      return null;
    }

    // Why: older builds had a demo login that stored a fake `mock-` token.
    // Purge it on upgrade so those devices go back to the real login screen.
    if (accessToken.startsWith('mock-')) {
      await _sessionStorage.clearSession();
      return null;
    }

    return AuthSession(
      accessToken: accessToken,
      refreshToken: _sessionStorage.getRefreshToken() ?? '',
      user: UserIdentity.fromJson(userJson),
    );
  }

  Future<AuthSession> login({
    required String email,
    required String password,
    required String instituteId,
    String? role,
  }) async {
    final requestData = <String, dynamic>{'email': email, 'password': password};
    if (role != null && role.trim().isNotEmpty) {
      requestData['role'] = role.trim().toLowerCase();
    }

    if (instituteId.trim().isNotEmpty) {
      requestData['instituteId'] = instituteId;
    }

    final response = await _apiClient.post('/auth/login', data: requestData);

    final session = AuthSession.fromJson(response);
    if (session.accessToken.isEmpty) {
      throw const ApiException('Login succeeded but token was missing');
    }

    // If the login response already contains user details, use them instead of calling /me
    if (session.user.id.isNotEmpty && session.user.name != 'User') {
      await _sessionStorage.saveSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        user: session.user.toJson(),
      );
      await _sessionStorage.saveRecentInstituteId(instituteId);
      return session;
    }

    // Fallback to /me if user data is missing in login response
    try {
      final me = await getMe(session.accessToken);
      final finalSession = AuthSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        user: me,
      );

      await _sessionStorage.saveSession(
        accessToken: finalSession.accessToken,
        refreshToken: finalSession.refreshToken,
        user: finalSession.user.toJson(),
      );
      await _sessionStorage.saveRecentInstituteId(instituteId);

      return finalSession;
    } catch (e) {
      // Even if /me fails, if we have a token, we might want to proceed if we have basic user info
      if (session.accessToken.isNotEmpty) {
        await _sessionStorage.saveSession(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
          user: session.user.toJson(),
        );
        return session;
      }
      rethrow;
    }
  }

  Future<UserIdentity> getMe(String token) async {
    // /users/me is the full profile; there is no /api/v1/me (it was a 404, so
    // the saved session was never re-checked on start-up).
    final response = await _apiClient.get('/users/me', token: token);
    final data = response['data'];
    final user = response['user'];

    if (data is Map<String, dynamic>) {
      if (data.containsKey('user') && data['user'] is Map<String, dynamic>) {
        return UserIdentity.fromJson(data['user'] as Map<String, dynamic>);
      }
      return UserIdentity.fromJson(data);
    }

    if (user is Map<String, dynamic>) {
      return UserIdentity.fromJson(user);
    }

    return UserIdentity.fromJson(response);
  }

  Future<AuthSession?> refreshStoredSession() async {
    final stored = await getStoredSession();
    if (stored == null) {
      return null;
    }

    try {
      final me = await getMe(stored.accessToken);
      // Swap in a fresh 30-day token so an active student is never signed
      // out; keep the old one if the refresh call fails.
      final freshToken = await _refreshToken(stored.accessToken);
      final session = AuthSession(
        accessToken: freshToken ?? stored.accessToken,
        refreshToken: stored.refreshToken,
        user: me,
      );

      await _sessionStorage.saveSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        user: session.user.toJson(),
      );

      return session;
    } on ApiException catch (e) {
      // 401: token expired or the account signed in elsewhere. The caller
      // signs out; carrying on would leave every screen failing.
      if (e.statusCode == 401) rethrow;
      debugPrint('Warning: Session refresh /me failed: $e');
      return stored;
    } catch (e) {
      // Offline or server trouble: keep the stored session.
      debugPrint('Warning: Session refresh /me failed: $e');
      return stored;
    }
  }

  Future<String?> _refreshToken(String token) async {
    try {
      final response = await _apiClient.post('/auth/refresh', token: token);
      final data = response['data'];
      final fresh = data is Map ? data['token']?.toString() : null;
      return fresh != null && fresh.isNotEmpty ? fresh : null;
    } catch (e) {
      // Older servers have no /auth/refresh; the current token still works.
      debugPrint('Token refresh skipped: $e');
      return null;
    }
  }

  Future<String> requestMobileOtp(
    String mobileNumber, {
    String role = 'teacher',
  }) async {
    final cleanPhone = mobileNumber.replaceAll(RegExp(r'\D'), '');
    final response = await _apiClient.post(
      '/auth/request-otp',
      data: {'mobileNumber': cleanPhone, 'role': role.toLowerCase()},
    );
    final message = response['message']?.toString() ?? 'OTP sent successfully';
    return message;
  }

  Future<AuthSession> verifyMobileOtp({
    required String phone,
    required String otp,
    String role = 'student',
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final response = await _apiClient.post(
      '/auth/verify-otp',
      data: {
        'phone': cleanPhone,
        'otp': otp.trim(),
        'role': role.toLowerCase(),
      },
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    final token = data['token']?.toString() ?? '';
    final userData = data['user'] as Map<String, dynamic>? ?? {};

    final session = AuthSession(
      accessToken: token,
      refreshToken: '',
      user: UserIdentity.fromJson(userData),
    );

    if (session.accessToken.isNotEmpty) {
      await _sessionStorage.saveSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        user: session.user.toJson(),
      );
    }

    return session;
  }

  Future<AuthSession> updateUserProfile({
    required String token,
    required String firstName,
    String? lastName,
    required String email,
    String? studentClass,
    String? state,
    String? city,
  }) async {
    final response = await _apiClient.put(
      '/users/me',
      token: token,
      data: {
        'firstName': firstName.trim(),
        'lastName': (lastName ?? '').trim(),
        'email': email.trim(),
        'metadata': {
          'studentClass': (studentClass ?? '').trim(),
          'state': (state ?? '').trim(),
          'city': (city ?? '').trim(),
          'isProfileIncomplete': false,
        },
      },
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    final userData = data['user'] as Map<String, dynamic>? ?? data;

    final updatedUser = UserIdentity.fromJson(userData);
    final session = AuthSession(
      accessToken: token,
      refreshToken: _sessionStorage.getRefreshToken() ?? '',
      user: updatedUser,
    );

    await _sessionStorage.saveSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      user: updatedUser.toJson(),
    );

    return session;
  }

  Future<void> changePassword({
    required String token,
    required String oldPassword,
    required String newPassword,
  }) async {
    await _apiClient.post(
      '/auth/change-password',
      token: token,
      data: {'oldPassword': oldPassword, 'newPassword': newPassword},
    );
  }

  Future<void> logout() async {
    // Local-only: logout must never depend on the server being reachable or the
    // token still being valid.
    await _sessionStorage.clearSession();
  }
}
