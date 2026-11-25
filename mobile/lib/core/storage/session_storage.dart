import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SessionStorage {
  SessionStorage(this._preferences);

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userKey = 'user_json';
  static const _recentInstituteIdsKey = 'recent_institute_ids';

  final SharedPreferences _preferences;

  static Future<SessionStorage> create() async {
    final preferences = await SharedPreferences.getInstance();
    return SessionStorage(preferences);
  }

  String? getAccessToken() => _preferences.getString(_accessTokenKey);

  String? getRefreshToken() => _preferences.getString(_refreshTokenKey);

  Map<String, dynamic>? getStoredUser() {
    final raw = _preferences.getString(_userKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return jsonDecode(raw) as Map<String, dynamic>;
  }

  List<String> getRecentInstituteIds() {
    return _preferences.getStringList(_recentInstituteIdsKey) ?? <String>[];
  }

  Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
    Map<String, dynamic>? user,
  }) async {
    await _preferences.setString(_accessTokenKey, accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _preferences.setString(_refreshTokenKey, refreshToken);
    }
    if (user != null) {
      await _preferences.setString(_userKey, jsonEncode(user));
    }
  }

  Future<void> saveRecentInstituteId(String instituteId) async {
    final current = getRecentInstituteIds();
    final updated = <String>[
      instituteId,
      ...current.where((value) => value != instituteId),
    ].take(5).toList();

    await _preferences.setStringList(_recentInstituteIdsKey, updated);
  }

  Future<void> clearSession() async {
    await _preferences.remove(_accessTokenKey);
    await _preferences.remove(_refreshTokenKey);
    await _preferences.remove(_userKey);
  }
}
