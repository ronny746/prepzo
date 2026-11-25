import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/features/academics/data/models/academics_models.dart';
import 'package:lms/features/academics/data/repositories/academics_repository.dart';

enum AcademicsStatus { initial, loading, success, failure }

class AcademicsState extends Equatable {
  const AcademicsState({
    this.status = AcademicsStatus.initial,
    this.tasks = const [],
    this.error,
    this.isSubmitting = false,
  });

  final AcademicsStatus status;
  final List<AcademicTask> tasks;
  final String? error;
  final bool isSubmitting;

  AcademicsState copyWith({
    AcademicsStatus? status,
    List<AcademicTask>? tasks,
    String? error,
    bool? isSubmitting,
  }) {
    return AcademicsState(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      error: error ?? this.error,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  @override
  List<Object?> get props => [status, tasks, error, isSubmitting];
}

class AcademicsCubit extends Cubit<AcademicsState> {
  AcademicsCubit({required AcademicsRepository academicsRepository})
    : _academicsRepository = academicsRepository,
      super(const AcademicsState());

  final AcademicsRepository _academicsRepository;

  Future<void> loadTasks(String token) async {
    emit(state.copyWith(status: AcademicsStatus.loading));
    try {
      final tasks = await _academicsRepository.getStudentTasks(token);
      emit(state.copyWith(status: AcademicsStatus.success, tasks: tasks));
    } catch (e) {
      emit(
        state.copyWith(status: AcademicsStatus.failure, error: e.toString()),
      );
    }
  }

  Future<void> submitTask({
    required String token,
    required String taskId,
    required String taskType,
    required String content,
    List<String> attachments = const [],
  }) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      await _academicsRepository.submitTask(
        token: token,
        taskId: taskId,
        taskType: taskType,
        content: content,
        attachments: attachments,
      );
      // Reload after submit
      await loadTasks(token);
    } catch (e) {
      emit(
        state.copyWith(
          status: AcademicsStatus.failure,
          error: e.toString(),
          isSubmitting: false, // Stop loading but let UI handle error
        ),
      );
      rethrow;
    }
  }
}
