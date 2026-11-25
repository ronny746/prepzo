import 'package:flutter/material.dart';
import 'package:lms/core/constants/app_data.dart';
import 'package:lms/core/widgets/app_scaffold.dart';
import 'package:lms/core/widgets/section_card.dart';

class NotificationDetailScreen extends StatelessWidget {
  const NotificationDetailScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final item = AppData.notifications.firstWhere(
      (notification) => notification.title == title,
      orElse: () => AppData.notifications.first,
    );

    return AppScaffold(
      title: 'Notification Details',
      body: SectionCard(
        title: item.title,
        subtitle: '${item.category} • ${item.time}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Chip(label: Text(item.category)),
            const SizedBox(height: 12),
            Text(item.message, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text('Mark as Read'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {},
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
