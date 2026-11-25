import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lms/core/config/app_config.dart';
import 'package:lms/features/courses/data/repositories/courses_repository.dart';
import 'package:lms/routes/app_router.dart';

/// Opens theprepzo.com links inside the app (Android App Links) and
/// builds the links the app shares.
///
/// Supported links:
///   `https://theprepzo.com/explore-courses/<slug>`
///   `https://theprepzo.com/course/<id or slug>`   (what the website and share button use)
///   `https://theprepzo.com/student/course/<id>`
///   `https://theprepzo.com/checkout/<id>`
///   `https://theprepzo.com/explore-courses`   (course catalogue)
///
/// A link that arrives before the student is signed in waits until the
/// student home screen calls [markReady].
class DeepLinkService {
  DeepLinkService._();

  static const MethodChannel _channel = MethodChannel('prepzo/links');
  static const _hosts = {'theprepzo.com', 'www.theprepzo.com'};
  static final _objectId = RegExp(r'^[a-f0-9]{24}$', caseSensitive: false);

  static GlobalKey<NavigatorState>? _navigatorKey;
  static Uri? _pending;
  static bool _ready = false;
  static bool _initialised = false;

  static Future<void> init({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    _navigatorKey = navigatorKey;
    if (_initialised || kIsWeb) return;
    _initialised = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLink' && call.arguments is String) {
        handle(Uri.tryParse(call.arguments as String));
      }
    });
    try {
      final initial = await _channel.invokeMethod<String>('getInitialLink');
      if (initial != null && initial.isNotEmpty) handle(Uri.tryParse(initial));
    } on PlatformException {
      // No link at launch.
    } on MissingPluginException {
      // Platform without the channel (tests, iOS for now).
    }
  }

  /// Called by the student home screen once the app is signed in and ready.
  static void markReady() {
    _ready = true;
    final pending = _pending;
    _pending = null;
    if (pending != null) {
      // Let the home screen finish its first frame before pushing on top.
      WidgetsBinding.instance.addPostFrameCallback((_) => _open(pending));
    }
  }

  /// Called on sign-out so a later link waits for the next sign-in.
  static void markNotReady() => _ready = false;

  static void handle(Uri? uri) {
    if (uri == null || target(uri) == null) return;
    if (!_ready) {
      _pending = uri;
      return;
    }
    _open(uri);
  }

  /// What a link points to: a course id/slug, '' for the course catalogue,
  /// or null when the app does not handle the link.
  @visibleForTesting
  static String? target(Uri uri) {
    if (!(uri.scheme == 'https' || uri.scheme == 'http')) return null;
    if (!_hosts.contains(uri.host.toLowerCase())) return null;
    final parts = uri.pathSegments.where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    final first = parts[0].toLowerCase();
    if (first == 'explore-courses') return parts.length > 1 ? parts[1] : '';
    if ((first == 'course' || first == 'checkout') && parts.length > 1) {
      return parts[1];
    }
    if (first == 'student' &&
        parts.length > 2 &&
        (parts[1] == 'course' || parts[1] == 'checkout')) {
      return parts[2];
    }
    return null;
  }

  /// Public web link for a course, used by the share button.
  static String courseUrl({required String id, String? slug}) {
    final ref = (slug != null && slug.trim().isNotEmpty) ? slug.trim() : id;
    return '${AppConfig.webUrl}/course/${Uri.encodeComponent(ref)}';
  }

  static Future<void> _open(Uri uri) async {
    final nav = _navigatorKey?.currentState;
    final ref = target(uri);
    if (nav == null || ref == null) return;
    if (ref.isEmpty) {
      nav.pushNamed(AppRoutes.courses);
      return;
    }
    var courseId = ref;
    if (!_objectId.hasMatch(ref)) {
      // A slug: ask the server which course it is, since the course
      // screen works with ids.
      try {
        // The public endpoint resolves slugs (the signed-in one takes ids).
        final course = await CoursesRepository().getCourseById(
          token: '',
          id: ref,
        );
        courseId = course.id;
      } catch (_) {
        nav.pushNamed(AppRoutes.courses);
        return;
      }
    }
    if (courseId.isEmpty) return;
    nav.pushNamed(AppRoutes.courseDetail, arguments: courseId);
  }
}

/// Android share sheet for plain text (links).
class AppShare {
  AppShare._();

  static const MethodChannel _channel = MethodChannel('prepzo/links');

  static Future<bool> text(String text, {String? subject}) async {
    try {
      await _channel.invokeMethod<void>('shareText', {
        'text': text,
        'subject': subject ?? '',
      });
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
