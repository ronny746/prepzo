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
        if (token.isNotEmpty)
          _repository.getMyBatches(token)
        else
          Future.value([]),
      ]);

      emit(
        state.copyWith(
          status: CoursesStatus.success,
          courses: results[0] as List<CourseModel>,
          myBatches: results[1] as List<BatchModel>,
          myBatchesLoaded: token.isNotEmpty,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: CoursesStatus.failure, error: e.toString()));
    }
  }

  /// Id of the most recent loadCourseDetail request. The cubit is global, so
  /// overlapping loads for different courses must not overwrite each other.
  String? _latestCourseId;

  /// Loads one course plus the student's batches (so enrollment state is
  /// known before the Enroll button is shown). A course failure clears the
  /// selected course; a batches failure keeps the course but leaves
  /// myBatchesLoaded false so the UI won't offer Enroll.
  Future<void> loadCourseDetail(String id, String token) async {
    _latestCourseId = id;
    // Keep the course on screen when reloading the same id (e.g. after a
    // purchase) to avoid a spinner flash; clear it for a different id.
    final sameCourse = state.selectedCourse?.id == id;
    emit(
      state.copyWith(
        status: sameCourse ? null : CoursesStatus.loading,
        clearSelectedCourse: !sameCourse,
      ),
    );
    try {
      // Batches get their own catch (never throws) so a batches outage can't
      // turn into a course error page; null means enrollment unknown.
      final batchesFuture = token.isEmpty
          ? Future<List<BatchModel>?>.value(const <BatchModel>[])
          : _repository
                .getMyBatches(token)
                .then<List<BatchModel>?>((b) => b)
                .catchError((_) => null);
      final course = await _repository.getCourseById(token: token, id: id);
      final batches = await batchesFuture;
      if (_latestCourseId != id) return; // superseded by a newer request
      emit(
        state.copyWith(
          status: CoursesStatus.success,
          selectedCourse: course,
          myBatches: batches,
          myBatchesLoaded: batches != null,
        ),
      );
    } catch (e) {
      if (_latestCourseId != id) return;
      emit(
        state.copyWith(
          status: CoursesStatus.failure,
          error: e.toString(),
          clearSelectedCourse: true,
        ),
      );
    }
  }

  Future<bool> enrollInCourse(String courseId, String token) async {
    emit(state.copyWith(isEnrolling: true));
    try {
      await _repository.enrollCourse(token: token, courseId: courseId);
      final updatedBatches = await _repository.getMyBatches(token);
      emit(
        state.copyWith(
          isEnrolling: false,
          myBatches: updatedBatches,
          myBatchesLoaded: true,
          enrollSuccessMessage: 'Enrollment successful!',
        ),
      );
      return true;
    } catch (e) {
      emit(state.copyWith(isEnrolling: false, error: e.toString()));
      return false;
    }
  }

  Future<Map<String, dynamic>?> initiateRazorpayOrder(
    String courseId,
    String token,
  ) async {
    emit(state.copyWith(isEnrolling: true));
    try {
      final res = await _repository.initiateRazorpayOrder(
        token: token,
        courseId: courseId,
      );
      emit(state.copyWith(isEnrolling: false));
      return res;
    } catch (e) {
      emit(state.copyWith(isEnrolling: false, error: e.toString()));
      return null;
    }
  }

  Future<bool> verifyRazorpayPayment({
    required String orderId,
    required String paymentId,
    required String signature,
    required String token,
  }) async {
    emit(state.copyWith(isEnrolling: true));
    try {
      await _repository.verifyRazorpayPayment(
        token: token,
        orderId: orderId,
        paymentId: paymentId,
        signature: signature,
      );
      final updatedBatches = await _repository.getMyBatches(token);
      emit(
        state.copyWith(
          isEnrolling: false,
          myBatches: updatedBatches,
          myBatchesLoaded: true,
          enrollSuccessMessage: 'Payment verified and enrolled successfully!',
        ),
      );
      return true;
    } catch (e) {
      emit(state.copyWith(isEnrolling: false, error: e.toString()));
      return false;
    }
  }

  Future<Map<String, dynamic>?> initiateCoursePayment(
    String courseId,
    String token,
  ) async {
    emit(state.copyWith(isEnrolling: true));
    try {
      final res = await _repository.initiateCoursePayment(
        token: token,
        courseId: courseId,
      );
      emit(state.copyWith(isEnrolling: false));
      return res;
    } catch (e) {
      emit(state.copyWith(isEnrolling: false, error: e.toString()));
      return null;
    }
  }
}
