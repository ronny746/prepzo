import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
        error
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
      final futures = await Future.wait([
        _examsRepository.getStudentExams(token),
        _examsRepository.getPerformanceData(token),
        _examsRepository.getSubjects(token),
        _examsRepository.getPracticeFilters(token),
        _examsRepository.getPracticeHistory(token, 'DPP'),
        _examsRepository.getPracticeHistory(token, 'PRACTICE'),
      ]);
      
      final exams = futures[0] as List<ExamModel>;
      final performanceData = futures[1] as Map<String, dynamic>;
      final subjects = futures[2] as List<String>;
      final practiceFilters = futures[3] as Map<String, dynamic>;
      final dppHistory = futures[4] as List<dynamic>;
      final practiceHistory = futures[5] as List<dynamic>;
      
      final List<ExamResultModel> resultsList = [];
      if (performanceData['recentExams'] is List) {
        final List<dynamic> recentExams = performanceData['recentExams'];
        resultsList.addAll(recentExams.map((e) => ExamResultModel.fromJson(e)).toList());
      }
      
      emit(state.copyWith(
        status: ExamsStatus.success,
        exams: exams,
        results: resultsList,
        performanceData: performanceData,
        subjects: subjects,
        practiceFilters: practiceFilters,
        dppHistory: dppHistory,
        practiceHistory: practiceHistory,
      ));
    } catch (e) {
      emit(state.copyWith(status: ExamsStatus.failure, error: e.toString()));
    }
  }

  Future<void> loadParentExams(String token) async {
    emit(state.copyWith(status: ExamsStatus.loading));
    try {
      final parentExams = await _examsRepository.getParentChildrenExams(token);
      emit(state.copyWith(
        status: ExamsStatus.success,
        parentExams: parentExams,
        results: [],
        performanceData: {},
      ));
    } catch (e) {
      emit(state.copyWith(status: ExamsStatus.failure, error: e.toString()));
    }
  }
}
