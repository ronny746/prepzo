class ProfileDetails {
  const ProfileDetails({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    required this.role,
    required this.userCode,
    required this.gender,
    required this.status,
    required this.instituteId,
    required this.branchId,
    required this.address,
    this.city = '',
    this.state = '',
    this.firstName,
    this.lastName,
    this.studentClass = '',
    this.section = '',
    this.rollNumber = '',
    this.session = '',
    this.targetExam = '',
    this.instituteName = '',
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String email;
  final String mobile;
  final String role;
  final String userCode;
  final String gender;
  final String status;
  final String instituteId;
  final String branchId;
  final String address;
  final String city;
  final String state;
  final String? firstName;
  final String? lastName;
  final String studentClass;
  final String section;
  final String rollNumber;
  final String session;
  final String targetExam;
  final String instituteName;
  final String? avatarUrl;

  factory ProfileDetails.fromJson(Map<String, dynamic> json) {
    final roleId = json['roleId'];
    final roleCode = roleId is Map<String, dynamic>
        ? roleId['code']?.toString()
        : json['role']?.toString();

    final firstName = json['firstName']?.toString();
    final lastName = json['lastName']?.toString();
    String? fullName;
    if (firstName != null || lastName != null) {
      fullName = [firstName, lastName]
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .join(' ');
    }

    final addressJson = json['address'];
    String addressStr = '';
    String cityStr = '';
    String stateStr = '';

    if (addressJson is Map<String, dynamic>) {
      cityStr = addressJson['city']?.toString() ?? '';
      stateStr = addressJson['state']?.toString() ?? '';
      addressStr = [
        addressJson['line1'],
        addressJson['city'],
        addressJson['state'],
        addressJson['country'],
        addressJson['pincode'],
      ].whereType<String>().where((item) => item.isNotEmpty).join(', ');
    } else if (addressJson != null) {
      addressStr = addressJson.toString();
    }

    final metadata = json['metadata'] is Map<String, dynamic>
        ? json['metadata'] as Map<String, dynamic>
        : <String, dynamic>{};

    if (cityStr.isEmpty) cityStr = metadata['city']?.toString() ?? json['city']?.toString() ?? '';
    if (stateStr.isEmpty) stateStr = metadata['state']?.toString() ?? json['state']?.toString() ?? '';

    final avatarUrlStr = json['profilePictureUrl']?.toString() ??
        json['profileImage']?.toString() ??
        json['avatarUrl']?.toString() ??
        json['avatar']?.toString() ??
        json['photo']?.toString() ??
        metadata['profilePictureUrl']?.toString() ??
        metadata['avatarUrl']?.toString() ??
        metadata['profileImage']?.toString();

    final mobileStr = json['mobile']?.toString() ?? json['phone']?.toString() ?? '';

    return ProfileDetails(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: fullName != null && fullName.isNotEmpty ? fullName : (json['name']?.toString() ?? 'User'),
      email: json['email']?.toString() ?? '',
      mobile: mobileStr,
      role: (roleCode ?? json['role']?.toString() ?? 'STUDENT').toString().toUpperCase(),
      userCode: json['userCode']?.toString() ?? json['rollNumber']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Active',
      instituteId: json['instituteId']?.toString() ?? '',
      branchId: json['branchId']?.toString() ?? '',
      address: addressStr.isNotEmpty ? addressStr : (metadata['address']?.toString() ?? ''),
      city: cityStr,
      state: stateStr,
      firstName: firstName,
      lastName: lastName,
      studentClass: metadata['studentClass']?.toString() ?? json['studentClass']?.toString() ?? metadata['class']?.toString() ?? json['class']?.toString() ?? '',
      section: metadata['section']?.toString() ?? json['section']?.toString() ?? '',
      rollNumber: json['rollNumber']?.toString() ?? metadata['rollNumber']?.toString() ?? '',
      session: metadata['session']?.toString() ?? json['session']?.toString() ?? '',
      targetExam: metadata['targetExam']?.toString() ?? json['targetExam']?.toString() ?? '',
      instituteName: json['instituteName']?.toString() ?? 'SKD Academy',
      avatarUrl: avatarUrlStr,
    );
  }

  ProfileDetails copyWith({
    String? id,
    String? name,
    String? email,
    String? mobile,
    String? role,
    String? userCode,
    String? gender,
    String? status,
    String? instituteId,
    String? branchId,
    String? address,
    String? city,
    String? state,
    String? firstName,
    String? lastName,
    String? studentClass,
    String? section,
    String? rollNumber,
    String? session,
    String? targetExam,
    String? instituteName,
    String? avatarUrl,
  }) {
    return ProfileDetails(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      role: role ?? this.role,
      userCode: userCode ?? this.userCode,
      gender: gender ?? this.gender,
      status: status ?? this.status,
      instituteId: instituteId ?? this.instituteId,
      branchId: branchId ?? this.branchId,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      studentClass: studentClass ?? this.studentClass,
      section: section ?? this.section,
      rollNumber: rollNumber ?? this.rollNumber,
      session: session ?? this.session,
      targetExam: targetExam ?? this.targetExam,
      instituteName: instituteName ?? this.instituteName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
