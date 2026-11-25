import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/constants/result_strings.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/exams/data/repositories/exams_repository.dart';
import 'package:lms/features/exams/presentation/cubit/parent_exam_analysis_cubit.dart';
import 'package:lms/features/exams/data/models/exams_models.dart';
import 'package:lms/core/widgets/math_html_renderer.dart';
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
  State<_ParentExamAnalysisView> createState() =>
      _ParentExamAnalysisViewState();
}

class _ParentExamAnalysisViewState extends State<_ParentExamAnalysisView> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ParentExamAnalysisCubit, ParentExamAnalysisState>(
      builder: (context, state) {
        if (state.status == ParentExamAnalysisStatus.loading) {
          return Scaffold(
            backgroundColor: AppTheme.page(context),
            appBar: AppBar(
              title: const Text('Exam Analysis'),
              elevation: 0,
              backgroundColor: AppTheme.card(context),
              foregroundColor: AppTheme.ink(context),
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
            backgroundColor: AppTheme.page(context),
            appBar: AppBar(
              title: const Text('Exam Analysis'),
              elevation: 0,
              backgroundColor: AppTheme.card(context),
              foregroundColor: AppTheme.ink(context),
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
            backgroundColor: AppTheme.page(context),
            appBar: AppBar(
              title: const Text('Exam Analysis'),
              elevation: 0,
              backgroundColor: AppTheme.card(context),
              foregroundColor: AppTheme.ink(context),
            ),
            body: const Center(child: Text('No analysis data available.')),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.page(context),
          appBar: AppBar(
            title: const Text('Exam Analysis'),
            elevation: 0,
            backgroundColor: AppTheme.card(context),
            foregroundColor: AppTheme.ink(context),
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
  const _WebAlignedAnalysisView({required this.analysis, required this.examId});
  final ParentExamAnalysisModel analysis;
  final String examId;

  @override
  State<_WebAlignedAnalysisView> createState() =>
      _WebAlignedAnalysisViewState();
}

class _WebAlignedAnalysisViewState extends State<_WebAlignedAnalysisView> {
  String? _activeSubject;
  bool _reviewExpanded = false;

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
    final selectedSubject =
        _activeSubject ?? (subjects.isNotEmpty ? subjects.first : 'General');
    final questions = analysis.details
        .where((question) => question.subjectName == selectedSubject)
        .toList();

    // A lazy list: only the question cards on screen are built, each with
    // one small WebView, so maths-heavy solutions no longer freeze the app.
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverList.list(
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
              _WebQuestionReviewHeader(
                subjects: subjects,
                selectedSubject: selectedSubject,
                questionCount: questions.length,
                analysis: analysis,
                expanded: _reviewExpanded,
                onToggle: () =>
                    setState(() => _reviewExpanded = !_reviewExpanded),
                onSubjectSelected: (subj) =>
                    setState(() => _activeSubject = subj),
              ),
            ],
          ),
        ),
        if (_reviewExpanded)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: questions.isEmpty
                ? const SliverToBoxAdapter(
                    child: _EmptyAnalysisState(
                      message: 'No questions are available for this subject.',
                    ),
                  )
                : SliverList.builder(
                    itemCount: questions.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _WebQuestionReviewCard(
                        key: ValueKey(
                          'review_${selectedSubject}_${questions[index].questionId}_$index',
                        ),
                        number: index + 1,
                        question: questions[index],
                      ),
                    ),
                  ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
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
        const PhosphorIcon(
          PhosphorIcons.trophy,
          color: Colors.amberAccent,
          size: 40,
        ),
        const SizedBox(height: 6),
        const Text(
          'Total Score',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$score / $totalMarks',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
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
    this.icon,
    this.badgeText,
  });

  final String title;
  final Widget child;
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
    _isExpanded = false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.line(context)),
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
                    PhosphorIcon(
                      widget.icon!,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink(context),
                      ),
                    ),
                  ),
                  if (widget.badgeText != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
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
                    _isExpanded
                        ? PhosphorIcons.caretUp
                        : PhosphorIcons.caretDown,
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
        ? const Text(
            'No subject data available.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          )
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
                  color: AppTheme.soft(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.line(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Score: ${value.score} / ${value.totalMarks}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '✓ ${value.correct}   ✕ ${value.wrong}   — $skipped',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                      ),
                    ),
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
        final value =
            stats[name] ??
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
              Row(
                children: [
                  Text(
                    '$name Level',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: color,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${value.accuracy}% Accuracy',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
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
              Text(
                'Questions: ${value.totalQuestions}   Correct: ${value.correct}   Wrong: ${value.wrong}   Skipped: $skipped',
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
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
        ? const Text(
            'No topic data available.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          )
        : Column(
            children: stats.entries.map((entry) {
              final value = entry.value;
              final label = value.accuracy >= 70
                  ? 'Strong'
                  : value.accuracy >= 50
                  ? 'Medium'
                  : 'Weak';
              final color = label == 'Strong'
                  ? const Color(0xFF059669)
                  : label == 'Medium'
                  ? const Color(0xFFD97706)
                  : const Color(0xFFDC2626);
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
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: AppTheme.ink(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Score: ${value.score} / ${value.totalMarks} M · Accuracy: ${value.accuracy}%',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
  );
}

/// Header of "Question Review & Solutions": title, expand toggle and the
/// subject chips. The question cards themselves are a lazy sliver list.
class _WebQuestionReviewHeader extends StatelessWidget {
  const _WebQuestionReviewHeader({
    required this.subjects,
    required this.selectedSubject,
    required this.questionCount,
    required this.analysis,
    required this.expanded,
    required this.onToggle,
    required this.onSubjectSelected,
  });

  final List<String> subjects;
  final String selectedSubject;
  final int questionCount;
  final ParentExamAnalysisModel analysis;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onSubjectSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.line(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const PhosphorIcon(
                    PhosphorIcons.article,
                    size: 18,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Question Review & Solutions',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink(context),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$questionCount Qs',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PhosphorIcon(
                    expanded ? PhosphorIcons.caretUp : PhosphorIcons.caretDown,
                    color: const Color(0xFF64748B),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (expanded && subjects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: subjects.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final subject = subjects[index];
                    final selected = subject == selectedSubject;
                    // Solid primary with white text when selected, dark text
                    // on white otherwise (white on pale yellow was unreadable).
                    return ChoiceChip(
                      label: Text(
                        '$subject (${analysis.subjectStats[subject]?.score ?? 0} M)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF334155),
                        ),
                      ),
                      selected: selected,
                      showCheckmark: true,
                      checkmarkColor: Colors.white,
                      selectedColor: AppTheme.primary,
                      backgroundColor: AppTheme.card(context),
                      side: BorderSide(
                        color: selected
                            ? AppTheme.primary
                            : const Color(0xFFCBD5E1),
                      ),
                      onSelected: (_) => onSubjectSelected(subject),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WebQuestionReviewCard extends StatelessWidget {
  const _WebQuestionReviewCard({
    super.key,
    required this.number,
    required this.question,
  });
  final int number;
  final ExamAnalysisDetailModel question;

  /// Skipped unless the student actually answered. A question only marked
  /// for review (no answer) is skipped, not "Incorrect (0)".
  bool get _attempted {
    // Newer servers say it directly.
    if (question.attempted != null) return question.attempted!;
    final ua = question.userAnswer;
    if (ua == null) return false;
    if (ua.hasValue) return true;
    return question.isCorrect || question.marksObtained != 0;
  }

  static String _escape(String v) => v
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static String _img(String url) =>
      '<img src="${QuestionImage.resolve(url).replaceAll('"', '&quot;')}" />';

  bool _isSelected(ExamAnalysisOptionModel option) {
    final ua = question.userAnswer;
    if (ua == null || option.id.isEmpty) return false;
    return ua.selectedOptionId == option.id ||
        ua.selectedOptionIds.contains(option.id);
  }

  /// Question, options and solution in ONE html page (one WebView per card
  /// instead of one per option), so maths-heavy reviews stay light.
  String _cardHtml() {
    final b = StringBuffer('<div>${question.questionText}</div>');
    final img = question.questionImageUrl;
    if (img != null && !question.questionText.contains(img)) b.write(_img(img));

    if (question.isTypedAnswer) {
      final typed = question.userAnswer?.typedAnswer;
      final correctText = question.correctAnswerText.trim();
      final answered = (typed ?? '').isNotEmpty;
      final ok = question.isCorrect;
      final border = !answered ? '#CBD5E1' : (ok ? '#10B981' : '#EF4444');
      final bg = !answered ? '#F8FAFC' : (ok ? '#ECFDF5' : '#FEF2F2');
      b.write(
        '<div style="margin-top:10px;border:1.5px solid $border;background:$bg;'
        'border-radius:12px;padding:8px 12px;color:#0F172A">'
        '<div style="font-size:11px;font-weight:700;color:#64748B">YOUR ANSWER</div>'
        '<div style="font-weight:700">${answered ? _escape(typed!) : 'Not answered'}</div></div>',
      );
      if (correctText.isNotEmpty) {
        b.write(
          '<div style="margin-top:8px;border:1.5px solid #10B981;background:#ECFDF5;'
          'border-radius:12px;padding:8px 12px;color:#0F172A">'
          '<div style="font-size:11px;font-weight:700;color:#059669">CORRECT ANSWER</div>'
          '<div style="font-weight:700">$correctText</div></div>',
        );
      }
    } else if (question.options.isNotEmpty) {
      b.write('<div style="margin-top:10px">');
      for (final option in question.options) {
        final selected = _isSelected(option);
        final border = option.isCorrect
            ? '#10B981'
            : selected
            ? '#EF4444'
            : '#E2E8F0';
        final bg = option.isCorrect
            ? '#ECFDF5'
            : selected
            ? '#FEF2F2'
            : '#FAFAFA';
        final mark = option.isCorrect
            ? '<span style="color:#059669;font-weight:800">&#10003;&nbsp;</span>'
            : selected
            ? '<span style="color:#DC2626;font-weight:800">&#10007;&nbsp;</span>'
            : '';
        final tag = selected
            ? '<span style="font-size:10px;font-weight:700;color:#64748B">&nbsp;(your answer)</span>'
            : '';
        final optImg =
            option.imageUrl != null && !option.text.contains(option.imageUrl!)
            ? _img(option.imageUrl!)
            : '';
        b.write(
          '<div style="border:${option.isCorrect || selected ? 1.5 : 1}px solid $border;'
          'background:$bg;color:#0F172A;border-radius:12px;padding:8px 12px;margin:8px 0">'
          '$mark${option.text}$tag$optImg</div>',
        );
      }
      b.write('</div>');
    }
    if (question.explanation.isNotEmpty) {
      b.write(
        '<div style="margin-top:12px;padding:12px;border-radius:14px;'
        'background:rgba(201,148,32,0.06);border:1px solid rgba(201,148,32,0.2)">'
        '<div style="font-size:10px;font-weight:900;letter-spacing:0.5px;'
        'color:#B7791F;margin-bottom:4px">EXPLANATION</div>'
        '<div style="font-size:13px">${question.explanation}</div></div>',
      );
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final attempted = _attempted;
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
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.line(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wrap, not Row: on a narrow phone the marks move to the next line
          // instead of overflowing.
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Q $number',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              Text(
                'Marks: +${question.marks} / -${question.negativeMarks}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          MathHtmlRenderer(
            htmlContent: _cardHtml(),
            baseFontSize: 15,
            fontColor: AppTheme.ink(context),
          ),
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
      color: AppTheme.card(context),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.line(context)),
    ),
    child: Text(
      message,
      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
      textAlign: TextAlign.center,
    ),
  );
}
