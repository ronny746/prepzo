import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class StudentInformationScreen extends StatelessWidget {
  const StudentInformationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = context.watch<AuthBloc>().state;
    final user = authState.session?.user;

    ProfileCubit? profileCubit;
    try {
      profileCubit = context.watch<ProfileCubit>();
    } catch (_) {}

    final profile = profileCubit?.state.profile;

    final name = profile?.name ?? user?.name ?? 'Aarav Sharma';
    final rollNo = profile?.rollNumber ?? 'PREPZO-2026-042';
    final studentClass = profile?.studentClass ?? 'Class 12';
    final section = profile?.section ?? 'Section A';
    final session = profile?.session ?? '2025-2026';
    final targetExam = profile?.targetExam ?? 'IIT-JEE (Main & Advanced)';
    final institute = profile?.instituteName ?? 'The Prepzo';
    final userCode = profile?.userCode.isNotEmpty == true ? profile!.userCode : (user?.id.substring(0, 8).toUpperCase() ?? 'STD-8840');

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const PhosphorIcon(PhosphorIcons.arrowLeft, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Academic Information',
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Banner Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const PhosphorIcon(PhosphorIcons.graduationCap, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$studentClass • $section | Roll No: $rollNo',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Student Identity Details
              _buildSectionCard(
                title: 'Student Credentials',
                icon: PhosphorIcons.identificationCard,
                isDark: isDark,
                children: [
                  _infoTile('Student ID / Code', userCode, isDark),
                  _infoTile('Admission Number', 'ADM-PREPZO-5567', isDark),
                  _infoTile('Roll Number', rollNo, isDark),
                  _infoTile('Class & Section', '$studentClass ($section)', isDark),
                  _infoTile('Academic Batch', session, isDark),
                ],
              ),
              const SizedBox(height: 18),

              // Academic Information
              _buildSectionCard(
                title: 'Program & Curriculum',
                icon: PhosphorIcons.books,
                isDark: isDark,
                children: [
                  _infoTile('Target Exam', targetExam, isDark),
                  _infoTile('Enrolled Subjects', 'Physics, Chemistry, Mathematics', isDark),
                  _infoTile('Class Teacher', 'Ms. Kavya Mehta', isDark),
                  _infoTile('Institute', institute, isDark),
                  _infoTile('Medium of Instruction', 'English / Hindi (Bilingual)', isDark),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
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
              PhosphorIcon(icon, color: AppTheme.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
