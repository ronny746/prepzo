import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/features/academics/presentation/cubit/academics_cubit.dart';
import 'package:lms/features/academics/data/repositories/academics_repository.dart';

class ParentAcademicsCubit extends Cubit<AcademicsState> {
  ParentAcademicsCubit({required AcademicsRepository academicsRepository})
    : _academicsRepository = academicsRepository,
      super(const AcademicsState());

  final AcademicsRepository _academicsRepository;

  Future<void> loadTasks(String token) async {
    emit(state.copyWith(status: AcademicsStatus.loading));
    try {
      final tasks = await _academicsRepository.getParentTasks(token);
      emit(state.copyWith(status: AcademicsStatus.success, tasks: tasks));
    } catch (e) {
      emit(
        state.copyWith(status: AcademicsStatus.failure, error: e.toString()),
      );
    }
  }
}
