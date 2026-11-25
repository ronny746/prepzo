import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/services/deep_link_service.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/courses/data/models/course_model.dart';
import 'package:lms/features/courses/presentation/cubit/courses_cubit.dart';
import 'package:lms/features/courses/presentation/cubit/courses_state.dart';
import 'package:lms/features/courses/presentation/screens/payment_webview_screen.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class CourseDetailScreen extends StatefulWidget {
  final String courseId;

  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  @override
  void initState() {
    super.initState();
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    context.read<CoursesCubit>().loadCourseDetail(widget.courseId, token);
  }

  void _showCheckoutModal(BuildContext context, CourseModel course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CheckoutModal(course: course, parentContext: context),
    );
  }

  /// Opens the phone's share sheet with the course's public web link
  /// (which opens straight in the app for students who have it).
  Future<void> _shareCourse(BuildContext context) async {
    final selected = context.read<CoursesCubit>().state.selectedCourse;
    final course = selected != null && selected.id == widget.courseId
        ? selected
        : null;
    final url = DeepLinkService.courseUrl(
      id: widget.courseId,
      slug: course?.slug,
    );
    final name = course?.name ?? 'this course';
    final text = 'Check out $name on Prepzo:\n$url';
    final shared = await AppShare.text(text, subject: name);
    if (shared || !context.mounted) return;
    // No share sheet available: fall back to copying the link.
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Course link copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: Material(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => Navigator.maybePop(context),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: PhosphorIcon(
                    PhosphorIcons.arrowLeft,
                    size: 20,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
          ),
        ),
        title: Text(
          'Course Details',
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
        actions: [
          IconButton(
            icon: const PhosphorIcon(PhosphorIcons.shareNetwork, size: 20),
            tooltip: 'Share Course',
            onPressed: () => _shareCourse(context),
          ),
          const SizedBox(width: 8),
        ],
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: BlocConsumer<CoursesCubit, CoursesState>(
        listener: (context, state) {
          if (state.enrollSuccessMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.enrollSuccessMessage!),
                backgroundColor: AppTheme.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.status == CoursesStatus.loading) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppTheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Loading course overview...',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          final course = state.selectedCourse;
          if (course == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PhosphorIcon(PhosphorIcons.warningCircle, size: 40, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('Course details not available.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.maybePop(context),
                    child: const Text('Back to Catalog'),
                  ),
                ],
              ),
            );
          }

          final isEnrolled = state.myBatches.any((b) => b.courseId == course.id);

          final hexColorStr = course.color?.replaceAll('#', '');
          final primaryColor = hexColorStr != null && hexColorStr.length == 6
              ? Color(int.parse('FF$hexColorStr', radix: 16))
              : AppTheme.primary;

          int? discountPercent;
          if (course.actualFee != null && course.actualFee! > course.fee && course.actualFee! > 0) {
            discountPercent = (((course.actualFee! - course.fee) / course.actualFee!) * 100).round();
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Banner Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryColor, const Color(0xFF0F172A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                if (course.tag != null && course.tag!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      course.tag!,
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                if (course.badge != null && course.badge!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.secondary,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      course.badge!.toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                if (discountPercent != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.success,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '$discountPercent% OFF',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              course.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                height: 1.3,
                              ),
                            ),
                            if (course.subtitle != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                course.subtitle!,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Access privileges chips
                            _buildAccessHighlights(course.access, isDark),

                            const SizedBox(height: 20),

                            // About section
                            _buildSectionCard(
                              title: 'About this course',
                              icon: PhosphorIcons.bookOpen,
                              color: primaryColor,
                              isDark: isDark,
                              child: Text(
                                course.description ?? 'Structured learning program designed by top educators with live classes, study materials, and regular testing.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                                  height: 1.6,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Features list
                            if (course.features.isNotEmpty)
                              _buildSectionCard(
                                title: 'What you will get',
                                icon: PhosphorIcons.checkCircle,
                                color: primaryColor,
                                isDark: isDark,
                                child: Column(
                                  children: course.features.map((feat) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Padding(
                                            padding: EdgeInsets.only(top: 2),
                                            child: PhosphorIcon(PhosphorIcons.checkCircleFill, color: AppTheme.success, size: 18),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              feat,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),

                            const SizedBox(height: 16),

                            // Best suited for
                            if (course.bestFor.isNotEmpty)
                              _buildSectionCard(
                                title: 'Best Suited For',
                                icon: PhosphorIcons.trophy,
                                color: primaryColor,
                                isDark: isDark,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: course.bestFor.map((bf) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const PhosphorIcon(PhosphorIcons.userCheck, size: 14, color: AppTheme.primary),
                                          const SizedBox(width: 6),
                                          Text(
                                            bf,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Checkout Bar
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'TOTAL FEE',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (course.actualFee != null && course.actualFee! > course.fee) ...[
                                Text(
                                  '₹${course.actualFee}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    decoration: TextDecoration.lineThrough,
                                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                '₹${course.fee}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isEnrolled
                              ? null
                              : () => _showCheckoutModal(context, course),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isEnrolled ? AppTheme.success : primaryColor,
                            disabledBackgroundColor: AppTheme.success.withValues(alpha: 0.8),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              PhosphorIcon(
                                isEnrolled ? PhosphorIcons.checkCircle : PhosphorIcons.lightning,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isEnrolled ? 'Enrolled' : 'Enroll Now',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAccessHighlights(CourseAccessModel access, bool isDark) {
    final items = [
      if (access.liveClasses) {'title': 'LIVE CLASSES', 'icon': PhosphorIcons.videoCamera, 'color': const Color(0xFF10B981)},
      if (access.testSeries) {'title': 'TEST SERIES', 'icon': PhosphorIcons.target, 'color': const Color(0xFF3B82F6)},
      if (access.studyMaterials) {'title': 'MATERIALS', 'icon': PhosphorIcons.books, 'color': const Color(0xFF8B5CF6)},
      if (access.dpps) {'title': 'DAILY DPPS', 'icon': PhosphorIcons.clipboardText, 'color': const Color(0xFFF59E0B)},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3.2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, idx) {
        final item = items[idx];
        final color = item['color'] as Color;
        final icon = item['icon'] as IconData;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            PhosphorIcon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(
              item['title'] as String,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.4),
            ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 12,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: PhosphorIcon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
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
}

class _CheckoutModal extends StatefulWidget {
  final CourseModel course;
  final BuildContext parentContext;

  const _CheckoutModal({required this.course, required this.parentContext});

  @override
  State<_CheckoutModal> createState() => _CheckoutModalState();
}

class _CheckoutModalState extends State<_CheckoutModal> {
  bool _isProcessing = false;

  void _handlePay() async {
    setState(() => _isProcessing = true);
    final parentCtx = widget.parentContext;
    final cubit = parentCtx.read<CoursesCubit>();
    final token = parentCtx.read<AuthBloc>().state.session?.accessToken ?? '';

    if (widget.course.fee <= 0) {
      await cubit.enrollInCourse(widget.course.id, token);
      if (mounted) Navigator.pop(context);
      return;
    }

    try {
      final res = await cubit.initiateCoursePayment(widget.course.id, token);

      if (res != null && res['paymentUrl'] != null && res['paymentUrl'].toString().isNotEmpty) {
        final paymentUrlStr = res['paymentUrl'].toString();
        if (mounted) Navigator.pop(context);

        // Open WebView instead of external browser
        if (parentCtx.mounted) {
          final bool? success = await Navigator.of(parentCtx).push<bool>(
            MaterialPageRoute(
              builder: (_) => PaymentWebViewScreen(
                url: paymentUrlStr,
                title: 'Course Enrollment',
              ),
            ),
          );

          if (success == true && parentCtx.mounted) {
            // Payment success, finalize enrollment and reload course details & batches
            // The server now refuses enrollment (402) unless the payment was
            // verified, so only claim success when enrollment really succeeded.
            final enrolled = await cubit.enrollInCourse(widget.course.id, token);
            try {
              await cubit.loadCourseDetail(widget.course.id, token);
              await cubit.loadCoursesAndBatches(token);
            } catch (_) {}
            if (parentCtx.mounted && !enrolled) {
              ScaffoldMessenger.of(parentCtx).showSnackBar(
                const SnackBar(
                  content: Text('Payment was not completed or failed.'),
                  backgroundColor: AppTheme.error,
                ),
              );
            } else if (parentCtx.mounted) {
              ScaffoldMessenger.of(parentCtx).showSnackBar(
                const SnackBar(
                  content: Text('Payment completed successfully! You are now enrolled.'),
                  backgroundColor: AppTheme.success,
                ),
              );
            }
          } else if (parentCtx.mounted) {
            ScaffoldMessenger.of(parentCtx).showSnackBar(
              const SnackBar(
                content: Text('Payment was not completed or failed.'),
                backgroundColor: AppTheme.error,
              ),
            );
          }
        }
      } else {
        await cubit.enrollInCourse(widget.course.id, token);
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const PhosphorIcon(PhosphorIcons.shieldCheck, color: AppTheme.primary, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Checkout',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const PhosphorIcon(PhosphorIcons.x, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.course.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Divider(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Payable',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '₹${widget.course.fee}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PhosphorIcon(PhosphorIcons.lockKey, size: 14, color: Color(0xFF059669)),
                SizedBox(width: 6),
                Text(
                  'Secured by Easebuzz Payment Gateway',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _handlePay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        widget.course.fee > 0 ? 'Pay ₹${widget.course.fee} via Easebuzz' : 'Confirm & Enroll Now',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
