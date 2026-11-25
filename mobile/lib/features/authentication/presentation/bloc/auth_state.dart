part of 'auth_bloc.dart';

enum AuthStatus { initial, checking, unauthenticated, loading, authenticated }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.session,
    this.errorMessage,
    this.recentInstituteIds = const <String>[],
    this.isSendingOtp = false,
    this.otpSent = false,
    this.otpMessage,
  });

  final AuthStatus status;
  final AuthSession? session;
  final String? errorMessage;
  final List<String> recentInstituteIds;
  final bool isSendingOtp;
  final bool otpSent;
  final String? otpMessage;

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    String? errorMessage,
    List<String>? recentInstituteIds,
    bool clearSession = false,
    bool? isSendingOtp,
    bool? otpSent,
    String? otpMessage,
    bool resetOtp = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: clearSession ? null : (session ?? this.session),
      errorMessage: errorMessage,
      recentInstituteIds: recentInstituteIds ?? this.recentInstituteIds,
      isSendingOtp: isSendingOtp ?? this.isSendingOtp,
      otpSent: resetOtp ? false : (otpSent ?? this.otpSent),
      otpMessage: resetOtp ? null : (otpMessage ?? this.otpMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    session,
    errorMessage,
    recentInstituteIds,
    isSendingOtp,
    otpSent,
    otpMessage,
  ];
}
