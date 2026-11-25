import 'package:flutter_test/flutter_test.dart';
import 'package:lms/core/network/api_client.dart';
import 'package:lms/core/storage/session_storage.dart';
import 'package:lms/features/authentication/data/repositories/auth_repository.dart';
import 'package:lms/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:lms/features/profile/data/repositories/profile_repository.dart';
import 'package:lms/features/academics/data/repositories/academics_repository.dart';
import 'package:lms/features/exams/data/repositories/exams_repository.dart';
import 'package:lms/features/extras/data/repositories/extras_repository.dart';
import 'package:lms/features/chat/data/repositories/chat_repository.dart';
import 'package:lms/features/resources/data/repositories/resources_repository.dart';
import 'package:lms/features/live_classes/data/repositories/live_classes_repository.dart';
import 'package:lms/features/courses/data/repositories/courses_repository.dart';
import 'package:lms/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lms/features/operations/data/repositories/operations_repository.dart';
import 'package:lms/core/services/push_notification_service.dart';

void main() {
  testWidgets('shows LMS login flow', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final sessionStorage = await SessionStorage.create();
    final apiClient = ApiClient();
    final authRepository = AuthRepository(
      apiClient: apiClient,
      sessionStorage: sessionStorage,
    );
    final dashboardRepository = DashboardRepository(apiClient: apiClient);
    final profileRepository = ProfileRepository(apiClient: apiClient);
    final academicsRepository = AcademicsRepository(apiClient: apiClient);
    final examsRepository = ExamsRepository(apiClient: apiClient);
    final extrasRepository = ExtrasRepository(apiClient: apiClient);
    final chatRepository = ChatRepository(apiClient: apiClient);
    final resourcesRepository = ResourcesRepository(apiClient: apiClient);
    final liveClassesRepository = LiveClassesRepository(apiClient);
    final coursesRepository = CoursesRepository(apiClient: apiClient);
    final operationsRepository = OperationsRepository(apiClient: apiClient);
    final pushNotificationService = PushNotificationService(apiClient);

    await tester.pumpWidget(
      LmsApp(
        authRepository: authRepository,
        dashboardRepository: dashboardRepository,
        profileRepository: profileRepository,
        academicsRepository: academicsRepository,
        examsRepository: examsRepository,
        extrasRepository: extrasRepository,
        chatRepository: chatRepository,
        resourcesRepository: resourcesRepository,
        liveClassesRepository: liveClassesRepository,
        coursesRepository: coursesRepository,
        operationsRepository: operationsRepository,
        pushNotificationService: pushNotificationService,
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // The login screen is for students and parents, signing in by mobile OTP.
    // Prepzo shows its wordmark as "prep" + "zo".
    expect(find.text('prep'), findsOneWidget);
    expect(find.text('zo'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Parent'), findsOneWidget);
    expect(find.text('REGISTERED MOBILE NUMBER'), findsOneWidget);
    expect(find.text('Get OTP'), findsOneWidget);
  });
}
