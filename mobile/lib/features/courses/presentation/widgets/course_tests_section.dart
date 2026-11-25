import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/courses/data/models/course_test_model.dart';
import 'package:lms/features/courses/data/repositories/courses_repository.dart';
import 'package:lms/features/exams/presentation/screens/exam_player_screen.dart';
import 'package:lms/features/exams/presentation/screens/parent_exam_analysis_screen.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// "Tests in this course" on the course page: free tests first, which any
/// signed-in student can take, then the paid ones (locked until enrolled).
class CourseTestsSection extends StatefulWidget {
  const CourseTestsSection({
    super.key,
    required this.courseId,
    required this.isEnrolled,
    required this.accent,
    required this.onUnlock,
  });

  final String courseId;
  final bool isEnrolled;
  final Color accent;

  /// Opens checkout for the course (used by locked tests).
  final VoidCallback onUnlock;

  @override
  State<CourseTestsSection> createState() => _CourseTestsSectionState();
}

enum _Filter { free, all }

class _CourseTestsSectionState extends State<CourseTestsSection> {
  static const _pageSize = 6;
  static const _freeGreen = Color(0xFF059669);

  List<CourseTest>? _tests;
  String? _error;
  _Filter _filter = _Filter.all;
  bool _filterChosen = false;
  int _visible = _pageSize;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    try {
      final tests = await context.read<CoursesRepository>().getCourseTests(
        token: token,
        courseId: widget.courseId,
      );
      if (!mounted) return;
      setState(() {
        _tests = tests;
        _error = null;
        // Not enrolled: open on the free tests they can take right now.
        if (!_filterChosen) {
          _filter = !widget.isEnrolled && tests.any((t) => t.isFree)
              ? _Filter.free
              : _Filter.all;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load tests. Pull down to retry.');
    }
  }

  List<CourseTest> get _shown {
    final all = _tests ?? const <CourseTest>[];
    return _filter == _Filter.free ? all.where((t) => t.isFree).toList() : all;
  }

  Future<void> _open(CourseTest t) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ExamPlayerScreen(exam: t.exam)),
    );
    if (mounted) _load(); // show "Attempted" + score after a test
  }

  Future<void> _openAnalysis(CourseTest t) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParentExamAnalysisScreen(examId: t.exam.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tests = _tests;

    if (tests == null && _error == null) {
      return _shell(
        isDark,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
        ),
      );
    }
    if (_error != null) {
      return _shell(
        isDark,
        child: Row(
          children: [
            Expanded(
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (tests!.isEmpty) return const SizedBox.shrink();

    final freeCount = tests.where((t) => t.isFree).length;
    final shown = _shown;
    final visible = shown.take(_visible).toList();

    return _shell(
      isDark,
      freeCount: freeCount,
      total: tests.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (freeCount > 0) ...[
            if (!widget.isEnrolled) _freeBanner(freeCount),
            const SizedBox(height: 12),
            _filterTabs(isDark, freeCount, tests.length),
            const SizedBox(height: 12),
          ],
          for (final t in visible) ...[
            _TestCard(
              test: t,
              isEnrolled: widget.isEnrolled,
              accent: widget.accent,
              onStart: () => _open(t),
              onAnalysis: () => _openAnalysis(t),
              onUnlock: widget.onUnlock,
            ),
            const SizedBox(height: 10),
          ],
          if (shown.length > visible.length)
            OutlinedButton.icon(
              onPressed: () => setState(() => _visible += _pageSize * 2),
              icon: const PhosphorIcon(PhosphorIcons.caretDown, size: 16),
              label: Text('Show more (${shown.length - visible.length} left)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: widget.accent,
                side: BorderSide(color: widget.accent.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _shell(
    bool isDark, {
    required Widget child,
    int? freeCount,
    int? total,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: PhosphorIcon(
                  PhosphorIcons.exam,
                  color: widget.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tests in this course',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    if (total != null)
                      Text(
                        freeCount != null && freeCount > 0
                            ? '$total tests · $freeCount free'
                            : '$total tests',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _freeBanner(int freeCount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _freeGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _freeGreen.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const PhosphorIcon(PhosphorIcons.gift, color: _freeGreen, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Try $freeCount ${freeCount == 1 ? 'test' : 'tests'} free, no purchase needed. '
              'Same exam screen and analysis as the full series.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppTheme.isDarkOf(context)
                    ? const Color(0xFF6EE7B7)
                    : const Color(0xFF065F46),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterTabs(bool isDark, int freeCount, int total) {
    Widget tab(_Filter f, String label) {
      final active = _filter == f;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            _filter = f;
            _filterChosen = true;
            _visible = _pageSize;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: active
                  ? (isDark ? AppTheme.darkBackground : Colors.white)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? widget.accent : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          tab(_Filter.free, 'Free ($freeCount)'),
          tab(_Filter.all, 'All tests ($total)'),
        ],
      ),
    );
  }
}

class _TestCard extends StatelessWidget {
  const _TestCard({
    required this.test,
    required this.isEnrolled,
    required this.accent,
    required this.onStart,
    required this.onAnalysis,
    required this.onUnlock,
  });

  final CourseTest test;
  final bool isEnrolled;
  final Color accent;
  final VoidCallback onStart;
  final VoidCallback onAnalysis;
  final VoidCallback onUnlock;

  static const _green = Color(0xFF059669);
  static final _dateFmt = DateFormat('d MMM, h:mm a');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final e = test.exam;
    final now = DateTime.now();
    final locked = !test.isFree && !isEnrolled;
    final notOpen = e.startTime != null && e.startTime!.isAfter(now);
    final ended = e.endTime != null && e.endTime!.isBefore(now);

    final meta = [
      if ((e.totalQuestions ?? 0) > 0) '${e.totalQuestions} Qs',
      '${e.totalMarks} marks',
      if (e.durationMinutes > 0) _duration(e.durationMinutes),
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : (test.isFree ? const Color(0xFFF7FEFB) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: test.isFree
              ? _green.withValues(alpha: 0.25)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (test.isFree)
                _chip('FREE', _green, filled: true)
              else
                _chip(
                  isEnrolled ? 'INCLUDED' : 'PREMIUM',
                  isEnrolled ? accent : const Color(0xFF64748B),
                  icon: isEnrolled ? null : PhosphorIcons.lockSimple,
                ),
              _chip(test.kind.toUpperCase(), const Color(0xFF475569)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            test.shortTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            meta,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statusLine(notOpen, ended)),
              const SizedBox(width: 10),
              _action(locked: locked, notOpen: notOpen, ended: ended),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusLine(bool notOpen, bool ended) {
    final e = test.exam;
    String text;
    IconData icon;
    Color color = const Color(0xFF64748B);
    if (test.isAttempted) {
      text = e.score != null
          ? 'Attempted · ${e.score}/${e.totalMarks}'
          : 'Attempted';
      icon = PhosphorIcons.checkCircle;
      color = _green;
    } else if (notOpen) {
      text = 'Opens ${_dateFmt.format(e.startTime!)}';
      icon = PhosphorIcons.calendarBlank;
    } else if (ended) {
      text = 'Closed';
      icon = PhosphorIcons.clockCounterClockwise;
    } else if (e.endTime != null) {
      text = 'Open till ${DateFormat('d MMM').format(e.endTime!)}';
      icon = PhosphorIcons.broadcast;
      color = _green;
    } else {
      text = 'Open now';
      icon = PhosphorIcons.broadcast;
      color = _green;
    }
    return Row(
      children: [
        PhosphorIcon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _action({
    required bool locked,
    required bool notOpen,
    required bool ended,
  }) {
    if (locked) {
      return _button(
        'Unlock',
        PhosphorIcons.lockSimpleOpen,
        accent,
        onUnlock,
        outlined: true,
      );
    }
    if (test.isAttempted) {
      // A finished test opens its result and solutions.
      return _button(
        'Analysis',
        PhosphorIcons.chartBar,
        accent,
        onAnalysis,
        outlined: true,
      );
    }
    if (notOpen || ended) {
      return const SizedBox.shrink();
    }
    return _button(
      test.isInProgress ? 'Resume' : (test.isFree ? 'Start free' : 'Start'),
      PhosphorIcons.play,
      test.isFree ? _green : accent,
      onStart,
    );
  }

  Widget _button(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool outlined = false,
  }) {
    final style = outlined
        ? OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withValues(alpha: 0.5)),
          )
        : ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0,
          );
    final shaped = style.copyWith(
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      ),
      minimumSize: const WidgetStatePropertyAll(Size.zero),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PhosphorIcon(icon, size: 14, color: outlined ? color : Colors.white),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
      ],
    );
    return outlined
        ? OutlinedButton(onPressed: onTap, style: shaped, child: child)
        : ElevatedButton(onPressed: onTap, style: shaped, child: child);
  }

  Widget _chip(
    String text,
    Color color, {
    bool filled = false,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            PhosphorIcon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: filled ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }

  static String _duration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h hr' : '$h hr $m min';
  }
}
