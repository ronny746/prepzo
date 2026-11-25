import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/core/widgets/app_scaffold.dart';
import 'package:lms/core/widgets/glass_card.dart';
import 'package:lms/core/widgets/section_card.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/dashboard/data/models/dashboard_models.dart';
import 'package:lms/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:lms/features/dashboard/presentation/cubit/teacher_dashboard_cubit.dart';
import 'package:lms/routes/app_router.dart';

class TeacherDashboardScreen extends StatelessWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';

    return BlocProvider(
      create: (_) => TeacherDashboardCubit(
        dashboardRepository: context.read<DashboardRepository>(),
      )..loadDashboard(token),
      child: const _TeacherDashboardView(),
    );
  }
}

class _TeacherDashboardView extends StatelessWidget {
  const _TeacherDashboardView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TeacherDashboardCubit, TeacherDashboardState>(
      builder: (context, state) {
        if (state.status == TeacherDashboardStatus.loading ||
            state.status == TeacherDashboardStatus.initial) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state.status == TeacherDashboardStatus.failure ||
            state.data == null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(state.errorMessage ?? 'Unable to load dashboard'),
              ),
            ),
          );
        }

        final data = state.data!;

        return AppScaffold(
          title: 'Teacher Dashboard',
          actions: [
            IconButton(
              tooltip: 'Notifications',
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.notifications),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            IconButton(
              tooltip: 'Apply for leave',
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.teacherLeave),
              icon: const Icon(Icons.event_busy_outlined),
            ),
            IconButton(
              onPressed: () {
                context.read<AuthBloc>().add(const AuthLogoutRequested());
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout),
            ),
          ],
          header: GlassCard(
            color: AppTheme.secondary.withValues(alpha: 0.92),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${data.teacherName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${data.userCode} • ${data.role}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              _TeacherSection(
                title: 'Assigned Subjects',
                items: data.subjects,
                error: data.subjectsError,
              ),
              const SizedBox(height: 20),
              _TeacherSection(
                title: 'Classes',
                items: data.classes,
                error: data.classesError,
              ),
              const SizedBox(height: 20),
              _TeacherSection(
                title: 'Sections',
                items: data.sections,
                error: data.sectionsError,
              ),
              const SizedBox(height: 20),
              _TeacherSection(
                title: 'Students',
                items: data.students,
                error: data.studentsError,
              ),
              const SizedBox(height: 20),
              _TeacherSection(
                title: 'Enrollments',
                items: data.enrollments,
                error: data.enrollmentsError,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TeacherSection extends StatelessWidget {
  const _TeacherSection({required this.title, required this.items, this.error});

  final String title;
  final List<DashboardItem> items;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      child: Column(
        children: [
          if (error != null && error!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text('Backend response: $error'),
            )
          else if (items.isEmpty)
            const Text('No records available from this API yet.')
          else
            ...items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.title),
                subtitle: Text(
                  [item.subtitle, item.tertiary]
                      .whereType<String>()
                      .where((value) => value.isNotEmpty)
                      .join(' • '),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
