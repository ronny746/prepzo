import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/constants/app_strings.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/core/widgets/resource_viewer_screen.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/resources/data/models/resource.dart';
import 'package:lms/features/resources/presentation/cubit/resources_cubit.dart';
import 'package:lms/routes/app_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  String _currentPath = '/';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    return context.read<ResourcesCubit>().loadResources(token);
  }

  void _handleNavigate(String folderName) {
    final normalizedCurrent = _currentPath.endsWith('/')
        ? _currentPath
        : '$_currentPath/';
    setState(() {
      _currentPath = '$normalizedCurrent$folderName/';
    });
  }

  void _handleBreadcrumbClick(int index, List<String> parts) {
    if (index == -1) {
      setState(() => _currentPath = '/');
    } else {
      final newPath = '/${parts.sublist(0, index + 1).join('/')}/';
      setState(() => _currentPath = newPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pathParts = _currentPath
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.page(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: BlocBuilder<ResourcesCubit, ResourcesState>(
                builder: (context, state) {
                  if (state.status == ResourcesStatus.loading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 80.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  // A plan without Study Materials is not a failure: show a
                  // neutral empty state instead of a red error.
                  final noStudyAccess =
                      state.error?.contains('access to Study Materials') ??
                      false;
                  if (noStudyAccess) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 80.0),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.menu_book_outlined,
                              size: 40,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              AppStrings.studyNotInCourseTitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              AppStrings.studyNotInCourseBody,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (state.error != null) {
                    // Never show raw error text (QA 7.2): a plan without
                    // study material gets an explanation, anything else a
                    // retry.
                    final locked =
                        state.locked ||
                        state.error!.toLowerCase().contains('current plan');
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _buildHeader(context),
                        _buildStateMessage(
                          icon: locked
                              ? PhosphorIcons.lockSimple
                              : PhosphorIcons.cloudSlash,
                          title: locked
                              ? 'Study material is not in your plan'
                              : 'Could not load study materials',
                          message: locked
                              ? 'Your current course does not include notes '
                                    'or videos. Your tests and practice are '
                                    'in the Practice tab.'
                              : 'Check your internet connection and try '
                                    'again.',
                          actionLabel: locked ? 'Explore courses' : 'Retry',
                          onAction: locked
                              ? () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.courses,
                                )
                              : _loadData,
                        ),
                      ],
                    );
                  }

                  // Filter resources according to selected batch section
                  final filteredResources = state.resources.where((res) {
                    final isGlobal =
                        (res.batchId == null || res.batchId!.isEmpty) &&
                        res.batchIds.isEmpty;
                    if (state.selectedSection == 'global') return isGlobal;
                    return isGlobal ||
                        res.batchId == state.selectedSection ||
                        res.batchIds.contains(state.selectedSection);
                  }).toList();

                  // Folder explorer computation
                  final Set<String> folders = {};
                  final List<Resource> files = [];

                  for (final res in filteredResources) {
                    final resPath = res.folderPath.isNotEmpty
                        ? res.folderPath
                        : '/';
                    final normalizedResPath = resPath.startsWith('/')
                        ? resPath
                        : '/$resPath';
                    var finalResPath = normalizedResPath.endsWith('/')
                        ? normalizedResPath
                        : '$normalizedResPath/';
                    final normalizedCurrentPath = _currentPath.endsWith('/')
                        ? _currentPath
                        : '$_currentPath/';

                    // A FOLDER record is a folder named by its title, located at
                    // its folderPath; it is never listed as a file. Treating it
                    // as a deeper path makes empty folders appear and open.
                    final isFolderRecord = res.type.toUpperCase() == 'FOLDER';
                    if (isFolderRecord) {
                      // Why: an empty or slash-containing title would build a
                      // broken path, so skip it / flatten slashes.
                      final folderName = res.title.trim().replaceAll('/', '-');
                      if (folderName.isEmpty) continue;
                      finalResPath = '$finalResPath$folderName/';
                      if (finalResPath == normalizedCurrentPath) continue;
                    }

                    if (finalResPath == normalizedCurrentPath) {
                      files.add(res);
                    } else if (finalResPath.startsWith(normalizedCurrentPath)) {
                      final relativePath = finalResPath.substring(
                        normalizedCurrentPath.length,
                      );
                      final nextFolder = relativePath.split('/').first;
                      if (nextFolder.isNotEmpty) {
                        folders.add(nextFolder);
                      }
                    }
                  }

                  final sortedFolders = folders.toList()..sort();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildHeader(context),
                      const SizedBox(height: 16),

                      // Batch section selector chip bar ("My Classes")
                      _buildBatchSelector(state),

                      const SizedBox(height: 16),
                      _buildBreadcrumbs(pathParts),
                      const SizedBox(height: 20),

                      if (sortedFolders.isEmpty && files.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 60, bottom: 40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const PhosphorIcon(
                                    PhosphorIcons.folderOpen,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No materials in this section',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Study notes and lectures will appear here.',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      if (sortedFolders.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          child: Text(
                            'Subject Folders',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: AppTheme.ink(context),
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildFoldersGrid(sortedFolders, filteredResources),
                        const SizedBox(height: 24),
                      ],

                      if (files.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          child: Text(
                            'Chapter Materials & PDFs',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: AppTheme.ink(context),
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildFilesList(files),
                      ],

                      const SizedBox(height: 100),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStateMessage({
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 60, bottom: 40),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: PhosphorIcon(icon, size: 40, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.ink(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (Navigator.canPop(context)) ...[
              const BackButton(),
              const SizedBox(width: 4),
            ],
            Text(
              'Study Materials',
              style: Theme.of(context).appBarTheme.titleTextStyle,
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Access class notes, past papers, and video lectures',
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBatchSelector(ResourcesState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'SELECT COURSE / BATCH',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Color(0xFF94A3B8),
              letterSpacing: 1.1,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              // Global / All Resources Card
              _buildCourseCard(
                title: 'All Resources',
                subtitle: 'Global Repository',
                icon: PhosphorIcons.globeSimple,
                isSelected: state.selectedSection == 'global',
                onTap: () {
                  context.read<ResourcesCubit>().setSelectedSection('global');
                  setState(() => _currentPath = '/');
                },
              ),
              const SizedBox(width: 12),
              // Enrolled Student Batches Cards
              ...state.myBatches.map((batch) {
                final isSelected = state.selectedSection == batch.id;
                final batchTitle =
                    '${batch.name} ${batch.section != null && batch.section!.isNotEmpty ? '(${batch.section})' : ''}'
                        .trim();
                final subtitle =
                    batch.courseName != null && batch.courseName!.isNotEmpty
                    ? batch.courseName!
                    : 'Enrolled Batch';

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildCourseCard(
                    title: batchTitle,
                    subtitle: subtitle,
                    icon: PhosphorIcons.chalkboardTeacher,
                    isSelected: isSelected,
                    onTap: () {
                      context.read<ResourcesCubit>().setSelectedSection(
                        batch.id,
                      );
                      setState(() => _currentPath = '/');
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCourseCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 125,
          height: 125,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : AppTheme.card(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.line(context),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.2)
                          : AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: PhosphorIcon(
                      icon,
                      size: 20,
                      color: isSelected ? Colors.white : AppTheme.primary,
                    ),
                  ),
                  if (isSelected)
                    const PhosphorIcon(
                      PhosphorIcons.checkCircleFill,
                      size: 18,
                      color: Colors.white,
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : AppTheme.ink(context),
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white70
                          : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs(List<String> pathParts) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.line(context)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _handleBreadcrumbClick(-1, pathParts),
              child: Row(
                children: [
                  PhosphorIcon(
                    PhosphorIcons.folderOpen,
                    size: 16,
                    color: pathParts.isEmpty
                        ? AppTheme.primary
                        : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Root',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: pathParts.isEmpty
                          ? AppTheme.primary
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            ...pathParts.asMap().entries.map((entry) {
              final index = entry.key;
              final part = entry.value;
              final isLast = index == pathParts.length - 1;
              return Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: PhosphorIcon(
                      PhosphorIcons.caretRight,
                      size: 12,
                      color: Colors.grey,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _handleBreadcrumbClick(index, pathParts),
                    child: Text(
                      part,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: isLast
                            ? AppTheme.primary
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getRandomFolderColor(String folderName, int index) {
    final List<Color> vibrantColors = [
      const Color(0xFF2563EB), // Royal Blue
      const Color(0xFF059669), // Emerald
      const Color(0xFF7C3AED), // Violet
      const Color(0xFFEA580C), // Orange
      const Color(0xFF0284C7), // Sky Blue
      const Color(0xFF0D9488), // Teal
      const Color(0xFF9333EA), // Purple
      const Color(0xFFD97706), // Amber
      const Color(0xFF4F46E5), // Indigo
      const Color(0xFFDB2777), // Pink
      const Color(0xFF16A34A), // Green
    ];
    final hash = folderName.hashCode.abs();
    return vibrantColors[(hash + index) % vibrantColors.length];
  }

  Widget _buildFoldersGrid(
    List<String> sortedFolders,
    List<Resource> allResources,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.25,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: sortedFolders.length,
      itemBuilder: (context, index) {
        final folder = sortedFolders[index];
        final folderColor = _getRandomFolderColor(folder, index);

        final normalizedCurrentPath = _currentPath.endsWith('/')
            ? _currentPath
            : '$_currentPath/';
        final folderFullPath = '$normalizedCurrentPath$folder/';
        final notesCount = allResources.where((r) {
          // Folder records are containers, not items.
          if (r.type.toUpperCase() == 'FOLDER') return false;
          final resPath = r.folderPath.endsWith('/')
              ? r.folderPath
              : '${r.folderPath}/';
          return resPath.startsWith(folderFullPath);
        }).length;

        return Material(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _handleNavigate(folder),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.line(context)),
                boxShadow: [
                  BoxShadow(
                    color: folderColor.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: folderColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: PhosphorIcon(
                          PhosphorIcons.folderNotchOpenFill,
                          color: folderColor,
                          size: 24,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: folderColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$notesCount ${notesCount == 1 ? 'item' : 'items'}',
                          style: TextStyle(
                            color: folderColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          folder,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppTheme.ink(context),
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.soft(context),
                          shape: BoxShape.circle,
                        ),
                        child: const PhosphorIcon(
                          PhosphorIcons.caretRight,
                          color: Color(0xFF64748B),
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilesList(List<Resource> files) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final resource = files[index];
        final isVideo = resource.type == 'VIDEO';
        final isNote =
            resource.type == 'NOTES' || resource.type == 'PAST_PAPER';

        final color = isVideo
            ? AppTheme.primary
            : (isNote ? AppTheme.error : AppTheme.brandInk(context));
        final icon = isVideo
            ? PhosphorIcons.playCircleFill
            : (isNote ? PhosphorIcons.filePdf : PhosphorIcons.link);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.soft(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: PhosphorIcon(icon, color: color, size: 22),
                ),
                title: Text(
                  resource.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppTheme.ink(context),
                    letterSpacing: -0.2,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    resource.description?.isNotEmpty == true
                        ? resource.description!
                        : resource.type,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                trailing: const PhosphorIcon(
                  PhosphorIcons.caretRight,
                  color: Colors.grey,
                  size: 16,
                ),
                onTap: () {
                  if (resource.fileUrl.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ResourceViewerScreen(
                          url: resource.fileUrl,
                          title: resource.title,
                          type: resource.type,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
