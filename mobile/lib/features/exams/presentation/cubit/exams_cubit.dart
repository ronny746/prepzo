import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/network/api_exception.dart';
import 'package:lms/features/exams/data/models/exams_models.dart';
import 'package:lms/features/exams/data/repositories/exams_repository.dart';

enum ExamsStatus { initial, loading, success, failure }

class ExamsState extends Equatable {
  const ExamsState({
    this.status = ExamsStatus.initial,
    this.exams = const [],
    this.parentExams = const [],
    this.results = const [],
    this.selectedCategory = 'All',
    this.performanceData = const {},
    this.subjects = const [],
    this.practiceFilters = const {},
    this.dppHistory = const [],
    this.practiceHistory = const [],
    this.error,
    this.examsError,
    this.examsErrorIsGeneric = false,
  });

  final ExamsStatus status;
  final List<ExamModel> exams;
  final List<ParentExamModel> parentExams;
  final List<ExamResultModel> results;
  final String selectedCategory;
  final Map<String, dynamic> performanceData;
  final List<String> subjects;
  final Map<String, dynamic> practiceFilters;
  final List<dynamic> dppHistory;
  final List<dynamic> practiceHistory;
  final String? error;

  /// Server message when only the my-exams call failed (e.g. plan has no
  /// access), so the UI can explain an empty list instead of hiding it.
  final String? examsError;

  /// True when the my-exams failure was not a server message (offline, parse
  /// error): the UI shows a localized generic text instead of raw exception text.
  final bool examsErrorIsGeneric;

  ExamsState copyWith({
    ExamsStatus? status,
    List<ExamModel>? exams,
    List<ParentExamModel>? parentExams,
    List<ExamResultModel>? results,
    String? selectedCategory,
    Map<String, dynamic>? performanceData,
    List<String>? subjects,
    Map<String, dynamic>? practiceFilters,
    List<dynamic>? dppHistory,
    List<dynamic>? practiceHistory,
    String? error,
    String? examsError,
    bool? examsErrorIsGeneric,
    bool clearExamsError = false,
  }) {
    return ExamsState(
      status: status ?? this.status,
      exams: exams ?? this.exams,
      parentExams: parentExams ?? this.parentExams,
      results: results ?? this.results,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      performanceData: performanceData ?? this.performanceData,
      subjects: subjects ?? this.subjects,
      practiceFilters: practiceFilters ?? this.practiceFilters,
      dppHistory: dppHistory ?? this.dppHistory,
      practiceHistory: practiceHistory ?? this.practiceHistory,
      error: error ?? this.error,
      examsError: clearExamsError ? null : (examsError ?? this.examsError),
      examsErrorIsGeneric: clearExamsError
          ? false
          : (examsErrorIsGeneric ?? this.examsErrorIsGeneric),
    );
  }

  @override
  List<Object?> get props => [
    status,
    exams,
    parentExams,
    results,
    selectedCategory,
    performanceData,
    subjects,
    practiceFilters,
    dppHistory,
    practiceHistory,
    error,
    examsError,
    examsErrorIsGeneric,
  ];
}

class ExamsCubit extends Cubit<ExamsState> {
  ExamsCubit({required ExamsRepository examsRepository})
    : _examsRepository = examsRepository,
      super(const ExamsState());

  final ExamsRepository _examsRepository;

  void changeCategory(String category) {
    emit(state.copyWith(selectedCategory: category));
  }

  Future<void> loadStudentExams(String token) async {
    emit(state.copyWith(status: ExamsStatus.loading));
    try {
      // Why per-call: a plan without test-series access makes my-exams return
      // 403. One failing call must not blank the other tabs, so each call falls
      // back to an empty value and only the my-exams message is surfaced.
      Object? examsFailure;
      var failedCalls = 0;
      Future<T> guarded<T>(
        Future<T> call,
        T fallback, {
        bool isExams = false,
      }) async {
        try {
          return await call;
        } catch (e) {
          // An expired session must still reach the outer handler (logout
          // path); swallowing it would show an empty, "successful" screen.
          if (e is ApiException && e.statusCode == 401) rethrow;
          failedCalls++;
          if (isExams) examsFailure = e;
          return fallback;
        }
      }

      final futures = await Future.wait<dynamic>([
        guarded<List<ExamModel>>(
          _examsRepository.getStudentExams(token),
          const <ExamModel>[],
          isExams: true,
        ),
        guarded<Map<String, dynamic>>(
          _examsRepository.getPerformanceData(token),
          const <String, dynamic>{},
        ),
        guarded<List<String>>(
          _examsRepository.getSubjects(token),
          const <String>[],
        ),
        guarded<Map<String, dynamic>>(
          _examsRepository.getPracticeFilters(token),
          const <String, dynamic>{},
        ),
        guarded<List<dynamic>>(
          _examsRepository.getPracticeHistory(token, 'DPP'),
          const <dynamic>[],
        ),
        guarded<List<dynamic>>(
          _examsRepository.getPracticeHistory(token, 'PRACTICE'),
          const <dynamic>[],
        ),
      ]);

      // Everything failed (offline, expired session): keep the old failure UX.
      if (failedCalls == futures.length) {
        emit(
          state.copyWith(
            status: ExamsStatus.failure,
            error: examsFailure.toString(),
          ),
        );
        return;
      }

      final exams = futures[0] as List<ExamModel>;
      final performanceData = futures[1] as Map<String, dynamic>;
      final subjects = futures[2] as List<String>;
      final practiceFilters = futures[3] as Map<String, dynamic>;
      final dppHistory = futures[4] as List<dynamic>;
      final practiceHistory = futures[5] as List<dynamic>;

      final List<ExamResultModel> resultsList = [];
      if (performanceData['recentExams'] is List) {
        final List<dynamic> recentExams = performanceData['recentExams'];
        resultsList.addAll(
          recentExams.map((e) => ExamResultModel.fromJson(e)).toList(),
        );
      }

      emit(
        state.copyWith(
          status: ExamsStatus.success,
          exams: exams,
          results: resultsList,
          performanceData: performanceData,
          subjects: subjects,
          practiceFilters: practiceFilters,
          dppHistory: dppHistory,
          practiceHistory: practiceHistory,
          // Server message for API errors (e.g. plan has no access); anything
          // else is flagged generic so the UI shows localized text.
          examsError: examsFailure is ApiException
              ? (examsFailure as ApiException).message
              : (examsFailure == null ? null : ''),
          examsErrorIsGeneric:
              examsFailure != null && examsFailure is! ApiException,
          clearExamsError: examsFailure == null,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: ExamsStatus.failure, error: e.toString()));
    }
  }

  Future<void> loadParentExams(String token) async {
    emit(state.copyWith(status: ExamsStatus.loading));
    try {
      final parentExams = await _examsRepository.getParentChildrenExams(token);
      emit(
        state.copyWith(
          status: ExamsStatus.success,
          parentExams: parentExams,
          results: [],
          performanceData: {},
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: ExamsStatus.failure, error: e.toString()));
    }
  }
}
