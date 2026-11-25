import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lms/features/live_classes/presentation/screens/zoom_webview_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ZoomService {
  Future<void> initZoom() async {
    debugPrint("Live Class WebView service initialized");
  }

  Future<void> joinMeeting({
    required BuildContext context,
    String? meetingId,
    String? meetingPassword,
    String? displayName,
    String? meetingLink,
    String? token,
  }) async {
    try {
      final zoomUri = _buildZoomJoinUri(
        meetingLink: meetingLink,
        meetingId: meetingId,
        meetingPassword: meetingPassword,
      );

      // A standard Zoom meeting cannot reliably run inside a mobile WebView.
      // Open its join URL externally so Android/iOS hands it to the installed
      // Zoom app, including the meeting password carried by the URL.
      if (zoomUri != null) {
        final appUri = _buildZoomAppUri(
          zoomUri: zoomUri,
          displayName: displayName,
        );
        if (appUri != null) {
          bool openedApp = false;
          try {
            openedApp = await launchUrl(
              appUri,
              mode: LaunchMode.externalNonBrowserApplication,
            );
          } catch (_) {
            // Android throws ACTIVITY_NOT_FOUND instead of returning false when
            // Zoom is not installed. Continue to the app-store fallback.
          }
          if (openedApp) return;
        }

        // Do not fall through to the HTTPS link here. Android can report that
        // a browser opened it even though no Zoom client joined the meeting.
        // A failed Zoom deep-link must take the learner to the install page.
        final storeOpened = await _openZoomStore();
        if (context.mounted && !storeOpened)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Zoom is required to join this class. Please install or update it.',
              ),
            ),
          );
        return;
      }

      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => LiveClassWebViewScreen(
            meetingLink: meetingLink,
            meetingId: meetingId,
            meetingPassword: meetingPassword,
            displayName: displayName,
            token: token,
          ),
        ),
      );
      debugPrint("Opening Live Class WebView");
    } catch (e) {
      debugPrint("Error opening Live Class WebView: $e");
    }
  }

  Future<bool> _openZoomStore() async {
    const tracking = 'utm_source=prepzo&utm_medium=live_class&utm_campaign=zoom_join';
    if (Platform.isAndroid) {
      final market = Uri.parse(
        'market://details?id=us.zoom.videomeetings&$tracking',
      );
      if (await launchUrl(
        market,
        mode: LaunchMode.externalNonBrowserApplication,
      ))
        return true;
      return launchUrl(
        Uri.parse(
          'https://play.google.com/store/apps/details?id=us.zoom.videomeetings&$tracking',
        ),
        mode: LaunchMode.externalApplication,
      );
    }
    if (Platform.isIOS)
      return launchUrl(
        Uri.parse(
          'https://apps.apple.com/app/zoom-workplace/id546505307?$tracking',
        ),
        mode: LaunchMode.externalApplication,
      );
    return false;
  }

  Uri? _buildZoomJoinUri({
    String? meetingLink,
    String? meetingId,
    String? meetingPassword,
  }) {
    final link = meetingLink?.trim() ?? '';
    if (link.isNotEmpty) {
      final uri = Uri.tryParse(link);
      final host = uri?.host.toLowerCase() ?? '';
      if (uri != null && (host == 'zoom.us' || host.endsWith('.zoom.us'))) {
        // Join links created by Zoom already include the encoded `pwd` value.
        return uri;
      }
    }

    final id = meetingId?.trim() ?? '';
    if (!RegExp(r'^\d{9,13}$').hasMatch(id)) return null;

    final password = meetingPassword?.trim() ?? '';
    return Uri.https(
      'zoom.us',
      '/j/$id',
      password.isEmpty ? null : {'pwd': password},
    );
  }

  Uri? _buildZoomAppUri({required Uri zoomUri, String? displayName}) {
    final segments = zoomUri.pathSegments;
    final joinIndex = segments.indexOf('j');
    if (joinIndex < 0 || joinIndex + 1 >= segments.length) return null;

    final meetingId = segments[joinIndex + 1];
    if (!RegExp(r'^\d{9,13}$').hasMatch(meetingId)) return null;

    final name = displayName?.trim() ?? '';
    final password = zoomUri.queryParameters['pwd'] ?? '';
    return Uri(
      scheme: 'zoomus',
      host: 'zoom.us',
      path: '/join',
      queryParameters: {
        'confno': meetingId,
        if (password.isNotEmpty) 'pwd': password,
        if (name.isNotEmpty) 'uname': name,
      },
    );
  }
}
