import 'package:flutter_test/flutter_test.dart';
import 'package:lms/features/voice_assistant/voice_destinations.dart';

void main() {
  test('tab keywords map to bottom-tab indices 0-4', () {
    expect(matchVoiceDestination('Open practice')!.value.tabIndex, 1);
    expect(matchVoiceDestination('my profile')!.value.tabIndex, 4);
  });

  test('non-tab keywords map to routes, not indices', () {
    expect(
      matchVoiceDestination('show attendance')!.value.routeName,
      '/attendance',
    );
    expect(matchVoiceDestination('pay fees')!.value.routeName, '/fees');
    expect(
      matchVoiceDestination('timetable')!.value.routeName,
      '/student-schedule',
    );
  });

  test('unknown command returns null', () {
    expect(matchVoiceDestination('hello'), null);
  });
}
