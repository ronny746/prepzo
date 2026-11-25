import 'package:lms/core/utils/practice_accuracy.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:lms/features/exams/data/models/exams_models.dart';
import 'package:lms/features/exams/data/repositories/exams_repository.dart';
import 'package:lms/features/exams/presentation/cubit/exams_cubit.dart';
import 'package:lms/features/exams/presentation/screens/dpp_practice_player_screen.dart';
import 'package:lms/features/exams/presentation/screens/parent_exam_analysis_screen.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Progress & Performance Screen with minimal, clean UI and smooth scrolling.
class StudentResultsScreen extends StatelessWidget {
  const StudentResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';

    return BlocProvider(
      create: (context) =>
          ExamsCubit(examsRepository: context.read<ExamsRepository>())
            ..loadStudentExams(token),
      child: const _StudentPerformanceView(),
    );
  }
}

class _StudentPerformanceView extends StatefulWidget {
  const _StudentPerformanceView();

  @override
  State<_StudentPerformanceView> createState() =>
      _StudentPerformanceViewState();
}

class _StudentPerformanceViewState extends State<_StudentPerformanceView> {
  String _activeTab = 'EXAMS'; // 'EXAMS' | 'DPPS'
  final Map<String, bool> _expandedSubjects = {};
  Future<List<Map<String, dynamic>>>? _flagsFuture;
  bool _autoSwitchedToDpps = false;
  // The tab shell keeps this page alive in an IndexedStack, so initState only
  // runs once; TickerMode flips when the tab is hidden/shown, which is our
  // "became visible again" signal.
  bool _wasVisible = true;

  @override
  void initState() {
    super.initState();
    _loadTopicFlags();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_wasVisible) {
      // Fire-and-forget silent reload: existing data stays on screen, so no
      // spinner flash, but a just-submitted test shows up immediately.
      _handleRefresh();
    }
    _wasVisible = visible;
  }

  /// Accuracy = correct / attempted * 100 from per-subject counts. Never the
  /// score percentage, which goes negative with negative marking.
  String _accuracyFromSubjects(List<dynamic> subjects) {
    int attempted = 0;
    int correct = 0;
    for (final s in subjects) {
      if (s is! Map) continue;
      attempted += int.tryParse(s['attempted']?.toString() ?? '') ?? 0;
      correct += int.tryParse(s['correct']?.toString() ?? '') ?? 0;
    }
    final acc = attempted > 0 ? correct / attempted * 100 : 0.0;
    return acc.toStringAsFixed(2);
  }

  void _loadTopicFlags() {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    if (token.isNotEmpty) {
      _flagsFuture = context.read<DashboardRepository>().getTopicFlags(
            token: token,
          );
    }
  }

  Future<void> _handleRefresh() async {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    setState(() {
      _loadTopicFlags();
    });
    await Future.wait([
      context.read<ExamsCubit>().loadStudentExams(token),
      _flagsFuture ?? Future.value([]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Progress & Results',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: AppTheme.primary,
          backgroundColor: Colors.white,
          child: BlocBuilder<ExamsCubit, ExamsState>(
            builder: (context, state) {
              if (state.status == ExamsStatus.loading &&
                  state.performanceData.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primary,
                    strokeWidth: 2.5,
                  ),
                );
              }

              final performanceData = state.performanceData;
              final overall = performanceData['overall'] is Map
                  ? performanceData['overall'] as Map<String, dynamic>
                  : <String, dynamic>{};
              final List<dynamic> subjectWise =
                  performanceData['subjectWise'] is List
                      ? performanceData['subjectWise'] as List<dynamic>
                      : [];
              final List<dynamic> recentExams =
                  performanceData['recentExams'] is List
                      ? performanceData['recentExams'] as List<dynamic>
                      : [];

              final dppData = performanceData['dppData'] is Map
                  ? performanceData['dppData'] as Map<String, dynamic>
                  : <String, dynamic>{};
              final dppOverall = dppData['overall'] is Map
                  ? dppData['overall'] as Map<String, dynamic>
                  : <String, dynamic>{};
              final List<dynamic> dppSubjectWise =
                  dppData['subjectWise'] is List
                      ? dppData['subjectWise'] as List<dynamic>
                      : [];
              final List<dynamic> recentDpps = dppData['recentDpps'] is List
                  ? dppData['recentDpps'] as List<dynamic>
                  : [];

              final totalExams = int.tryParse(
                    (overall['totalExamsTaken'] ?? recentExams.length)
                        .toString(),
                  ) ??
                  0;
              final totalDpps = int.tryParse(
                    (dppOverall['totalDppsTaken'] ?? recentDpps.length)
                        .toString(),
                  ) ??
                  0;

              // Auto-switch to DPP tab if student has completed DPPs but 0 exams yet
              if (!_autoSwitchedToDpps && totalExams == 0 && totalDpps > 0) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _activeTab = 'DPPS';
                      _autoSwitchedToDpps = true;
                    });
                  }
                });
              }

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 100.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Segmented Tab Selector
                    _buildSegmentedTabBar(totalExams, totalDpps),
                    SizedBox(height: 16.h),

                    // Active Tab Content
                    _activeTab == 'EXAMS'
                        ? _buildExamsTabContent(
                            overall: overall,
                            subjectWise: subjectWise,
                            recentExams: recentExams,
                            results: state.results,
                            totalExams: totalExams,
                          )
                        : _buildDppsTabContent(
                            dppOverall: dppOverall,
                            dppSubjectWise: dppSubjectWise,
                            recentDpps: recentDpps,
                            dppHistory: state.dppHistory,
                            totalDpps: totalDpps,
                          ),

                    SizedBox(height: 24.h),

                    // Topic Health Section
                    _buildTopicHealthSection(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedTabBar(int totalExams, int totalDpps) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              label: 'Exams',
              count: totalExams > 0 ? totalExams : null,
              tabKey: 'EXAMS',
              icon: PhosphorIcons.articleBold,
            ),
          ),
          Expanded(
            child: _buildTabButton(
              label: 'DPP Practice',
              count: totalDpps > 0 ? totalDpps : null,
              tabKey: 'DPPS',
              icon: PhosphorIcons.targetBold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required int? count,
    required String tabKey,
    required IconData icon,
  }) {
    final bool isActive = _activeTab == tabKey;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tabKey),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8.r),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: Offset(0, 1.h),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PhosphorIcon(
              icon,
              size: 14.sp,
              color: isActive ? AppTheme.primary : const Color(0xFF64748B),
            ),
            SizedBox(width: 6.w),
            Flexible(
              child: Text(
                count != null ? '$label ($count)' : label,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive ? AppTheme.primary : const Color(0xFF64748B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- EXAMS TAB CONTENT ---
  Widget _buildExamsTabContent({
    required Map<String, dynamic> overall,
    required List<dynamic> subjectWise,
    required List<dynamic> recentExams,
    required List<ExamResultModel> results,
    required int totalExams,
  }) {
    if (totalExams == 0 &&
        subjectWise.isEmpty &&
        recentExams.isEmpty &&
        results.isEmpty) {
      return _buildEmptyTabState(
        icon: PhosphorIcons.fileTextBold,
        title: 'No Exam Records Yet',
        message: 'Your scores and subject analysis will appear here once you complete a test.',
      );
    }

    final avgScore = (overall['averageScore'] ?? '0').toString();
    final overallAcc = _accuracyFromSubjects(subjectWise);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 3 Stat Cards
        _buildStatCardsRow(
          card1Label: 'EXAMS',
          card1Value: totalExams.toString(),
          card1Icon: PhosphorIcons.fileTextBold,
          card1Color: const Color(0xFF2563EB),
          card1Gradient: const [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
          card2Label: 'AVG SCORE',
          card2Value: avgScore,
          card2Icon: PhosphorIcons.targetBold,
          card2Color: const Color(0xFF059669),
          card2Gradient: const [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
          card3Label: 'ACCURACY',
          card3Value: '$overallAcc%',
          card3Icon: PhosphorIcons.trophyBold,
          card3Color: const Color(0xFF7C3AED),
          card3Gradient: const [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
        ),

        SizedBox(height: 20.h),

        // Section: Subject Breakdown
        _buildSectionTitle('Subject Breakdown'),
        SizedBox(height: 10.h),
        _buildComprehensiveAccordion(subjectWise),

        SizedBox(height: 20.h),

        // Section: Exam History
        _buildSectionTitle('Exam History'),
        SizedBox(height: 10.h),
        _buildPastExamsList(recentExams, results),
      ],
    );
  }

  // --- DPPS TAB CONTENT ---
  Widget _buildDppsTabContent({
    required Map<String, dynamic> dppOverall,
    required List<dynamic> dppSubjectWise,
    required List<dynamic> recentDpps,
    required List<dynamic> dppHistory,
    required int totalDpps,
  }) {
    if (totalDpps == 0 &&
        dppSubjectWise.isEmpty &&
        recentDpps.isEmpty &&
        dppHistory.isEmpty) {
      return _buildEmptyTabState(
        icon: PhosphorIcons.targetBold,
        title: 'No DPP Sessions Yet',
        message: 'Complete daily practice sets to track your practice score and accuracy.',
      );
    }

    final avgScore = (dppOverall['averageScore'] ?? '0').toString();
    final overallAcc = _accuracyFromSubjects(dppSubjectWise);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 3 Stat Cards
        _buildStatCardsRow(
          card1Label: 'COMPLETED',
          card1Value: totalDpps.toString(),
          card1Icon: PhosphorIcons.fileTextBold,
          card1Color: const Color(0xFF2563EB),
          card1Gradient: const [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
          card2Label: 'AVG SCORE',
          card2Value: avgScore,
          card2Icon: PhosphorIcons.targetBold,
          card2Color: const Color(0xFF059669),
          card2Gradient: const [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
          card3Label: 'ACCURACY',
          card3Value: '$overallAcc%',
          card3Icon: PhosphorIcons.trophyBold,
          card3Color: const Color(0xFF7C3AED),
          card3Gradient: const [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
        ),

        SizedBox(height: 20.h),

        // Section: DPP Subject Breakdown
        _buildSectionTitle('DPP Breakdown'),
        SizedBox(height: 10.h),
        _buildComprehensiveAccordion(dppSubjectWise),

        SizedBox(height: 20.h),

        // Section: DPP History
        _buildSectionTitle('DPP History'),
        SizedBox(height: 10.h),
        _buildPastDppsList(recentDpps, dppHistory),
      ],
    );
  }

  // --- STAT CARDS ROW ---
  Widget _buildStatCardsRow({
    required String card1Label,
    required String card1Value,
    required IconData card1Icon,
    required Color card1Color,
    required List<Color> card1Gradient,
    required String card2Label,
    required String card2Value,
    required IconData card2Icon,
    required Color card2Color,
    required List<Color> card2Gradient,
    required String card3Label,
    required String card3Value,
    required IconData card3Icon,
    required Color card3Color,
    required List<Color> card3Gradient,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            label: card1Label,
            value: card1Value,
            icon: card1Icon,
            color: card1Color,
            gradient: card1Gradient,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _buildMetricCard(
            label: card2Label,
            value: card2Value,
            icon: card2Icon,
            color: card2Color,
            gradient: card2Gradient,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _buildMetricCard(
            label: card3Label,
            value: card3Value,
            icon: card3Icon,
            color: card3Color,
            gradient: card3Gradient,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required List<Color> gradient,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: Offset(0, 1.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(5.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: PhosphorIcon(icon, color: color, size: 14.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 8.5.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF0F172A),
        letterSpacing: -0.2,
      ),
    );
  }

  // --- COMPREHENSIVE ACCORDION (SUBJECT -> TOPIC -> DIFFICULTY) ---
  Widget _buildComprehensiveAccordion(List<dynamic> subjectWiseData) {
    if (subjectWiseData.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Text(
            'No subject breakdown available.',
            style: TextStyle(
              color: const Color(0xFF64748B),
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Column(
      children: subjectWiseData.map((subjNode) {
        final Map<String, dynamic> subjMap = subjNode is Map
            ? Map<String, dynamic>.from(subjNode)
            : {};
        final subject = subjMap['subject']?.toString() ?? 'Subject';
        final marksObtained = subjMap['marksObtained']?.toString() ?? '0';
        final totalPossibleMarks =
            subjMap['totalPossibleMarks']?.toString() ?? '0';
        final isExpanded = _expandedSubjects[subject] ?? false;
        final isNegative = (double.tryParse(marksObtained) ?? 0) < 0;

        final List<dynamic> topics = subjMap['topics'] is List
            ? subjMap['topics'] as List<dynamic>
            : [];

        return Container(
          margin: EdgeInsets.only(bottom: 8.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isExpanded ? AppTheme.primary : const Color(0xFFE2E8F0),
              width: isExpanded ? 1.2 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: Offset(0, 1.h),
              ),
            ],
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _expandedSubjects[subject] = !isExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(12.r),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 11.h,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 3.w,
                        height: 18.h,
                        decoration: BoxDecoration(
                          color: isExpanded
                              ? AppTheme.primary
                              : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          subject,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 7.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: isNegative
                              ? const Color(0xFFFEF2F2)
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6.r),
                          border: Border.all(
                            color: isNegative
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFFBFDBFE),
                          ),
                        ),
                        child: Text(
                          '$marksObtained / $totalPossibleMarks',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: isNegative
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      PhosphorIcon(
                        isExpanded
                            ? PhosphorIcons.caretUpBold
                            : PhosphorIcons.caretDownBold,
                        color: const Color(0xFF64748B),
                        size: 13.sp,
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded)
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    border: Border(
                      top: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Column(
                    children: topics.map((topNode) {
                      final Map<String, dynamic> topMap = topNode is Map
                          ? Map<String, dynamic>.from(topNode)
                          : {};
                      final topicName =
                          topMap['topic']?.toString() ?? 'Topic';
                      final topicScore =
                          topMap['marksObtained']?.toString() ?? '0';
                      final topicTotal =
                          topMap['totalPossibleMarks']?.toString() ?? '0';
                      final accuracyVal =
                          double.tryParse(
                            topMap['accuracy']?.toString() ?? '',
                          ) ??
                          0.0;
                      final isWeak = accuracyVal < 50.0;
                      final List<dynamic> difficulties =
                          topMap['difficulties'] is List
                              ? topMap['difficulties'] as List<dynamic>
                              : [];

                      return Container(
                        margin: EdgeInsets.only(bottom: 8.h),
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          topicName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11.5.sp,
                                            color: const Color(0xFF0F172A),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isWeak) ...[
                                        SizedBox(width: 5.w),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 4.w,
                                            vertical: 1.5.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF2F2),
                                            borderRadius:
                                                BorderRadius.circular(4.r),
                                            border: Border.all(
                                              color: const Color(0xFFFCA5A5),
                                            ),
                                          ),
                                          child: Text(
                                            'WEAK',
                                            style: TextStyle(
                                              fontSize: 7.5.sp,
                                              fontWeight: FontWeight.w900,
                                              color: const Color(0xFFDC2626),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Text(
                                  '$topicScore / $topicTotal',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w700,
                                    color: (double.tryParse(topicScore) ?? 0) <
                                            0
                                        ? const Color(0xFFDC2626)
                                        : AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                            Row(
                              children: ['Easy', 'Medium', 'Hard'].map((
                                diff,
                              ) {
                                final diffNode = difficulties.firstWhere(
                                  (d) => d is Map && d['difficulty'] == diff,
                                  orElse: () => {
                                    'difficulty': diff,
                                    'totalQuestions': 0,
                                    'attempted': 0,
                                    'correct': 0,
                                    'wrong': 0,
                                    'marksObtained': 0,
                                    'totalPossibleMarks': 0,
                                  },
                                );
                                final Map<String, dynamic> diffMap =
                                    diffNode is Map
                                        ? Map<String, dynamic>.from(diffNode)
                                        : {};
                                return Expanded(
                                  child: _buildDifficultyBadgeCard(
                                    diff,
                                    diffMap,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDifficultyBadgeCard(String diff, Map<String, dynamic> data) {
    final Color badgeColor = diff == 'Easy'
        ? const Color(0xFF059669)
        : (diff == 'Medium'
            ? const Color(0xFFD97706)
            : const Color(0xFFDC2626));

    final int correct = int.tryParse(data['correct']?.toString() ?? '0') ?? 0;
    final int wrong = int.tryParse(data['wrong']?.toString() ?? '0') ?? 0;
    final int totalQ =
        int.tryParse(data['totalQuestions']?.toString() ?? '0') ?? 0;
    final String score = data['marksObtained']?.toString() ?? '0';
    final String possible = data['totalPossibleMarks']?.toString() ?? '0';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 2.w),
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                diff,
                style: TextStyle(
                  fontSize: 8.5.sp,
                  fontWeight: FontWeight.w800,
                  color: badgeColor,
                ),
              ),
              Text(
                '$totalQ Qs',
                style: TextStyle(
                  fontSize: 7.5.sp,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '✓ $correct',
                style: TextStyle(
                  fontSize: 8.sp,
                  color: const Color(0xFF059669),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '✕ $wrong',
                style: TextStyle(
                  fontSize: 8.sp,
                  color: const Color(0xFFDC2626),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            '$score / $possible M',
            style: TextStyle(
              fontSize: 8.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  // --- PAST EXAMS LIST ---
  Widget _buildPastExamsList(
    List<dynamic> recentExams,
    List<ExamResultModel> results,
  ) {
    final items = recentExams.isNotEmpty ? recentExams : results;
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Text(
            'No evaluated tests found.',
            style: TextStyle(
              color: const Color(0xFF64748B),
              fontSize: 12.sp,
            ),
          ),
        ),
      );
    }

    return Column(
      children: items.map((item) {
        final title = item is Map
            ? (item['examTitle'] ?? item['title'] ?? 'Exam').toString()
            : (item as ExamResultModel).examTitle;
        final type = item is Map
            ? (item['examType'] ?? 'Test').toString()
            : 'Test';
        final score = item is Map
            ? item['score']?.toString() ?? '0'
            : (item as ExamResultModel).score.toString();
        final totalMarks = item is Map
            ? item['totalMarks']?.toString() ?? '0'
            : (item as ExamResultModel).totalMarks.toString();
        final examId = item is Map
            ? (item['examId'] ?? item['id'] ?? '').toString()
            : (item as ExamResultModel).examId;
        final dateStr = item is Map ? item['date']?.toString() ?? '' : '';

        // Calculate accuracy
        double accuracy = 0.0;
        if (item is Map) {
          final totalCorrect =
              int.tryParse(item['totalCorrect']?.toString() ?? '0') ?? 0;
          final totalWrong =
              int.tryParse(item['totalWrong']?.toString() ?? '0') ?? 0;
          if (totalCorrect + totalWrong > 0) {
            accuracy = (totalCorrect / (totalCorrect + totalWrong)) * 100;
          }
          // else: nothing attempted -> 0; falling back to score/total made
          // negative-marked tests show a negative "accuracy".
        }
        // ExamResultModel carries no attempt counts, so accuracy stays 0.

        final Color accuracyColor = accuracy >= 80
            ? const Color(0xFF059669)
            : (accuracy >= 50
                ? const Color(0xFFD97706)
                : const Color(0xFFDC2626));
        final Color accuracyBg = accuracy >= 80
            ? const Color(0xFFECFDF5)
            : (accuracy >= 50
                ? const Color(0xFFFFFBEB)
                : const Color(0xFFFEF2F2));

        return Container(
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: Offset(0, 1.h),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5.sp,
                        color: const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Text(
                          type,
                          style: TextStyle(
                            color: const Color(0xFF64748B),
                            fontSize: 9.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (dateStr.isNotEmpty) ...[
                          Text(
                            ' • ${_formatDate(dateStr)}',
                            style: TextStyle(
                              color: const Color(0xFF94A3B8),
                              fontSize: 9.5.sp,
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 5.h),
                    Row(
                      children: [
                        Text(
                          '$score / $totalMarks',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 5.w,
                            vertical: 1.5.h,
                          ),
                          decoration: BoxDecoration(
                            color: accuracyBg,
                            borderRadius: BorderRadius.circular(4.r),
                            border: Border.all(
                              color: accuracyColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '${accuracy.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: accuracyColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 8.5.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ParentExamAnalysisScreen(examId: examId),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Analysis',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // --- PAST DPPS LIST ---
  Widget _buildPastDppsList(
    List<dynamic> recentDpps,
    List<dynamic> dppHistory,
  ) {
    final items = recentDpps.isNotEmpty ? recentDpps : dppHistory;
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Text(
            'No completed DPPs found.',
            style: TextStyle(
              color: const Color(0xFF64748B),
              fontSize: 12.sp,
            ),
          ),
        ),
      );
    }

    return Column(
      children: items.map((item) {
        final Map<String, dynamic> dppMap = item is Map
            ? Map<String, dynamic>.from(item)
            : {};
        final title =
            dppMap['title']?.toString() ?? 'DPP Practice Session';
        final subject = dppMap['subject']?.toString() ?? 'General';
        final score = dppMap['score']?.toString() ?? '0';
        final totalMarks = dppMap['totalMarks']?.toString() ?? '0';
        // Prefer correct / attempted; fall back to the server percentage only
        // when an older backend omits the counts.
        final countAcc = practiceAccuracy(dppMap);
        final percentage = countAcc != null
            ? countAcc.toStringAsFixed(0)
            : (dppMap['percentage'] ?? dppMap['accuracy'] ?? '0').toString();
        final dateStr = dppMap['date']?.toString() ?? '';

        final double numPct = double.tryParse(percentage) ?? 0;
        final Color accColor = numPct >= 70
            ? const Color(0xFF059669)
            : (numPct >= 40
                ? const Color(0xFFD97706)
                : const Color(0xFFDC2626));
        final Color accBg = numPct >= 70
            ? const Color(0xFFECFDF5)
            : (numPct >= 40
                ? const Color(0xFFFFFBEB)
                : const Color(0xFFFEF2F2));

        return Container(
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: Offset(0, 1.h),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5.sp,
                        color: const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Text(
                          subject,
                          style: TextStyle(
                            color: const Color(0xFF64748B),
                            fontSize: 9.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (dateStr.isNotEmpty) ...[
                          Text(
                            ' • ${_formatDate(dateStr)}',
                            style: TextStyle(
                              color: const Color(0xFF94A3B8),
                              fontSize: 9.5.sp,
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 5.h),
                    Row(
                      children: [
                        Text(
                          '$score / $totalMarks',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 5.w,
                            vertical: 1.5.h,
                          ),
                          decoration: BoxDecoration(
                            color: accBg,
                            borderRadius: BorderRadius.circular(4.r),
                            border: Border.all(
                              color: accColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '$percentage%',
                            style: TextStyle(
                              color: accColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 8.5.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              ElevatedButton(
                onPressed: () {
                  final mockExam = ExamModel(
                    id: (dppMap['sessionId'] ?? dppMap['_id'] ?? '').toString(),
                    title: title,
                    subjectId: dppMap['subjectId']?.toString() ?? '',
                    subjectName: subject,
                    date: DateTime.tryParse(dateStr) ?? DateTime.now(),
                    durationMinutes: 30,
                    totalQuestions: dppMap['totalQuestions'] ?? 10,
                    totalMarks: num.tryParse(totalMarks) ?? 40,
                    passingMarks: 0,
                    status: 'SUBMITTED',
                    questions: const [],
                    submissionStatus: 'SUBMITTED',
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          DppPracticePlayerScreen(exam: mockExam),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0C8044),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Review',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // --- TOPIC HEALTH SECTION (TOPIC FLAGS) ---
  Widget _buildTopicHealthSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Topic Health'),
        SizedBox(height: 10.h),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _flagsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                padding: EdgeInsets.symmetric(vertical: 20.h),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primary,
                    strokeWidth: 2,
                  ),
                ),
              );
            }

            final flags = snapshot.data ?? [];
            if (flags.isEmpty) {
              return Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Center(
                  child: Text(
                    'No weak topics flagged yet.',
                    style: TextStyle(
                      color: const Color(0xFF64748B),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: flags.length,
              separatorBuilder: (_, __) => SizedBox(height: 8.h),
              itemBuilder: (context, index) {
                final flag = flags[index];
                final level = flag['flag']?.toString() ?? 'GREEN';
                final Color color = level == 'RED'
                    ? const Color(0xFFDC2626)
                    : (level == 'YELLOW'
                        ? const Color(0xFFD97706)
                        : const Color(0xFF059669));
                final String label = level == 'RED'
                    ? 'Needs remedy'
                    : (level == 'YELLOW'
                        ? 'Practice more'
                        : 'Mastered');

                final remedy = flag['remedialSessionId'];
                final String? remedySessionId = remedy is Map
                    ? (remedy['_id'] ?? remedy['id'])?.toString()
                    : null;

                return Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: color.withValues(alpha: 0.25),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 3.5.w,
                        height: 32.h,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3.r),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              flag['topicName']?.toString() ?? 'Topic',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.sp,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 1.h),
                            Text(
                              '${flag['subjectName'] ?? ''} • $label',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w600,
                                fontSize: 9.5.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${flag['percentage'] ?? 0}%',
                            style: TextStyle(
                              color: color,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (level == 'RED' && remedySessionId != null) ...[
                            SizedBox(height: 3.h),
                            GestureDetector(
                              onTap: () {
                                final mockExam = ExamModel(
                                  id: remedySessionId,
                                  title:
                                      'Remedy DPP: ${flag['topicName'] ?? 'Topic'}',
                                  subjectId: '',
                                  subjectName:
                                      flag['subjectName']?.toString() ??
                                          'Subject',
                                  date: DateTime.now(),
                                  durationMinutes: 20,
                                  totalQuestions: 10,
                                  totalMarks: 40,
                                  passingMarks: 0,
                                  status: 'IN_PROGRESS',
                                  questions: const [],
                                  submissionStatus: 'IN_PROGRESS',
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        DppPracticePlayerScreen(
                                      exam: mockExam,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626),
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Text(
                                  'Start remedy',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8.5.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ] else if (level == 'GREEN') ...[
                            PhosphorIcon(
                              PhosphorIcons.checkCircleFill,
                              color: const Color(0xFF059669),
                              size: 14.sp,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyTabState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: PhosphorIcon(
                icon,
                color: AppTheme.primary,
                size: 20.sp,
              ),
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF64748B),
              fontSize: 11.sp,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
