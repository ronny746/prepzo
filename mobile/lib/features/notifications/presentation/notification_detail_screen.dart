import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lms/core/widgets/app_scaffold.dart';
import 'package:lms/core/widgets/section_card.dart';
import 'package:lms/features/notifications/data/models/notification_model.dart';
import 'package:lms/features/notifications/presentation/notification_links.dart';
import 'package:lms/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows one real notification passed in via route arguments.
/// If only a title is available, renders the title alone (no placeholder data).
class NotificationDetailScreen extends StatelessWidget {
  const NotificationDetailScreen({super.key, this.notification, this.title});

  final AppNotificationModel? notification;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final item = notification;
    final heading = item?.title ?? title ?? l10n.notificationDetailTitle;

    return AppScaffold(
      title: l10n.notificationDetailTitle,
      body: SectionCard(
        title: heading,
        subtitle: item == null
            ? null
            : '${item.category} • ${DateFormat.yMMMd().add_jm().format(item.createdAt)}',
        child: item == null
            ? const SizedBox.shrink()
            : _NotificationBody(item: item),
      ),
    );
  }
}

/// Message text with any links turned into buttons (QA 7.6: raw URLs).
class _NotificationBody extends StatelessWidget {
  const _NotificationBody({required this.item});

  final AppNotificationModel item;

  Future<void> _open(BuildContext context, Uri uri) async {
    final opened =
        await canLaunchUrl(uri) &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = NotificationLinks.parse(
      item.message,
      actionUrl: item.actionUrl,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (info.text.isNotEmpty)
          Text(info.text, style: Theme.of(context).textTheme.bodyLarge),
        for (final uri in info.links) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _open(context, uri),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(NotificationLinks.labelFor(uri)),
          ),
        ],
      ],
    );
  }
}
