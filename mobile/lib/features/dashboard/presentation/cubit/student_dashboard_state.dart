part of 'student_dashboard_cubit.dart';

enum StudentDashboardStatus { initial, loading, success, failure }

class StudentDashboardState extends Equatable {
  const StudentDashboardState({
    this.status = StudentDashboardStatus.initial,
    this.data,
    this.banners = const [],
    this.access = const StudentAccess(),
    this.errorMessage,
  });

  final StudentDashboardStatus status;
  final StudentDashboardData? data;
  final List<BannerModel> banners;
  final StudentAccess access;
  final String? errorMessage;

  StudentDashboardState copyWith({
    StudentDashboardStatus? status,
    StudentDashboardData? data,
    List<BannerModel>? banners,
    StudentAccess? access,
    String? errorMessage,
  }) {
    return StudentDashboardState(
      status: status ?? this.status,
      data: data ?? this.data,
      banners: banners ?? this.banners,
      access: access ?? this.access,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, data, banners, access, errorMessage];
}
