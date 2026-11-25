import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/core/widgets/app_scaffold.dart';
import 'package:lms/core/widgets/section_card.dart';
import 'package:lms/features/extras/presentation/cubit/extras_cubit.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/live_classes/data/services/zoom_service.dart';
import 'package:lms/features/profile/presentation/cubit/profile_cubit.dart';

class LiveClassesScreen extends StatefulWidget {
  const LiveClassesScreen({super.key, this.drawer});

  final Widget? drawer;

  @override
  State<LiveClassesScreen> createState() => _LiveClassesScreenState();
}

class _LiveClassesScreenState extends State<LiveClassesScreen> {
  @override
  void initState() {
    super.initState();
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    context.read<ExtrasCubit>().loadLiveClasses(token);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Live Classes',
      showAppBar: true,
      drawer: widget.drawer,
      body: BlocBuilder<ExtrasCubit, ExtrasState>(
        builder: (context, state) {
          if (state.status == ExtrasStatus.loading &&
              state.liveClasses.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.error != null) {
            return Center(
              child: Text(
                state.error!,
                style: const TextStyle(color: AppTheme.error),
              ),
            );
          }

          if (state.liveClasses.isEmpty) {
            return const Center(child: Text('No upcoming live classes.'));
          }

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: state.liveClasses.length,
            itemBuilder: (context, index) {
              final lc = state.liveClasses[index];
              return SectionCard(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              color: AppTheme.error,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          lc.status,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      lc.topic,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      '${lc.subjectName} • ${lc.teacherName}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    if (lc.startTime != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${lc.startTime!.day}/${lc.startTime!.month}/${lc.startTime!.year} - ${lc.startTime!.hour}:${lc.startTime!.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        final user = context
                            .read<AuthBloc>()
                            .state
                            .session
                            ?.user;
                        final role = user?.role;
                        final isParent = role == 'PARENT' || role == 'GUARDIAN';

                        if (isParent) {
                          if (lc.status.toUpperCase() != 'COMPLETED') {
                            return const Text(
                              'Waiting for class to end...',
                              style: TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            );
                          }

                          final attended = lc.participants.isNotEmpty;
                          if (attended) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Joined',
                                style: TextStyle(
                                  color: AppTheme.success,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          } else {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Absent',
                                style: TextStyle(
                                  color: AppTheme.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }
                        }

                        // Student View
                        return SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              final token =
                                  context
                                      .read<AuthBloc>()
                                      .state
                                      .session
                                      ?.accessToken ??
                                  '';
                              String studentName = '';
                              if (user != null) {
                                final fn = user.firstName ?? '';
                                final ln = user.lastName ?? '';
                                final full = '$fn $ln'.trim();
                                if (full.isNotEmpty &&
                                    full != 'Student' &&
                                    full != 'User') {
                                  studentName = full;
                                } else if (user.name.isNotEmpty &&
                                    user.name != 'Student' &&
                                    user.name != 'User') {
                                  studentName = user.name;
                                }
                              }

                              if (studentName.isEmpty) {
                                try {
                                  final p = context
                                      .read<ProfileCubit>()
                                      .state
                                      .profile;
                                  if (p != null) {
                                    final fn = p.firstName ?? '';
                                    final ln = p.lastName ?? '';
                                    final full = '$fn $ln'.trim();
                                    if (full.isNotEmpty &&
                                        full != 'Student' &&
                                        full != 'User') {
                                      studentName = full;
                                    } else if (p.name.isNotEmpty &&
                                        p.name != 'Student') {
                                      studentName = p.name;
                                    }
                                  }
                                } catch (_) {}
                              }

                              if (studentName.isEmpty) {
                                studentName = 'Student';
                              }

                              ZoomService().joinMeeting(
                                context: context,
                                meetingId: lc.id,
                                meetingLink: lc.meetingLink,
                                displayName: studentName,
                                token: token,
                              );
                            },
                            icon: const Icon(Icons.video_call),
                            label: const Text('Join Class'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
