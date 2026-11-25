import 'package:lms/core/utils/practice_accuracy.dart';
import 'package:lms/core/constants/result_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:intl/intl.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/l10n/app_localizations.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/exams/data/models/exams_models.dart';
import 'package:lms/features/exams/presentation/cubit/exams_cubit.dart';
import 'package:lms/features/exams/presentation/screens/dpp_practice_player_screen.dart';
import 'package:lms/features/exams/presentation/screens/exam_player_screen.dart';
import 'package:lms/features/exams/presentation/screens/parent_exam_analysis_screen.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class StudentExamsScreen extends StatefulWidget {
  const StudentExamsScreen({super.key});

  @override
  State<StudentExamsScreen> createState() => _StudentExamsScreenState();
}

class _StudentExamsScreenState extends State<StudentExamsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;

  // Exams Tab Filters
  String _examSearchQuery = '';
  bool _showCompletedExams = false;
  String _examSelectedSubject = ResultStrings.allSubjects;
  final TextEditingController _examSearchController = TextEditingController();

  // DPP Tab Filters
  String _dppSubTab = 'ASSIGNED'; // 'ASSIGNED' | 'HISTORY'
  String _dppSearchQuery = '';
  String _dppSelectedSubject = 'All';
  final TextEditingController _dppSearchController = TextEditingController();

  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _handleRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _examSearchController.dispose();
    _dppSearchController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    try {
      await context.read<ExamsCubit>().loadStudentExams(token);
    } finally {
      if (mounted) _isRefreshing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _handleRefresh();
    }
  }

  bool _isTeacherDpp(Map<String, dynamic> dpp) {
    final title = (dpp['title'] ?? '').toString().toLowerCase();
    final filters = dpp['filters'] is Map ? dpp['filters'] as Map : {};
    final topics = filters['topics'] is List ? filters['topics'] as List : [];

    return dpp['isTeacherAssigned'] == true ||
        dpp['assignedBy'] != null ||
        title.contains('remedial') ||
        title.startsWith('dpp -') ||
        topics.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.page(context),
      appBar: AppBar(
        title: Text(
          'Practice & Exams',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink(context),
          ),
        ),
        elevation: 0,
        backgroundColor: AppTheme.card(context),
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 2.5,
          labelColor: AppTheme.primary,
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.sp),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13.sp,
          ),
          tabs: const [
            Tab(
              iconMargin: EdgeInsets.only(bottom: 4),
              icon: PhosphorIcon(PhosphorIcons.articleBold, size: 18),
              text: 'Exams',
            ),
            Tab(
              iconMargin: EdgeInsets.only(bottom: 4),
              icon: PhosphorIcon(PhosphorIcons.targetBold, size: 18),
              text: 'Daily Practice (DPP)',
            ),
          ],
        ),
      ),
      body: BlocBuilder<ExamsCubit, ExamsState>(
        builder: (context, state) {
          if (state.status == ExamsStatus.loading && state.exams.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primary,
                strokeWidth: 2.5,
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [_buildExamsTab(state), _buildDppsTab(state)],
          );
        },
      ),
    );
  }

  // ==========================================
  // TAB 1: EXAMS VIEW
  // ==========================================
  Widget _buildExamsTab(ExamsState state) {
    // Why: everything in state.exams comes from /exams/student/my-exams, so
    // these are real exams even if the title starts with "DPP -". Real DPP
    // sessions live in state.dppHistory (DPP tab). Hiding by title made
    // legitimately assigned exams vanish.
    var exams = List<ExamModel>.of(state.exams);

    // Chips come from the loaded tests so they never offer an empty subject.
    // Built before filtering so the chip row stays stable while searching.
    final examSubjects = exams
        .map((e) => e.subjectName.trim())
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final hasSelectedSubject = _examSelectedSubject == ResultStrings.allSubjects ||
        examSubjects.contains(_examSelectedSubject);
    final activeSubject =
        hasSelectedSubject ? _examSelectedSubject : ResultStrings.allSubjects;
    if (activeSubject != ResultStrings.allSubjects) {
      exams = exams.where((e) => e.subjectName.trim() == activeSubject).toList();
    }

    // Search query filter (combines with the subject chip above)
    if (_examSearchQuery.trim().isNotEmpty) {
      final q = _examSearchQuery.toLowerCase().trim();
      exams = exams
          .where(
            (e) =>
                e.title.toLowerCase().contains(q) ||
                e.subjectName.toLowerCase().contains(q),
          )
          .toList();
    }

    if (_examSelectedSubject != 'All') {
      exams = exams
          .where((e) => e.subjectName == _examSelectedSubject)
          .toList();
    }

    final subjects = <String>{
      'All',
      ...state.exams
          .where((e) => e.subjectName.trim().isNotEmpty)
          .map((e) => e.subjectName),
    }.toList();

    // Completed vs Active toggle
    final completedExams = exams.where((e) {
      final sub = e.submissionStatus.toUpperCase();
      return sub == 'SUBMITTED' || sub == 'AUTO_SUBMITTED';
    }).toList();

    final activeUpcomingExams = exams.where((e) {
      final sub = e.submissionStatus.toUpperCase();
      return sub != 'SUBMITTED' && sub != 'AUTO_SUBMITTED';
    }).toList();

    final displayedExams = _showCompletedExams
        ? completedExams
        : activeUpcomingExams;

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppTheme.primary,
      backgroundColor: AppTheme.card(context),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 100.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input
            _buildSearchBox(
              controller: _examSearchController,
              hint: 'Search scheduled exams, mock tests...',
              onChanged: (val) => setState(() => _examSearchQuery = val),
              onClear: () => setState(() {
                _examSearchController.clear();
                _examSearchQuery = '';
              }),
            ),
            SizedBox(height: 10.h),
            if (examSubjects.isNotEmpty) ...[
              _buildSubjectChips(
                subjects: examSubjects,
                selected: activeSubject,
                onSelected: (sub) => setState(() => _examSelectedSubject = sub),
              ),
              SizedBox(height: 12.h),
            ],

            SizedBox(
              height: 38.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: subjects.length,
                separatorBuilder: (_, __) => SizedBox(width: 8.w),
                itemBuilder: (context, index) {
                  final subject = subjects[index];
                  final selected = subject == _examSelectedSubject;
                  return ChoiceChip(
                    label: Text(subject),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _examSelectedSubject = subject),
                    selectedColor: AppTheme.primary,
                    backgroundColor: AppTheme.card(context),
                    labelStyle: TextStyle(
                      color: selected
                          ? Colors.white
                          : AppTheme.inkSoft(context),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(
                      color: selected
                          ? AppTheme.primary
                          : const Color(0xFFE2E8F0),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 12.h),

            // Toggle: Active & Upcoming vs Completed
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: AppTheme.soft(context),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: AppTheme.line(context)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSubTabToggle(
                      label:
                          'Active & Upcoming (${activeUpcomingExams.length})',
                      isSelected: !_showCompletedExams,
                      onTap: () => setState(() => _showCompletedExams = false),
                    ),
                  ),
                  Expanded(
                    child: _buildSubTabToggle(
                      label: 'Completed (${completedExams.length})',
                      isSelected: _showCompletedExams,
                      onTap: () => setState(() => _showCompletedExams = true),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14.h),

            // Exams List
            if (displayedExams.isEmpty && state.examsError != null)
              // Show the server's reason (e.g. plan has no access) instead of
              // a misleading "no exams scheduled".
              _buildEmptyState(
                icon: PhosphorIcons.fileText,
                title: AppLocalizations.of(context)!.examLoadFailedTitle,
                message: state.examsErrorIsGeneric
                    ? AppLocalizations.of(context)!.examLoadFailedMessage
                    : state.examsError!,
              )
            else if (displayedExams.isEmpty)
              _buildEmptyState(
                icon: PhosphorIcons.fileText,
                title: _showCompletedExams
                    ? 'No Completed Exams Found'
                    : 'No Active Exams Scheduled',
                message: _showCompletedExams
                    ? 'Your evaluated exam submissions and analysis reports will appear here.'
                    : 'You have no scheduled exams currently pending for this filter.',
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayedExams.length,
                separatorBuilder: (_, __) => SizedBox(height: 10.h),
                itemBuilder: (context, index) {
                  return _buildExamCard(displayedExams[index]);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamCard(ExamModel exam) {
    final subStatus = exam.submissionStatus.toUpperCase();
    final isSubmitted =
        subStatus == 'SUBMITTED' || subStatus == 'AUTO_SUBMITTED';
    final isInProgress = subStatus == 'IN_PROGRESS';

    // Startable check
    final now = DateTime.now();
    bool isWindowOpen = true;
    if (exam.startTime != null && exam.endTime != null) {
      isWindowOpen =
          !now.isBefore(exam.startTime!) && !now.isAfter(exam.endTime!);
    }

    final dateStr = exam.date != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(exam.date!)
        : (exam.startTime != null
              ? DateFormat('dd MMM yyyy, hh:mm a').format(exam.startTime!)
              : 'Scheduled');

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppTheme.line(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Subject Chip & Status Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    (exam.subjectName.isNotEmpty
                            ? exam.subjectName
                            : 'All subjects')
                        .toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 9.sp,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              if (isSubmitted)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Text(
                    'Evaluated',
                    style: TextStyle(
                      color: const Color(0xFF047857),
                      fontWeight: FontWeight.w800,
                      fontSize: 9.sp,
                    ),
                  ),
                )
              else if (isInProgress)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    'In Progress',
                    style: TextStyle(
                      color: const Color(0xFFB45309),
                      fontWeight: FontWeight.w800,
                      fontSize: 9.sp,
                    ),
                  ),
                )
              else
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppTheme.soft(context),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    isWindowOpen ? 'Available' : 'Upcoming',
                    style: TextStyle(
                      color: AppTheme.inkSoft(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 9.sp,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8.h),

          // Title
          Text(
            exam.title,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink(context),
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: 6.h),

          // Exam Metrics Info
          Row(
            children: [
              PhosphorIcon(
                PhosphorIcons.calendarBlank,
                size: 13.sp,
                color: const Color(0xFF64748B),
              ),
              SizedBox(width: 4.w),
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 10.5.sp,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),

          Row(
            children: [
              Text(
                '${exam.durationMinutes} Mins • ${exam.totalMarks} Marks',
                style: TextStyle(
                  fontSize: 10.5.sp,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if ((exam.totalQuestions ?? 0) > 0) ...[
                Text(
                  ' • ${exam.totalQuestions} Qs',
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 12.h),

          // Action Button Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isSubmitted)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ParentExamAnalysisScreen(examId: exam.id),
                      ),
                    );
                  },
                  icon: PhosphorIcon(
                    PhosphorIcons.chartLineUpBold,
                    size: 13.sp,
                  ),
                  label: const Text('View Result'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 6.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    elevation: 0,
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: isWindowOpen || isInProgress
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ExamPlayerScreen(exam: exam),
                            ),
                          ).then((_) => _handleRefresh());
                        }
                      : null,
                  icon: PhosphorIcon(
                    isInProgress
                        ? PhosphorIcons.playBold
                        : PhosphorIcons.arrowRightBold,
                    size: 13.sp,
                  ),
                  label: Text(isInProgress ? 'Resume' : 'Start Exam'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0C8044),
                    disabledBackgroundColor: const Color(0xFFE2E8F0),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: const Color(0xFF94A3B8),
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 6.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    elevation: 0,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: TEACHER DPPS VIEW (MATCHING WEB PORTAL)
  // ==========================================
  Widget _buildDppsTab(ExamsState state) {
    final List<dynamic> allDpps = state.dppHistory;

    // Separate Teacher Assigned DPPs vs General DPPs
    final teacherDpps = allDpps.where((item) {
      final Map<String, dynamic> map = item is Map
          ? Map<String, dynamic>.from(item)
          : {};
      return _isTeacherDpp(map);
    }).toList();

    final pendingTeacherDpps = teacherDpps.where((item) {
      final Map<String, dynamic> map = item is Map
          ? Map<String, dynamic>.from(item)
          : {};
      final status = (map['status'] ?? '').toString().toUpperCase();
      return status != 'COMPLETED';
    }).toList();

    final completedTeacherDpps = teacherDpps.where((item) {
      final Map<String, dynamic> map = item is Map
          ? Map<String, dynamic>.from(item)
          : {};
      final status = (map['status'] ?? '').toString().toUpperCase();
      return status == 'COMPLETED';
    }).toList();

    final completedAllDpps = allDpps.where((item) {
      final Map<String, dynamic> map = item is Map
          ? Map<String, dynamic>.from(item)
          : {};
      final status = (map['status'] ?? '').toString().toUpperCase();
      return status == 'COMPLETED';
    }).toList();

    // Stats calculations
    num totalScore = 0;
    num totalPossible = 0;
    int totalQuestionsSolved = 0;
    // Counts-based accuracy (correct / attempted) across items that have them.
    num totalCorrect = 0;
    num totalAttempted = 0;
    bool haveCounts = false;
    for (final item in completedAllDpps) {
      if (item is Map) {
        if (practiceAccuracy(item) != null) {
          haveCounts = true;
          totalCorrect += num.tryParse(item['correctCount'].toString()) ?? 0;
          totalAttempted +=
              num.tryParse(item['attemptedCount'].toString()) ?? 0;
        }
        final sc = num.tryParse(item['score']?.toString() ?? '0') ?? 0;
        final tMarks =
            num.tryParse(item['totalMarks']?.toString() ?? '0') ??
            ((item['totalQuestions'] ?? 0) * 4);
        final qCount =
            int.tryParse(item['totalQuestions']?.toString() ?? '0') ?? 0;
        totalScore += sc;
        totalPossible += tMarks;
        totalQuestionsSolved += qCount;
      }
    }
    final accuracyStr = haveCounts
        ? (totalAttempted > 0
              ? ((totalCorrect / totalAttempted) * 100).toStringAsFixed(1)
              : '0.0')
        : (totalPossible > 0
              ? ((totalScore / totalPossible) * 100).toStringAsFixed(1)
              : '0.0');

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppTheme.primary,
      backgroundColor: AppTheme.card(context),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 100.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Stat Cards Row
            _buildDppStatsRow(
              assignedTotal: teacherDpps.length,
              assignedPending: pendingTeacherDpps.length,
              totalCompleted: completedAllDpps.length,
              accuracy: accuracyStr,
              questionsSolved: totalQuestionsSolved,
            ),
            SizedBox(height: 14.h),

            // Segmented Sub-Tab Bar: Assigned by Teachers | Results & History
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: AppTheme.soft(context),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: AppTheme.line(context)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSubTabToggle(
                      label: pendingTeacherDpps.isNotEmpty
                          ? 'Assigned (${pendingTeacherDpps.length} Due)'
                          : 'Assigned by Teachers',
                      isSelected: _dppSubTab == 'ASSIGNED',
                      onTap: () => setState(() => _dppSubTab = 'ASSIGNED'),
                    ),
                  ),
                  Expanded(
                    child: _buildSubTabToggle(
                      label: 'Results & History (${allDpps.length})',
                      isSelected: _dppSubTab == 'HISTORY',
                      onTap: () => setState(() => _dppSubTab = 'HISTORY'),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14.h),

            // Sub-Tab Content
            if (_dppSubTab == 'ASSIGNED')
              _buildTeacherAssignedView(
                pendingList: pendingTeacherDpps,
                completedList: completedTeacherDpps,
              )
            else
              _buildDppHistoryView(allDpps: allDpps, subjects: state.subjects),
          ],
        ),
      ),
    );
  }

  // --- DPP STATS OVERVIEW ---
  Widget _buildDppStatsRow({
    required int assignedTotal,
    required int assignedPending,
    required int totalCompleted,
    required String accuracy,
    required int questionsSolved,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildMiniStatCard(
            label: 'ASSIGNED',
            value: assignedTotal.toString(),
            badge: assignedPending > 0 ? '$assignedPending Due' : null,
            icon: PhosphorIcons.sparkleBold,
            color: const Color(0xFF047857),
            bg: const Color(0xFFECFDF5),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _buildMiniStatCard(
            label: 'COMPLETED',
            value: totalCompleted.toString(),
            icon: PhosphorIcons.checkCircleBold,
            color: const Color(0xFF2563EB),
            bg: const Color(0xFFEFF6FF),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _buildMiniStatCard(
            label: 'ACCURACY',
            value: '$accuracy%',
            icon: PhosphorIcons.trophyBold,
            color: const Color(0xFF7C3AED),
            bg: const Color(0xFFF5F3FF),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatCard({
    required String label,
    required String value,
    String? badge,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.line(context)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: PhosphorIcon(icon, size: 13.sp, color: color),
              ),
              if (badge != null)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 4.w,
                    vertical: 1.5.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 7.5.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 8.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF64748B),
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink(context),
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  // --- TEACHER ASSIGNED SUB-TAB ---
  Widget _buildTeacherAssignedView({
    required List<dynamic> pendingList,
    required List<dynamic> completedList,
  }) {
    if (pendingList.isEmpty && completedList.isEmpty) {
      return _buildEmptyState(
        icon: PhosphorIcons.checkCircle,
        title: 'No Teacher Assignments Pending',
        message:
            'Remedial and targeted practice DPPs assigned by your teachers based on your evaluations will appear here.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pending Section
        if (pendingList.isNotEmpty) ...[
          Row(
            children: [
              Container(
                width: 8.w,
                height: 8.w,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 6.w),
              Text(
                'Pending Teacher DPPs (${pendingList.length})',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink(context),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pendingList.length,
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (context, index) {
              final dppMap = pendingList[index] is Map
                  ? Map<String, dynamic>.from(pendingList[index])
                  : <String, dynamic>{};
              return _buildTeacherDppCard(dppMap, isPending: true);
            },
          ),
          SizedBox(height: 20.h),
        ],

        // Completed Teacher Assignments Section
        if (completedList.isNotEmpty) ...[
          Text(
            'Completed Teacher Remedial DPPs (${completedList.length})',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink(context),
            ),
          ),
          SizedBox(height: 8.h),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: completedList.length,
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (context, index) {
              final dppMap = completedList[index] is Map
                  ? Map<String, dynamic>.from(completedList[index])
                  : <String, dynamic>{};
              return _buildTeacherDppCard(dppMap, isPending: false);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildTeacherDppCard(
    Map<String, dynamic> dppMap, {
    required bool isPending,
  }) {
    final title = dppMap['title']?.toString() ?? 'Teacher Assigned DPP';
    final filters = dppMap['filters'] is Map ? dppMap['filters'] as Map : {};
    final subject = (filters['subject'] ?? dppMap['subject'] ?? 'General')
        .toString();
    final topicsList =
        filters['topics'] is List && (filters['topics'] as List).isNotEmpty
        ? (filters['topics'] as List).map((e) => e.toString()).toList()
        : (filters['topic'] != null
              ? [filters['topic'].toString()]
              : <String>[]);

    final teacherObj = dppMap['assignedBy'];
    final String teacherName = teacherObj is Map
        ? '${teacherObj['firstName'] ?? ''} ${teacherObj['lastName'] ?? ''}'
              .trim()
        : (teacherObj != null && teacherObj.toString().isNotEmpty
              ? teacherObj.toString()
              : 'Faculty Teacher');

    final int totalQuestions = dppMap['totalQuestions'] is num
        ? (dppMap['totalQuestions'] as num).toInt()
        : (int.tryParse(dppMap['totalQuestions']?.toString() ?? '10') ?? 10);

    final totalMarks = dppMap['totalMarks'] ?? (totalQuestions * 4);
    final score = dppMap['score'] ?? 0;
    final difficulty = (filters['difficulty'] ?? 'Medium').toString();

    final dateStr = dppMap['createdAt']?.toString() ?? '';
    final formattedDate = dateStr.isNotEmpty ? _formatDate(dateStr) : '';

    final answers = dppMap['answers'] is List ? dppMap['answers'] as List : [];
    final bool isStarted = answers.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isPending ? const Color(0xFFA7F3D0) : AppTheme.line(context),
          width: isPending ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badges Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF047857),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.sparkleBold,
                      color: Colors.white,
                      size: 10.sp,
                    ),
                    SizedBox(width: 3.w),
                    Text(
                      'Teacher Assigned',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8.5.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              if (isPending)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    isStarted ? 'In Progress' : 'Pending',
                    style: TextStyle(
                      color: const Color(0xFFB45309),
                      fontWeight: FontWeight.w800,
                      fontSize: 8.5.sp,
                    ),
                  ),
                )
              else
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Text(
                    'Score: $score / $totalMarks',
                    style: TextStyle(
                      color: const Color(0xFF047857),
                      fontWeight: FontWeight.w800,
                      fontSize: 8.5.sp,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8.h),

          // Title
          Text(
            title,
            style: TextStyle(
              fontSize: 13.5.sp,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink(context),
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: 2.h),

          // Assigned By
          Text(
            'Assigned by: $teacherName',
            style: TextStyle(
              fontSize: 10.sp,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 6.h),

          // Subject & Topics Chips
          Wrap(
            spacing: 5.w,
            runSpacing: 4.h,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: AppTheme.soft(context),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  subject,
                  style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.inkSoft(context),
                  ),
                ),
              ),
              ...topicsList.map(
                (topic) => Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(4.r),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Text(
                    topic,
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF047857),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),

          // Details Row: Qs, Marks, Level, Action Button
          Row(
            children: [
              Expanded(
                child: Text(
                  '$totalQuestions Qs • $totalMarks Marks • $difficulty${formattedDate.isNotEmpty ? ' • $formattedDate' : ''}',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              ElevatedButton(
                onPressed: () {
                  final mockExam = ExamModel(
                    id: (dppMap['_id'] ?? dppMap['sessionId'] ?? '').toString(),
                    title: title,
                    subjectId: '',
                    subjectName: subject,
                    date: DateTime.now(),
                    durationMinutes: 30,
                    totalQuestions: totalQuestions,
                    totalMarks: num.tryParse(totalMarks.toString()) ?? 40,
                    passingMarks: 0,
                    status: isPending ? 'IN_PROGRESS' : 'SUBMITTED',
                    questions: const [],
                    submissionStatus: isPending ? 'IN_PROGRESS' : 'SUBMITTED',
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          DppPracticePlayerScreen(exam: mockExam),
                    ),
                  ).then((_) => _handleRefresh());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPending
                      ? const Color(0xFF047857)
                      : AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
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
                  isPending
                      ? (isStarted ? 'Resume DPP' : 'Start DPP')
                      : 'Review',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- DPP RESULTS & HISTORY SUB-TAB ---
  Widget _buildDppHistoryView({
    required List<dynamic> allDpps,
    required List<String> subjects,
  }) {
    var filtered = allDpps;

    // Filter by subject
    if (_dppSelectedSubject != 'All') {
      filtered = filtered.where((item) {
        if (item is! Map) return false;
        final filters = item['filters'] is Map ? item['filters'] as Map : {};
        final sub = (filters['subject'] ?? item['subject'] ?? '').toString();
        return sub.toLowerCase() == _dppSelectedSubject.toLowerCase();
      }).toList();
    }

    // Filter by search query
    if (_dppSearchQuery.trim().isNotEmpty) {
      final q = _dppSearchQuery.toLowerCase().trim();
      filtered = filtered.where((item) {
        if (item is! Map) return false;
        final title = (item['title'] ?? '').toString().toLowerCase();
        final filters = item['filters'] is Map ? item['filters'] as Map : {};
        final sub = (filters['subject'] ?? item['subject'] ?? '')
            .toString()
            .toLowerCase();
        return title.contains(q) || sub.contains(q);
      }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input
        _buildSearchBox(
          controller: _dppSearchController,
          hint: 'Search practice history by title or topic...',
          onChanged: (val) => setState(() => _dppSearchQuery = val),
          onClear: () => setState(() {
            _dppSearchController.clear();
            _dppSearchQuery = '';
          }),
        ),
        SizedBox(height: 10.h),

        // Subject Filter Chips
        _buildSubjectChips(
          subjects: subjects,
          selected: _dppSelectedSubject,
          onSelected: (sub) => setState(() => _dppSelectedSubject = sub),
        ),
        SizedBox(height: 12.h),

        if (filtered.isEmpty)
          _buildEmptyState(
            icon: PhosphorIcons.clockCounterClockwise,
            title: 'No DPP History Found',
            message:
                'Completed DPP practice sessions will be logged here for evaluation.',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (context, index) {
              final dppMap = filtered[index] is Map
                  ? Map<String, dynamic>.from(filtered[index])
                  : <String, dynamic>{};

              final title =
                  dppMap['title']?.toString() ?? 'DPP Practice Session';
              final filters = dppMap['filters'] is Map
                  ? dppMap['filters'] as Map
                  : {};
              final subject =
                  (filters['subject'] ?? dppMap['subject'] ?? 'General')
                      .toString();
              final score = dppMap['score']?.toString() ?? '0';
              final totalMarks =
                  dppMap['totalMarks']?.toString() ?? '40';
              final countAcc = practiceAccuracy(dppMap);
              final percentage = countAcc != null
                  ? countAcc.toStringAsFixed(0)
                  : (dppMap['percentage'] ?? dppMap['accuracy'] ?? '0')
                      .toString();
              final dateStr = dppMap['createdAt']?.toString() ??
                  dppMap['date']?.toString() ??
                  '';

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
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppTheme.card(context),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppTheme.line(context)),
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
                              color: AppTheme.ink(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2.h),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  subject,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: const Color(0xFF64748B),
                                    fontSize: 9.5.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
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
                          id: (dppMap['_id'] ?? dppMap['sessionId'] ?? '')
                              .toString(),
                          title: title,
                          subjectId: '',
                          subjectName: subject,
                          date: DateTime.now(),
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
            },
          ),
      ],
    );
  }

  // --- REUSABLE UI WIDGETS ---
  Widget _buildSearchBox({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
    required VoidCallback onClear,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(
        fontSize: 12.5.sp,
        color: AppTheme.ink(context),
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: const Color(0xFF94A3B8),
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Padding(
          padding: EdgeInsets.all(10.w),
          child: PhosphorIcon(
            PhosphorIcons.magnifyingGlass,
            color: const Color(0xFF64748B),
            size: 16.sp,
          ),
        ),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: PhosphorIcon(PhosphorIcons.xCircleFill, size: 16.sp),
                onPressed: onClear,
              )
            : null,
        filled: true,
        fillColor: AppTheme.card(context),
        contentPadding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: AppTheme.line(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: AppTheme.line(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSubjectChips({
    required List<String> subjects,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    final list = ['All', ...subjects];
    return SizedBox(
      height: 28.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: list.length,
        separatorBuilder: (_, __) => SizedBox(width: 6.w),
        itemBuilder: (context, index) {
          final sub = list[index];
          final isSelected = selected.toLowerCase() == sub.toLowerCase();
          return GestureDetector(
            onTap: () => onSelected(sub),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : AppTheme.card(context),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primary
                      : const Color(0xFFCBD5E1),
                ),
              ),
              child: Center(
                child: Text(
                  sub,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : AppTheme.inkSoft(context),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubTabToggle({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(vertical: 7.h),
        decoration: BoxDecoration(
          color: isSelected
              ? (AppTheme.isDarkOf(context)
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8.r),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: Offset(0, 1.h),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5.sp,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? AppTheme.primary : const Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppTheme.line(context)),
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
              child: PhosphorIcon(icon, color: AppTheme.primary, size: 20.sp),
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink(context),
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
