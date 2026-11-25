import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lms/core/network/api_client.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class AppUpdateInfo {
  final String latestVersion;
  final String minRequiredVersion;
  final bool isMandatory;
  final String updateUrl;
  final String updateNotes;

  AppUpdateInfo({
    required this.latestVersion,
    required this.minRequiredVersion,
    required this.isMandatory,
    required this.updateUrl,
    required this.updateNotes,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      latestVersion: json['latestVersion']?.toString() ?? '1.0.0',
      minRequiredVersion: json['minRequiredVersion']?.toString() ?? '1.0.0',
      isMandatory: json['isMandatory'] == true,
      updateUrl: json['updateUrl']?.toString() ??
          'https://play.google.com/store/apps/details?id=com.app.prepzo',
      updateNotes: json['updateNotes']?.toString() ??
          'New features, bug fixes, and performance improvements available.',
    );
  }
}

class AppUpdateService {
  static String _cachedVersion = '1.0.1';
  static bool _hasCheckedThisSession = false;

  static Future<String> getCurrentAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (packageInfo.version.isNotEmpty) {
        _cachedVersion = packageInfo.version;
      }
    } catch (e) {
      debugPrint('Error getting package info: $e');
    }
    return _cachedVersion;
  }

  static bool isVersionOlder(String current, String target) {
    try {
      final cParts = current
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
      final tParts = target
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();

      final maxLength = cParts.length > tParts.length
          ? cParts.length
          : tParts.length;
      for (int i = 0; i < maxLength; i++) {
        final c = i < cParts.length ? cParts[i] : 0;
        final t = i < tParts.length ? tParts[i] : 0;
        if (c < t) return true;
        if (c > t) return false;
      }
    } catch (_) {}
    return false;
  }

  static Future<void> checkAppUpdate(
    BuildContext context, {
    bool forceCheck = false,
  }) async {
    if (_hasCheckedThisSession && !forceCheck) return;
    _hasCheckedThisSession = true;

    try {
      final apiClient = ApiClient();
      final response = await apiClient.get('/public-settings');
      final data = response['data'] ?? response;
      if (data is Map<String, dynamic> && data['appUpdate'] != null) {
        final updateInfo = AppUpdateInfo.fromJson(
          data['appUpdate'] as Map<String, dynamic>,
        );

        final currentVersion = await getCurrentAppVersion();
        final hasNewVersion = isVersionOlder(
          currentVersion,
          updateInfo.latestVersion,
        );
        final isMinVersionMissing = isVersionOlder(
          currentVersion,
          updateInfo.minRequiredVersion,
        );
        final isMandatory = updateInfo.isMandatory || isMinVersionMissing;

        if (hasNewVersion && context.mounted) {
          showAppUpdateDialog(
            context,
            updateInfo: updateInfo,
            isMandatory: isMandatory,
            currentVersion: currentVersion,
          );
        }
      }
    } catch (e) {
      debugPrint('App update check error: $e');
    }
  }

  /// Opens this app's own store page. On Android a Play link for another
  /// package (the server setting once pointed at
  /// com.prepzoneet.online) is replaced with this app's id.
  static Future<void> openStore(String configuredUrl) async {
    var url = configuredUrl;
    try {
      if (Platform.isAndroid) {
        final pkg = (await PackageInfo.fromPlatform()).packageName;
        final configured = Uri.tryParse(configuredUrl);
        final isPlay = configured?.host.contains('play.google.com') ?? false;
        if (!isPlay || configured?.queryParameters['id'] != pkg) {
          url = 'https://play.google.com/store/apps/details?id=$pkg';
        }
      }
    } catch (_) {}
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not open store: $e');
    }
  }

  static void showAppUpdateDialog(
    BuildContext context, {
    required AppUpdateInfo updateInfo,
    required bool isMandatory,
    String currentVersion = '1.0.1',
  }) {
    showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return PopScope(
          canPop: !isMandatory,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 16,
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon Header
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: isMandatory
                          ? const Color(0xFFFEF2F2)
                          : const Color(0xFFEEF2FF),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isMandatory
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFFC7D2FE),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      isMandatory
                          ? PhosphorIcons.warningCircleBold
                          : PhosphorIcons.rocketLaunchBold,
                      size: 32,
                      color: isMandatory
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    isMandatory
                        ? 'Mandatory Update Required'
                        : 'New Update Available!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Version Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'v$currentVersion ➔ v${updateInfo.latestVersion}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Description / Notes
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      updateInfo.updateNotes,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF475569),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Actions
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              AppUpdateService.openStore(updateInfo.updateUrl),
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: Text(
                            isMandatory
                                ? 'Update Now to Continue'
                                : 'Download Update',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isMandatory
                                ? const Color(0xFFDC2626)
                                : AppTheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      if (!isMandatory) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Later / Remind Me Next Time',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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
}
