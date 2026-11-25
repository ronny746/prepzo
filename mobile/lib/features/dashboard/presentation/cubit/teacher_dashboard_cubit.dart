import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/network/api_exception.dart';
import 'package:lms/features/dashboard/data/models/dashboard_models.dart';
import 'package:lms/features/dashboard/data/repositories/dashboard_repository.dart';

part 'teacher_dashboard_state.dart';

class TeacherDashboardCubit extends Cubit<TeacherDashboardState> {
  TeacherDashboardCubit({required DashboardRepository dashboardRepository})
    : _dashboardRepository = dashboardRepository,
      super(const TeacherDashboardState());

  final DashboardRepository _dashboardRepository;

  // This method loads all teacher dashboard sections from the backend.
  // Each section uses the APIs that already exist in the collection.
  Future<void> loadDashboard(String token) async {
    emit(
      state.copyWith(
        status: TeacherDashboardStatus.loading,
        errorMessage: null,
      ),
    );

    try {
      final data = await _dashboardRepository.getTeacherDashboard(token: token);
      emit(
        state.copyWith(
          status: TeacherDashboardStatus.success,
          data: data,
          errorMessage: null,
        ),
      );
    } on ApiException catch (error) {
      emit(
        state.copyWith(
          status: TeacherDashboardStatus.failure,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: TeacherDashboardStatus.failure,
          errorMessage: 'Unable to load teacher dashboard.',
        ),
      );
    }
  }
}
