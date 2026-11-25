import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/features/courses/data/models/batch_model.dart';
import 'package:lms/features/courses/data/models/course_model.dart';
import 'package:lms/features/courses/data/repositories/courses_repository.dart';
import 'package:lms/features/courses/presentation/cubit/courses_state.dart';

class CoursesCubit extends Cubit<CoursesState> {
  final CoursesRepository _repository;

  CoursesCubit({CoursesRepository? repository})
      : _repository = repository ?? CoursesRepository(),
        super(const CoursesState());

  Future<void> loadCoursesAndBatches(String token) async {
    emit(state.copyWith(status: CoursesStatus.loading));
    try {
      final results = await Future.wait([
        _repository.getCourses(token),
        if (token.isNotEmpty) _repository.getMyBatches(token) else Future.value([]),
      ]);

      emit(state.copyWith(
        status: CoursesStatus.success,
        courses: results[0] as List<CourseModel>,
        myBatches: results[1] as List<BatchModel>,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CoursesStatus.failure,
        error: e.toString(),
      ));
    }
  }

  Future<void> loadCourseDetail(String id, String token) async {
    emit(state.copyWith(status: CoursesStatus.loading));
    try {
      final course = await _repository.getCourseById(token: token, id: id);
      emit(state.copyWith(
        status: CoursesStatus.success,
        selectedCourse: course,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CoursesStatus.failure,
        error: e.toString(),
      ));
    }
  }

  Future<bool> enrollInCourse(String courseId, String token) async {
    emit(state.copyWith(isEnrolling: true));
    try {
      await _repository.enrollCourse(token: token, courseId: courseId);
      final updatedBatches = await _repository.getMyBatches(token);
      emit(state.copyWith(
        isEnrolling: false,
        myBatches: updatedBatches,
        enrollSuccessMessage: 'Enrollment successful!',
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(
        isEnrolling: false,
        error: e.toString(),
      ));
      return false;
    }
  }

  Future<Map<String, dynamic>?> initiateCoursePayment(String courseId, String token) async {
    emit(state.copyWith(isEnrolling: true));
    try {
      final res = await _repository.initiateCoursePayment(token: token, courseId: courseId);
      emit(state.copyWith(isEnrolling: false));
      return res;
    } catch (e) {
      emit(state.copyWith(
        isEnrolling: false,
        error: e.toString(),
      ));
      return null;
    }
  }
}
