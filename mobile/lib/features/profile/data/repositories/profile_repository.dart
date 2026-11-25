import 'package:dio/dio.dart';
import 'package:lms/core/network/api_client.dart';
import 'package:lms/features/profile/data/models/profile_details.dart';

class ProfileRepository {
  ProfileRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<ProfileDetails> getProfile(String token) async {
    final response = await _apiClient.get('/users/me', token: token);
    final data = response['data'];

    if (data is Map<String, dynamic>) {
      return ProfileDetails.fromJson(data);
    }

    return ProfileDetails.fromJson(response);
  }

  /// Uploads an avatar and returns its URL, or null on any failure so the
  /// profile fields can still be saved; the caller warns about the avatar.
  Future<String?> uploadImage({
    required String token,
    required String filePath,
  }) async {
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
    } catch (_) {
      return null;
    }
  }

  Future<ProfileDetails> updateProfile({
    required String token,
    required String firstName,
    required String lastName,
    required String email,
    required String mobile,
    String? gender,
    String? studentClass,
    String? city,
    String? state,
    String? address,
    String? avatarUrl,
  }) async {
    final response = await _apiClient.put(
      '/users/me',
      token: token,
      data: {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        // Backend rejects empty email; omit the key when blank.
        if (email.trim().isNotEmpty) 'email': email.trim(),
        'mobile': mobile.trim(),
        'phone': mobile.trim(),
        'gender': (gender ?? '').trim(),
        'profilePictureUrl': (avatarUrl ?? '').trim(),
        'avatarUrl': (avatarUrl ?? '').trim(),
        'profileImage': (avatarUrl ?? '').trim(),
        'city': (city ?? '').trim(),
        'state': (state ?? '').trim(),
        'address': {
          'line1': (address ?? '').trim(),
          'city': (city ?? '').trim(),
          'state': (state ?? '').trim(),
        },
        'metadata': {
          'gender': (gender ?? '').trim(),
          'studentClass': (studentClass ?? '').trim(),
          'class': (studentClass ?? '').trim(),
          'city': (city ?? '').trim(),
          'state': (state ?? '').trim(),
          'address': (address ?? '').trim(),
          if (email.trim().isNotEmpty) 'email': email.trim(),
          'mobile': mobile.trim(),
          'phone': mobile.trim(),
          'profilePictureUrl': (avatarUrl ?? '').trim(),
          'avatarUrl': (avatarUrl ?? '').trim(),
          'profileImage': (avatarUrl ?? '').trim(),
          'isProfileIncomplete': false,
        },
      },
    );

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return ProfileDetails.fromJson(data);
    }

    return ProfileDetails.fromJson(response);
  }

  Future<void> setupParent({
    required String token,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
  }) async {
    await _apiClient.post(
      '/users/setup-parent',
      token: token,
      data: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
      },
    );
  }
}
