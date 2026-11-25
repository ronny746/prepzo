import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lms/features/courses/data/models/batch_model.dart';
import 'package:lms/features/courses/data/models/course_model.dart';
import 'package:lms/features/courses/data/repositories/courses_repository.dart';
import 'package:lms/features/courses/presentation/cubit/courses_cubit.dart';
import 'package:lms/features/courses/presentation/cubit/courses_state.dart';

/// Fake repository: canned data, per-id completers, no network.
class _FakeRepo extends CoursesRepository {
  bool failCourse = false;
  bool failBatches;
  List<BatchModel> batches;
  final Map<String, Completer<CourseModel>> gates = {};

  _FakeRepo({this.failBatches = false, this.batches = const []});

  @override
  Future<CourseModel> getCourseById({
    required String token,
    required String id,
  }) async {
    final gate = gates[id];
    if (gate != null) return gate.future;
    if (failCourse) throw Exception('boom');
    return CourseModel(id: id, name: 'Course $id');
  }

  @override
  Future<List<BatchModel>> getMyBatches(String token) async {
    if (failBatches) throw Exception('batches down');
    return batches;
  }
}

void main() {
  test('loadCourseDetail loads course and my-batches together', () async {
    final cubit = CoursesCubit(
      repository: _FakeRepo(
        batches: const [BatchModel(id: 'b1', name: 'B', courseId: 'c1')],
      ),
    );
    await cubit.loadCourseDetail('c1', 'tok');
    expect(cubit.state.selectedCourse?.id, 'c1');
    expect(cubit.state.myBatches.single.courseId, 'c1');
    expect(cubit.state.myBatchesLoaded, isTrue);
  });

  test('failure clears the previously selected course', () async {
    final repo = _FakeRepo();
    final cubit = CoursesCubit(repository: repo);
    await cubit.loadCourseDetail('c1', 'tok');
    expect(cubit.state.selectedCourse?.id, 'c1');

    repo.failCourse = true;
    await cubit.loadCourseDetail('c2', 'tok');
    expect(cubit.state.status, CoursesStatus.failure);
    expect(cubit.state.selectedCourse, isNull);
    expect(cubit.state.error, isNotNull);
  });

  test(
    'batches failure keeps the course but marks enrollment unknown',
    () async {
      final cubit = CoursesCubit(repository: _FakeRepo(failBatches: true));
      await cubit.loadCourseDetail('c1', 'tok');
      expect(cubit.state.status, CoursesStatus.success);
      expect(cubit.state.selectedCourse?.id, 'c1');
      expect(cubit.state.myBatchesLoaded, isFalse);
    },
  );

  test('reloading the same id does not clear the course', () async {
    final cubit = CoursesCubit(repository: _FakeRepo());
    await cubit.loadCourseDetail('c1', 'tok');
    final states = <CoursesState>[];
    final sub = cubit.stream.listen(states.add);
    await cubit.loadCourseDetail('c1', 'tok');
    await sub.cancel();
    expect(states.every((s) => s.selectedCourse?.id == 'c1'), isTrue);
  });

  test(
    'overlapping loads: result of a superseded request is dropped',
    () async {
      final repo = _FakeRepo();
      repo.gates['c1'] = Completer<CourseModel>();
      final cubit = CoursesCubit(repository: repo);

      final first = cubit.loadCourseDetail('c1', 'tok'); // stays pending
      await cubit.loadCourseDetail('c2', 'tok'); // newer, finishes first
      repo.gates['c1']!.complete(const CourseModel(id: 'c1', name: 'late'));
      await first;

      expect(cubit.state.selectedCourse?.id, 'c2');
    },
  );
}
