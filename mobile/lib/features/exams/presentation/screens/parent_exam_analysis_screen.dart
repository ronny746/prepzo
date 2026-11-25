import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/exams/data/repositories/exams_repository.dart';
import 'package:lms/features/exams/presentation/cubit/parent_exam_analysis_cubit.dart';
import 'package:lms/features/exams/data/models/exams_models.dart';
import 'package:lms/core/widgets/math_html_renderer.dart';
import 'package:lms/core/config/app_config.dart';
import 'package:lms/core/constants/result_strings.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class ParentExamAnalysisScreen extends StatelessWidget {
  const ParentExamAnalysisScreen({
    super.key,
    required this.examId,
    this.childId,
  });

  final String examId;
  final String? childId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
        return ParentExamAnalysisCubit(
          examsRepository: context.read<ExamsRepository>(),
        )..loadAnalysis(token, examId, childId: childId);
      },
      child: _ParentExamAnalysisView(examId: examId),
    );
  }
}

class _ParentExamAnalysisView extends StatefulWidget {
  const _ParentExamAnalysisView({required this.examId});
  final String examId;

  @override
  State<_ParentExamAnalysisView> createState() => _ParentExamAnalysisViewState();
}

class _ParentExamAnalysisViewState extends State<_ParentExamAnalysisView> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ParentExamAnalysisCubit, ParentExamAnalysisState>(
      builder: (context, state) {
        if (state.status == ParentExamAnalysisStatus.loading) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              title: const Text('Exam Analysis'),
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
            ),
            body: const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primary,
                strokeWidth: 2.5,
              ),
            ),
          );
        }

        if (state.status == ParentExamAnalysisStatus.failure) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              title: const Text('Exam Analysis'),
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
            ),
            body: Center(
              child: Text(
                state.error ?? 'Failed to load analysis',
                style: const TextStyle(color: AppTheme.error),
              ),
            ),
          );
        }

        final analysis = state.analysis;
        if (analysis == null) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              title: const Text('Exam Analysis'),
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
            ),
            body: const Center(child: Text('No analysis data available.')),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text('Exam Analysis'),
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0F172A),
          ),
          body: _WebAlignedAnalysisView(
            analysis: analysis,
            examId: widget.examId,
          ),
        );
      },
    );
  }
}

/// Mirrors the data and conditions used by the student web analysis page.
class _WebAlignedAnalysisView extends StatefulWidget {
  const _WebAlignedAnalysisView({
    required this.analysis,
    required this.examId,
  });
  final ParentExamAnalysisModel analysis;
  final String examId;

  @override
  State<_WebAlignedAnalysisView> createState() => _WebAlignedAnalysisViewState();
}

class _WebAlignedAnalysisViewState extends State<_WebAlignedAnalysisView> {
  String? _activeSubject;

  @override
  void initState() {
    super.initState();
    final subjects = widget.analysis.subjectStats.keys;
    _activeSubject = subjects.isNotEmpty ? subjects.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final analysis = widget.analysis;
    final totalMarks = analysis.totalMarks > 0
        ? analysis.totalMarks
        : analysis.details.fold<num>(0, (sum, item) => sum + item.marks);
    final subjects = analysis.subjectStats.keys.toList();
    final selectedSubject = _activeSubject ??
        (subjects.isNotEmpty ? subjects.first : 'General');
    final questions = analysis.details
        .where((question) => question.subjectName == selectedSubject)
        .toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WebScoreCard(
            score: analysis.score,
            totalMarks: totalMarks,
            submissionStatus: analysis.submissionStatus,
          ),
          const SizedBox(height: 12),
          _WebSubjectBreakdown(stats: analysis.subjectStats),
          const SizedBox(height: 12),
          _WebDifficultyBreakdown(stats: analysis.difficultyStats),
          const SizedBox(height: 12),
          _WebTopicBreakdown(stats: analysis.topicStats),
          const SizedBox(height: 12),
          _WebQuestionReviewSection(
            subjects: subjects,
            selectedSubject: selectedSubject,
            questions: questions,
            analysis: analysis,
            onSubjectSelected: (subj) => setState(() => _activeSubject = subj),
          ),
        ],
      ),
    );
  }
}

class _WebScoreCard extends StatelessWidget {
  const _WebScoreCard({
    required this.score,
    required this.totalMarks,
    required this.submissionStatus,
  });
  final num score, totalMarks;
  final String submissionStatus;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            const PhosphorIcon(PhosphorIcons.trophy, color: Colors.amberAccent, size: 40),
            const SizedBox(height: 6),
            const Text('Total Score', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('$score / $totalMarks', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
            if (submissionStatus.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Status: ${submissionStatus.replaceAll("_", " ")}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      );
}

class _WebCollapsibleCard extends StatefulWidget {
  const _WebCollapsibleCard({
    required this.title,
    required this.child,
    this.initialExpanded = false,
    this.icon,
    this.badgeText,
  });

  final String title;
  final Widget child;
  final bool initialExpanded;
  final IconData? icon;
  final String? badgeText;

  @override
  State<_WebCollapsibleCard> createState() => _WebCollapsibleCardState();
}

class _WebCollapsibleCardState extends State<_WebCollapsibleCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    PhosphorIcon(widget.icon!, size: 18, color: AppTheme.primary),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  if (widget.badgeText != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.badgeText!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  PhosphorIcon(
                    _isExpanded ? PhosphorIcons.caretUp : PhosphorIcons.caretDown,
                    color: const Color(0xFF64748B),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

class _WebSubjectBreakdown extends StatelessWidget {
  const _WebSubjectBreakdown({required this.stats});
  final Map<String, ExamAnalysisStatsModel> stats;

  @override
  Widget build(BuildContext context) => _WebCollapsibleCard(
        title: 'Subject-wise Breakdown',
        icon: PhosphorIcons.books,
        badgeText: '${stats.length} Subjects',
        child: stats.isEmpty
            ? const Text('No subject data available.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B)))
            : Wrap(
                spacing: 10,
                runSpacing: 10,
                children: stats.entries.map((entry) {
                  final value = entry.value;
                  final skipped = value.totalQuestions - value.attempted;
                  return Container(
                    width: 156,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('Score: ${value.score} / ${value.totalMarks}', style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text('✓ ${value.correct}   ✕ ${value.wrong}   — $skipped', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      ],
                    ),
                  );
                }).toList(),
              ),
      );
}

class _WebDifficultyBreakdown extends StatelessWidget {
  const _WebDifficultyBreakdown({required this.stats});
  final Map<String, ExamAnalysisStatsModel> stats;

  @override
  Widget build(BuildContext context) => _WebCollapsibleCard(
        title: 'Difficulty-wise Performance',
        icon: PhosphorIcons.chartBar,
        child: Column(
          children: ['Easy', 'Medium', 'Hard'].map((name) {
            final value = stats[name] ??
                ExamAnalysisStatsModel.fromJson(const <String, dynamic>{});
            final color = name == 'Easy'
                ? const Color(0xFF059669)
                : name == 'Medium'
                    ? const Color(0xFFD97706)
                    : const Color(0xFFDC2626);
            final skipped = value.totalQuestions - value.attempted;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(children: [
                    Text('$name Level', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: color)),
                    const Spacer(),
                    Text('${value.accuracy}% Accuracy', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
                  ]),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (value.accuracy / 100).clamp(0, 1).toDouble(),
                      color: color,
                      backgroundColor: const Color(0xFFF1F5F9),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Questions: ${value.totalQuestions}   Correct: ${value.correct}   Wrong: ${value.wrong}   Skipped: $skipped', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                ],
              ),
            );
          }).toList(),
        ),
      );
}

class _WebTopicBreakdown extends StatelessWidget {
  const _WebTopicBreakdown({required this.stats});
  final Map<String, ExamAnalysisStatsModel> stats;

  @override
  Widget build(BuildContext context) => _WebCollapsibleCard(
        title: 'Topic-wise Performance',
        icon: PhosphorIcons.listChecks,
        badgeText: '${stats.length} Topics',
        child: stats.isEmpty
            ? const Text('No topic data available.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B)))
            : Column(
                children: stats.entries.map((entry) {
                  final value = entry.value;
                  final label = value.accuracy >= 70 ? 'Strong' : value.accuracy >= 50 ? 'Medium' : 'Weak';
                  final color = label == 'Strong' ? const Color(0xFF059669) : label == 'Medium' ? const Color(0xFFD97706) : const Color(0xFFDC2626);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Score: ${value.score} / ${value.totalMarks} M · Accuracy: ${value.accuracy}%',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: color.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 9),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
      );
}

class _WebQuestionReviewSection extends StatelessWidget {
  const _WebQuestionReviewSection({
    required this.subjects,
    required this.selectedSubject,
    required this.questions,
    required this.analysis,
    required this.onSubjectSelected,
  });

  final List<String> subjects;
  final String selectedSubject;
  final List<ExamAnalysisDetailModel> questions;
  final ParentExamAnalysisModel analysis;
  final ValueChanged<String> onSubjectSelected;

  @override
  Widget build(BuildContext context) {
    return _WebCollapsibleCard(
      title: 'Question Review & Solutions',
      icon: PhosphorIcons.article,
      badgeText: '${questions.length} Qs',
      initialExpanded: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subjects.isNotEmpty) ...[
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: subjects.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final subject = subjects[index];
                  final selected = subject == selectedSubject;
                  return ChoiceChip(
                    label: Text(
                      '$subject (${analysis.subjectStats[subject]?.score ?? 0} M)',
                    ),
                    selected: selected,
                    // Primary fill + white text: the old 20% tint left the
                    // default white selected label unreadable.
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : const Color(0xFF0F172A),
                    ),
                    checkmarkColor: Colors.white,
                    onSelected: (_) => onSubjectSelected(subject),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (questions.isEmpty)
            const _EmptyAnalysisState(message: 'No questions are available for this subject.')
          else
            ...questions.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _WebQuestionReviewCard(
                  number: entry.key + 1,
                  question: entry.value,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WebQuestionReviewCard extends StatelessWidget {
  const _WebQuestionReviewCard({required this.number, required this.question});
  final int number;
  final ExamAnalysisDetailModel question;

  String _formatHtml(String value) {
    if (value.isEmpty) return '';
    final String domain = AppConfig.webUrl;
    return value.replaceAll('src="/', 'src="$domain/');
  }

  @override
  Widget build(BuildContext context) {
    final attempted = question.userAnswer?.hasAnswer ?? false;
    final status = !attempted
        ? ResultStrings.skipped
        : question.isCorrect
            ? 'Correct (+${question.marksObtained})'
            : 'Incorrect (${question.marksObtained})';
    final Color badgeColor = !attempted
        ? const Color(0xFF64748B)
        : question.isCorrect
            ? const Color(0xFF059669)
            : const Color(0xFFDC2626);
    final Color badgeBg = !attempted
        ? const Color(0xFFF1F5F9)
        : question.isCorrect
            ? const Color(0xFFECFDF5)
            : const Color(0xFFFEF2F2);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Q $number',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primary, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              const Spacer(),
              Text(
                'Marks: +${question.marks} / -${question.negativeMarks}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AnalysisContent(html: _formatHtml(question.questionText), fontSize: 15),
          const SizedBox(height: 14),
          if (question.options.isEmpty && attempted)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${ResultStrings.yourAnswer}: ${question.userAnswer?.subjectiveAnswerText ?? question.userAnswer?.selectedOptionId ?? ''}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ...question.options.map((option) {
            final selected = question.userAnswer?.selectedOptionId == option.id;
            final border = option.isCorrect
                ? const Color(0xFF10B981)
                : selected
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFE2E8F0);
            final background = option.isCorrect
                ? const Color(0xFFECFDF5)
                : selected
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFFAFAFA);
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: background,
                border: Border.all(color: border, width: (option.isCorrect || selected) ? 1.5 : 1.0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (option.isCorrect) ...[
                    const PhosphorIcon(PhosphorIcons.checkCircle, color: Color(0xFF059669), size: 18),
                    const SizedBox(width: 8),
                  ] else if (selected) ...[
                    const PhosphorIcon(PhosphorIcons.xCircle, color: Color(0xFFDC2626), size: 18),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: _AnalysisContent(html: _formatHtml(option.text), fontSize: 14),
                  ),
                ],
              ),
            );
          }),
          if (question.explanation.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      PhosphorIcon(PhosphorIcons.lightbulb, color: AppTheme.primary, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'EXPLANATION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _AnalysisContent(html: _formatHtml(question.explanation), fontSize: 13),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyAnalysisState extends StatelessWidget {
  const _EmptyAnalysisState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          message,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          textAlign: TextAlign.center,
        ),
      );
}

/// Avoids creating a WebView for ordinary question and option text. The
/// WebView renderer remains available for real HTML, images, or MathJax.
class _AnalysisContent extends StatelessWidget {
  const _AnalysisContent({required this.html, required this.fontSize});
  final String html;
  final double fontSize;

  bool get _needsHtmlRenderer =>
      RegExp(r'<(?:img|math)\b|\\\\\(|\$[^$]+\$', caseSensitive: false)
          .hasMatch(html);

  String get _plainText => html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .trim();

  @override
  Widget build(BuildContext context) {
    if (_needsHtmlRenderer) {
      return MathHtmlRenderer(htmlContent: html, baseFontSize: fontSize);
    }
    return Text(
      _plainText,
      style: TextStyle(
        fontSize: fontSize,
        height: 1.45,
        color: const Color(0xFF1F2937),
      ),
    );
  }
}
