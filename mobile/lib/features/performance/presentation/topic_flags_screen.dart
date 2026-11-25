import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/core/widgets/app_scaffold.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/dashboard/data/models/dashboard_models.dart';
import 'package:lms/features/dashboard/data/repositories/dashboard_repository.dart';

class TopicFlagsScreen extends StatefulWidget {
  const TopicFlagsScreen({super.key, this.children = const [], this.drawer});

  final List<DashboardItem> children;
  final Widget? drawer;

  @override
  State<TopicFlagsScreen> createState() => _TopicFlagsScreenState();
}

class _TopicFlagsScreenState extends State<TopicFlagsScreen> {
  String? _selectedChildId;
  late Future<List<Map<String, dynamic>>> _flags;

  @override
  void initState() {
    super.initState();
    _selectedChildId = widget.children.isEmpty
        ? null
        : widget.children.first.id;
    _load();
  }

  @override
  void didUpdateWidget(covariant TopicFlagsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Parent data arrives after the dashboard shell is built. Select the first
    // linked child once it becomes available, then fetch that child's flags.
    if (_selectedChildId == null && widget.children.isNotEmpty) {
      _selectedChildId = widget.children.first.id;
      _load();
    }
  }

  void _load() {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    _flags = context.read<DashboardRepository>().getTopicFlags(
      token: token,
      childId: _selectedChildId,
    );
  }

  Future<void> _refresh() async {
    setState(_load);
    await _flags;
  }

  Color _flagColor(String flag) => switch (flag) {
    'RED' => AppTheme.error,
    'YELLOW' => Colors.orange.shade700,
    _ => AppTheme.success,
  };

  String _flagLabel(String flag) => switch (flag) {
    'RED' => 'Needs remedial work',
    'YELLOW' => 'Build confidence',
    _ => 'On track',
  };

  @override
  Widget build(BuildContext context) {
    final isParent = widget.children.isNotEmpty;
    return AppScaffold(
      title: isParent ? 'Progress & Remedies' : 'Topic Progress',
      drawer: widget.drawer,
      onRefresh: _refresh,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Topic-level performance',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            isParent
                ? 'Review your child\'s progress and assigned remedies.'
                : 'Flags are updated when a test is submitted.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          if (isParent) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey(_selectedChildId),
              initialValue: _selectedChildId,
              decoration: const InputDecoration(labelText: 'Child'),
              items: widget.children
                  .where((child) => child.id != null)
                  .map(
                    (child) => DropdownMenuItem(
                      value: child.id,
                      child: Text(child.title),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                _selectedChildId = value;
                _load();
              }),
            ),
          ],
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _flags,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Unable to load topic progress. Pull down to try again.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                );
              }
              final flags = snapshot.data ?? const [];
              if (flags.isEmpty) {
                return Center(
                  child: Text(
                    isParent && _selectedChildId == null
                        ? 'Select a child to view progress.'
                        : 'Topic flags will appear after a submitted test.',
                    style: TextStyle(color: Colors.grey.shade700),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: flags.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final flag = flags[index];
                  final level = flag['flag']?.toString() ?? 'GREEN';
                  final color = _flagColor(level);
                  final remedy = flag['remedialSessionId'];
                  final remedyAssigned = remedy is Map && remedy.isNotEmpty;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 54,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  flag['subjectName']?.toString() ?? 'Subject',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  flag['topicName']?.toString() ?? 'Topic',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  remedyAssigned
                                      ? '${_flagLabel(level)} • Remedy assigned'
                                      : _flagLabel(level),
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${flag['percentage'] ?? 0}%',
                            style: TextStyle(
                              color: color,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
