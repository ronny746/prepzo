import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/network/api_exception.dart';
import 'package:lms/features/profile/data/models/profile_details.dart';
import 'package:lms/features/profile/data/repositories/profile_repository.dart';

part 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({required ProfileRepository profileRepository})
    : _profileRepository = profileRepository,
      super(const ProfileState());

  final ProfileRepository _profileRepository;

  Future<void> loadProfile(String token) async {
    emit(
      state.copyWith(
        status: ProfileStatus.loading,
        errorMessage: null,
        successMessage: null,
      ),
    );

    try {
      final profile = await _profileRepository.getProfile(token);
      emit(
        state.copyWith(
          status: ProfileStatus.success,
          profile: profile,
          errorMessage: null,
        ),
      );
    } on ApiException catch (error) {
      emit(
        state.copyWith(
          status: ProfileStatus.failure,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: ProfileStatus.failure,
          errorMessage: 'Unable to load profile right now.',
        ),
      );
    }
  }

  Future<void> updateProfile({
    required String token,
    required String firstName,
    required String lastName,
    required String email,
    required String mobile,
    String? gender,
    String? studentClass,
    String? city,
    String? stateName,
    String? address,
    String? avatarUrl,
  }) async {
    emit(
      state.copyWith(
        status: ProfileStatus.updating,
        errorMessage: null,
        successMessage: null,
      ),
    );

    try {
      final updatedProfile = await _profileRepository.updateProfile(
        token: token,
        firstName: firstName,
        lastName: lastName,
        email: email,
        mobile: mobile,
        gender: gender,
        studentClass: studentClass,
        city: city,
        state: stateName,
        address: address,
        avatarUrl: avatarUrl,
      );

      emit(
        state.copyWith(
          status: ProfileStatus.success,
          profile: updatedProfile,
          successMessage: 'Profile updated successfully!',
          errorMessage: null,
        ),
      );
    } on ApiException catch (error) {
      // Surface the server message; never fake a local "success".
      emit(
        state.copyWith(
          status: ProfileStatus.failure,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: ProfileStatus.failure,
          // null: the screen shows the localized profileUpdateFailed text.
          errorMessage: null,
        ),
      );
    }
  }

  Future<void> setupParent({
    required String token,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
  }) async {
    emit(
      state.copyWith(
        status: ProfileStatus.updating,
        errorMessage: null,
        successMessage: null,
      ),
    );

    try {
      await _profileRepository.setupParent(
        token: token,
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
      );
      emit(
        state.copyWith(
          status: ProfileStatus.success,
          successMessage: 'Parent setup successful!',
          errorMessage: null,
        ),
      );
    } on ApiException catch (error) {
      emit(
        state.copyWith(
          status: ProfileStatus.failure,
          errorMessage: error.message,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ProfileStatus.failure,
          errorMessage: 'Unable to setup parent right now.',
        ),
      );
    }
  }
}
