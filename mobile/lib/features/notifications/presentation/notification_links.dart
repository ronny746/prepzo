/// Splits a notification body into readable text plus the links it carries,
/// so links are shown as buttons instead of raw URLs (QA 7.6).
class NotificationLinks {
  const NotificationLinks({required this.text, required this.links});

  /// The message with URLs (and web-portal paths) removed or reworded.
  final String text;

  /// Absolute http(s) links found in the message, in order, de-duplicated.
  final List<Uri> links;

  static final RegExp _url = RegExp(
    r'''(https?://[^\s<>"')\]]+|www\.[^\s<>"')\]]+)''',
    caseSensitive: false,
  );

  // Web-portal paths that mean something to a student in words.
  static const Map<String, String> _portalPaths = {
    '/student/timetable': 'your timetable',
    '/student/schedule': 'your schedule',
    '/student/exams': 'the Practice tab',
    '/student/results': 'the Progress tab',
    '/student/resources': 'the Study tab',
    '/student/doubts': 'your doubts',
    '/student/fees': 'Fees',
  };

  factory NotificationLinks.parse(String message, {String? actionUrl}) {
    final links = <Uri>[];
    void addLink(String raw) {
      var s = raw.trim().replaceAll(RegExp(r'[.,;:!?]+$'), '');
      if (s.toLowerCase().startsWith('www.')) s = 'https://$s';
      final uri = Uri.tryParse(s);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) return;
      if (!(uri.scheme == 'http' || uri.scheme == 'https')) return;
      if (links.any((l) => l.toString() == uri.toString())) return;
      links.add(uri);
    }

    if (actionUrl != null && actionUrl.isNotEmpty) addLink(actionUrl);

    var text = message.replaceAllMapped(_url, (m) {
      addLink(m.group(0)!);
      return '';
    });
    _portalPaths.forEach((path, words) {
      text = text.replaceAll(path, words);
    });
    // Tidy what the removed links leave behind ("Join here: " / double spaces).
    text = text
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' +([.,;:!?])'), r'$1')
        .replaceAll(RegExp(r'\(\s*\)'), '')
        .split('\n')
        .map((l) => l.trim().replaceAll(RegExp(r'[:\-–]\s*$'), '').trim())
        .where((l) => l.isNotEmpty)
        .join('\n');
    return NotificationLinks(text: text, links: links);
  }

  /// Button label for a link, e.g. "Join class" for a Zoom link.
  static String labelFor(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host.contains('zoom.')) return 'Join class';
    if (host.contains('meet.google') || host.contains('teams.')) {
      return 'Join meeting';
    }
    if (host.contains('youtube.') || host.contains('youtu.be')) {
      return 'Watch video';
    }
    if (host.contains('wa.me') || host.contains('whatsapp')) {
      return 'Open WhatsApp';
    }
    final shortHost = host.startsWith('www.') ? host.substring(4) : host;
    return 'Open $shortHost';
  }
}
