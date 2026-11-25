import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/core/theme/theme_controller.dart';
import 'package:lms/core/widgets/app_scaffold.dart';
import 'package:lms/core/widgets/section_card.dart';
import 'package:lms/features/authentication/data/repositories/auth_repository.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/routes/app_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.drawer});

  final Widget? drawer;


  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _examAlerts = true;
  bool _liveClassAlerts = true;
  bool _doubtReplies = true;
  bool _feeAnnouncements = true;

  void _showChangePasswordDialog(BuildContext context) {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const PhosphorIcon(
                      PhosphorIcons.lockKey,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Change Password',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Enter your current password and choose a new secure password.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: oldPasswordController,
                        obscureText: obscureOld,
                        decoration: InputDecoration(
                          labelText: 'Current Password',
                          prefixIcon: const PhosphorIcon(
                            PhosphorIcons.key,
                            size: 18,
                          ),
                          suffixIcon: IconButton(
                            icon: PhosphorIcon(
                              obscureOld
                                  ? PhosphorIcons.eyeClosed
                                  : PhosphorIcons.eye,
                              size: 18,
                            ),
                            onPressed: () =>
                                setDialogState(() => obscureOld = !obscureOld),
                          ),
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Please enter current password'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNew,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          prefixIcon: const PhosphorIcon(
                            PhosphorIcons.lock,
                            size: 18,
                          ),
                          suffixIcon: IconButton(
                            icon: PhosphorIcon(
                              obscureNew
                                  ? PhosphorIcons.eyeClosed
                                  : PhosphorIcons.eye,
                              size: 18,
                            ),
                            onPressed: () =>
                                setDialogState(() => obscureNew = !obscureNew),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please enter new password';
                          }
                          if (v.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          prefixIcon: const PhosphorIcon(
                            PhosphorIcons.shieldCheck,
                            size: 18,
                          ),
                          suffixIcon: IconButton(
                            icon: PhosphorIcon(
                              obscureConfirm
                                  ? PhosphorIcons.eyeClosed
                                  : PhosphorIcons.eye,
                              size: 18,
                            ),
                            onPressed: () => setDialogState(
                              () => obscureConfirm = !obscureConfirm,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please confirm new password';
                          }
                          if (v != newPasswordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);
                          final token =
                              context
                                  .read<AuthBloc>()
                                  .state
                                  .session
                                  ?.accessToken ??
                              '';
                          final authRepo = context.read<AuthRepository>();

                          try {
                            await authRepo.changePassword(
                              token: token,
                              oldPassword: oldPasswordController.text,
                              newPassword: newPasswordController.text,
                            );

                            if (ctx.mounted) {
                              Navigator.pop(dialogCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Password updated successfully!',
                                  ),
                                  backgroundColor: AppTheme.success,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            final msg = e
                                .toString()
                                .replaceAll('Exception:', '')
                                .replaceAll('ApiException:', '')
                                .trim();
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    msg.isNotEmpty
                                        ? msg
                                        : 'Failed to update password.',
                                  ),
                                  backgroundColor: AppTheme.error,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showNotificationPreferences(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final isDark = Theme.of(modalCtx).brightness == Brightness.dark;
            return Container(
              padding: const EdgeInsets.all(24),
              color: isDark ? AppTheme.darkSurface : Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Notification Preferences',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      IconButton(
                        icon: const PhosphorIcon(PhosphorIcons.x, size: 20),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Exam & Test Alerts',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'New online exams, scheduled tests, and published results',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    value: _examAlerts,
                    activeTrackColor: AppTheme.primary,
                    onChanged: (val) {
                      setModalState(() => _examAlerts = val);
                      setState(() => _examAlerts = val);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Live Class & DPP Alerts',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'Daily practice papers and live session reminders',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    value: _liveClassAlerts,
                    activeTrackColor: AppTheme.primary,
                    onChanged: (val) {
                      setModalState(() => _liveClassAlerts = val);
                      setState(() => _liveClassAlerts = val);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Doubt Resolution Alerts',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'Get notified as soon as a teacher responds to your doubt',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    value: _doubtReplies,
                    activeTrackColor: AppTheme.primary,
                    onChanged: (val) {
                      setModalState(() => _doubtReplies = val);
                      setState(() => _doubtReplies = val);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Fee & Announcement Alerts',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'Fee receipts, installment reminders, and academy updates',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    value: _feeAnnouncements,
                    activeTrackColor: AppTheme.primary,
                    onChanged: (val) {
                      setModalState(() => _feeAnnouncements = val);
                      setState(() => _feeAnnouncements = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(modalCtx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Select Language',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const PhosphorIcon(
                PhosphorIcons.checkCircle,
                color: AppTheme.primary,
                size: 20,
              ),
              title: const Text('English (Default)'),
              subtitle: const Text(
                'Active application language',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () => Navigator.pop(ctx),
            ),
            const Divider(height: 1),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: PhosphorIcon(
                PhosphorIcons.circle,
                color: Color(0xFFCBD5E1),
                size: 20,
              ),
              title: Text('Hindi (हिंदी) - Coming Soon'),
              subtitle: Text(
                'Hindi translations are in active preparation',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSessionInfoDialog(BuildContext context) {
    final user = context.read<AuthBloc>().state.session?.user;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Active Session Info',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('User Account', user?.name ?? 'Student'),
            _infoRow('Role', user?.role ?? 'STUDENT'),
            _infoRow('User ID', user?.id ?? ''),
            _infoRow('Connection', 'Secure TLS / HTTPS'),
            _infoRow('Platform', 'Prepzo Mobile App'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            PhosphorIcon(
              PhosphorIcons.signOut,
              color: AppTheme.error,
              size: 22,
            ),
            SizedBox(width: 10),
            Text(
              'Logout Confirmation',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out from your Prepzo account?',
          style: TextStyle(fontSize: 14, color: AppTheme.inkSoft(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(const AuthLogoutRequested());
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (r) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role =
        (context.read<AuthBloc>().state.session?.user.role ?? 'STUDENT')
            .toUpperCase()
            .trim();
    // Students and parents sign in with a mobile OTP and have no password
    // to change (QA 7.7), so the option is only for password accounts.
    final usesOtpLogin = role.contains('STUDENT') || role.contains('PARENT');
    return AppScaffold(
      title: 'Settings',
      drawer: widget.drawer,
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
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const PhosphorIcon(
                      PhosphorIcons.translate,
                      size: 22,
                      color: AppTheme.primary,
                    ),
                    title: const Text(
                      'Language Selection',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'English • Hindi coming soon',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    trailing: const PhosphorIcon(
                      PhosphorIcons.caretRight,
                      size: 16,
                      color: Color(0xFF94A3B8),
                    ),
                    onTap: () => _showLanguageDialog(context),
                  ),
                ),
                const Divider(height: 1),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const PhosphorIcon(
                      PhosphorIcons.bellSimpleRinging,
                      size: 22,
                      color: AppTheme.primary,
                    ),
                    title: const Text(
                      'Notification Preferences',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'Academic, attendance, exam and fee alerts',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    trailing: const PhosphorIcon(
                      PhosphorIcons.caretRight,
                      size: 16,
                      color: Color(0xFF94A3B8),
                    ),
                    onTap: () => _showNotificationPreferences(context),
                  ),
                ),
                const Divider(height: 1),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const PhosphorIcon(
                      PhosphorIcons.deviceMobile,
                      size: 22,
                      color: AppTheme.primary,
                    ),
                    title: const Text(
                      'Session Information',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'Trusted devices and account connection info',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    trailing: const PhosphorIcon(
                      PhosphorIcons.caretRight,
                      size: 16,
                      color: Color(0xFF94A3B8),
                    ),
                    onTap: () => _showSessionInfoDialog(context),
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
                if (!usesOtpLogin)
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const PhosphorIcon(
                        PhosphorIcons.lockKey,
                        size: 22,
                        color: Color(0xFFD97706),
                      ),
                      title: const Text(
                        'Change Password',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Verify current password and update it securely.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      trailing: const PhosphorIcon(
                        PhosphorIcons.caretRight,
                        size: 16,
                        color: Color(0xFF94A3B8),
                      ),
                      onTap: () => _showChangePasswordDialog(context),
                    ),
                  ),
                if (!usesOtpLogin) const Divider(height: 1),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const PhosphorIcon(
                      PhosphorIcons.signOut,
                      size: 22,
                      color: AppTheme.error,
                    ),
                    title: const Text(
                      'Logout',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.error,
                      ),
                    ),
                    subtitle: const Text(
                      'Invalidate active session and sign out safely.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    trailing: const PhosphorIcon(
                      PhosphorIcons.caretRight,
                      size: 16,
                      color: Color(0xFF94A3B8),
                    ),
                    onTap: () => _showLogoutDialog(context),
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
                leading: const PhosphorIcon(
                  PhosphorIcons.headset,
                  size: 22,
                  color: Color(0xFF0284C7),
                ),
                title: const Text(
                  'Open Support Center',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: const Text(
                  'Help center, academy contact and FAQs.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                trailing: const PhosphorIcon(
                  PhosphorIcons.caretRight,
                  size: 16,
                  color: Color(0xFF94A3B8),
                ),
                onTap: () => Navigator.pushNamed(context, AppRoutes.support),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
