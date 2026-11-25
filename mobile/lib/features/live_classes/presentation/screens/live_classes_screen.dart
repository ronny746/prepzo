import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/widgets/app_scaffold.dart';
import 'package:lms/features/live_classes/presentation/cubit/live_classes_cubit.dart';
import 'package:lms/features/live_classes/data/services/zoom_service.dart';
import 'package:lms/features/live_classes/data/repositories/live_classes_repository.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/live_classes/data/models/live_classes_models.dart';
import 'package:lms/features/profile/presentation/cubit/profile_cubit.dart';

class LiveClassesScreen extends StatefulWidget {
  const LiveClassesScreen({super.key, this.drawer});
  final Widget? drawer;

  @override
  State<LiveClassesScreen> createState() => _LiveClassesScreenState();
}

class _LiveClassesScreenState extends State<LiveClassesScreen> {
  final ZoomService _zoomService = ZoomService();

  @override
  void initState() {
    super.initState();
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    context.read<LiveClassesCubit>().fetchLiveClasses(token);
    _zoomService.initZoom();
  }

  void _joinClass(LiveClass liveClass) {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    final user = context.read<AuthBloc>().state.session?.user;

    String studentName = '';
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

    if (studentName.isEmpty) {
      try {
        final p = context.read<ProfileCubit>().state.profile;
        if (p != null) {
          final fn = p.firstName ?? '';
          final ln = p.lastName ?? '';
          final full = '$fn $ln'.trim();
          if (full.isNotEmpty && full != 'Student' && full != 'User') {
            studentName = full;
          } else if (p.name.isNotEmpty && p.name != 'Student') {
            studentName = p.name;
          }
        }
      } catch (_) {}
    }

    if (studentName.isEmpty) {
      studentName = 'Student';
    }

    context.read<LiveClassesRepository>().recordLiveClassJoin(
      liveClassId: liveClass.id,
      token: token,
    );

    _zoomService.joinMeeting(
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
    return AppScaffold(
      drawer: widget.drawer,
      title: 'Live Classes',
      showAppBar: true,
      onRefresh: () async {
        final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
        await context.read<LiveClassesCubit>().fetchLiveClasses(token);
      },
      body: BlocBuilder<LiveClassesCubit, LiveClassesState>(
        builder: (context, state) {
          if (state is LiveClassesLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is LiveClassesError) {
            return Center(child: Text('Error: ${state.message}'));
          } else if (state is LiveClassesLoaded) {
            if (state.classes.isEmpty) {
              return const Center(
                child: Text(
                  'No active live classes at the moment',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(0),
              itemCount: state.classes.length,
              itemBuilder: (context, index) {
                final liveClass = state.classes[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    color: Colors.red,
                                    size: 8,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          liveClass.subject,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.person,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Teacher: ${liveClass.teacherName}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        if (liveClass.courseName.isNotEmpty ||
                            liveClass.batchName.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.groups_rounded,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  [
                                    if (liveClass.courseName.isNotEmpty)
                                      liveClass.courseName,
                                    if (liveClass.batchName.isNotEmpty)
                                      liveClass.batchName,
                                  ].join(' • '),
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (liveClass.startTime != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${liveClass.startTime!.day}/${liveClass.startTime!.month}/${liveClass.startTime!.year} - ${liveClass.startTime!.hour}:${liveClass.startTime!.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.video_call),
                            label: const Text('Join Class'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => _joinClass(liveClass),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
          return const SizedBox();
        },
      ),
    );
  }
}
