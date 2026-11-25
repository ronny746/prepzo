import 'package:lms/core/config/app_config.dart';

/// Resolves a resource URL to an absolute one. Relative paths (starting with
/// '/', e.g. `/api/v1/resources/stream/<id>`) are joined to [webUrl]
/// (defaults to [AppConfig.webUrl]); absolute URLs are returned untouched.
String resolveResourceUrl(String url, {String? webUrl}) {
  if (!url.startsWith('/')) return url;
  final base = (webUrl ?? AppConfig.webUrl).replaceFirst(RegExp(r'/+$'), '');
  return '$base$url';
}

/// True when [url] points at our own backend host, i.e. it needs the Bearer
/// token. Why: the token must only ever be sent to this host, never to
/// third parties (Google, YouTube, CDNs).
bool isProtectedAppUrl(String url, {String? webUrl}) {
  final target = Uri.tryParse(resolveResourceUrl(url, webUrl: webUrl));
  final app = Uri.tryParse(webUrl ?? AppConfig.webUrl);
  if (target == null || app == null || target.host.isEmpty) return false;
  // Why: compare scheme and port too, so an `http://` copy of our host never
  // receives the token in cleartext; reject userinfo outright.
  return target.host == app.host &&
      target.scheme == app.scheme &&
      target.port == app.port &&
      target.userInfo.isEmpty;
}
