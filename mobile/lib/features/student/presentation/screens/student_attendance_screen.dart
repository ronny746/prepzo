import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:intl/intl.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _registers = [];
  String _selectedStatusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  Future<void> _fetchAttendance() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
      final repo = context.read<DashboardRepository>();
      final data = await repo.getStudentAttendance(token: token);
      if (mounted) {
        setState(() {
          _registers = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load attendance records. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _flattenRows() {
    final List<Map<String, dynamic>> rows = [];
    for (final reg in _registers) {
      final records = reg['records'] is List ? reg['records'] as List : [];
      if (records.isEmpty) {
        rows.add({
          'register': reg,
          'record': {
            'status': 'absent',
            'joinEvents': [],
            'firstJoinTime': null,
          },
        });
      } else {
        for (final rec in records) {
          rows.add({
            'register': reg,
            'record': rec is Map ? rec : {'status': 'absent'},
          });
        }
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allRows = _flattenRows();

    // Stats calculations
    int presentCount = 0;
    int lateCount = 0;
    int absentCount = 0;

    for (final row in allRows) {
      final record = row['record'] is Map ? row['record'] as Map : {};
      final status = (record['status'] ?? 'absent').toString().toLowerCase();
      if (status == 'present') {
        presentCount++;
      } else if (status == 'late') {
        lateCount++;
      } else if (status == 'absent') {
        absentCount++;
      }
    }

    final totalRecords = allRows.length;
    final rate = totalRecords > 0
        ? ((presentCount / totalRecords) * 100).round()
        : 0;

    final filteredRows = allRows.where((row) {
      if (_selectedStatusFilter == 'ALL') return true;
      final record = row['record'] is Map ? row['record'] as Map : {};
      final status = (record['status'] ?? 'absent').toString().toUpperCase();
      return status == _selectedStatusFilter;
    }).toList();

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.darkBackground
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: PhosphorIcon(
            PhosphorIcons.arrowLeftBold,
            size: 20.sp,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Attendance',
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: PhosphorIcon(
              PhosphorIcons.arrowClockwiseBold,
              size: 20.sp,
              color: AppTheme.primary,
            ),
            onPressed: _fetchAttendance,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchAttendance,
          color: AppTheme.primary,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                )
              : _error != null
              ? _buildErrorState()
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 14.h,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top KPI Summary
                      _buildKpiSummaryGrid(
                        rate: rate,
                        present: presentCount,
                        late: lateCount,
                        absent: absentCount,
                        total: totalRecords,
                      ),
                      SizedBox(height: 16.h),

                      // Status Filter Chips
                      _buildStatusFilterRow(isDark),
                      SizedBox(height: 14.h),

                      // Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'CLASS ATTENDANCE REGISTER',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF94A3B8),
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            '${filteredRows.length} classes',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),

                      // Attendance Records List
                      if (filteredRows.isEmpty)
                        _buildEmptyState()
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredRows.length,
                          separatorBuilder: (_, __) => SizedBox(height: 8.h),
                          itemBuilder: (context, index) {
                            return _buildAttendanceCard(filteredRows[index]);
                          },
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  // --- KPI SUMMARY GRID ---
  Widget _buildKpiSummaryGrid({
    required int rate,
    required int present,
    required int late,
    required int absent,
    required int total,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                label: 'ATTENDANCE RATE',
                value: '$rate%',
                subtitle: '$present of $total present',
                icon: PhosphorIcons.chartPieSliceBold,
                color: const Color(0xFF0033A0),
                bg: const Color(0xFFEFF6FF),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _buildKpiCard(
                label: 'PRESENT',
                value: present.toString(),
                subtitle: 'On time joins',
                icon: PhosphorIcons.checkCircleBold,
                color: const Color(0xFF059669),
                bg: const Color(0xFFECFDF5),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                label: 'LATE',
                value: late.toString(),
                subtitle: 'Joined with delay',
                icon: PhosphorIcons.clockBold,
                color: const Color(0xFFD97706),
                bg: const Color(0xFFFFFBEB),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _buildKpiCard(
                label: 'ABSENT',
                value: absent.toString(),
                subtitle: 'Missed classes',
                icon: PhosphorIcons.xCircleBold,
                color: const Color(0xFFDC2626),
                bg: const Color(0xFFFEF2F2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Center(
              child: PhosphorIcon(icon, color: color, size: 18.sp),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 8.5.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 0.4,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- STATUS FILTER CHIPS ---
  Widget _buildStatusFilterRow(bool isDark) {
    final filters = ['ALL', 'PRESENT', 'LATE', 'ABSENT', 'LEAVE'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedStatusFilter == f;
          return Padding(
            padding: EdgeInsets.only(right: 6.w),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedStatusFilter = f;
                });
              },
              borderRadius: BorderRadius.circular(20.r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary
                      : (isDark ? AppTheme.darkSurface : Colors.white),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primary
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Text(
                  f,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : const Color(0xFF475569)),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- ATTENDANCE CARD ---
  Widget _buildAttendanceCard(Map<String, dynamic> row) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reg = row['register'] is Map ? row['register'] as Map : {};
    final rec = row['record'] is Map ? row['record'] as Map : {};

    final status = (rec['status'] ?? 'absent').toString().toLowerCase();

    final classTopic = (reg['classTopic'] ?? reg['title'] ?? 'Live Class')
        .toString();
    final subject = (reg['subject'] ?? 'General').toString();
    final batch =
        (reg['batchId'] is Map
                ? reg['batchId']['name']
                : (reg['batchName'] ?? ''))
            .toString();

    // Date formatting
    String dateStr = '—';
    if (reg['date'] != null) {
      try {
        final parsed = DateTime.parse(reg['date'].toString()).toLocal();
        dateStr = DateFormat('EEE, dd MMM yyyy').format(parsed);
      } catch (_) {
        dateStr = reg['date'].toString();
      }
    }

    final startTime = (reg['startTime'] ?? '').toString();
    final endTime = (reg['endTime'] ?? '').toString();
    final timeStr = (startTime.isNotEmpty && endTime.isNotEmpty)
        ? '$startTime - $endTime'
        : (startTime.isNotEmpty ? startTime : '');

    // Status styling
    Color statusColor;
    Color statusBg;
    IconData statusIcon;
    String statusLabel;

    switch (status) {
      case 'present':
        statusColor = const Color(0xFF059669);
        statusBg = const Color(0xFFECFDF5);
        statusIcon = PhosphorIcons.checkCircleFill;
        statusLabel = 'Present';
        break;
      case 'late':
        statusColor = const Color(0xFFD97706);
        statusBg = const Color(0xFFFFFBEB);
        statusIcon = PhosphorIcons.clockFill;
        statusLabel = 'Late';
        break;
      case 'leave':
        statusColor = const Color(0xFF6366F1);
        statusBg = const Color(0xFFEEF2FF);
        statusIcon = PhosphorIcons.infoFill;
        statusLabel = 'Leave';
        break;
      default:
        statusColor = const Color(0xFFDC2626);
        statusBg = const Color(0xFFFEF2F2);
        statusIcon = PhosphorIcons.xCircleFill;
        statusLabel = 'Absent';
    }

    final firstJoinTime = rec['firstJoinTime']?.toString();
    final joinEvents = rec['joinEvents'] is List
        ? rec['joinEvents'] as List
        : [];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 4,
            offset: Offset(0, 1.h),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Topic & Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classTopic,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          if (subject.isNotEmpty) ...[
                            Flexible(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF0033A0,
                                  ).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Text(
                                  subject,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0033A0),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 6.w),
                          ],
                          if (batch.isNotEmpty)
                            Flexible(
                              flex: 2,
                              child: Text(
                                batch,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9.5.sp,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(statusIcon, color: statusColor, size: 12.sp),
                      SizedBox(width: 4.w),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),

            // Metadata Row: Date & Time
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  PhosphorIcon(
                    PhosphorIcons.calendarBlankBold,
                    size: 13.sp,
                    color: const Color(0xFF64748B),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                  if (timeStr.isNotEmpty) ...[
                    SizedBox(width: 8.w),
                    // Right-aligned, and a long time string ellipsizes
                    // instead of overflowing the row.
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          PhosphorIcon(
                            PhosphorIcons.clockBold,
                            size: 13.sp,
                            color: const Color(0xFF64748B),
                          ),
                          SizedBox(width: 4.w),
                          Flexible(
                            child: Text(
                              timeStr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Join details / timeline if available
            if (firstJoinTime != null && firstJoinTime.isNotEmpty) ...[
              SizedBox(height: 6.h),
              Row(
                children: [
                  PhosphorIcon(
                    PhosphorIcons.signInBold,
                    size: 11.sp,
                    color: const Color(0xFF059669),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'First Joined: ${_formatTimestamp(firstJoinTime)}',
                    style: TextStyle(
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF059669),
                    ),
                  ),
                  if (joinEvents.length > 1) ...[
                    const Spacer(),
                    Text(
                      '${joinEvents.length} join logs',
                      style: TextStyle(
                        fontSize: 9.sp,
                        color: const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return raw;
    }
  }

  // --- EMPTY & ERROR STATES ---
  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 36.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          PhosphorIcon(
            PhosphorIcons.calendarXBold,
            size: 38.sp,
            color: const Color(0xFF94A3B8),
          ),
          SizedBox(height: 10.h),
          Text(
            'No Attendance Records',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Classes you attend will be recorded automatically here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.sp, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PhosphorIcon(
              PhosphorIcons.warningCircleBold,
              size: 40.sp,
              color: AppTheme.error,
            ),
            SizedBox(height: 10.h),
            Text(
              'Could Not Load Attendance',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink(context),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              _error ?? 'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5.sp,
                color: const Color(0xFF64748B),
              ),
            ),
            SizedBox(height: 16.h),
            ElevatedButton.icon(
              onPressed: _fetchAttendance,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              icon: PhosphorIcon(PhosphorIcons.arrowClockwiseBold, size: 16.sp),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
