import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/core/config/app_config.dart';

class NeetCountdownWidget extends StatefulWidget {
  const NeetCountdownWidget({super.key});

  @override
  State<NeetCountdownWidget> createState() => _NeetCountdownWidgetState();
}

class _NeetCountdownWidgetState extends State<NeetCountdownWidget> {
  String _examTitle = 'NEET UG 2027';
  String _examDateStr = '2027-05-02T10:00:00.000Z';
  String _targetDateLabel = 'Expected May 2027 (Tentative)';
  String _subtitle = 'Stay focused. Every day counts toward your goal! 🎯';
  String _daysLabel = 'DAYS LEFT';

  @override
  void initState() {
    super.initState();
    _fetchPublicConfig();
  }

  Future<void> _fetchPublicConfig() async {
    try {
      final dio = Dio();
      final response = await dio.get('${AppConfig.baseUrl}/public-settings');
      if (response.data is Map<String, dynamic> &&
          response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data['neetExamConfig'] != null) {
          final neet = data['neetExamConfig'];
          if (mounted) {
            setState(() {
              _examTitle = neet['examTitle']?.toString() ?? _examTitle;
              _examDateStr = neet['examDate']?.toString() ?? _examDateStr;
              _targetDateLabel =
                  neet['targetDateLabel']?.toString() ?? _targetDateLabel;
              _subtitle = neet['subtitle']?.toString() ?? _subtitle;
              _daysLabel = neet['daysLabel']?.toString() ?? _daysLabel;
            });
          }
        }
      }
    } catch (e) {
      // Fallback silently to default config if offline/error
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final targetDate = DateTime.tryParse(_examDateStr) ?? DateTime(2027, 5, 2);
    final now = DateTime.now();

    final difference = targetDate.difference(now);
    final remainingDays = difference.inDays > 0 ? difference.inDays : 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF1E1E2E), Color(0xFF13131E)]
              : const [Color(0xFF0F172A), Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.15),
            blurRadius: 12,
            offset: Offset(0, 4.h),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          // Flame Icon Badge
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF4D4D), Color(0xFFF59E0B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF4D4D).withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: Offset(0, 2.h),
                ),
              ],
            ),
            child: Center(
              child: PhosphorIcon(
                PhosphorIcons.flameFill,
                color: Colors.white,
                size: 18.sp,
              ),
            ),
          ),
          SizedBox(width: 10.w),

          // Center Text Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _examTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_subtitle.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    _subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.sp,
                      color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 10.w),

          // Right Days Badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFE11D48)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: Offset(0, 2.h),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$remainingDays',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  _daysLabel.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 7.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
