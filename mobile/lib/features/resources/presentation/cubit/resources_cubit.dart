import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/features/courses/data/models/batch_model.dart';
import 'package:lms/features/resources/data/models/resource.dart';
import 'package:lms/features/resources/data/repositories/resources_repository.dart';

enum ResourcesStatus { initial, loading, success, failure }

class ResourcesState extends Equatable {
  const ResourcesState({
    this.status = ResourcesStatus.initial,
    this.resources = const [],
    this.myBatches = const [],
    this.selectedSection = 'global',
    this.error,
  });

  final ResourcesStatus status;
  final List<Resource> resources;
  final List<BatchModel> myBatches;
  final String selectedSection; // 'global' or batch ID
  final String? error;

  ResourcesState copyWith({
    ResourcesStatus? status,
    List<Resource>? resources,
    List<BatchModel>? myBatches,
    String? selectedSection,
    String? error,
  }) {
    return ResourcesState(
      status: status ?? this.status,
      resources: resources ?? this.resources,
      myBatches: myBatches ?? this.myBatches,
      selectedSection: selectedSection ?? this.selectedSection,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, resources, myBatches, selectedSection, error];
}

class ResourcesCubit extends Cubit<ResourcesState> {
  ResourcesCubit({required ResourcesRepository resourcesRepository})
      : _resourcesRepository = resourcesRepository,
        super(const ResourcesState());

  final ResourcesRepository _resourcesRepository;

  Future<void> loadResources(String token) async {
    emit(state.copyWith(status: ResourcesStatus.loading));
    try {
      final results = await Future.wait([
        _resourcesRepository.getResources(token),
        if (token.isNotEmpty) _resourcesRepository.getMyBatches(token) else Future.value(<BatchModel>[]),
      ]);

      final resources = results[0] as List<Resource>;
      final batches = results[1] as List<BatchModel>;

      String defaultSection = 'global';
      if (batches.isNotEmpty) {
        defaultSection = batches[0].id;
      }

      emit(state.copyWith(
        status: ResourcesStatus.success,
        resources: resources,
        myBatches: batches,
        selectedSection: defaultSection,
      ));
    } catch (e) {
      emit(state.copyWith(status: ResourcesStatus.failure, error: e.toString()));
    }
  }

  void setSelectedSection(String sectionId) {
    emit(state.copyWith(selectedSection: sectionId));
  }
}
