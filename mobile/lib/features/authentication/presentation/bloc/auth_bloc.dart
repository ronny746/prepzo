import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/constants/app_strings.dart';
import 'package:lms/core/network/api_exception.dart';
import 'package:lms/core/services/deep_link_service.dart';
import 'package:lms/features/authentication/data/models/auth_session.dart';
import 'package:lms/features/authentication/data/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(
        AuthState(recentInstituteIds: authRepository.getRecentInstituteIds()),
      ) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthOtpRequested>(_onOtpRequested);
    on<AuthOtpVerifyRequested>(_onOtpVerifyRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthSessionExpired>(_onSessionExpired);
    _sessionExpiredSub = authRepository.sessionExpired.listen(
      (_) => add(const AuthSessionExpired()),
    );
  }

  final AuthRepository _authRepository;
  late final StreamSubscription<void> _sessionExpiredSub;

  @override
  Future<void> close() {
    _sessionExpiredSub.cancel();
    return super.close();
  }

  Future<void> _onSessionExpired(
    AuthSessionExpired event,
    Emitter<AuthState> emit,
  ) async {
    // Several in-flight requests can fail together; only react once.
    if (state.status != AuthStatus.authenticated) return;
    DeepLinkService.markNotReady();
    await _authRepository.logout();
    emit(
      state.copyWith(
        status: AuthStatus.unauthenticated,
        clearSession: true,
        resetOtp: true,
        errorMessage: AppStrings.sessionExpired,
      ),
    );
  }

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    emit(
      state.copyWith(
        status: AuthStatus.checking,
        errorMessage: null,
        recentInstituteIds: _authRepository.getRecentInstituteIds(),
      ),
    );

    try {
      final session = await _authRepository.refreshStoredSession();
      if (session == null) {
        emit(
          state.copyWith(
            status: AuthStatus.unauthenticated,
            clearSession: true,
            resetOtp: true,
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          session: session,
          resetOtp: true,
          recentInstituteIds: _authRepository.getRecentInstituteIds(),
        ),
      );
    } on ApiException catch (error) {
      DeepLinkService.markNotReady();
      await _authRepository.logout();
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          clearSession: true,
          resetOtp: true,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      DeepLinkService.markNotReady();
      await _authRepository.logout();
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          clearSession: true,
          resetOtp: true,
        ),
      );
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));

    try {
      final session = await _authRepository.login(
        email: event.email,
        password: event.password,
        instituteId: event.instituteId,
        role: event.role,
      );

      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          session: session,
          resetOtp: true,
          recentInstituteIds: _authRepository.getRecentInstituteIds(),
        ),
      );
    } on ApiException catch (error) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: error.message,
          resetOtp: true,
          recentInstituteIds: _authRepository.getRecentInstituteIds(),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Unable to login right now. Please try again.',
          resetOtp: true,
          recentInstituteIds: _authRepository.getRecentInstituteIds(),
        ),
      );
    }
  }

  Future<void> _onOtpRequested(
    AuthOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(isSendingOtp: true, errorMessage: null));

    try {
      final message = await _authRepository.requestMobileOtp(
        event.mobileNumber,
        role: event.role,
      );
      emit(
        state.copyWith(isSendingOtp: false, otpSent: true, otpMessage: message),
      );
    } on ApiException catch (error) {
      emit(state.copyWith(isSendingOtp: false, errorMessage: error.message));
    } catch (e) {
      emit(
        state.copyWith(
          isSendingOtp: false,
          errorMessage: 'Failed to send OTP. Please try again.',
        ),
      );
    }
  }

  Future<void> _onOtpVerifyRequested(
    AuthOtpVerifyRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));

    try {
      final session = await _authRepository.verifyMobileOtp(
        phone: event.phone,
        otp: event.otp,
        role: event.role,
      );

      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          session: session,
          resetOtp: true,
          recentInstituteIds: _authRepository.getRecentInstituteIds(),
        ),
      );
    } on ApiException catch (error) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: error.message,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Invalid OTP or login credentials.',
        ),
      );
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      DeepLinkService.markNotReady();
      await _authRepository.logout();
    } catch (_) {
      // Ignore: state below must still flip to unauthenticated so the user can
      // always leave a broken session.
    }
    emit(
      state.copyWith(
        status: AuthStatus.unauthenticated,
        clearSession: true,
        resetOtp: true,
        recentInstituteIds: _authRepository.getRecentInstituteIds(),
      ),
    );
  }
}
