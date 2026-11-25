part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthStarted extends AuthEvent {
  const AuthStarted();
}

class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({
    required this.email,
    required this.password,
    this.instituteId = '',
    this.role,
  });

  final String email;
  final String password;
  final String instituteId;
  final String? role;

  @override
  List<Object?> get props => [email, password, instituteId, role];
}

class AuthOtpRequested extends AuthEvent {
  const AuthOtpRequested({required this.mobileNumber, this.role = 'teacher'});

  final String mobileNumber;
  final String role;

  @override
  List<Object?> get props => [mobileNumber, role];
}

class AuthOtpVerifyRequested extends AuthEvent {
  const AuthOtpVerifyRequested({
    required this.phone,
    required this.otp,
    this.role = 'student',
  });

  final String phone;
  final String otp;
  final String role;

  @override
  List<Object?> get props => [phone, otp, role];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Raised when the server rejects our token (session ended / other device).
class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired();
}
