import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/profile/data/models/profile_details.dart';
import 'package:lms/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:lms/features/profile/presentation/edit_profile_screen.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class ProfileDetailScreen extends StatelessWidget {
  const ProfileDetailScreen({super.key, this.profile});

  final ProfileDetails? profile;

  ImageProvider? _getAvatarImage(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return null;
    if (avatarUrl.startsWith('http')) return NetworkImage(avatarUrl);
    final file = File(avatarUrl);
    if (file.existsSync()) return FileImage(file);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final currentProfile = state.profile ??
            profile ??
            const ProfileDetails(
              id: '',
              name: 'Student User',
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

        final avatarImage = _getAvatarImage(currentProfile.avatarUrl);

        return Scaffold(
          backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
          appBar: AppBar(
            leading: IconButton(
              icon: const PhosphorIcon(PhosphorIcons.arrowLeft, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Personal Profile Details',
              style: Theme.of(context).appBarTheme.titleTextStyle,
            ),
            actions: [
              IconButton(
                icon: const PhosphorIcon(PhosphorIcons.pencilSimple, size: 20),
                tooltip: 'Edit Profile',
                onPressed: () => _navigateToEdit(context, currentProfile),
              ),
              const SizedBox(width: 8),
            ],
            backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
                await context.read<ProfileCubit>().loadProfile(token);
              },
              color: AppTheme.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar Banner
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [AppTheme.primary, AppTheme.secondary],
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 46,
                              backgroundColor: Colors.white24,
                              backgroundImage: avatarImage,
                              child: avatarImage == null
                                  ? const PhosphorIcon(PhosphorIcons.user, size: 48, color: Colors.white)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            currentProfile.name.isNotEmpty ? currentProfile.name : 'Student User',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentProfile.email.isNotEmpty ? currentProfile.email : 'No email provided',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Personal Information Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const PhosphorIcon(PhosphorIcons.user, color: AppTheme.primary, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Personal Details',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _detailRow('Full Name', currentProfile.name.isNotEmpty ? currentProfile.name : 'Not Provided', PhosphorIcons.user, isDark),
                          const Divider(height: 20),
                          _detailRow('Email Address', currentProfile.email.isNotEmpty ? currentProfile.email : 'Not Provided', PhosphorIcons.envelope, isDark),
                          const Divider(height: 20),
                          _detailRow('Mobile Number', currentProfile.mobile.isNotEmpty ? currentProfile.mobile : 'Not Provided', PhosphorIcons.phone, isDark),
                          const Divider(height: 20),
                          _detailRow('Class', currentProfile.studentClass.isNotEmpty ? currentProfile.studentClass : 'Not Provided', PhosphorIcons.chalkboard, isDark),
                          const Divider(height: 20),
                          _detailRow('City', currentProfile.city.isNotEmpty ? currentProfile.city : 'Not Provided', PhosphorIcons.buildings, isDark),
                          const Divider(height: 20),
                          _detailRow('State', currentProfile.state.isNotEmpty ? currentProfile.state : 'Not Provided', PhosphorIcons.mapTrifold, isDark),
                          const Divider(height: 20),
                          _detailRow('Gender', currentProfile.gender.isNotEmpty ? currentProfile.gender : 'Not Specified', PhosphorIcons.genderIntersex, isDark),
                          const Divider(height: 20),
                          _detailRow('Full Address', currentProfile.address.isNotEmpty ? currentProfile.address : 'Not Provided', PhosphorIcons.mapPin, isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Edit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateToEdit(context, currentProfile),
                        icon: const PhosphorIcon(PhosphorIcons.pencilSimple, size: 18),
                        label: const Text('Edit Profile Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value, IconData icon, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: PhosphorIcon(icon, size: 16, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToEdit(BuildContext context, ProfileDetails currentProfile) async {
    final cubit = context.read<ProfileCubit>();
    final authBloc = context.read<AuthBloc>();
    final token = authBloc.state.session?.accessToken ?? '';

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: EditProfileScreen(initialProfile: cubit.state.profile ?? currentProfile),
        ),
      ),
    );

    // Call GET API to fetch updated user info from server
    if (token.isNotEmpty) {
      await cubit.loadProfile(token);
    }
  }
}
