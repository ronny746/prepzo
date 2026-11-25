import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms/features/courses/data/models/course_model.dart';
import 'package:lms/features/courses/presentation/widgets/shakti_planner.dart';

void main() {
  test('planner is shown only for Shakti courses (name or tag)', () {
    expect(
      isShaktiCourse(const CourseModel(id: '1', name: 'Shakti Test Series')),
      isTrue,
    );
    expect(
      isShaktiCourse(
        const CourseModel(id: '2', name: 'JEE 2027', tag: 'SHAKTI'),
      ),
      isTrue,
    );
    expect(
      isShaktiCourse(const CourseModel(id: '3', name: 'NEET Crash Course')),
      isFalse,
    );
  });

  // A small phone (320dp) with the system font at 130% must not overflow.
  testWidgets('planner fits a narrow phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: ShaktiPlanner(),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Six levels of preparation'), findsOneWidget);
    expect(find.text('Final full mock'), findsOneWidget);
  });
}
