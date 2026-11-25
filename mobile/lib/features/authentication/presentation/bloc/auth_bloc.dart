import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/services/deep_link_service.dart';
import 'package:lms/core/network/api_exception.dart';
import 'package:lms/features/authentication/data/models/auth_session.dart';
import 'package:lms/features/authentication/data/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required AuthRepository authRepository,
    Future<void> Function(String? accessToken)? onSignOut,
  }) : _authRepository = authRepository,
       _onSignOut = onSignOut,
       super(
         AuthState(recentInstituteIds: authRepository.getRecentInstituteIds()),
       ) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthOtpRequested>(_onOtpRequested);
    on<AuthOtpVerifyRequested>(_onOtpVerifyRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthSessionExpired>(_onSessionExpired);
  }

  final AuthRepository _authRepository;
  final Future<void> Function(String? accessToken)? _onSignOut;
  // Several requests can fail with 401 at once; sign out only once.
  bool _signingOut = false;

  // Runs before the saved session is cleared, so the old token is still
  // available (e.g. to unregister this phone for push notifications).
  Future<void> _beforeSignOut() async {
    try {
      await _onSignOut?.call(state.session?.accessToken);
    } catch (_) {
      // Never block signing out.
    }
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

  Future<void> _onSessionExpired(
    AuthSessionExpired event,
    Emitter<AuthState> emit,
  ) async {
    // Only a signed-in app needs this; startup handles its own 401, and
    // several failing requests at once must sign out just once.
    if (state.status != AuthStatus.authenticated || _signingOut) return;
    _signingOut = true;
    try {
      await _beforeSignOut();
      DeepLinkService.markNotReady();
      await _authRepository.logout();
    } finally {
      _signingOut = false;
    }
    emit(
      state.copyWith(
        status: AuthStatus.unauthenticated,
        clearSession: true,
        resetOtp: true,
        errorMessage: event.message,
        recentInstituteIds: _authRepository.getRecentInstituteIds(),
      ),
    );
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _beforeSignOut();
    await _authRepository.logout();
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
