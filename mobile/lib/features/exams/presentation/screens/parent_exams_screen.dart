import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/core/widgets/app_scaffold.dart';
import 'package:lms/core/widgets/section_card.dart';
import 'package:lms/features/exams/data/models/exams_models.dart';
import 'package:lms/features/exams/presentation/cubit/exams_cubit.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/exams/presentation/screens/parent_exam_analysis_screen.dart'
    show ParentExamAnalysisScreen;
import 'package:intl/intl.dart';

class ParentExamsScreen extends StatefulWidget {
  const ParentExamsScreen({super.key, this.drawer});

  final Widget? drawer;

  @override
  State<ParentExamsScreen> createState() => _ParentExamsScreenState();
}

class _ParentExamsScreenState extends State<ParentExamsScreen> {
  String _selectedChildId = 'ALL';

  @override
  void initState() {
    super.initState();
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    context.read<ExamsCubit>().loadParentExams(token);
  }

  @override
  Widget build(BuildContext context) {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';

    return BlocBuilder<ExamsCubit, ExamsState>(
      builder: (context, state) {
        if (state.status == ExamsStatus.loading && state.parentExams.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final Map<String, String> childrenMap = {};
        for (var exam in state.parentExams) {
          if (exam.childId.isNotEmpty) {
            childrenMap[exam.childId] = exam.childName.isNotEmpty
                ? exam.childName
                : 'Student';
          }
        }

        final filteredExams = _selectedChildId == 'ALL'
            ? state.parentExams
            : state.parentExams
                  .where((e) => e.childId == _selectedChildId)
                  .toList();

        return AppScaffold(
          title: "My Children's Exams",
          showAppBar: widget.drawer != null ? true : false,
          drawer: widget.drawer,
          onRefresh: () => context.read<ExamsCubit>().loadParentExams(token),
          body: ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    state.error!,
                    style: const TextStyle(color: AppTheme.error),
                  ),
                ),
              const Text(
                'Track your children\'s performance and view detailed analysis',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 16),

              if (childrenMap.length > 1) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('All Children'),
                          selected: _selectedChildId == 'ALL',
                          onSelected: (_) =>
                              setState(() => _selectedChildId = 'ALL'),
                          selectedColor: AppTheme.primary,
                          labelStyle: TextStyle(
                            color: _selectedChildId == 'ALL'
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...childrenMap.entries.map((entry) {
                        final isSelected = _selectedChildId == entry.key;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(entry.value),
                            selected: isSelected,
                            onSelected: (_) =>
                                setState(() => _selectedChildId = entry.key),
                            selectedColor: AppTheme.primary,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (filteredExams.isEmpty)
                const _EmptyState()
              else
                ...filteredExams.map((e) => _ParentExamCard(exam: e)),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  size: 48,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Exams Scheduled',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your children don\'t have any upcoming or active exams right now.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParentExamCard extends StatelessWidget {
  const _ParentExamCard({required this.exam});
  final ParentExamModel exam;

  @override
  Widget build(BuildContext context) {
    final bool isCompleted =
        exam.submissionStatus == 'SUBMITTED' ||
        exam.submissionStatus == 'AUTO_SUBMITTED';
    final bool inProgress = exam.submissionStatus == 'IN_PROGRESS';
    final now = DateTime.now();

    String statusText = 'Active Now';
    Color statusColor = AppTheme.primary;
    IconData statusIcon = Icons.play_arrow;

    if (isCompleted) {
      statusText = 'Completed';
      statusColor = AppTheme.success;
      statusIcon = Icons.check_circle;
    } else if (inProgress) {
      statusText = 'In Progress';
      statusColor = Colors.orange;
      statusIcon = Icons.access_time;
    } else if (exam.startTime != null && now.isBefore(exam.startTime!)) {
      statusText = 'Upcoming';
      statusColor = Colors.grey.shade600;
      statusIcon = Icons.access_time;
    } else if (exam.endTime != null && now.isAfter(exam.endTime!)) {
      statusText = 'Missed';
      statusColor = AppTheme.error;
      statusIcon = Icons.error_outline;
    }

    final df = DateFormat('dd/MM/yyyy, HH:mm:ss');

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
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Student: ${exam.childName}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            exam.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppTheme.ink(context),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Questions:',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              Text(
                '${exam.totalQuestions}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Marks:',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              Text(
                '${exam.totalMarks}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          if (exam.startTime != null)
            Text(
              'Starts: ${df.format(exam.startTime!)}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          if (exam.endTime != null)
            Text(
              'Ends: ${df.format(exam.endTime!)}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),

          if (isCompleted) ...[
            if (exam.score != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Score:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    Text(
                      '${exam.score} / ${exam.totalMarks}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ParentExamAnalysisScreen(
                        examId: exam.id,
                        childId: exam.childId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('View Analysis'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
