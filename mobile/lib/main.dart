import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lms/l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:lms/core/services/student_data_refresh.dart';
import 'package:lms/core/network/api_client.dart';
import 'package:lms/core/network/app_bloc_observer.dart';
import 'package:lms/core/storage/session_storage.dart';
import 'package:lms/core/services/deep_link_service.dart';
import 'package:lms/core/services/push_notification_service.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/core/theme/theme_controller.dart';
import 'package:lms/features/authentication/data/repositories/auth_repository.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:lms/features/profile/data/repositories/profile_repository.dart';
import 'package:lms/features/academics/data/repositories/academics_repository.dart';
import 'package:lms/features/exams/data/repositories/exams_repository.dart';
import 'package:lms/features/extras/data/repositories/extras_repository.dart';
import 'package:lms/features/extras/presentation/cubit/extras_cubit.dart';
import 'package:lms/features/chat/data/repositories/chat_repository.dart';
import 'package:lms/features/chat/presentation/cubit/chat_cubit.dart';
import 'package:lms/features/chat/presentation/cubit/chat_room_cubit.dart';
import 'package:lms/features/resources/data/repositories/resources_repository.dart';
import 'package:lms/features/resources/presentation/cubit/resources_cubit.dart';
import 'package:lms/features/live_classes/data/repositories/live_classes_repository.dart';
import 'package:lms/features/live_classes/presentation/cubit/live_classes_cubit.dart';
import 'package:lms/features/courses/data/repositories/courses_repository.dart';
import 'package:lms/features/courses/presentation/cubit/courses_cubit.dart';
import 'package:lms/features/operations/data/repositories/operations_repository.dart';
import 'package:lms/routes/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Firebase (Crashlytics/FCM/Analytics) is removed until a google-services.json
  // for com.app.prepzo exists; originals are in .firebase_backup/.
  // First screens (splash/login) are dark. Each screen then sets its own
  // style through AnnotatedRegion / AppBarTheme (see AppTheme).
  SystemChrome.setSystemUIOverlayStyle(AppTheme.darkScreenSystemUi);

  // Set the global Bloc observer for debugging transitions and errors
  Bloc.observer = AppBlocObserver();

  await ThemeController.load();
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
  unawaited(pushNotificationService.initialize());

  // Wired before runApp so a link the app was opened with is kept.
  DeepLinkService.init(navigatorKey: _navigatorKey);
  runApp(
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
}

// Used to send the student to the login screen from outside any widget when
// the server ends the session, and to tell them why.
final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> _messengerKey =
    GlobalKey<ScaffoldMessengerState>();

class LmsApp extends StatelessWidget {
  const LmsApp({
    super.key,
    required this.authRepository,
    required this.dashboardRepository,
    required this.profileRepository,
    required this.academicsRepository,
    required this.examsRepository,
    required this.extrasRepository,
    required this.chatRepository,
    required this.resourcesRepository,
    required this.liveClassesRepository,
    required this.coursesRepository,
    required this.operationsRepository,
    required this.pushNotificationService,
  });

  final AuthRepository authRepository;
  final DashboardRepository dashboardRepository;
  final ProfileRepository profileRepository;
  final AcademicsRepository academicsRepository;
  final ExamsRepository examsRepository;
  final ExtrasRepository extrasRepository;
  final ChatRepository chatRepository;
  final ResourcesRepository resourcesRepository;
  final LiveClassesRepository liveClassesRepository;
  final CoursesRepository coursesRepository;
  final OperationsRepository operationsRepository;
  final PushNotificationService pushNotificationService;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: dashboardRepository),
        RepositoryProvider.value(value: profileRepository),
        RepositoryProvider.value(value: academicsRepository),
        RepositoryProvider.value(value: examsRepository),
        RepositoryProvider.value(value: extrasRepository),
        RepositoryProvider.value(value: chatRepository),
        RepositoryProvider.value(value: resourcesRepository),
        RepositoryProvider.value(value: liveClassesRepository),
        RepositoryProvider.value(value: coursesRepository),
        RepositoryProvider.value(value: operationsRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) {
              final bloc = AuthBloc(
                authRepository: authRepository,
                // Stop this phone getting the old student's notifications.
                onSignOut: pushNotificationService.stopForSession,
              );
              ApiClient.onUnauthorized = (message) {
                if (!bloc.isClosed) bloc.add(AuthSessionExpired(message));
              };
              return bloc;
            },
          ),
          BlocProvider(
            create: (_) => ExtrasCubit(extrasRepository: extrasRepository),
          ),
          BlocProvider(
            create: (_) => ChatCubit(chatRepository: chatRepository),
          ),
          BlocProvider(
            create: (_) => ChatRoomCubit(chatRepository: chatRepository),
          ),
          BlocProvider(
            create: (_) =>
                ResourcesCubit(resourcesRepository: resourcesRepository),
          ),
          BlocProvider(create: (_) => LiveClassesCubit(liveClassesRepository)),
          BlocProvider(
            create: (_) => CoursesCubit(repository: coursesRepository),
          ),
        ],
        child: BlocListener<AuthBloc, AuthState>(
          // Any authenticated -> unauthenticated transition (logout button or
          // server-ended session) sends the user to login from one place, so no
          // screen can leave them stuck.
          listenWhen: (prev, curr) =>
              prev.status == AuthStatus.authenticated &&
              curr.status == AuthStatus.unauthenticated,
          listener: (_, state) {
            _navigatorKey.currentState?.pushNamedAndRemoveUntil(
              AppRoutes.login,
              (_) => false,
            );
            final message = state.errorMessage;
            if (message != null && message.isNotEmpty) {
              _messengerKey.currentState
                ?..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(message)));
            }
          },
          child: BlocListener<AuthBloc, AuthState>(
            // Server ended a live session (token expired / other device):
            // go to login and say why. A normal logout carries no message
            // and its screen navigates by itself.
            listenWhen: (prev, curr) =>
                prev.status == AuthStatus.authenticated &&
                curr.status == AuthStatus.unauthenticated &&
                curr.errorMessage != null,
            listener: (_, state) {
              _navigatorKey.currentState?.pushNamedAndRemoveUntil(
                AppRoutes.login,
                (route) => false,
              );
              _messengerKey.currentState?.showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 5),
                ),
              );
            },
            child: ScreenUtilPlusInit(
              designSize: const Size(
                375,
                812,
              ), // Standard iPhone size for reference
              minTextAdapt: true,
              splitScreenMode: true,
              builder: (context, child) {
                return ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeController.mode,
                  builder: (context, themeMode, _) => MaterialApp(
                    title: 'The Prepzo',
                    debugShowCheckedModeBanner: false,
                    theme: AppTheme.lightTheme,
                    darkTheme: AppTheme.darkTheme,
                    themeMode: themeMode,
                    navigatorKey: _navigatorKey,
                    navigatorObservers: [appRouteObserver],
                    scaffoldMessengerKey: _messengerKey,
                    initialRoute: AppRoutes.splash,
                    onGenerateRoute: AppRouter.onGenerateRoute,
                    // Locale strings come from lib/l10n/*.arb (see docs/engineering-standards.md#i18n).
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: const TextScaler.linear(1.0)),
                      // Default: cream screens get dark status-bar icons.
                      // Dark screens (login, splash) override this with
                      // their own AnnotatedRegion further down the tree.
                      child: AnnotatedRegion<SystemUiOverlayStyle>(
                        value: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.darkScreenSystemUi
                            : AppTheme.lightScreenSystemUi,
                        child: child ?? const SizedBox.shrink(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
