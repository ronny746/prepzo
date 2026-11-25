import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/network/api_exception.dart';
import 'package:lms/features/dashboard/data/models/dashboard_models.dart';
import 'package:lms/features/dashboard/data/models/banner_model.dart';
import 'package:lms/features/dashboard/data/repositories/dashboard_repository.dart';

part 'student_dashboard_state.dart';

class StudentDashboardCubit extends Cubit<StudentDashboardState> {
  StudentDashboardCubit({required DashboardRepository dashboardRepository})
    : _dashboardRepository = dashboardRepository,
      super(const StudentDashboardState());

  final DashboardRepository _dashboardRepository;

  // This method loads all student dashboard sections from the backend.
  // Even if some APIs fail, the repository keeps the screen usable.
  Future<void> loadDashboard(String token) async {
    emit(
      state.copyWith(
        status: StudentDashboardStatus.loading,
        errorMessage: null,
      ),
    );

    try {
      final results = await Future.wait([
        _dashboardRepository.getStudentDashboard(token: token),
        _dashboardRepository.getBanners(),
        _dashboardRepository.getAccess(token),
      ]);

      final data = results[0] as StudentDashboardData;
      final banners = results[1] as List<BannerModel>;
      final access = results[2] as StudentAccess;

      emit(
        state.copyWith(
          status: StudentDashboardStatus.success,
          data: data,
          banners: banners,
          access: access,
          errorMessage: null,
        ),
      );
    } on ApiException catch (error) {
      emit(
        state.copyWith(
          status: StudentDashboardStatus.failure,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: StudentDashboardStatus.failure,
          errorMessage: 'Unable to load student dashboard.',
        ),
      );
    }
  }
}
