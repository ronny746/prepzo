import 'package:flutter/material.dart';
import 'package:lms/core/theme/app_theme.dart';

/// Friendly "could not load" state with a Retry button. Used instead of
/// printing raw (red) error text on screens.
class LoadErrorView extends StatelessWidget {
  const LoadErrorView({
    super.key,
    this.title = 'Something went wrong',
    this.message = 'Check your internet connection and try again.',
    this.icon = Icons.cloud_off_rounded,
    this.actionLabel = 'Retry',
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            if (onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }
}
