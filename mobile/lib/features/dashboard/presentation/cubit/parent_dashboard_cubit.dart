import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/features/dashboard/data/models/dashboard_models.dart';
import 'package:lms/features/dashboard/data/repositories/dashboard_repository.dart';

enum ParentDashboardStatus { initial, loading, success, failure }

class ParentDashboardState extends Equatable {
  const ParentDashboardState({
    this.status = ParentDashboardStatus.initial,
    this.data,
    this.error,
  });

  final ParentDashboardStatus status;
  final ParentDashboardData? data;
  final String? error;

  ParentDashboardState copyWith({
    ParentDashboardStatus? status,
    ParentDashboardData? data,
    String? error,
  }) {
    return ParentDashboardState(
      status: status ?? this.status,
      data: data ?? this.data,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, data, error];
}

class ParentDashboardCubit extends Cubit<ParentDashboardState> {
  ParentDashboardCubit({required DashboardRepository dashboardRepository})
      : _dashboardRepository = dashboardRepository,
        super(const ParentDashboardState());

  final DashboardRepository _dashboardRepository;

  Future<void> loadDashboard(String token) async {
    emit(state.copyWith(status: ParentDashboardStatus.loading));
    try {
      final data = await _dashboardRepository.getParentDashboard(token: token);
      emit(state.copyWith(status: ParentDashboardStatus.success, data: data));
    } catch (e) {
      emit(
        state.copyWith(
          status: ParentDashboardStatus.failure,
          error: e.toString(),
        ),
      );
    }
  }
}
