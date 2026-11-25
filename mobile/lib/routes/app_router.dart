import 'package:flutter/material.dart';
import 'package:lms/features/authentication/presentation/forgot_password_screen.dart';
import 'package:lms/features/authentication/presentation/login_screen.dart';
import 'package:lms/features/authentication/presentation/otp_verification_screen.dart';
import 'package:lms/features/authentication/presentation/reset_password_screen.dart';
import 'package:lms/features/authentication/presentation/splash_screen.dart';
import 'package:lms/features/dashboard/presentation/main_layout_screen.dart';
import 'package:lms/features/notifications/data/models/notification_model.dart';
import 'package:lms/features/notifications/presentation/notification_detail_screen.dart';
import 'package:lms/features/notifications/presentation/notification_list_screen.dart';
import 'package:lms/features/parent/presentation/parent_dashboard_screen.dart';
import 'package:lms/features/profile/presentation/edit_profile_screen.dart';
import 'package:lms/features/profile/presentation/profile_screen.dart';
import 'package:lms/features/settings/presentation/settings_screen.dart';
import 'package:lms/features/settings/presentation/support_screen.dart';
import 'package:lms/features/student/presentation/student_information_screen.dart';
import 'package:lms/features/live_classes/presentation/screens/live_classes_screen.dart';
import 'package:lms/features/extras/presentation/screens/resources_screen.dart';
import 'package:lms/features/extras/presentation/screens/fees_screen.dart';
import 'package:lms/features/extras/presentation/screens/ptm_booking_screen.dart';
import 'package:lms/features/chat/presentation/screens/chat_rooms_screen.dart';
import 'package:lms/features/chat/presentation/screens/chat_room_screen.dart';
import 'package:lms/features/chat/data/models/chat_models.dart';
import 'package:lms/features/teacher/presentation/teacher_dashboard_screen.dart';
import 'package:lms/features/student/presentation/screens/student_attendance_screen.dart';
import 'package:lms/features/student/presentation/screens/student_schedule_screen.dart';
import 'package:lms/features/student/presentation/screens/student_results_screen.dart';
import 'package:lms/features/student/presentation/screens/parent_setup_screen.dart';
import 'package:lms/features/exams/presentation/screens/student_exams_screen.dart';
import 'package:lms/features/exams/presentation/screens/exam_analysis_screen.dart';
import 'package:lms/features/exams/data/models/exams_models.dart';

import 'package:lms/features/authentication/presentation/complete_profile_screen.dart';
import 'package:lms/features/courses/presentation/screens/courses_catalog_screen.dart';
import 'package:lms/features/courses/presentation/screens/course_detail_screen.dart';

import 'package:lms/features/parent/presentation/parent_children_screen.dart';
import 'package:lms/features/operations/presentation/teacher_leave_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const otpVerification = '/otp-verification';
  static const resetPassword = '/reset-password';
  static const completeProfile = '/complete-profile';
  static const studentDashboard = '/student-dashboard';
  static const teacherDashboard = '/teacher-dashboard';
  static const parentDashboard = '/parent-dashboard';
  static const parentChildren = '/parent-children';
  static const profile = '/profile';
  static const editProfile = '/edit-profile';
  static const notifications = '/notifications';
  static const notificationDetail = '/notification-detail';
  static const settings = '/settings';
  static const support = '/support';
  static const studentInformation = '/student-information';
  static const liveClasses = '/live-classes';
  static const resources = '/resources';
  static const fees = '/fees';
  static const chatRooms = '/chat-rooms';
  static const chatRoom = '/chat-room';
  static const ptmBooking = '/ptm-booking';
  static const studentSchedule = '/student-schedule';
  static const studentResults = '/student-results';
  static const studentExams = '/student-exams';
  static const examAnalysis = '/exam-analysis';
  static const parentSetup = '/parent-setup';
  static const courses = '/courses';
  static const courseDetail = '/course-detail';
  static const teacherLeave = '/teacher-leave';
  static const attendance = '/attendance';
}

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return _buildRoute(const SplashScreen(), settings);
      case AppRoutes.login:
        return _buildRoute(const LoginScreen(), settings);
      case AppRoutes.forgotPassword:
        return _buildRoute(const ForgotPasswordScreen(), settings);
      case AppRoutes.otpVerification:
        return _buildRoute(const OtpVerificationScreen(), settings);
      case AppRoutes.resetPassword:
        return _buildRoute(const ResetPasswordScreen(), settings);
      case AppRoutes.completeProfile:
        return _buildRoute(const CompleteProfileScreen(), settings);
      case AppRoutes.studentDashboard:
        return _buildRoute(const MainLayoutScreen(), settings);
      case AppRoutes.teacherDashboard:
        return _buildRoute(const TeacherDashboardScreen(), settings);
      case AppRoutes.parentDashboard:
        return _buildRoute(const ParentDashboardScreen(), settings);
      case AppRoutes.parentChildren:
        return _buildRoute(const ParentChildrenScreen(), settings);
      case AppRoutes.profile:
        return _buildRoute(const ProfileScreen(), settings);
      case AppRoutes.editProfile:
        return _buildRoute(const EditProfileScreen(), settings);
      case AppRoutes.notifications:
        return _buildRoute(const NotificationListScreen(), settings);
      case AppRoutes.notificationDetail:
        final arg = settings.arguments;
        return _buildRoute(
          NotificationDetailScreen(
            notification: arg is AppNotificationModel ? arg : null,
            title: arg is String ? arg : null,
          ),
          settings,
        );
      case AppRoutes.settings:
        return _buildRoute(const SettingsScreen(), settings);
      case AppRoutes.support:
        return _buildRoute(const SupportScreen(), settings);
      case AppRoutes.studentInformation:
        return _buildRoute(const StudentInformationScreen(), settings);
      case AppRoutes.liveClasses:
        return _buildRoute(const LiveClassesScreen(), settings);
      case AppRoutes.resources:
        return _buildRoute(const ResourcesScreen(), settings);
      case AppRoutes.fees:
        return _buildRoute(const FeesScreen(), settings);
      case AppRoutes.ptmBooking:
        return _buildRoute(const PtmBookingScreen(), settings);
      case AppRoutes.chatRooms:
        return _buildRoute(const ChatRoomsScreen(), settings);
      case AppRoutes.chatRoom:
        final room = settings.arguments as ChatRoom;
        return _buildRoute(ChatRoomScreen(room: room), settings);
      case AppRoutes.studentSchedule:
        return _buildRoute(const StudentScheduleScreen(), settings);
      case AppRoutes.studentResults:
        return _buildRoute(const StudentResultsScreen(), settings);
      case AppRoutes.studentExams:
        return _buildRoute(const StudentExamsScreen(), settings);
      case AppRoutes.examAnalysis:
        final result = settings.arguments as ExamResultModel;
        return _buildRoute(ExamAnalysisScreen(result: result), settings);
      case AppRoutes.parentSetup:
        return _buildRoute(const ParentSetupScreen(), settings);
      case AppRoutes.courses:
        return _buildRoute(const CoursesCatalogScreen(), settings);
      case AppRoutes.courseDetail:
        final courseId = settings.arguments as String;
        return _buildRoute(CourseDetailScreen(courseId: courseId), settings);
      case AppRoutes.teacherLeave:
        return _buildRoute(const TeacherLeaveScreen(), settings);
      case AppRoutes.attendance:
        return _buildRoute(const StudentAttendanceScreen(), settings);
      default:
        return _buildRoute(const SplashScreen(), settings);
    }
  }

  static MaterialPageRoute<dynamic> _buildRoute(
    Widget child,
    RouteSettings settings,
  ) {
    return MaterialPageRoute(builder: (_) => child, settings: settings);
  }
}
