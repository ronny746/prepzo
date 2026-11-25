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
  final String? enrollSuccessMessage;

  const CoursesState({
    this.status = CoursesStatus.initial,
    this.courses = const [],
    this.myBatches = const [],
    this.selectedCourse,
    this.error,
    this.isEnrolling = false,
    this.enrollSuccessMessage,
  });

  CoursesState copyWith({
    CoursesStatus? status,
    List<CourseModel>? courses,
    List<BatchModel>? myBatches,
    CourseModel? selectedCourse,
    String? error,
    bool? isEnrolling,
    String? enrollSuccessMessage,
  }) {
    return CoursesState(
      status: status ?? this.status,
      courses: courses ?? this.courses,
      myBatches: myBatches ?? this.myBatches,
      selectedCourse: selectedCourse ?? this.selectedCourse,
      error: error,
      isEnrolling: isEnrolling ?? this.isEnrolling,
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
        enrollSuccessMessage,
      ];
}
