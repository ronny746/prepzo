import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/features/exams/data/models/exams_models.dart';
import 'package:lms/features/exams/presentation/screens/parent_exam_analysis_screen.dart' show ParentExamAnalysisScreen;
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/exams/presentation/cubit/exams_cubit.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class StudentResultsScreen extends StatefulWidget {
  const StudentResultsScreen({super.key});

  @override
  State<StudentResultsScreen> createState() => _StudentResultsScreenState();
}

class _StudentResultsScreenState extends State<StudentResultsScreen> {
  @override
  void initState() {
    super.initState();
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    context.read<ExamsCubit>().loadStudentExams(token);
  }

  Future<void> _handleRefresh() async {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    await context.read<ExamsCubit>().loadStudentExams(token);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExamsCubit, ExamsState>(
      builder: (context, state) {
        final results = state.results;

        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          body: RefreshIndicator(
            onRefresh: _handleRefresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  if (state.status == ExamsStatus.loading && results.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 60.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (results.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 80.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            PhosphorIcon(PhosphorIcons.trophy, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            const Text('No results published yet', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                            const Text('Take an exam to view your score card.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    _OverallStatsGrid(results: results),
                    const SizedBox(height: 28),
                    if (results.length > 1) ...[
                      const _SectionHeader(title: 'Improvement Curve'),
                      const SizedBox(height: 12),
                      _PerformanceLineChart(results: results),
                      const SizedBox(height: 28),
                    ],
                    const _SectionHeader(title: 'Individual Exam Reports'),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: results.length,
                      itemBuilder: (context, index) => _ResultItemCard(result: results[index]),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Hub',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              letterSpacing: -1.0,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Track your progress, view detailed analysis, and improve your scores.',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverallStatsGrid extends StatelessWidget {
  const _OverallStatsGrid({required this.results});
  final List<ExamResultModel> results;

  @override
  Widget build(BuildContext context) {
    final double avgScore = results.isEmpty
        ? 0.0
        : results.map((e) => e.percentage.toDouble()).reduce((a, b) => a + b) / results.length;
    final double bestScore = results.isEmpty
        ? 0.0
        : results.map((e) => e.percentage.toDouble()).reduce((a, b) => a > b ? a : b);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _StatSummaryCard(
          label: 'Avg. Score',
          value: '${avgScore.toStringAsFixed(1)}%',
          icon: PhosphorIcons.chartLineUp,
          color: AppTheme.primary,
        ),
        _StatSummaryCard(
          label: 'Best Score',
          value: '${bestScore.toInt()}%',
          icon: PhosphorIcons.trophy,
          color: AppTheme.warning,
        ),
        _StatSummaryCard(
          label: 'Tests Taken',
          value: '${results.length}',
          icon: PhosphorIcons.clipboardText,
          color: AppTheme.secondary,
        ),
        _StatSummaryCard(
          label: 'Global Rank',
          value: '#42',
          icon: PhosphorIcons.globe,
          color: Colors.purple,
        ),
      ],
    );
  }
}

class _StatSummaryCard extends StatelessWidget {
  const _StatSummaryCard({required this.label, required this.value, required this.icon, required this.color});
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PhosphorIcon(icon, color: color, size: 24),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceLineChart extends StatelessWidget {
  const _PerformanceLineChart({required this.results});
  final List<ExamResultModel> results;

  @override
  Widget build(BuildContext context) {
    final spots = results.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.percentage.toDouble());
    }).toList();

    return Container(
      height: 200,
      padding: const EdgeInsets.only(top: 24, right: 24, left: 8, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppTheme.primary,
              barWidth: 4,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultItemCard extends StatelessWidget {
  const _ResultItemCard({required this.result});
  final ExamResultModel result;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = result.percentage >= 70 ? AppTheme.success : (result.percentage >= 40 ? AppTheme.warning : AppTheme.error);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: PhosphorIcon(PhosphorIcons.clipboardText, color: statusColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.examTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF111827),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Score: ${result.score}/${result.totalMarks}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${result.percentage.toInt()}%',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    result.percentage >= 40 ? 'Passed' : 'Failed',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ParentExamAnalysisScreen(examId: result.examId),
                  ),
                );
              },
              icon: const PhosphorIcon(PhosphorIcons.chartLineUp, size: 16),
              label: const Text('View Detailed Analysis'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
                foregroundColor: AppTheme.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Color(0xFF111827),
          letterSpacing: -0.4,
        ),
      ),
    );
  }
}
