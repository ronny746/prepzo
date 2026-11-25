import 'package:flutter_test/flutter_test.dart';
import 'package:lms/features/notifications/presentation/notification_links.dart';

void main() {
  test('pulls URLs out of the message text', () {
    final info = NotificationLinks.parse(
      'Physics class starts at 5 PM. Join here: https://zoom.us/j/123?pwd=abc.',
    );
    expect(info.text, 'Physics class starts at 5 PM. Join here');
    expect(info.links.single.toString(), 'https://zoom.us/j/123?pwd=abc');
    expect(NotificationLinks.labelFor(info.links.single), 'Join class');
  });

  test('rewords portal paths and keeps plain messages', () {
    expect(
      NotificationLinks.parse('Check /student/timetable for changes').text,
      'Check your timetable for changes',
    );
    final plain = NotificationLinks.parse('Your test result is out');
    expect(plain.text, 'Your test result is out');
    expect(plain.links, isEmpty);
  });

  test('uses an absolute actionUrl and ignores relative ones', () {
    expect(
      NotificationLinks.parse(
        'New video',
        actionUrl: 'https://youtu.be/x',
      ).links.single.host,
      'youtu.be',
    );
    expect(
      NotificationLinks.parse('New', actionUrl: '/student/exams').links,
      isEmpty,
    );
  });
}
