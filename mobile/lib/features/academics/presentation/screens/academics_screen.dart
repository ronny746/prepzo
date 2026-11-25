import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/core/widgets/app_scaffold.dart';
import 'package:lms/core/widgets/section_card.dart';
import 'package:lms/features/academics/data/models/academics_models.dart';
import 'package:lms/features/academics/presentation/cubit/academics_cubit.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';

class AcademicsScreen extends StatefulWidget {
  const AcademicsScreen({super.key});

  @override
  State<AcademicsScreen> createState() => _AcademicsScreenState();
}

class _AcademicsScreenState extends State<AcademicsScreen> {
  @override
  void initState() {
    super.initState();
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    context.read<AcademicsCubit>().loadTasks(token);
  }

  void _openSubmitDialog(BuildContext context, AcademicTask task, String token) {
    final contentController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Submit ${task.taskType}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(task.description),
            const SizedBox(height: 16),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(
                labelText: 'Submission Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              context.read<AcademicsCubit>().submitTask(
                token: token,
                taskId: task.id,
                taskType: task.taskType,
                content: contentController.text,
              ).then((_) {
                if (ctx.mounted) Navigator.pop(ctx);
              }).catchError((e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              });
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    
    return BlocBuilder<AcademicsCubit, AcademicsState>(
      builder: (context, state) {
        if (state.status == AcademicsStatus.loading && state.tasks.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return AppScaffold(
          title: 'Homework & Tasks',
          showAppBar: false,
          onRefresh: () async {
            await context.read<AcademicsCubit>().loadTasks(token);
          },
          body: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(state.error!, style: const TextStyle(color: AppTheme.error)),
                ),
              if (state.tasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user_rounded, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('All caught up!', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              else
                ...state.tasks.map((task) => _TaskItem(
                  task: task,
                  onSubmitTap: () => _openSubmitDialog(context, task, token),
                )),
              const SizedBox(height: 100), // spacing for bottom nav
            ],
          ),
        ),
        );
      },
    );
  }
}

class _TaskItem extends StatelessWidget {
  const _TaskItem({required this.task, required this.onSubmitTap});
  final AcademicTask task;
  final VoidCallback onSubmitTap;

  @override
  Widget build(BuildContext context) {
    final isSubmitted = task.isSubmitted;
    
    Color statusColor = AppTheme.warning;
    String statusText = 'Pending';
    if (task.submissionStatus == 'graded') {
      statusColor = AppTheme.primary;
      statusText = 'Graded (${task.marksObtained}/${task.maxMarks})';
    } else if (isSubmitted) {
      statusColor = AppTheme.success;
      statusText = 'Submitted';
    }

    return SectionCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  task.taskType,
                  style: const TextStyle(color: AppTheme.secondary, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(task.subjectName, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          if (task.dueDate != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Due: ${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: isSubmitted ? null : onSubmitTap,
              child: Text(isSubmitted ? 'Already Submitted' : 'Submit Work'),
            ),
          ),
        ],
      ),
    );
  }
}
