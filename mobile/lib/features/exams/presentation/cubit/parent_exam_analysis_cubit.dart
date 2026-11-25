import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/features/exams/data/models/exams_models.dart';
import 'package:lms/features/exams/data/repositories/exams_repository.dart';

enum ParentExamAnalysisStatus { initial, loading, success, failure }

class ParentExamAnalysisState extends Equatable {
  const ParentExamAnalysisState({
    this.status = ParentExamAnalysisStatus.initial,
    this.analysis,
    this.remedialDpps = const [],
    this.error,
  });

  final ParentExamAnalysisStatus status;
  final ParentExamAnalysisModel? analysis;
  final List<dynamic> remedialDpps;
  final String? error;

  ParentExamAnalysisState copyWith({
    ParentExamAnalysisStatus? status,
    ParentExamAnalysisModel? analysis,
    List<dynamic>? remedialDpps,
    String? error,
  }) {
    return ParentExamAnalysisState(
      status: status ?? this.status,
      analysis: analysis ?? this.analysis,
      remedialDpps: remedialDpps ?? this.remedialDpps,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, analysis, remedialDpps, error];
}

class ParentExamAnalysisCubit extends Cubit<ParentExamAnalysisState> {
  ParentExamAnalysisCubit({required ExamsRepository examsRepository})
    : _examsRepository = examsRepository,
      super(const ParentExamAnalysisState());

  final ExamsRepository _examsRepository;

  Future<void> loadAnalysis(
    String token,
    String examId, {
    String? childId,
  }) async {
    emit(state.copyWith(status: ParentExamAnalysisStatus.loading));
    try {
      final futures = await Future.wait([
        childId != null && childId.isNotEmpty
            ? _examsRepository.getParentExamAnalysis(token, examId, childId)
            : _examsRepository.getStudentExamAnalysis(token, examId),
        _examsRepository.getRemedialDpps(token, examId),
      ]);
      final analysis = futures[0] as ParentExamAnalysisModel;
      final remedialDpps = futures[1] as List<dynamic>;

      emit(
        state.copyWith(
          status: ParentExamAnalysisStatus.success,
          analysis: analysis,
          remedialDpps: remedialDpps,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ParentExamAnalysisStatus.failure,
          error: e.toString(),
        ),
      );
    }
  }
}
