class UserIdentity {
  const UserIdentity({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.firstName,
    this.lastName,
    this.metadata,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String? firstName;
  final String? lastName;
  final Map<String, dynamic>? metadata;

  bool get isProfileIncomplete {
    if (firstName == 'Student') return true;
    if (email.contains('@skd.com')) return true;
    if (metadata != null && metadata!['isProfileIncomplete'] == true)
      return true;
    return false;
  }

  factory UserIdentity.fromJson(Map<String, dynamic> json) {
    final roleId = json['roleId'];
    final roleCode = roleId is Map<String, dynamic>
        ? roleId['code']?.toString()
        : null;

    final firstName = json['firstName']?.toString();
    final lastName = json['lastName']?.toString();
    String? fullName;
    if (firstName != null || lastName != null) {
      fullName = [
        firstName,
        lastName,
      ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
    }

    final metadataJson = json['metadata'] is Map<String, dynamic>
        ? json['metadata'] as Map<String, dynamic>
        : null;

    return UserIdentity(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name:
          fullName ??
          json['name']?.toString() ??
          json['fullName']?.toString() ??
          json['username']?.toString() ??
          'User',
      email: json['email']?.toString() ?? '',
      role:
          roleCode?.toUpperCase() ??
          json['role']?.toString().toUpperCase() ??
          'STUDENT',
      firstName: firstName,
      lastName: lastName,
      metadata: metadataJson,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'firstName': firstName,
      'lastName': lastName,
      'metadata': metadata,
    };
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final UserIdentity user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    final message = json['message'] is Map<String, dynamic>
        ? json['message'] as Map<String, dynamic>
        : <String, dynamic>{};

    final userJson = _extractUserJson(data, json, message);

    String? token =
        data['token']?.toString() ??
        message['accessToken']?.toString() ??
        data['accessToken']?.toString() ??
        data['access_token']?.toString() ??
        json['token']?.toString() ??
        message['token']?.toString();

    return AuthSession(
      accessToken: token ?? '',
      refreshToken:
          data['refreshToken']?.toString() ??
          message['refreshToken']?.toString() ??
          data['refresh_token']?.toString() ??
          '',
      user: UserIdentity.fromJson(userJson),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'user': user.toJson(),
    };
  }

  static Map<String, dynamic> _extractUserJson(
    Map<String, dynamic> data,
    Map<String, dynamic> root,
    Map<String, dynamic> message,
  ) {
    if (data.containsKey('user') && data['user'] is Map<String, dynamic>) {
      return data['user'] as Map<String, dynamic>;
    }

    if (root.containsKey('user') && root['user'] is Map<String, dynamic>) {
      return root['user'] as Map<String, dynamic>;
    }

    if (message.containsKey('user') &&
        message['user'] is Map<String, dynamic>) {
      return message['user'] as Map<String, dynamic>;
    }

    return data;
  }
}
