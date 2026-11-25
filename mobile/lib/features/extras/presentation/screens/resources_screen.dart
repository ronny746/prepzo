import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/core/widgets/app_scaffold.dart';
import 'package:lms/core/widgets/section_card.dart';
import 'package:lms/features/extras/presentation/cubit/extras_cubit.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/core/widgets/resource_viewer_screen.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  @override
  void initState() {
    super.initState();
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    context.read<ExtrasCubit>().loadResources(token);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Study Materials',
      showAppBar: true,
      body: BlocBuilder<ExtrasCubit, ExtrasState>(
        builder: (context, state) {
          if (state.status == ExtrasStatus.loading && state.resources.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.error != null) {
            return Center(child: Text(state.error!, style: const TextStyle(color: AppTheme.error)));
          }

          if (state.resources.isEmpty) {
            return const Center(child: Text('No resources available.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.resources.length,
            itemBuilder: (context, index) {
              final res = state.resources[index];
              return SectionCard(
                margin: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        res.type == 'video' ? Icons.play_circle_fill : Icons.picture_as_pdf,
                        color: AppTheme.secondary,
                      ),
                    ),
                    title: Text(res.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(res.subjectName, style: const TextStyle(color: AppTheme.primary, fontSize: 12)),
                        if (res.description.isNotEmpty) Text(res.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    trailing: const Icon(Icons.download, color: AppTheme.primary),
                    onTap: () {
                      if (res.fileUrl.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ResourceViewerScreen(
                              url: res.fileUrl,
                              title: res.title,
                              type: res.type.toUpperCase(),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
