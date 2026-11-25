import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/core/widgets/app_scaffold.dart';
import 'package:lms/core/widgets/section_card.dart';
import 'package:lms/features/dashboard/presentation/cubit/student_dashboard_cubit.dart';
import 'package:lms/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/dashboard/data/models/dashboard_models.dart';

class StudentScheduleScreen extends StatelessWidget {
  const StudentScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';

    return BlocProvider(
      create: (context) => StudentDashboardCubit(
        dashboardRepository: context.read<DashboardRepository>(),
      )..loadDashboard(token),
      child: Builder(
        builder: (context) {
          return AppScaffold(
            title: 'My Schedule',
            showAppBar: true,
            onRefresh: () async {
              final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
              await context.read<StudentDashboardCubit>().loadDashboard(token);
            },
            body: BlocBuilder<StudentDashboardCubit, StudentDashboardState>(
              builder: (context, state) {
                if (state.status == StudentDashboardStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.data == null) {
                  return const Center(child: Text('Unable to load schedule.'));
                }

                final schedule = state.data!.schedule;

                if (schedule.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 60, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No schedule found for this week.', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                // Group by Day
                final Map<String, List<DashboardItem>> grouped = {};
                for (var s in schedule) {
                  final day = s.tertiary ?? 'Unknown';
                  grouped[day] = [...(grouped[day] ?? []), s];
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: grouped.keys.length,
                  itemBuilder: (context, index) {
                    final day = grouped.keys.elementAt(index);
                    final items = grouped[day]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                          child: Text(
                            day,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                        ),
                        ...items.map((s) => SectionCard(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.access_time_rounded, color: AppTheme.primary, size: 18),
                              ),
                              title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text('${s.subtitle}${s.value != null && s.value!.isNotEmpty ? ' • ${s.value}' : ''}', style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                        )),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
