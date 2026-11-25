import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/courses/data/models/course_model.dart';
import 'package:lms/features/courses/presentation/cubit/courses_cubit.dart';
import 'package:lms/features/courses/presentation/cubit/courses_state.dart';
import 'package:lms/routes/app_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class CoursesCatalogScreen extends StatefulWidget {
  const CoursesCatalogScreen({super.key});

  @override
  State<CoursesCatalogScreen> createState() => _CoursesCatalogScreenState();
}

class _CoursesCatalogScreenState extends State<CoursesCatalogScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    context.read<CoursesCubit>().loadCoursesAndBatches(token);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.darkBackground
          : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _loadData(),
          color: AppTheme.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopNavigation(context, isDark),
                      const SizedBox(height: 18),
                      _buildSearchBar(isDark),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              BlocBuilder<CoursesCubit, CoursesState>(
                builder: (context, state) {
                  if (state.status == CoursesStatus.loading &&
                      state.courses.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: AppTheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Fetching courses...',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.white60
                                    : const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (state.error != null && state.courses.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.error.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const PhosphorIcon(
                                  PhosphorIcons.warningCircle,
                                  color: AppTheme.error,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Unable to load courses',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                state.error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _loadData,
                                icon: const PhosphorIcon(
                                  PhosphorIcons.arrowsClockwise,
                                  size: 18,
                                ),
                                label: const Text('Try Again'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final filteredCourses = state.courses.where((c) {
                    if (_searchQuery.isEmpty) return true;
                    final query = _searchQuery.toLowerCase();
                    return c.name.toLowerCase().contains(query) ||
                        (c.tag?.toLowerCase().contains(query) ?? false) ||
                        (c.subtitle?.toLowerCase().contains(query) ?? false);
                  }).toList();

                  if (filteredCourses.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const PhosphorIcon(
                                PhosphorIcons.magnifyingGlass,
                                size: 40,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No matching courses found',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Try searching with a different term.',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13,
                              ),
                            ),
                            if (_searchQuery.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _searchController.clear();
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Clear Search'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final course = filteredCourses[index];
                        final isEnrolled = state.myBatches.any(
                          (b) => b.courseId == course.id,
                        );
                        return _CourseCard(
                          course: course,
                          isEnrolled: isEnrolled,
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.courseDetail,
                              arguments: course.id,
                            );
                          },
                        );
                      }, childCount: filteredCourses.length),
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopNavigation(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Back Button
            Material(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => Navigator.maybePop(context),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: PhosphorIcon(
                    PhosphorIcons.arrowLeft,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Explore Courses',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Find expert-curated programs for your success',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Material(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: _loadData,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  child: const PhosphorIcon(
                    PhosphorIcons.arrowsClockwise,
                    color: AppTheme.primary,
                    size: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          icon: const PhosphorIcon(
            PhosphorIcons.magnifyingGlass,
            color: Color(0xFF94A3B8),
            size: 20,
          ),
          hintText: 'Search courses, tags, or topics...',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const PhosphorIcon(
                    PhosphorIcons.x,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final CourseModel course;
  final bool isEnrolled;
  final VoidCallback onTap;

  const _CourseCard({
    required this.course,
    required this.isEnrolled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hexColorStr = course.color?.replaceAll('#', '');
    final courseColor = AppTheme.readableAccent(
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: courseColor.withValues(alpha: 0.1),
            highlightColor: courseColor.withValues(alpha: 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Color Gradient Strip
                Container(
                  height: 6,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [courseColor, courseColor.withValues(alpha: 0.6)],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row (Icon + Exam Tags + Badge)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: courseColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: PhosphorIcon(
                              PhosphorIcons.graduationCap,
                              color: courseColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    if (course.tag != null &&
                                        course.tag!.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          course.tag!,
                                          style: const TextStyle(
                                            color: AppTheme.primary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    if (course.badge != null &&
                                        course.badge!.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.brandInk(
                                            context,
                                          ).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          course.badge!.toUpperCase(),
                                          style: TextStyle(
                                            color: AppTheme.brandInk(context),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    if (discountPercent != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.success.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          '$discountPercent% OFF',
                                          style: const TextStyle(
                                            color: AppTheme.success,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  course.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                    letterSpacing: -0.4,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      if (course.subtitle != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          course.subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white60
                                : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ],

                      if (course.features.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: course.features.take(3).map((f) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const PhosphorIcon(
                                    PhosphorIcons.checkCircle,
                                    size: 12,
                                    color: AppTheme.success,
                                  ),
                                  const SizedBox(width: 4),
                                  // Flexible + ellipsis: long feature strings must not overflow the chip.
                                  Flexible(
                                    child: Text(
                                      f,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 16),
                      Divider(
                        height: 1,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFE2E8F0),
                      ),
                      const SizedBox(height: 14),

                      // Pricing & Action Button Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Expanded + FittedBox: two 5-digit fees shrink
                          // instead of pushing the button off a narrow card.
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'COURSE FEE',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF94A3B8),
                                      letterSpacing: 0.6,
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
                                            fontSize: 12,
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
                                        style: const TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w900,
                                          color: AppTheme.primary,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: onTap,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isEnrolled
                                  ? AppTheme.success
                                  : AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isEnrolled ? 'Enrolled' : 'View Details',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                if (!isEnrolled) ...[
                                  const SizedBox(width: 4),
                                  const PhosphorIcon(
                                    PhosphorIcons.arrowRight,
                                    size: 14,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
