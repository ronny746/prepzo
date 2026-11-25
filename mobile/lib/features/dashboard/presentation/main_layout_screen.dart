import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:lms/core/services/deep_link_service.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/dashboard/presentation/student_dashboard_screen.dart';
import 'package:lms/features/exams/presentation/screens/student_exams_screen.dart';
import 'package:lms/features/student/presentation/screens/student_results_screen.dart';
import 'package:lms/routes/app_router.dart';

// Import missing screens (we will create placeholders if they don't exist yet)
import 'package:lms/features/resources/presentation/screens/resources_screen.dart';
import 'package:lms/features/profile/presentation/screens/profile_screen.dart';
import 'package:lms/features/student/presentation/screens/student_schedule_screen.dart';
import 'package:lms/features/academics/presentation/screens/academics_screen.dart';
import 'package:lms/features/chat/presentation/screens/chat_rooms_screen.dart';
import 'package:lms/features/student/presentation/screens/parent_setup_screen.dart';
import 'package:lms/features/extras/presentation/screens/fees_screen.dart';
import 'package:lms/features/student/presentation/screens/student_attendance_screen.dart';

// Import Cubits
import 'package:lms/features/dashboard/presentation/cubit/student_dashboard_cubit.dart';
import 'package:lms/features/live_classes/presentation/cubit/live_classes_cubit.dart';
import 'package:lms/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:lms/features/academics/presentation/cubit/academics_cubit.dart';
import 'package:lms/features/exams/presentation/cubit/exams_cubit.dart';
import 'package:lms/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:lms/features/dashboard/data/models/dashboard_models.dart';
import 'package:lms/features/profile/data/repositories/profile_repository.dart';
import 'package:lms/features/academics/data/repositories/academics_repository.dart';
import 'package:lms/features/exams/data/repositories/exams_repository.dart';

import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:lms/core/services/app_update_service.dart';
import 'package:lms/features/voice_assistant/presentation/voice_assistant_sheet.dart';

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  MainLayoutScreenState createState() => MainLayoutScreenState();
}

class MainLayoutScreenState extends State<MainLayoutScreen> {
  // Keep the menu implementation available, but do not expose it in the app yet.
  static const bool _showSideMenu = false;
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // Cubits are created inside build() (below this State's context), so keep
  // handles to refresh Home when its tab is tapped.
  StudentDashboardCubit? _dashboardCubit;
  ExamsCubit? _examsCubit;

  @override
  void initState() {
    super.initState();
    // Signed in and on the student home: open any course link that is waiting.
    DeepLinkService.markReady();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppUpdateService.checkAppUpdate(context);
      }
    });
  }

  void setSelectedIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  final List<Widget> _screens = [
    const StudentDashboardScreen(),
    const StudentExamsScreen(),
    const ResourcesScreen(),
    const StudentResultsScreen(),
    const ProfileScreen(),
    const StudentScheduleScreen(),
    const AcademicsScreen(),
    const StudentResultsScreen(),
    const ChatRoomsScreen(),
    const ParentSetupScreen(),
    const FeesScreen(),
    const StudentAttendanceScreen(),
  ];

  final List<Map<String, dynamic>> _navItems = [
    {
      'title': 'Home',
      'icon': PhosphorIcons.house,
      'activeIcon': PhosphorIcons.houseFill,
    },
    {
      'title': 'Practice',
      'icon': PhosphorIcons.target,
      'activeIcon': PhosphorIcons.targetFill,
    },
    {
      'title': 'Study',
      'icon': PhosphorIcons.bookOpen,
      'activeIcon': PhosphorIcons.bookOpenFill,
    },
    {
      'title': 'Progress',
      'icon': PhosphorIcons.chartBar,
      'activeIcon': PhosphorIcons.chartBarFill,
    },
    {
      'title': 'Profile',
      'icon': PhosphorIcons.user,
      'activeIcon': PhosphorIcons.userFill,
    },
  ];

  final List<Map<String, dynamic>> _drawerItems = [
    {'title': 'My Schedule', 'icon': Icons.calendar_month_rounded, 'index': 5},
    {'title': 'Homework', 'icon': Icons.assignment_rounded, 'index': 6},
    {'title': 'Results', 'icon': Icons.grade_rounded, 'index': 7},
    {
      'title': 'Messages',
      'icon': Icons.chat_bubble_outline_rounded,
      'index': 8,
    },
    {
      'title': 'Parent Setup',
      'icon': Icons.family_restroom_rounded,
      'index': 9,
    },
    {
      'title': 'Transactions & Fees',
      'icon': Icons.receipt_long_rounded,
      'index': 10,
    },
    {'title': 'Attendance', 'icon': Icons.calendar_today_rounded, 'index': 11},
  ];

  /// Index of the Study tab in [_screens]/[_navItems]. Indices stay fixed
  /// (other code navigates by number), so a hidden tab is only left out of
  /// the bar, never removed from the lists.
  static const int _studyTabIndex = 2;

  /// Study is hidden for students whose plan has no study material
  /// (`GET /users/me/access`). Unknown access counts as allowed.
  bool _isTabVisible(int index, [StudentAccess? access]) {
    final a = access ?? _dashboardCubit?.state.access;
    if (index == _studyTabIndex && a != null && !a.studyMaterials) return false;
    return true;
  }

  void _onItemTapped(int index) {
    // Voice commands can still ask for a hidden tab; stay where we are.
    if (!_isTabVisible(index)) return;
    setState(() {
      _selectedIndex = index;
    });
    // The IndexedStack keeps Home alive, so without this it shows stale data
    // when re-selected (same reload as StudentDashboardScreen.didPopNext).
    if (index == 0) {
      final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
      _dashboardCubit?.loadDashboard(token);
      _examsCubit?.loadStudentExams(token);
    }
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
  }

  void _openVoiceAssistant() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => VoiceAssistantSheet(onNavigate: _onItemTapped),
    );
  }

  @override
  Widget build(BuildContext context) {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
          return;
        }

        final shouldExit = await _showExitConfirmationDialog(context);
        if (shouldExit && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => _dashboardCubit = StudentDashboardCubit(
              dashboardRepository: context.read<DashboardRepository>(),
            )..loadDashboard(token),
          ),
          BlocProvider(
            create: (_) => ProfileCubit(
              profileRepository: context.read<ProfileRepository>(),
            )..loadProfile(token),
          ),
          BlocProvider(
            create: (_) => AcademicsCubit(
              academicsRepository: context.read<AcademicsRepository>(),
            )..loadTasks(token),
          ),
          BlocProvider(
            create: (_) => _examsCubit = ExamsCubit(
              examsRepository: context.read<ExamsRepository>(),
            )..loadStudentExams(token),
          ),
          BlocProvider.value(
            value: context.read<LiveClassesCubit>()..fetchLiveClasses(token),
          ),
        ],
        child: Scaffold(
          key: _scaffoldKey,
          appBar:
              null, // Let individual screens show their custom headers to avoid double app bar
          drawer: _showSideMenu ? _buildDrawer() : null,
          body: SafeArea(
            bottom: false,
            child: IndexedStack(index: _selectedIndex, children: _screens),
          ),
          floatingActionButton: FloatingActionButton.small(
            heroTag: 'voice-assistant',
            onPressed: _openVoiceAssistant,
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            tooltip: 'Open voice assistant',
            child: const Icon(Icons.mic_rounded),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: Container(
            margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 20,
                  offset: Offset(0, 6.h),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24.r),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  height: 64.h,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkSurface.withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(24.r),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child:
                      BlocConsumer<
                        StudentDashboardCubit,
                        StudentDashboardState
                      >(
                        listenWhen: (a, b) => a.access != b.access,
                        listener: (context, state) {
                          // Plan changed while on a now-hidden tab: go Home.
                          if (!_isTabVisible(_selectedIndex, state.access)) {
                            setState(() => _selectedIndex = 0);
                          }
                        },
                        buildWhen: (a, b) => a.access != b.access,
                        builder: (context, state) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            for (
                              var index = 0;
                              index < _navItems.length;
                              index++
                            )
                              if (_isTabVisible(index, state.access))
                                _buildNavTab(index),
                          ],
                        ),
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavTab(int index) {
    final item = _navItems[index];
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: PhosphorIcon(
                isSelected ? item['activeIcon'] : item['icon'],
                color: isSelected ? AppTheme.primary : const Color(0xFF9CA3AF),
                size: 18.sp,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              item['title'],
              style: TextStyle(
                fontSize: 8.sp,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.primary : const Color(0xFF9CA3AF),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final user = context.read<AuthBloc>().state.session?.user;

    return Drawer(
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CircleAvatar(
                      radius: 24.r,
                      backgroundColor: Colors.white24,
                      child: Icon(
                        Icons.person,
                        size: 24.sp,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      user?.name ?? 'Student Name',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      user?.email ?? 'student@example.com',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(vertical: 6.h),
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 8.h,
                    ),
                    child: Text(
                      'MAIN NAVIGATION',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  ..._navItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isSelected = _selectedIndex == index;
                    return _buildDrawerTile(item, index, isSelected);
                  }),
                  const Divider(),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 8.h,
                    ),
                    child: Text(
                      'MORE SERVICES',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  ..._drawerItems.map((item) {
                    final index = item['index'];
                    final isSelected = _selectedIndex == index;
                    return _buildDrawerTile(item, index, isSelected);
                  }),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppTheme.error,
                ),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    color: AppTheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  context.read<AuthBloc>().add(const AuthLogoutRequested());
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.login,
                    (route) => false,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerTile(
    Map<String, dynamic> item,
    int index,
    bool isSelected,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
        selected: isSelected,
        selectedTileColor: AppTheme.primary.withValues(alpha: 0.1),
        leading: Icon(
          item['icon'],
          color: isSelected ? AppTheme.primary : Colors.grey.shade600,
          size: 20.sp,
        ),
        title: Text(
          item['title'],
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? AppTheme.primary
                : Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        onTap: () => _onItemTapped(index),
      ),
    );
  }

  Future<bool> _showExitConfirmationDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          elevation: 16,
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Exit Icon Header
                Container(
                  width: 50.w,
                  height: 50.w,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.primary.withValues(alpha: 0.15)
                        : const Color(0xFFEEF2FF),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                      width: 1.2,
                    ),
                  ),
                  child: PhosphorIcon(
                    PhosphorIcons.signOutBold,
                    size: 22.sp,
                    color: AppTheme.primary,
                  ),
                ),
                SizedBox(height: 14.h),

                // Title
                Text(
                  'Exit The Prepzo?',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6.h),

                // Subtitle
                Text(
                  'Are you sure you want to exit the application?',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20.h),

                // Actions Row
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40.h,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white24
                                  : const Color(0xFFE2E8F0),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: SizedBox(
                        height: 40.h,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                          ),
                          child: Text(
                            'Exit',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return result ?? false;
  }
}
