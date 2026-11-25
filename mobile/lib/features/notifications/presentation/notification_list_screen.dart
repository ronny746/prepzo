import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/config/app_config.dart';
import 'package:lms/core/network/api_client.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/notifications/data/models/notification_model.dart';
import 'package:lms/features/notifications/data/repositories/notifications_repository.dart';
import 'package:lms/features/notifications/presentation/notification_links.dart';
import 'package:lms/routes/app_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  late NotificationsRepository _repository;
  List<AppNotificationModel> _notifications = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  io.Socket? _notificationSocket;

  final List<String> _categories = [
    'All',
    'Unread',
    'Academic',
    'Exams',
    'Fees',
    'Live Class',
    'DPP',
  ];

  @override
  void initState() {
    super.initState();
    _repository = NotificationsRepository(ApiClient());
    _loadNotifications();
    _startRealtimeNotifications();
  }

  @override
  void dispose() {
    _notificationSocket?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _startRealtimeNotifications() {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    if (token.isEmpty) return;
    _notificationSocket =
        io.io(
            AppConfig.webUrl,
            io.OptionBuilder()
                .setTransports(['websocket'])
                .enableReconnection()
                .build(),
          )
          ..onConnect(
            (_) => _notificationSocket?.emit('subscribe-notifications', {
              'token': token,
            }),
          )
          ..on('notification:created', (_) {
            if (mounted) _loadNotifications(silent: true);
          });
  }

  Future<void> _loadNotifications({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _isLoading = true);

    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    final items = await _repository.fetchNotifications(token);

    if (mounted) {
      setState(() {
        _notifications = items;
        _isLoading = false;
      });
    }
  }

  void _deleteNotification(AppNotificationModel item) {
    final index = _notifications.indexWhere((n) => n.id == item.id);
    if (index == -1) return;

    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    final removed = _notifications.removeAt(index);
    setState(() {});

    _repository.deleteNotification(item.id, token);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Notification "${removed.title}" deleted'),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.amber,
          onPressed: () {
            if (!mounted) return;
            setState(() {
              _notifications.insert(index, removed);
            });
          },
        ),
      ),
    );
  }

  void _markAllAsRead() {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    setState(() {
      _notifications = _notifications
          .map((item) => item.copyWith(isRead: true))
          .toList();
    });
    _repository.markAllAsRead(token);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All notifications marked as read')),
    );
  }

  void _clearAllNotifications() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Clear All Notifications?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete all notifications? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
      for (var item in _notifications) {
        _repository.deleteNotification(item.id, token);
      }
      setState(() {
        _notifications.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var filtered = _notifications.where((item) {
      if (_selectedCategory == 'Unread' && item.isRead) return false;
      if (_selectedCategory != 'All' &&
          _selectedCategory != 'Unread' &&
          item.category.toLowerCase() != _selectedCategory.toLowerCase()) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return item.title.toLowerCase().contains(q) ||
            item.message.toLowerCase().contains(q) ||
            item.category.toLowerCase().contains(q);
      }

      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.page(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.card(context),
        foregroundColor: AppTheme.ink(context),
        title: const Text(
          'Notification Center',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (_notifications.isNotEmpty) ...[
            IconButton(
              icon: const PhosphorIcon(
                PhosphorIcons.checks,
                color: AppTheme.primary,
                size: 20,
              ),
              tooltip: 'Mark All Read',
              onPressed: _markAllAsRead,
            ),
            IconButton(
              icon: const PhosphorIcon(
                PhosphorIcons.trash,
                color: Colors.grey,
                size: 20,
              ),
              tooltip: 'Clear All',
              onPressed: _clearAllNotifications,
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search notifications...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 13,
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(12),
                    child: PhosphorIcon(
                      PhosphorIcons.magnifyingGlass,
                      color: Color(0xFF6B7280),
                      size: 18,
                    ),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.card(context),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: AppTheme.line(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppTheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Personalize Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    final count = cat == 'Unread'
                        ? _notifications.where((n) => !n.isRead).length
                        : (cat == 'All'
                              ? _notifications.length
                              : _notifications
                                    .where(
                                      (n) =>
                                          n.category.toLowerCase() ==
                                          cat.toLowerCase(),
                                    )
                                    .length);

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('$cat ($count)'),
                        selected: isSelected,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat),
                        selectedColor: AppTheme.primary,
                        backgroundColor: AppTheme.card(context),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF4B5563),
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontSize: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? AppTheme.primary
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  ),
                )
              else if (filtered.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.card(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.line(context)),
                  ),
                  child: Column(
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.bellSlash,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No notifications found',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.ink(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _notifications.isEmpty
                            ? 'All notifications cleared.'
                            : 'Try changing your search or category filter.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final timeAgoStr = DateFormat(
                      'd MMM, hh:mm a',
                    ).format(item.createdAt);
                    final linkInfo = NotificationLinks.parse(
                      item.message,
                      actionUrl: item.actionUrl,
                    );

                    return Dismissible(
                      key: Key(item.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _deleteNotification(item),
                      background: Container(
                        padding: const EdgeInsets.only(right: 20),
                        alignment: Alignment.centerRight,
                        decoration: BoxDecoration(
                          color: AppTheme.error,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(Icons.delete_outline, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Delete',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: item.isRead
                              ? AppTheme.card(context)
                              : AppTheme.primary.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: item.isRead
                                ? AppTheme.line(context)
                                : AppTheme.primary.withValues(alpha: 0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            onTap: () async {
                              final token =
                                  context
                                      .read<AuthBloc>()
                                      .state
                                      .session
                                      ?.accessToken ??
                                  '';
                              setState(() {
                                final idx = _notifications.indexWhere(
                                  (n) => n.id == item.id,
                                );
                                if (idx != -1) {
                                  _notifications[idx] = item.copyWith(
                                    isRead: true,
                                  );
                                }
                              });
                              _repository.markAsRead(item.id, token);
                              // One link and nothing else to read: open it.
                              // Otherwise show the message with link buttons.
                              if (linkInfo.links.length == 1 &&
                                  linkInfo.text.isEmpty) {
                                final uri = linkInfo.links.first;
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                  return;
                                }
                              } else if (linkInfo.links.isEmpty) {
                                final actionUrl = item.actionUrl;
                                if (actionUrl != null && actionUrl.isNotEmpty) {
                                  final uri = Uri.tryParse(actionUrl);
                                  if (uri != null &&
                                      uri.hasScheme &&
                                      await canLaunchUrl(uri)) {
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                    return;
                                  }
                                }
                              }
                              if (!context.mounted) return;
                              Navigator.pushNamed(
                                context,
                                AppRoutes.notificationDetail,
                                arguments: item,
                              );
                            },
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: item.isRead
                                    ? AppTheme.soft(context)
                                    : AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: PhosphorIcon(
                                item.category == 'Exams'
                                    ? PhosphorIcons.clipboardText
                                    : (item.category == 'DPP'
                                          ? PhosphorIcons.lightning
                                          : (item.category == 'Live Class'
                                                ? PhosphorIcons.videoCamera
                                                : PhosphorIcons.bell)),
                                color: item.isRead
                                    ? AppTheme.inkSoft(context)
                                    : AppTheme.primary,
                                size: 20,
                              ),
                            ),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: TextStyle(
                                      fontWeight: item.isRead
                                          ? FontWeight.bold
                                          : FontWeight.w800,
                                      fontSize: 14,
                                      color: AppTheme.ink(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(
                                    Icons.more_vert,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                  onSelected: (val) {
                                    final token =
                                        context
                                            .read<AuthBloc>()
                                            .state
                                            .session
                                            ?.accessToken ??
                                        '';
                                    if (val == 'toggle') {
                                      setState(() {
                                        final idx = _notifications.indexWhere(
                                          (n) => n.id == item.id,
                                        );
                                        if (idx != -1) {
                                          _notifications[idx] = item.copyWith(
                                            isRead: !item.isRead,
                                          );
                                        }
                                      });
                                      _repository.markAsRead(item.id, token);
                                    } else if (val == 'delete') {
                                      _deleteNotification(item);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Text(
                                        item.isRead
                                            ? 'Mark as Unread'
                                            : 'Mark as Read',
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        'Hide / Delete Notification',
                                        style: TextStyle(color: AppTheme.error),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    // Links become a button on the detail
                                    // screen; never show a raw URL here.
                                    linkInfo.text.isEmpty &&
                                            linkInfo.links.isNotEmpty
                                        ? 'Tap to open the link'
                                        : linkInfo.text,
                                    style: TextStyle(
                                      color: AppTheme.inkSoft(context),
                                      fontSize: 12,
                                      fontWeight: item.isRead
                                          ? FontWeight.normal
                                          : FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          item.category,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          timeAgoStr,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF9CA3AF),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
