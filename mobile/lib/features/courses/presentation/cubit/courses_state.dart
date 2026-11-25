import 'package:equatable/equatable.dart';
import 'package:lms/features/courses/data/models/batch_model.dart';
import 'package:lms/features/courses/data/models/course_model.dart';

enum CoursesStatus { initial, loading, success, failure }

class CoursesState extends Equatable {
  final CoursesStatus status;
  final List<CourseModel> courses;
  final List<BatchModel> myBatches;
  final CourseModel? selectedCourse;
  final String? error;
  final bool isEnrolling;

  /// False until my-batches loaded successfully; enrollment is unknown before that.
  final bool myBatchesLoaded;
  final String? enrollSuccessMessage;

  const CoursesState({
    this.status = CoursesStatus.initial,
    this.courses = const [],
    this.myBatches = const [],
    this.selectedCourse,
    this.error,
    this.isEnrolling = false,
    this.myBatchesLoaded = false,
    this.enrollSuccessMessage,
  });

  CoursesState copyWith({
    CoursesStatus? status,
    List<CourseModel>? courses,
    List<BatchModel>? myBatches,
    CourseModel? selectedCourse,
    String? error,
    bool? isEnrolling,
    bool? myBatchesLoaded,
    String? enrollSuccessMessage,
    bool clearSelectedCourse = false,
  }) {
    return CoursesState(
      status: status ?? this.status,
      courses: courses ?? this.courses,
      myBatches: myBatches ?? this.myBatches,
      // clearSelectedCourse lets a new load drop the previous course (copyWith
      // alone cannot set a field back to null).
      selectedCourse: clearSelectedCourse
          ? null
          : (selectedCourse ?? this.selectedCourse),
      error: error,
      isEnrolling: isEnrolling ?? this.isEnrolling,
      myBatchesLoaded: myBatchesLoaded ?? this.myBatchesLoaded,
      enrollSuccessMessage: enrollSuccessMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    courses,
    myBatches,
    selectedCourse,
    error,
    isEnrolling,
    myBatchesLoaded,
    enrollSuccessMessage,
  ];
}
