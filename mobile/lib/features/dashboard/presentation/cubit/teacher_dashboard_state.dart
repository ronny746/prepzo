part of 'teacher_dashboard_cubit.dart';

enum TeacherDashboardStatus { initial, loading, success, failure }

class TeacherDashboardState extends Equatable {
  const TeacherDashboardState({
    this.status = TeacherDashboardStatus.initial,
    this.data,
    this.errorMessage,
  });

  final TeacherDashboardStatus status;
  final TeacherDashboardData? data;
  final String? errorMessage;

  TeacherDashboardState copyWith({
    TeacherDashboardStatus? status,
    TeacherDashboardData? data,
    String? errorMessage,
  }) {
    return TeacherDashboardState(
      status: status ?? this.status,
      data: data ?? this.data,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, data, errorMessage];
}
