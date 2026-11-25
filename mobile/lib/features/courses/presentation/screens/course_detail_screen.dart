import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:lms/core/services/deep_link_service.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/l10n/app_localizations.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/courses/data/models/course_model.dart';
import 'package:lms/features/courses/presentation/cubit/courses_cubit.dart';
import 'package:lms/features/courses/presentation/cubit/courses_state.dart';
import 'package:lms/features/courses/presentation/widgets/course_tests_section.dart';
import 'package:lms/features/courses/presentation/widgets/shakti_planner.dart';
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
    _load();
  }

  /// Loads (or retries loading) the course detail for this screen's id.
  void _load() {
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
      backgroundColor: isDark
          ? AppTheme.darkBackground
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: Material(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFF1F5F9),
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

          // Only render a course whose id matches this screen; a stale
          // selectedCourse from a previous visit must never be shown.
          final selected = state.selectedCourse;
          final course = selected != null && selected.id == widget.courseId
              ? selected
              : null;
          if (course == null) {
            if (state.status == CoursesStatus.initial) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              );
            }
            final l10n = AppLocalizations.of(context)!;
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PhosphorIcon(
                    PhosphorIcons.warningCircle,
                    size: 40,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.courseLoadFailed,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _load,
                    child: Text(l10n.courseRetry),
                  ),
                ],
              ),
            );
          }

          final enrollmentKnown = state.myBatchesLoaded;
          final isEnrolled = state.myBatches.any(
            (b) => b.courseId == course.id,
          );

          final hexColorStr = course.color?.replaceAll('#', '');
          // A navy course colour would vanish on the dark theme, so it is
          // swapped for gold there.
          final primaryColor = AppTheme.readableAccent(
            context,
            hexColorStr != null && hexColorStr.length == 6
                ? Color(int.parse('FF$hexColorStr', radix: 16))
                : AppTheme.primary,
          );

          int? discountPercent;
          if (course.actualFee != null &&
              course.actualFee! > course.fee &&
              course.actualFee! > 0) {
            discountPercent =
                (((course.actualFee! - course.fee) / course.actualFee!) * 100)
                    .round();
          }

          final isShakti = isShaktiCourse(course);
          final tabs = <Tab>[
            const Tab(text: 'Overview'),
            const Tab(text: 'Tests'),
            if (isShakti) const Tab(text: 'Schedule'),
          ];
          // Each tab scrolls on its own under a pinned tab bar, so no section
          // is buried at the bottom of one very long page.
          Widget tabBody(String key, List<Widget> children) => Builder(
            builder: (context) => CustomScrollView(
              key: PageStorageKey<String>(key),
              slivers: [
                SliverOverlapInjector(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                    context,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(children),
                  ),
                ),
              ],
            ),
          );

          return DefaultTabController(
            length: tabs.length,
            child: Column(
              children: [
                Expanded(
                  child: NestedScrollView(
                    headerSliverBuilder: (context, _) => [
                      SliverToBoxAdapter(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
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
                                  if (course.tag != null &&
                                      course.tag!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        course.tag!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  if (course.badge != null &&
                                      course.badge!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.brandInk(context),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        course.badge!.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  if (discountPercent != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.success,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '$discountPercent% OFF',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                course.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  height: 1.3,
                                ),
                              ),
                              if (course.subtitle != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  course.subtitle!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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
                      ),
                      SliverOverlapAbsorber(
                        handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                          context,
                        ),
                        sliver: SliverPersistentHeader(
                          pinned: true,
                          delegate: _TabBarHeader(
                            background: isDark
                                ? AppTheme.darkBackground
                                : const Color(0xFFF8FAFC),
                            divider: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : const Color(0xFFE2E8F0),
                            tabBar: TabBar(
                              tabs: tabs,
                              labelColor: isDark ? Colors.white : primaryColor,
                              unselectedLabelColor: const Color(0xFF64748B),
                              indicatorColor: primaryColor,
                              indicatorWeight: 3,
                              indicatorSize: TabBarIndicatorSize.label,
                              dividerColor: Colors.transparent,
                              labelStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              unselectedLabelStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    body: TabBarView(
                      children: [
                        tabBody('overview', [
                          _buildAccessHighlights(course.access, isDark),
                          const SizedBox(height: 16),
                          _buildSectionCard(
                            title: 'About this course',
                            icon: PhosphorIcons.bookOpen,
                            color: primaryColor,
                            isDark: isDark,
                            // Long descriptions fold to a few lines so the
                            // tests below are reachable without endless scrolling.
                            child: _ExpandableText(
                              text:
                                  course.description ??
                                  'Structured learning program designed by top educators with live classes, study materials, and regular testing.',
                              linkColor: primaryColor,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF334155),
                                height: 1.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (course.features.isNotEmpty) ...[
                            _buildSectionCard(
                              title: 'What you will get',
                              icon: PhosphorIcons.checkCircle,
                              color: primaryColor,
                              isDark: isDark,
                              child: _FeatureList(
                                features: course.features,
                                isDark: isDark,
                                linkColor: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (course.bestFor.isNotEmpty)
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
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.05,
                                              )
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.08,
                                                )
                                              : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const PhosphorIcon(
                                            PhosphorIcons.userCheck,
                                            size: 14,
                                            color: AppTheme.primary,
                                          ),
                                          const SizedBox(width: 6),
                                          // Flexible + ellipsis: long strings must not overflow the chip.
                                          Flexible(
                                            child: Text(
                                              bf,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                        ]),
                        tabBody('tests', [
                          CourseTestsSection(
                            key: ValueKey('tests-${course.id}-$isEnrolled'),
                            courseId: course.id,
                            isEnrolled: isEnrolled,
                            accent: primaryColor,
                            onUnlock: () {
                              // Same guard as the Enroll button: never
                              // offer payment while enrollment is unknown.
                              if (isEnrolled || !enrollmentKnown) return;
                              _showCheckoutModal(context, course);
                            },
                          ),
                        ]),
                        if (isShakti)
                          tabBody('schedule', [const ShaktiPlanner()]),
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
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.3 : 0.05,
                        ),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        // Price keeps its natural width (capped at 42% of the
                        // screen, shrinking a very big fee) and the button fills
                        // the rest, right up to the edge.
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.42,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'TOTAL FEE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    if (course.actualFee != null &&
                                        course.actualFee! > course.fee) ...[
                                      Text(
                                        '₹${course.actualFee}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          decoration:
                                              TextDecoration.lineThrough,
                                          color: isDark
                                              ? Colors.white38
                                              : const Color(0xFF94A3B8),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      '₹${course.fee}',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            // Disabled while enrollment is unknown (batches failed)
                            // so a possibly-enrolled student can't pay twice.
                            onPressed: (isEnrolled || !enrollmentKnown)
                                ? null
                                : () => _showCheckoutModal(context, course),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isEnrolled
                                  ? AppTheme.success
                                  : primaryColor,
                              disabledBackgroundColor: isEnrolled
                                  ? AppTheme.success.withValues(alpha: 0.8)
                                  : Colors.grey.withValues(alpha: 0.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                PhosphorIcon(
                                  isEnrolled
                                      ? PhosphorIcons.checkCircle
                                      : PhosphorIcons.lightning,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    isEnrolled ? 'Enrolled' : 'Enroll Now',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: Colors.white,
                                    ),
                                  ),
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccessHighlights(CourseAccessModel access, bool isDark) {
    final items = [
      if (access.liveClasses)
        {
          'title': 'LIVE CLASSES',
          'icon': PhosphorIcons.videoCamera,
          'color': const Color(0xFF10B981),
        },
      if (access.testSeries)
        {
          'title': 'TEST SERIES',
          'icon': PhosphorIcons.target,
          'color': const Color(0xFF3B82F6),
        },
      if (access.studyMaterials)
        {
          'title': 'MATERIALS',
          'icon': PhosphorIcons.books,
          'color': const Color(0xFF8B5CF6),
        },
      if (access.dpps)
        {
          'title': 'DAILY DPPS',
          'icon': PhosphorIcons.clipboardText,
          'color': const Color(0xFFF59E0B),
        },
    ];

    if (items.isEmpty) return const SizedBox.shrink();
    // Small pills that wrap, so one or three items never leave a half-empty
    // grid cell.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (item['color'] as Color).withValues(
                alpha: isDark ? 0.15 : 0.08,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (item['color'] as Color).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PhosphorIcon(
                  item['icon'] as IconData,
                  color: item['color'] as Color,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Text(
                  item['title'] as String,
                  style: TextStyle(
                    color: item['color'] as Color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
      ],
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
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
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
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
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
  late final Razorpay _razorpay;
  String? _pendingOrderId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final parentCtx = widget.parentContext;
    final cubit = parentCtx.read<CoursesCubit>();
    final token = parentCtx.read<AuthBloc>().state.session?.accessToken ?? '';

    setState(() => _isProcessing = true);
    try {
      final orderId = response.orderId ?? _pendingOrderId ?? '';
      final paymentId = response.paymentId ?? '';
      final signature = response.signature ?? '';

      final verified = await cubit.verifyRazorpayPayment(
        orderId: orderId,
        paymentId: paymentId,
        signature: signature,
        token: token,
      );

      if (verified) {
        try {
          await cubit.loadCourseDetail(widget.course.id, token);
          await cubit.loadCoursesAndBatches(token);
        } catch (_) {}

        if (mounted) Navigator.pop(context);

        if (parentCtx.mounted) {
          ScaffoldMessenger.of(parentCtx).showSnackBar(
            const SnackBar(
              content: Text('Payment verified and enrolled successfully!'),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) setState(() => _isProcessing = false);
        if (parentCtx.mounted) {
          ScaffoldMessenger.of(parentCtx).showSnackBar(
            const SnackBar(
              content: Text(
                'Payment verification failed. Please contact support if amount was deducted.',
              ),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
      if (parentCtx.mounted) {
        ScaffoldMessenger.of(parentCtx).showSnackBar(
          SnackBar(
            content: Text('Verification error: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) setState(() => _isProcessing = false);
    final msg = response.message ?? 'Payment cancelled or failed';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment Failed: $msg'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // External wallet response
  }

  void _handlePay() async {
    setState(() => _isProcessing = true);
    final parentCtx = widget.parentContext;
    final cubit = parentCtx.read<CoursesCubit>();
    final token = parentCtx.read<AuthBloc>().state.session?.accessToken ?? '';

    if (widget.course.fee <= 0) {
      final ok = await cubit.enrollInCourse(widget.course.id, token);
      if (ok) {
        if (mounted) Navigator.pop(context);
        return;
      }
      // Failure (e.g. incomplete profile): surface the server error and keep
      // the modal open and usable instead of failing silently.
      if (mounted) setState(() => _isProcessing = false);
      final err = cubit.state.error;
      if (parentCtx.mounted) {
        ScaffoldMessenger.of(parentCtx).showSnackBar(
          SnackBar(
            content: Text(
              err ?? AppLocalizations.of(parentCtx)!.courseEnrollFailed,
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      final res = await cubit.initiateRazorpayOrder(widget.course.id, token);

      if (res != null && res['orderId'] != null) {
        _pendingOrderId = res['orderId'].toString();
        final keyId = res['keyId']?.toString() ?? '';
        final amount = res['amount']; // in paise from backend
        final user = res['user'] is Map ? res['user'] as Map : {};

        final options = {
          'key': keyId,
          'amount': amount,
          'name': 'Prepzo',
          'description': widget.course.name,
          'order_id': _pendingOrderId,
          'prefill': {
            'contact': user['phone']?.toString() ?? '',
            'email': user['email']?.toString() ?? '',
            'name': user['name']?.toString() ?? '',
          },
          'theme': {'color': '#025036'}, // Prepzo emerald
          'retry': {'enabled': true, 'max_count': 1},
        };

        _razorpay.open(options);
      } else {
        setState(() => _isProcessing = false);
        final err =
            res?['message'] ?? 'Could not initiate payment order with server';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment initiation failed: $err'),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
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
                    const PhosphorIcon(
                      PhosphorIcons.shieldCheck,
                      color: AppTheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Checkout',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
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
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.course.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Divider(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Payable',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '₹${widget.course.fee}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
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
                PhosphorIcon(
                  PhosphorIcons.lockKey,
                  size: 14,
                  color: Color(0xFF059669),
                ),
                SizedBox(width: 6),
                Text(
                  'Secured by Razorpay Payment Gateway',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF059669),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        widget.course.fee > 0
                            ? 'Pay ₹${widget.course.fee} via Razorpay'
                            : 'Confirm & Enroll Now',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandableText extends StatefulWidget {
  const _ExpandableText({
    required this.text,
    required this.style,
    required this.linkColor,
  });

  final String text;
  final TextStyle style;
  final Color linkColor;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  static const _collapsedLines = 6;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: _collapsedLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: Text(
                widget.text,
                style: widget.style,
                maxLines: _expanded ? null : _collapsedLines,
                overflow: _expanded ? null : TextOverflow.fade,
              ),
            ),
            if (overflows)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(top: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: widget.linkColor,
                ),
                child: Text(
                  _expanded ? 'Show less' : 'Read more',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Pinned tab bar under the course banner.
class _TabBarHeader extends SliverPersistentHeaderDelegate {
  _TabBarHeader({
    required this.tabBar,
    required this.background,
    required this.divider,
  });

  final TabBar tabBar;
  final Color background;
  final Color divider;

  @override
  double get minExtent => tabBar.preferredSize.height + 1;

  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border(bottom: BorderSide(color: divider)),
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarHeader old) =>
      old.tabBar != tabBar ||
      old.background != background ||
      old.divider != divider;
}

/// "What you will get": the first few points, the rest behind "Show all".
class _FeatureList extends StatefulWidget {
  const _FeatureList({
    required this.features,
    required this.isDark,
    required this.linkColor,
  });

  final List<String> features;
  final bool isDark;
  final Color linkColor;

  @override
  State<_FeatureList> createState() => _FeatureListState();
}

class _FeatureListState extends State<_FeatureList> {
  static const _collapsed = 5;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final all = widget.features;
    final shown = _expanded ? all : all.take(_collapsed).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final feat in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: PhosphorIcon(
                    PhosphorIcons.checkCircleFill,
                    color: AppTheme.success,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    feat,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark
                          ? Colors.white
                          : const Color(0xFF1E293B),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (all.length > _collapsed)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: widget.linkColor,
            ),
            child: Text(
              _expanded ? 'Show less' : 'Show all ${all.length}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}
