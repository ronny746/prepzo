import 'package:flutter/material.dart';
import 'package:lms/core/constants/app_data.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/core/theme/theme_controller.dart';
import 'package:lms/core/widgets/app_scaffold.dart';
import 'package:lms/core/widgets/section_card.dart';
import 'package:lms/routes/app_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.drawer});

  final Widget? drawer;

  void _showThemePicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        Widget option(ThemeMode value, IconData icon, String hint) {
          return ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.mode,
            builder: (context, current, _) {
              final selected = current == value;
              final dark = Theme.of(context).brightness == Brightness.dark;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    ThemeController.set(value);
                    Navigator.of(sheetContext).pop();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.primary.withValues(alpha: 0.12)
                          : (dark
                                ? Colors.white.withValues(alpha: 0.04)
                                : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? AppTheme.primary
                            : (dark ? Colors.white12 : const Color(0xFFE2E8F0)),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        PhosphorIcon(icon, size: 22, color: AppTheme.primary),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ThemeController.label(value),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                hint,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: dark
                                      ? Colors.white60
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: selected
                              ? AppTheme.primary
                              : (dark ? Colors.white38 : Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'App Theme',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose how Prepzo looks on this phone.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 18),
                option(ThemeMode.light, PhosphorIcons.sun, 'Bright and clear'),
                option(
                  ThemeMode.dark,
                  PhosphorIcons.moon,
                  'Easy on the eyes at night',
                ),
                option(
                  ThemeMode.system,
                  PhosphorIcons.deviceMobile,
                  'Follow the phone setting',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Students and parents sign in with an OTP and have no password, so
    // "Change Password" would only confuse them.
    final role = (context.read<AuthBloc>().state.session?.user.role ?? '')
        .toUpperCase();
    final hasPassword = role != 'STUDENT' && role != 'PARENT';

    return AppScaffold(
      title: 'Settings',
      drawer: drawer,
      header: const SectionCard(
        title: 'Preferences & Security',
        subtitle:
            'Accessibility-friendly controls, secure sessions and personalized experience.',
        child: SizedBox.shrink(),
      ),
      body: Column(
        children: [
          SectionCard(
            title: 'General Settings',
            child: Column(
              children: [
                if (ThemeController.darkModeEnabled) ...[
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: ThemeController.mode,
                    builder: (context, mode, _) => Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: PhosphorIcon(
                          mode == ThemeMode.dark
                              ? PhosphorIcons.moon
                              : PhosphorIcons.sun,
                          size: 22,
                          color: AppTheme.primary,
                        ),
                        title: const Text(
                          'App Theme',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          ThemeController.label(mode),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        trailing: const PhosphorIcon(
                          PhosphorIcons.caretRight,
                          size: 16,
                          color: Color(0xFF94A3B8),
                        ),
                        onTap: () => _showThemePicker(context),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                ],
                ...AppData.settings.map(
                  (item) => Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(item.icon),
                      title: Text(item.title),
                      subtitle: Text(item.subtitle),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Security',
            child: Column(
              children: [
                if (hasPassword)
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Change Password'),
                      subtitle: const Text(
                        'Verify current password and update it securely.',
                      ),
                    ),
                  ),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.devices_outlined),
                    title: const Text('Logout'),
                    subtitle: const Text(
                      'Invalidate active sessions across mobile devices.',
                    ),
                    onTap: () {
                      context.read<AuthBloc>().add(const AuthLogoutRequested());
                      // Navigate explicitly: when the session had already
                      // ended the bloc state does not change, so nothing else
                      // would move the user off this screen.
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.login,
                        (route) => false,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Support',
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.support_agent),
                title: const Text('Open Support Center'),
                subtitle: const Text(
                  'Help center, school contact and support ticketing.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, AppRoutes.support),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
