import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/core/widgets/app_scaffold.dart';
import 'package:lms/features/dashboard/data/models/dashboard_models.dart';
import 'package:lms/features/dashboard/presentation/cubit/student_dashboard_cubit.dart';
import 'package:lms/features/dashboard/presentation/main_layout_screen.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/routes/app_router.dart';
import 'package:lms/features/exams/data/models/exams_models.dart';
import 'package:lms/features/exams/presentation/cubit/exams_cubit.dart';
import 'package:lms/features/exams/presentation/screens/exam_player_screen.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:lms/features/courses/data/models/course_model.dart';
import 'package:lms/features/courses/presentation/cubit/courses_cubit.dart';
import 'package:lms/features/courses/presentation/cubit/courses_state.dart';
import 'package:lms/features/live_classes/presentation/cubit/live_classes_cubit.dart';
import 'package:lms/features/live_classes/data/models/live_classes_models.dart';
import 'package:lms/features/live_classes/data/repositories/live_classes_repository.dart';
import 'package:lms/features/live_classes/data/services/zoom_service.dart';
import 'package:lms/features/profile/presentation/cubit/profile_cubit.dart';

import 'package:lms/features/dashboard/data/models/banner_model.dart';
import 'package:lms/features/doubts/presentation/screens/doubt_session_screen.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  // MainLayoutScreen reloads Home when a pushed page closes (student_data_refresh).
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StudentDashboardCubit, StudentDashboardState>(
      builder: (context, state) {
        if (state.status == StudentDashboardStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        final data = state.data;
        if (data == null) {
          // First load failed (or has not started): explain and offer a
          // retry instead of a permanent "Connecting..." screen.
          final failed = state.status == StudentDashboardStatus.failure;
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 36,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    failed
                        ? 'Could not load your dashboard'
                        : 'Connecting to Academy...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (failed) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Check your internet connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () =>
                        context.read<StudentDashboardCubit>().loadDashboard(
                          context.read<AuthBloc>().state.session?.accessToken ??
                              '',
                        ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final activeExam = _findStartableExam(
          context.watch<ExamsCubit>().state.exams,
        );

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () async {
              final token =
                  context.read<AuthBloc>().state.session?.accessToken ?? '';
              await Future.wait([
                context.read<StudentDashboardCubit>().loadDashboard(
                  token,
                  silent: true,
                ),
                context.read<CoursesCubit>().loadCoursesAndBatches(token),
                context.read<LiveClassesCubit>().fetchLiveClasses(token),
              ]);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, data),
                    SizedBox(height: 12.h),
                    _PromotionBanner(banners: state.banners),
                    SizedBox(height: 18.h),
                    if (data.mentorSessions.isNotEmpty) ...[
                      _MentorSessionCard(sessions: data.mentorSessions),
                      SizedBox(height: 18.h),
                    ],
                    _buildSectionHeader(
                      context,
                      'My Performance',
                      actionLabel: 'View Details',
                      onActionTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.studentResults,
                      ),
                    ),
                    _PerformanceDashboardCard(
                      performanceData: data.performanceData,
                    ),
                    SizedBox(height: 18.h),

                    // Available Courses Section from Web Portal
                    const _AvailableCoursesList(),

                    // Live Classes Section
                    BlocBuilder<LiveClassesCubit, LiveClassesState>(
                      builder: (context, liveState) {
                        if (liveState is LiveClassesLoaded &&
                            liveState.classes.isNotEmpty) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(
                                context,
                                'Ongoing Live Classes',
                                actionLabel: 'View All',
                                onActionTap: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.liveClasses,
                                ),
                              ),
                              _DashboardLiveClassesList(
                                classes: liveState.classes,
                              ),
                              SizedBox(height: 18.h),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),

                    _buildSectionHeader(context, 'Quick Access Tools'),
                    // Only tools the student's courses allow (QA 7.3). The old
                    // check guessed from the batch name ("test", "shakti").
                    _QuickAccessGrid(access: data.access),
                    SizedBox(height: 18.h),

                    if (activeExam != null) ...[
                      _buildSectionHeader(context, 'Active Test'),
                      _ActiveExamCard(exam: activeExam),
                      SizedBox(height: 18.h),
                    ],

                    // _buildSectionHeader(
                    //   context,
                    //   'Continue Learning',
                    //   actionLabel: 'Resume All',
                    //   onActionTap: () => Navigator.pushNamed(context, AppRoutes.resources),
                    // ),
                    // const _ContinueLearningCard(),
                    SizedBox(height: 24.h),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  ExamModel? _findStartableExam(List<ExamModel> exams) {
    final now = DateTime.now();
    final active =
        exams.where((exam) {
          final submissionStatus = exam.submissionStatus.toUpperCase();
          if (submissionStatus == 'SUBMITTED' ||
              submissionStatus == 'AUTO_SUBMITTED') {
            return false;
          }

          final status = exam.status.toLowerCase();
          if (status.contains('active') || status.contains('available')) {
            return true;
          }
          if (exam.startTime != null && exam.endTime != null) {
            return !now.isBefore(exam.startTime!) &&
                !now.isAfter(exam.endTime!);
          }
          return submissionStatus == 'IN_PROGRESS';
        }).toList()..sort((a, b) {
          final aDate =
              a.startTime ?? a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate =
              b.startTime ?? b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
    return active.isEmpty ? null : active.first;
  }

  Widget _buildHeader(BuildContext context, StudentDashboardData data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String? avatarUrl;
    try {
      avatarUrl = context.watch<ProfileCubit>().state.profile?.avatarUrl;
    } catch (_) {}

    final hasValidAvatar =
        avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        avatarUrl.startsWith('http');

    final hour = DateTime.now().hour;
    final String greeting = hour < 12
        ? 'Good morning 👋'
        : (hour < 17 ? 'Good afternoon ☀️' : 'Good evening 🌙');

    return Padding(
      padding: EdgeInsets.only(top: 14.h, bottom: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _openProfileTab(context),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppTheme.primary, AppTheme.secondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(
                                alpha: isDark ? 0.3 : 0.2,
                              ),
                              blurRadius: 8,
                              offset: Offset(0, 2.h),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 18.r,
                          backgroundColor: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          backgroundImage: hasValidAvatar
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: !hasValidAvatar
                              ? PhosphorIcon(
                                  PhosphorIcons.userBold,
                                  size: 16.sp,
                                  color: isDark
                                      ? Colors.white70
                                      : AppTheme.primary,
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        right: 1.w,
                        bottom: 1.w,
                        child: Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF0F172A)
                                  : Colors.white,
                              width: 1.5.w,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openProfileTab(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          greeting,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white60
                                : const Color(0xFF64748B),
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 1.h),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                data.studentName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            if (data.userCode.isNotEmpty) ...[
                              SizedBox(width: 4.w),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppTheme.primary.withValues(alpha: 0.2)
                                      : AppTheme.primary.withValues(
                                          alpha: 0.08,
                                        ),
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  data.userCode,
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 8.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildHeaderButton(
                    context,
                    icon: PhosphorIcons.bell,
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.notifications),
                  ),
                  Positioned(
                    right: 2.w,
                    top: 2.w,
                    child: Container(
                      width: 7.w,
                      height: 7.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : Colors.white,
                          width: 1.2.w,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openProfileTab(BuildContext context) {
    final mainLayout = context.findAncestorStateOfType<MainLayoutScreenState>();
    if (mainLayout != null) {
      mainLayout.setSelectedIndex(4);
    } else {
      Navigator.pushNamed(context, AppRoutes.profile);
    }
  }

  Widget _buildHeaderButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 36.w,
      height: 36.w,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: IconButton(
        icon: PhosphorIcon(
          icon,
          color: isDark ? Colors.white : const Color(0xFF334155),
          size: 16.sp,
        ),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    String? actionLabel,
    VoidCallback? onActionTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h, left: 4.w, right: 4.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF111827),
              letterSpacing: -0.4,
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onActionTap,
              child: Row(
                children: [
                  Text(
                    actionLabel,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  SizedBox(width: 2.w),
                  PhosphorIcon(
                    PhosphorIcons.caretRight,
                    size: 10.sp,
                    color: AppTheme.primary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MentorSessionCard extends StatelessWidget {
  const _MentorSessionCard({required this.sessions});

  final List<MentorSessionItem> sessions;

  Future<void> _join(BuildContext context, MentorSessionItem session) async {
    final uri = Uri.tryParse(session.meetingLink);
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The mentor meeting link is unavailable.'),
        ),
      );
      return;
    }
    final opened = await url_launcher.launchUrl(
      uri,
      mode: url_launcher.LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the mentor meeting.')),
      );
    }
  }

  String _countdown(Duration duration) {
    final totalSeconds = duration.inSeconds.clamp(0, 24 * 60 * 60);
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return hours > 0
        ? '${hours}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s'
        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = sessions.first;
    final date = session.startAt?.toLocal();
    final schedule = date == null
        ? 'Schedule will be shared shortly'
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} · ${TimeOfDay.fromDateTime(date).format(context)}';

    return StreamBuilder<DateTime>(
      stream: Stream<DateTime>.periodic(
        const Duration(seconds: 1),
        (_) => DateTime.now(),
      ),
      initialData: DateTime.now(),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        final canJoin = date != null && !now.isBefore(date);
        final countdown = date == null ? Duration.zero : date.difference(now);

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: AppTheme.accent.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: isDark ? 0.28 : 0.20),
                blurRadius: 16,
                offset: Offset(0, 7.h),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38.w,
                    height: 38.w,
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: AppTheme.ink(context),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MENTOR CONNECT',
                          style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          canJoin
                              ? 'Your mentor call is live'
                              : 'Your guidance call is scheduled',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (sessions.length > 1)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        '${sessions.length} upcoming',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 14.h),
              Text(
                session.mentorName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                '${session.audienceName}  •  $schedule',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFFE0E7FF),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                canJoin
                    ? 'You can join the mentor call now.'
                    : 'Join opens in ${_countdown(countdown)}',
                style: TextStyle(
                  color: canJoin
                      ? const Color(0xFFBBF7D0)
                      : const Color(0xFFFDE68A),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 10.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canJoin ? () => _join(context, session) : null,
                  icon: Icon(
                    canJoin
                        ? Icons.video_call_rounded
                        : Icons.lock_clock_rounded,
                  ),
                  label: Text(
                    canJoin ? 'Join mentor call' : 'Available at start time',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    foregroundColor: const Color(0xFF025036),
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    textStyle: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardLiveClassesList extends StatelessWidget {
  const _DashboardLiveClassesList({required this.classes});
  final List<LiveClass> classes;

  void _joinClass(BuildContext context, LiveClass liveClass) {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    final user = context.read<AuthBloc>().state.session?.user;

    String studentName = 'Student';
    if (user != null) {
      final fn = user.firstName ?? '';
      final ln = user.lastName ?? '';
      final full = '$fn $ln'.trim();
      if (full.isNotEmpty && full != 'Student' && full != 'User') {
        studentName = full;
      } else if (user.name.isNotEmpty &&
          user.name != 'Student' &&
          user.name != 'User') {
        studentName = user.name;
      }
    }

    // Fire-and-forget: the API records present/late attendance from the server
    // clock while the Zoom handoff remains immediate for the learner.
    context.read<LiveClassesRepository>().recordLiveClassJoin(
      liveClassId: liveClass.id,
      token: token,
    );

    ZoomService().joinMeeting(
      context: context,
      meetingId: liveClass.meetingId,
      meetingPassword: liveClass.meetingPassword,
      meetingLink: liveClass.meetingLink,
      displayName: studentName,
      token: token,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: classes.length > 3 ? 3 : classes.length,
      separatorBuilder: (context, index) => SizedBox(height: 8.h),
      itemBuilder: (context, index) {
        final liveClass = classes[index];

        return GestureDetector(
          onTap: () => _joinClass(context, liveClass),
          child: Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: Offset(0, 3.h),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    '🔴 LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        liveClass.subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF991B1B),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        [
                          if (liveClass.courseName.isNotEmpty)
                            liveClass.courseName,
                          if (liveClass.batchName.isNotEmpty)
                            liveClass.batchName,
                          liveClass.teacherName,
                        ].join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.sp,
                          color: isDark
                              ? Colors.red.shade200
                              : const Color(0xFFB91C1C),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                ElevatedButton(
                  onPressed: () => _joinClass(context, liveClass),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 6.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Text(
                    'Join Now',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PromotionBanner extends StatefulWidget {
  const _PromotionBanner({required this.banners});

  final List<BannerModel> banners;

  @override
  State<_PromotionBanner> createState() => _PromotionBannerState();
}

class _PromotionBannerState extends State<_PromotionBanner> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (widget.banners.length <= 1) return;
      if (_pageController.hasClients) {
        int nextPage = _currentPage + 1;
        if (nextPage >= widget.banners.length) {
          nextPage = 0;
        }
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.banners.isEmpty) {
      return Container(
        width: double.infinity,
        height: 130.h,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFF060D1E),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.r),
          child: Image.asset(
            'assets/images/lms_banner.webp',
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 130.h,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.banners.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return GestureDetector(
                onTap: () async {
                  if (banner.linkUrl != null && banner.linkUrl!.isNotEmpty) {
                    final uri = Uri.tryParse(banner.linkUrl!);
                    if (uri != null && await url_launcher.canLaunchUrl(uri)) {
                      await url_launcher.launchUrl(uri);
                    }
                  }
                },
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF060D1E),
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.3 : 0.08,
                        ),
                        blurRadius: 10,
                        offset: Offset(0, 3.h),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.r),
                    child: Image.network(
                      banner.imageUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
                        'assets/images/lms_banner.webp',
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.banners.length > 1) ...[
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.banners.length,
              (index) => Container(
                width: 6.w,
                height: 6.w,
                margin: EdgeInsets.symmetric(horizontal: 2.w),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index
                      ? AppTheme.primary
                      : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ClassScheduleList extends StatelessWidget {
  const _ClassScheduleList({required this.schedule});
  final List<DashboardItem> schedule;

  void _joinLiveClass(BuildContext context, DashboardItem item) {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    final user = context.read<AuthBloc>().state.session?.user;

    String studentName = 'Student';
    if (user != null) {
      final fn = user.firstName ?? '';
      final ln = user.lastName ?? '';
      final full = '$fn $ln'.trim();
      if (full.isNotEmpty && full != 'Student' && full != 'User') {
        studentName = full;
      } else if (user.name.isNotEmpty &&
          user.name != 'Student' &&
          user.name != 'User') {
        studentName = user.name;
      }
    }

    ZoomService().joinMeeting(
      context: context,
      meetingLink: item.value,
      meetingId: item.id,
      displayName: studentName,
      token: token,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (schedule.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 14.w),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFE5E7EB),
            width: 0.8,
          ),
        ),
        child: Column(
          children: [
            PhosphorIcon(
              PhosphorIcons.calendar,
              size: 28.sp,
              color: Colors.grey,
            ),
            SizedBox(height: 6.h),
            Text(
              'No Enrolled Classes Scheduled Today',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: schedule.length > 4 ? 4 : schedule.length,
      separatorBuilder: (context, index) => SizedBox(height: 8.h),
      itemBuilder: (context, index) {
        final item = schedule[index];
        final isOngoing =
            item.status == 'ONGOING' || item.tertiary == 'LIVE NOW';

        return GestureDetector(
          // Scheduled lessons are information only. The join action becomes
          // available solely after the teacher has actually started a session.
          onTap: isOngoing ? () => _joinLiveClass(context, item) : null,
          child: Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: isOngoing
                  ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2))
                  : (isDark ? AppTheme.darkSurface : Colors.white),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: isOngoing
                    ? const Color(0xFFEF4444)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : const Color(0xFFE5E7EB)),
                width: isOngoing ? 1.2 : 0.8,
              ),
              boxShadow: isOngoing
                  ? [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: Offset(0, 3.h),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: isOngoing
                        ? const Color(0xFFEF4444)
                        : AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    isOngoing ? '🔴 LIVE' : (item.tertiary ?? 'Scheduled'),
                    style: TextStyle(
                      color: isOngoing ? Colors.white : AppTheme.primary,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: isOngoing
                              ? (isDark
                                    ? Colors.white
                                    : const Color(0xFF991B1B))
                              : (isDark
                                    ? Colors.white
                                    : const Color(0xFF1F2937)),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          fontSize: 9.sp,
                          color: isOngoing
                              ? (isDark
                                    ? Colors.red.shade200
                                    : const Color(0xFFB91C1C))
                              : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                if (isOngoing)
                  ElevatedButton.icon(
                    onPressed: () => _joinLiveClass(context, item),
                    icon: PhosphorIcon(PhosphorIcons.videoCamera, size: 12.sp),
                    label: Text(
                      'Join Now',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  )
                else
                  Text(
                    'Scheduled',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickAccessGrid extends StatelessWidget {
  const _QuickAccessGrid({required this.access});

  final StudentFeatureAccess access;

  @override
  Widget build(BuildContext context) {
    // Tiles for plan-locked areas are hidden (not disabled); Courses, Doubt
    // and Fees are never gated.
    final access = context.select<StudentDashboardCubit, StudentAccess>(
      (c) => c.state.access,
    );
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.25,
      crossAxisSpacing: 10.w,
      mainAxisSpacing: 10.h,
      children: [
        if (access.studyMaterials)
          _buildAccessCard(
            context,
            title: 'Courses',
            subtitle: 'Videos & Notes',
            icon: PhosphorIcons.bookOpenBold,
            accentColor: const Color(0xFF0033A0), // Deep Blue
            route: AppRoutes.courses,
          ),
        _buildAccessCard(
          context,
          title: 'DPP',
          subtitle: 'Daily Practice',
          icon: PhosphorIcons.clipboardTextBold,
          accentColor: const Color(0xFF4F46E5), // Indigo
          category: 'DPPs',
          tabIndex: 1,
        ),
        if (access.liveClasses)
          _buildAccessCard(
            context,
            title: 'Live Class',
            subtitle: 'Join Live Now',
            icon: PhosphorIcons.videoCameraBold,
            accentColor: const Color(0xFFDC2626), // Red
            route: AppRoutes.liveClasses,
          ),
        _buildAccessCard(
          context,
          title: 'Ask Doubt',
          subtitle: 'Instant Help',
          icon: PhosphorIcons.chatsCircleBold,
          accentColor: const Color(0xFFD97706), // Amber
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DoubtSessionScreen(),
              ),
            );
          },
        ),
        if (access.attendance)
          _buildAccessCard(
            context,
            title: 'Attendance',
            subtitle: 'My Register',
            icon: PhosphorIcons.calendarCheckBold,
            accentColor: const Color(0xFF059669), // Emerald
            route: AppRoutes.attendance,
          ),
        _buildAccessCard(
          context,
          title: 'Fees',
          subtitle: 'Receipts & Due',
          icon: PhosphorIcons.receiptBold,
          accentColor: const Color(0xFF8B5CF6), // Purple
          route: AppRoutes.fees,
        ),
      ],
    );
  }

  Widget _buildAccessCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    int? tabIndex,
    String? route,
    String? category,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppTheme.darkSurface : Colors.white,
      borderRadius: BorderRadius.circular(14.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (onTap != null) {
            onTap();
            return;
          }
          if (category != null) {
            context.read<ExamsCubit>().changeCategory(category);
          }
          if (tabIndex != null) {
            context
                .findAncestorStateOfType<MainLayoutScreenState>()
                ?.setSelectedIndex(tabIndex);
          } else if (route != null) {
            Navigator.pushNamed(context, route);
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 6,
                offset: Offset(0, 2.h),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Center(
                  child: PhosphorIcon(icon, color: accentColor, size: 19.sp),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5.sp,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 1.5.h),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 9.sp,
                        color: isDark
                            ? Colors.white60
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              PhosphorIcon(
                PhosphorIcons.caretRightBold,
                size: 11.sp,
                color: isDark ? Colors.white30 : const Color(0xFFCBD5E1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PerformanceDashboardCard extends StatelessWidget {
  const _PerformanceDashboardCard({required this.performanceData});
  final Map<String, dynamic> performanceData;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final summary = performanceData['dashboardSummary'] is Map
        ? performanceData['dashboardSummary'] as Map<String, dynamic>
        : <String, dynamic>{};

    final overall = performanceData['overall'] is Map
        ? performanceData['overall'] as Map<String, dynamic>
        : <String, dynamic>{};

    final List<dynamic> subjectWiseList = [
      if (performanceData['subjectWise'] is List)
        ...performanceData['subjectWise'] as List,
      if (performanceData['dppData'] is Map &&
          (performanceData['dppData'] as Map)['subjectWise'] is List)
        ...(performanceData['dppData'] as Map)['subjectWise'] as List,
    ];

    final hasAnalytics =
        performanceData.isNotEmpty &&
        (summary.isNotEmpty ||
            overall.isNotEmpty ||
            subjectWiseList.isNotEmpty);

    if (!hasAnalytics) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.insights_outlined,
              color: AppTheme.primary.withValues(alpha: 0.75),
              size: 30.sp,
            ),
            SizedBox(height: 8.h),
            Text(
              'Performance will appear here',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Complete an exam to see your actual accuracy and subject insights.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.sp,
                color: isDark ? Colors.white60 : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    int totalAttemptedAll = 0;
    int totalCorrectAll = 0;

    final Map<String, Map<String, int>> subjectTotals = {};

    for (final s in subjectWiseList) {
      if (s is! Map) continue;
      final rawName = (s['subject'] ?? s['subjectName'] ?? 'Uncategorised')
          .toString()
          .trim();
      final subjectName = rawName.isEmpty ? 'Uncategorised' : rawName;
      final attempted = (s['attempted'] is num)
          ? (s['attempted'] as num).toInt()
          : 0;
      final correct = (s['correct'] is num) ? (s['correct'] as num).toInt() : 0;

      totalAttemptedAll += attempted;
      totalCorrectAll += correct;

      final current =
          subjectTotals[subjectName] ?? {'attempted': 0, 'correct': 0};
      subjectTotals[subjectName] = {
        'attempted': (current['attempted'] ?? 0) + attempted,
        'correct': (current['correct'] ?? 0) + correct,
      };
    }

    // Fallback if subjectTotals is empty but summary has subjectAccuracies
    if (subjectTotals.isEmpty && summary['subjectAccuracies'] is Map) {
      final accMap = summary['subjectAccuracies'] as Map;
      for (final entry in accMap.entries) {
        final key = entry.key.toString();
        final val = (entry.value is num)
            ? (entry.value as num).toDouble()
            : (double.tryParse(entry.value.toString()) ?? 0.0);
        subjectTotals[key] = {'attempted': 100, 'correct': val.round()};
      }
    }

    // Accuracy = correct / attempted; never the marks percentage, which goes
    // negative with negative marking (QA 6.5).
    final double calcOverallAcc = totalAttemptedAll > 0
        ? (totalCorrectAll / totalAttemptedAll) * 100
        : (double.tryParse(overall['accuracy']?.toString() ?? '0') ?? 0.0)
              .clamp(0.0, 100.0);

    final String overallAccuracyStr =
        summary['overallAccuracy']?.toString() ??
        '${calcOverallAcc.toStringAsFixed(1)}%';

    final List<MapEntry<String, double>> subjectAccuracies =
        subjectTotals.entries.map((e) {
          final att = e.value['attempted'] ?? 0;
          final corr = e.value['correct'] ?? 0;
          final acc = att > 0 ? (corr / att) * 100.0 : 0.0;
          return MapEntry(e.key, acc);
        }).toList()..sort((a, b) => b.value.compareTo(a.value));

    final displaySubjects = subjectAccuracies.take(4).toList();

    const List<Color> subjectColors = [
      Color(0xFF10B981), // Emerald
      Color(0xFFF59E0B), // Amber
      Color(0xFF6366F1), // Indigo
      Color(0xFF8B5CF6), // Violet
      Color(0xFF0EA5E9), // Sky Blue
    ];

    final counts = summary['counts'] is Map
        ? summary['counts'] as Map<String, dynamic>
        : <String, dynamic>{};

    final Map dppDataMap = performanceData['dppData'] is Map
        ? performanceData['dppData'] as Map
        : {};

    final int liveExams = (counts['liveExams'] is num)
        ? (counts['liveExams'] as num).toInt()
        : ((overall['totalExamsTaken'] is num)
              ? (overall['totalExamsTaken'] as num).toInt()
              : (performanceData['recentExams'] is List
                    ? (performanceData['recentExams'] as List).length
                    : 0));

    final int dpps = (counts['dpps'] is num)
        ? (counts['dpps'] as num).toInt()
        : (dppDataMap['recentDpps'] is List
              ? (dppDataMap['recentDpps'] as List).length
              : 0);

    // Backend key is practicePaperCount; keep the old key as fallback.
    final dynamic practiceRaw =
        counts['practicePaperCount'] ?? counts['practicePapers'];
    final int practicePapers = practiceRaw is num ? practiceRaw.toInt() : 0;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: Offset(0, 3.h),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFE5E7EB),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OVERALL ACCURACY',
                      style: TextStyle(
                        fontSize: 8.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF9CA3AF),
                        letterSpacing: 0.8,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      overallAccuracyStr,
                      style: TextStyle(
                        fontSize: 26.sp,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppTheme.primary,
                        letterSpacing: -1.0,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.trending_up,
                            color: const Color(0xFF059669),
                            size: 11.sp,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'Overall Accuracy',
                            style: TextStyle(
                              color: const Color(0xFF059669),
                              fontSize: 8.5.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              Container(
                height: 80.h,
                width: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : const Color(0xFFE5E7EB),
              ),
              SizedBox(width: 10.w),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SUBJECT ACCURACY',
                      style: TextStyle(
                        fontSize: 8.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF9CA3AF),
                        letterSpacing: 0.8,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    if (displaySubjects.isNotEmpty)
                      ...displaySubjects.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final color = subjectColors[idx % subjectColors.length];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: idx == displaySubjects.length - 1 ? 0 : 5.h,
                          ),
                          child: _buildSubjectAccuracyProgress(
                            isDark,
                            item.key,
                            item.value,
                            color,
                          ),
                        );
                      })
                    else
                      Padding(
                        padding: EdgeInsets.only(top: 4.h),
                        child: Text(
                          'Subject accuracy will appear after your first submitted assessment.',
                          style: TextStyle(
                            fontSize: 9.sp,
                            color: isDark
                                ? Colors.white60
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Divider(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFF3F4F6),
            height: 1,
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBottomKpi(
                context,
                isDark: isDark,
                label: 'Live Exams',
                value: '$liveExams',
                icon: PhosphorIcons.videoConference,
                // Practice tab (index 1); pushing studentExams crashed (no ExamsCubit).
                onTap: () => context
                    .findAncestorStateOfType<MainLayoutScreenState>()
                    ?.setSelectedIndex(1),
              ),
              _buildBottomKpi(
                context,
                isDark: isDark,
                label: 'DPPs',
                value: '$dpps',
                icon: PhosphorIcons.target,
                onTap: () {
                  context.read<ExamsCubit>().changeCategory('DPPs');
                  context
                      .findAncestorStateOfType<MainLayoutScreenState>()
                      ?.setSelectedIndex(1);
                },
              ),
              _buildBottomKpi(
                context,
                isDark: isDark,
                label: 'Practice Papers',
                value: '$practicePapers',
                icon: PhosphorIcons.clipboardText,
                // Practice tab (index 1); pushing studentExams crashed (no ExamsCubit).
                onTap: () => context
                    .findAncestorStateOfType<MainLayoutScreenState>()
                    ?.setSelectedIndex(1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectAccuracyProgress(
    bool isDark,
    String subject,
    double accuracyPct,
    Color color,
  ) {
    final progress = (accuracyPct / 100.0).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.9)
                      : const Color(0xFF374151),
                ),
              ),
            ),
            Text(
              '${accuracyPct.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 8.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        SizedBox(height: 3.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(10.r),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4.h,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomKpi(
    BuildContext context, {
    required bool isDark,
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(5.w),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: PhosphorIcon(icon, size: 11.sp, color: Colors.grey),
            ),
            SizedBox(width: 6.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 7.5.sp,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveExamCard extends StatelessWidget {
  const _ActiveExamCard({required this.exam});

  final ExamModel exam;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFE5E7EB),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: Offset(0, 3.h),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64.w,
            child: Column(
              children: [
                Container(
                  height: 48.w,
                  width: 48.w,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: PhosphorIcon(
                    PhosphorIcons.clipboardText,
                    color: AppTheme.primary,
                    size: 22.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    'Active now',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 7.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exam.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.sp,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.calendar,
                      size: 10.sp,
                      color: const Color(0xFF9CA3AF),
                    ),
                    SizedBox(width: 4.w),
                    Flexible(
                      child: Text(
                        exam.subjectName.isNotEmpty
                            ? exam.subjectName
                            : 'All subjects',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.sp,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    PhosphorIcon(
                      PhosphorIcons.clock,
                      size: 10.sp,
                      color: const Color(0xFF9CA3AF),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '${exam.durationMinutes} min',
                      style: TextStyle(
                        fontSize: 9.sp,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    _buildPillBadge(
                      isDark,
                      '${exam.totalQuestions ?? exam.questions.length} Questions',
                    ),
                    SizedBox(width: 4.w),
                    _buildPillBadge(isDark, '${exam.totalMarks} Marks'),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          ElevatedButton(
            onPressed: () async {
              // MainLayoutScreen reloads Home, the exam list and Progress
              // when this route closes (RouteAware.didPopNext).
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ExamPlayerScreen(exam: exam)),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: Text(
              'Start',
              style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillBadge(bool isDark, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white70 : const Color(0xFF6B7280),
          fontSize: 7.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ContinueLearningCard extends StatelessWidget {
  const _ContinueLearningCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFE5E7EB),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: Offset(0, 3.h),
          ),
        ],
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/open_book.webp',
            height: 40.w,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => PhosphorIcon(
              PhosphorIcons.bookOpen,
              color: AppTheme.primary,
              size: 28.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Physics Electrostatics Notes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11.sp,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(10.r)),
                        child: LinearProgressIndicator(
                          value: 0.45,
                          backgroundColor: const Color(0xFFF1F5F9),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.primary,
                          ),
                          minHeight: 4.h,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      '45%',
                      style: TextStyle(
                        fontSize: 8.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          OutlinedButton(
            onPressed: () {
              context
                  .findAncestorStateOfType<MainLayoutScreenState>()
                  ?.setSelectedIndex(2);
            },
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
              side: BorderSide(
                color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
              ),
            ),
            child: Text(
              'Resume',
              style: TextStyle(
                fontSize: 9.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '',
      showAppBar: false,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Row(
              children: [
                _buildPulseCircle(26),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPulseBar(width: 100, height: 12),
                    const SizedBox(height: 6),
                    _buildPulseBar(width: 160, height: 16),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildPulseBox(height: 130),
            const SizedBox(height: 24),
            _buildPulseBox(height: 160),
            const SizedBox(height: 24),
            _buildPulseBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildPulseBar({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildPulseCircle(double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE5E7EB),
    );
  }

  Widget _buildPulseBox({required double height}) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

class _AvailableCoursesList extends StatelessWidget {
  const _AvailableCoursesList();

  @override
  Widget build(BuildContext context) {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    final coursesState = context.watch<CoursesCubit>().state;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (coursesState.status == CoursesStatus.initial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<CoursesCubit>().loadCoursesAndBatches(token);
      });
    }

    final enrolledCourseIds = <String>{};
    final enrolledCourseNames = <String>{};

    for (final b in coursesState.myBatches) {
      if (b.courseId != null && b.courseId!.isNotEmpty) {
        enrolledCourseIds.add(b.courseId!);
      }
      if (b.id.isNotEmpty) {
        enrolledCourseIds.add(b.id);
      }
      if (b.courseName != null && b.courseName!.trim().isNotEmpty) {
        enrolledCourseNames.add(b.courseName!.trim().toLowerCase());
      }
      if (b.name.trim().isNotEmpty) {
        enrolledCourseNames.add(b.name.trim().toLowerCase());
      }
    }

    final seenIds = <String>{};
    final seenNames = <String>{};
    final unenrolledCourses = <CourseModel>[];

    for (final course in coursesState.courses) {
      final cId = course.id;
      final cName = course.name.trim().toLowerCase();

      final isEnrolled =
          (cId.isNotEmpty && enrolledCourseIds.contains(cId)) ||
          (cName.isNotEmpty && enrolledCourseNames.contains(cName));
      if (isEnrolled) {
        continue;
      }

      if ((cId.isNotEmpty && seenIds.contains(cId)) ||
          (cName.isNotEmpty && seenNames.contains(cName))) {
        continue;
      }

      if (cId.isNotEmpty) seenIds.add(cId);
      if (cName.isNotEmpty) seenNames.add(cName);
      unenrolledCourses.add(course);
    }

    if (unenrolledCourses.isEmpty) {
      if (coursesState.status == CoursesStatus.loading) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 12.h, left: 4.w, right: 4.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Available Courses',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                      letterSpacing: -0.4,
                    ),
                  ),
                  GestureDetector(
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.courses),
                    child: Row(
                      children: [
                        Text(
                          'View All',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16.sp,
                          color: AppTheme.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 140.h,
              child: const Center(child: CircularProgressIndicator()),
            ),
            SizedBox(height: 24.h),
          ],
        );
      }
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 10.h, left: 4.w, right: 4.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available Courses',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                  letterSpacing: -0.4,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppRoutes.courses),
                child: Row(
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 14.sp,
                      color: AppTheme.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 160.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            physics: const BouncingScrollPhysics(),
            itemCount: unenrolledCourses.length,
            separatorBuilder: (context, index) => SizedBox(width: 10.w),
            itemBuilder: (context, index) {
              final course = unenrolledCourses[index];

              final palette = [
                const Color(0xFF0033A0),
                const Color(0xFFE8470A),
                const Color(0xFF7B3FA0),
                const Color(0xFF059669),
                const Color(0xFFD97706),
              ];

              final hexColorStr = course.color?.replaceAll('#', '');
              final courseColor = AppTheme.readableAccent(
                context,
                hexColorStr != null && hexColorStr.length == 6
                    ? Color(int.parse('FF$hexColorStr', radix: 16))
                    : palette[index % palette.length],
              );

              // The whole card opens the course, not just the Enroll button.
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.courseDetail,
                  arguments: course.id,
                ),
                child: Container(
                  width: 220.w,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE5E7EB),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.2 : 0.03,
                        ),
                        blurRadius: 12,
                        offset: Offset(0, 3.h),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.r),
                    child: Column(
                      children: [
                        Container(
                          height: 4.h,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                courseColor,
                                courseColor.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(12.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(6.w),
                                          decoration: BoxDecoration(
                                            color: courseColor.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8.r,
                                            ),
                                          ),
                                          child: PhosphorIcon(
                                            PhosphorIcons.graduationCap,
                                            color: courseColor,
                                            size: 14.sp,
                                          ),
                                        ),
                                        if (course.tag != null &&
                                            course.tag!.isNotEmpty) ...[
                                          SizedBox(width: 6.w),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 6.w,
                                              vertical: 2.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primary
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(6.r),
                                            ),
                                            child: Text(
                                              course.tag!,
                                              style: TextStyle(
                                                color: AppTheme.primary,
                                                fontSize: 8.sp,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      course.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF111827),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      course.subtitle ??
                                          course.description ??
                                          'Comprehensive preparation package.',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white60
                                            : const Color(0xFF6B7280),
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        if (course.actualFee != null) ...[
                                          Text(
                                            '₹${course.actualFee}',
                                            style: TextStyle(
                                              fontSize: 9.sp,
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              color: isDark
                                                  ? Colors.white38
                                                  : const Color(0xFF9CA3AF),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(width: 4.w),
                                        ],
                                        Text(
                                          '₹${course.fee}',
                                          style: TextStyle(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w900,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pushNamed(
                                          context,
                                          AppRoutes.courseDetail,
                                          arguments: course.id,
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primary,
                                        foregroundColor: Colors.white,
                                        // Default 48dp tap target doesn't
                                        // shrink with the fixed-height card.
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10.w,
                                          vertical: 6.h,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8.r,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        'Enroll',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10.sp,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 18.h),
      ],
    );
  }
}
