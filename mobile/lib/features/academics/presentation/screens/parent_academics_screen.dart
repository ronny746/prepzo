import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/core/widgets/app_scaffold.dart';
import 'package:lms/core/widgets/section_card.dart';
import 'package:lms/features/academics/data/models/academics_models.dart';
import 'package:lms/features/academics/presentation/cubit/academics_cubit.dart';
import 'package:lms/features/academics/presentation/cubit/parent_academics_cubit.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';

class ParentAcademicsScreen extends StatefulWidget {
  const ParentAcademicsScreen({super.key, this.drawer});
  
  final Widget? drawer;

  @override
  State<ParentAcademicsScreen> createState() => _ParentAcademicsScreenState();
}

class _ParentAcademicsScreenState extends State<ParentAcademicsScreen> {
  @override
  void initState() {
    super.initState();
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    context.read<ParentAcademicsCubit>().loadTasks(token);
  }

  @override
  Widget build(BuildContext context) {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    
    return BlocBuilder<ParentAcademicsCubit, AcademicsState>(
      builder: (context, state) {
        if (state.status == AcademicsStatus.loading && state.tasks.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final academics = state.tasks.where((t) => t.taskType.toLowerCase() != 'assignment' && t.taskType.toLowerCase() != 'homework').toList();

        return AppScaffold(
          title: 'Academics & Attendance',
          showAppBar: widget.drawer != null ? true : false,
          drawer: widget.drawer,
          onRefresh: () => context.read<ParentAcademicsCubit>().loadTasks(token),
          body: ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(state.error!, style: const TextStyle(color: AppTheme.error)),
                ),
              if (academics.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.verified_user_rounded, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('All caught up!', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              else
                ...academics.map((task) => _ParentTaskItem(task: task)),
              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }
}

class _ParentTaskItem extends StatelessWidget {
  const _ParentTaskItem({required this.task});
  final AcademicTask task;

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
        ],
      ),
    );
  }
}
