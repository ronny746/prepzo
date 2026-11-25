import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/courses/data/models/batch_model.dart';
import 'package:lms/features/courses/presentation/cubit/courses_cubit.dart';
import 'package:lms/features/courses/presentation/cubit/courses_state.dart';
import 'package:lms/features/profile/data/models/profile_details.dart';
import 'package:lms/features/profile/data/repositories/profile_repository.dart';
import 'package:lms/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:lms/features/profile/presentation/profile_detail_screen.dart';
import 'package:lms/routes/app_router.dart';
import 'package:lms/core/services/app_update_service.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.drawer});

  final Widget? drawer;

  @override
  Widget build(BuildContext context) {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              ProfileCubit(profileRepository: context.read<ProfileRepository>())
                ..loadProfile(token),
        ),
        BlocProvider(
          create: (_) => CoursesCubit()..loadCoursesAndBatches(token),
        ),
      ],
      child: _ProfileView(drawer: drawer),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView({this.drawer});
  final Widget? drawer;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<ProfileCubit, ProfileState>(
      listener: (context, state) {
        if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage!),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        if (state.errorMessage != null &&
            state.status == ProfileStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          if (state.status == ProfileStatus.loading ||
              state.status == ProfileStatus.initial) {
            return Scaffold(
              backgroundColor: isDark
                  ? AppTheme.darkBackground
                  : const Color(0xFFF8FAFC),
              body: const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            );
          }

          final profile =
              state.profile ??
              const ProfileDetails(
                id: '',
                name: 'User Profile',
                email: '',
                mobile: '',
                role: 'STUDENT',
                userCode: '',
                gender: '',
                status: 'Active',
                instituteId: '',
                branchId: '',
                address: '',
                city: '',
                state: '',
                studentClass: '',
              );

          return Scaffold(
            backgroundColor: isDark
                ? AppTheme.darkBackground
                : const Color(0xFFF8FAFC),
            drawer: drawer,
            body: SafeArea(
              child: RefreshIndicator(
                onRefresh: () async {
                  final token =
                      context.read<AuthBloc>().state.session?.accessToken ?? '';
                  await context.read<ProfileCubit>().loadProfile(token);
                  if (context.mounted) {
                    context.read<CoursesCubit>().loadCoursesAndBatches(token);
                  }
                },
                color: AppTheme.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderTopBar(context, isDark),
                      const SizedBox(height: 16),

                      // Modern Redesigned Profile Banner Card
                      _ModernProfileBanner(profile: profile, isDark: isDark),
                      const SizedBox(height: 24),

                      // Enrolled Batches Section
                      _buildSectionTitle('ENROLLED BATCHES', isDark),
                      const SizedBox(height: 10),
                      _EnrolledBatchesSection(isDark: isDark),
                      const SizedBox(height: 24),

                      // Account Options & Information Cards
                      _buildSectionTitle('ACCOUNT & PERSONAL', isDark),
                      const SizedBox(height: 10),
                      _MenuOptionsCard(isDark: isDark, profile: profile),
                      const SizedBox(height: 32),

                      // Version Footer
                      Center(
                        child: FutureBuilder<String>(
                          future: AppUpdateService.getCurrentAppVersion(),
                          builder: (context, snapshot) {
                            final ver = snapshot.data ?? '1.0.1';
                            return Column(
                              children: [
                                Text(
                                  'The Prepzo v$ver',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white38
                                        : const Color(0xFF94A3B8),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'https://prepzo.app/',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white24
                                        : const Color(0xFFCBD5E1),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderTopBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Profile',
            style: Theme.of(context).appBarTheme.titleTextStyle,
          ),
          const SizedBox(height: 2),
          Text(
            'Manage account preferences and view enrolled batches',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Color(0xFF94A3B8),
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _ModernProfileBanner extends StatelessWidget {
  const _ModernProfileBanner({required this.profile, required this.isDark});

  final ProfileDetails profile;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile.avatarUrl;
    final hasValidAvatar =
        avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        avatarUrl.startsWith('http');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [AppTheme.primary, const Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: isDark ? 0.3 : 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar Image from API with Edit Action
              GestureDetector(
                onTap: () async {
                  final cubit = context.read<ProfileCubit>();
                  final authBloc = context.read<AuthBloc>();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: cubit,
                        child: const ProfileDetailScreen(),
                      ),
                    ),
                  );
                  final token = authBloc.state.session?.accessToken ?? '';
                  if (token.isNotEmpty) {
                    cubit.loadProfile(token);
                  }
                },
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 38,
                        backgroundColor: Colors.white24,
                        backgroundImage: hasValidAvatar
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: !hasValidAvatar
                            ? const PhosphorIcon(
                                PhosphorIcons.user,
                                size: 42,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name.isNotEmpty ? profile.name : 'Student User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (profile.email.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        profile.email,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            profile.role.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        if (profile.studentClass.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.secondary.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              profile.studentClass,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        if (profile.city.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              profile.city,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EnrolledBatchesSection extends StatelessWidget {
  const _EnrolledBatchesSection({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CoursesCubit, CoursesState>(
      builder: (context, state) {
        if (state.status == CoursesStatus.loading && state.myBatches.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: const Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: AppTheme.primary,
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        }

        final myBatches = state.myBatches;

        if (myBatches.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
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
              children: [
                const PhosphorIcon(
                  PhosphorIcons.usersThree,
                  size: 36,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(height: 10),
                Text(
                  'No Enrolled Batches',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Explore courses and enroll in batches to get started.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.courses);
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Explore Courses'),
                ),
              ],
            ),
          );
        }

        return Column(
          children: myBatches.map((batch) {
            return _ProfileBatchCard(batch: batch, isDark: isDark);
          }).toList(),
        );
      },
    );
  }
}

class _ProfileBatchCard extends StatelessWidget {
  const _ProfileBatchCard({required this.batch, required this.isDark});

  final BatchModel batch;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const PhosphorIcon(
              PhosphorIcons.chalkboardTeacher,
              color: AppTheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${batch.name} ${batch.section != null && batch.section!.isNotEmpty ? '(${batch.section})' : ''}'
                      .trim(),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                if (batch.courseName != null &&
                    batch.courseName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    batch.courseName!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PhosphorIcon(
                  PhosphorIcons.checkCircle,
                  color: AppTheme.success,
                  size: 12,
                ),
                SizedBox(width: 4),
                Text(
                  'Active',
                  style: TextStyle(
                    color: AppTheme.success,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
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

class _MenuOptionsCard extends StatelessWidget {
  const _MenuOptionsCard({required this.isDark, required this.profile});

  final bool isDark;
  final ProfileDetails profile;

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? AppTheme.darkSurface : Colors.white;
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Personal Information Tile -> Navigates to ProfileDetailScreen
            _MenuOptionTile(
              icon: PhosphorIcons.user,
              iconColor: AppTheme.primary,
              title: 'Personal Information',
              subtitle: 'View & edit name, email, mobile, class, city & state',
              onTap: () async {
                final cubit = context.read<ProfileCubit>();
                final authBloc = context.read<AuthBloc>();
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: cubit,
                      child: const ProfileDetailScreen(),
                    ),
                  ),
                );
                final token = authBloc.state.session?.accessToken ?? '';
                if (token.isNotEmpty) {
                  cubit.loadProfile(token);
                }
              },
            ),
            const Divider(height: 1, indent: 56, endIndent: 16),
            if (profile.role.toUpperCase() == 'STUDENT') ...[
              _MenuOptionTile(
                icon: PhosphorIcons.calendarCheck,
                iconColor: const Color(0xFF0033A0),
                title: 'My Attendance',
                subtitle: 'View class attendance history, stats & register',
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.attendance);
                },
              ),
              const Divider(height: 1, indent: 56, endIndent: 16),
            ],
            _MenuOptionTile(
              icon: PhosphorIcons.receipt,
              iconColor: const Color(0xFF8B5CF6),
              title: 'Transactions & Fees',
              subtitle: 'View receipts, enrolled batch & payment history',
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.fees);
              },
            ),
            const Divider(height: 1, indent: 56, endIndent: 16),
            _MenuOptionTile(
              icon: PhosphorIcons.gear,
              iconColor: const Color(0xFF6B7280),
              title: 'Settings & Security',
              subtitle: 'App theme, notifications & password',
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.settings);
              },
            ),
            const Divider(height: 1, indent: 56, endIndent: 16),
            _MenuOptionTile(
              icon: PhosphorIcons.question,
              iconColor: const Color(0xFF0284C7),
              title: 'Help & Support',
              subtitle: 'Contact academy support & FAQs',
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.support);
              },
            ),
            const Divider(height: 1, indent: 56, endIndent: 16),
            _MenuOptionTile(
              icon: PhosphorIcons.signOut,
              iconColor: AppTheme.error,
              title: 'Logout',
              subtitle: 'Sign out from your account safely',
              isDestructive: true,
              onTap: () {
                _showLogoutDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            PhosphorIcon(
              PhosphorIcons.signOut,
              color: AppTheme.error,
              size: 22,
            ),
            SizedBox(width: 10),
            Text(
              'Logout Confirmation',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(const AuthLogoutRequested());
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (r) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _MenuOptionTile extends StatelessWidget {
  const _MenuOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: PhosphorIcon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isDestructive
                ? AppTheme.error
                : (isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white60 : const Color(0xFF64748B),
          ),
        ),
        trailing: PhosphorIcon(
          PhosphorIcons.caretRight,
          size: 18,
          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}
