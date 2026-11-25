import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/core/widgets/app_scaffold.dart';
import 'package:lms/core/widgets/section_card.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/dashboard/data/models/dashboard_models.dart';
import 'package:lms/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:lms/features/dashboard/presentation/cubit/parent_dashboard_cubit.dart';
import 'package:lms/features/parent/presentation/parent_dashboard_screen.dart' show showLinkStudentModal;

class ParentChildrenScreen extends StatefulWidget {
  const ParentChildrenScreen({super.key, this.drawer});

  final Widget? drawer;

  @override
  State<ParentChildrenScreen> createState() => _ParentChildrenScreenState();
}

class _ParentChildrenScreenState extends State<ParentChildrenScreen> {
  @override
  Widget build(BuildContext context) {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';

    return BlocProvider(
      create: (_) => ParentDashboardCubit(
        dashboardRepository: context.read<DashboardRepository>(),
      )..loadDashboard(token),
      child: BlocBuilder<ParentDashboardCubit, ParentDashboardState>(
        builder: (context, state) {
          final reload = () => context.read<ParentDashboardCubit>().loadDashboard(token);

          return AppScaffold(
            title: 'My Children',
            drawer: widget.drawer,
            onRefresh: reload,
            actions: [
              IconButton(
                onPressed: () => showLinkStudentModal(context, token, reload),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                tooltip: 'Link Student',
              ),
            ],
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Manage and view your linked children profiles',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => showLinkStudentModal(context, token, reload),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Link Student'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (state.status == ParentDashboardStatus.loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (state.data == null || state.data!.children.isEmpty)
                    _buildEmptyState(context, token, reload)
                  else
                    ...state.data!.children.map((child) => _buildChildCard(child)),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String token, VoidCallback reload) {
    return SectionCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, size: 40, color: Colors.red),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Children Linked',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              'We couldn\'t find any student profiles linked to your mobile number. You can request to link your child using their Roll Number or registered Mobile Number.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => showLinkStudentModal(context, token, reload),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Link Student Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildCard(DashboardItem child) {
    final avatarUrl = child.status ?? '';
    final name = child.title;
    final phone = child.subtitle;
    final classSec = child.tertiary ?? '';
    final rollNo = child.value ?? '';

    return SectionCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          // Header with Avatar, Name, Phone
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.06),
                  Colors.transparent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                  backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'C',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: Colors.black87,
                        ),
                      ),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone_iphone_rounded, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              phone,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (classSec.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.menu_book_outlined, size: 18, color: AppTheme.primary),
                          SizedBox(width: 8),
                          Text('Class / Batch', style: TextStyle(color: Colors.grey, fontSize: 14)),
                        ],
                      ),
                      Text(
                        classSec,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                      ),
                    ],
                  ),
                ],
                if (classSec.isNotEmpty && rollNo.isNotEmpty) const SizedBox(height: 12),
                if (rollNo.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.assignment_turned_in_outlined, size: 18, color: Color(0xFF6B46C1)),
                          SizedBox(width: 8),
                          Text('Roll No', style: TextStyle(color: Colors.grey, fontSize: 14)),
                        ],
                      ),
                      Text(
                        rollNo,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
