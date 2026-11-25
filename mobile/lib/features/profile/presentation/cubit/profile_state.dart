part of 'profile_cubit.dart';

enum ProfileStatus { initial, loading, success, failure, updating }

class ProfileState extends Equatable {
  const ProfileState({
    this.status = ProfileStatus.initial,
    this.profile,
    this.errorMessage,
    this.successMessage,
  });

  final ProfileStatus status;
  final ProfileDetails? profile;
  final String? errorMessage;
  final String? successMessage;

  ProfileState copyWith({
    ProfileStatus? status,
    ProfileDetails? profile,
    String? errorMessage,
    String? successMessage,
  }) {
    return ProfileState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }

  @override
  List<Object?> get props => [status, profile, errorMessage, successMessage];
}
