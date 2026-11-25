/// Where a voice command should take the user: either a bottom-tab index
/// or a named route (for screens that are not bottom tabs).
class VoiceDestination {
  const VoiceDestination.tab(int this.tabIndex) : routeName = null;
  const VoiceDestination.route(String this.routeName) : tabIndex = null;

  final int? tabIndex;
  final String? routeName;
}

/// Keyword -> destination map. Tabs 0-4 are the bottom tabs; the rest are
/// pushed routes (the old indices 5/10/11 did not map to any tab).
const Map<String, VoiceDestination> voiceDestinations = {
  'home': VoiceDestination.tab(0),
  'dashboard': VoiceDestination.tab(0),
  'practice': VoiceDestination.tab(1),
  'test': VoiceDestination.tab(1),
  'study': VoiceDestination.tab(2),
  'material': VoiceDestination.tab(2),
  'progress': VoiceDestination.tab(3),
  'result': VoiceDestination.tab(3),
  'profile': VoiceDestination.tab(4),
  'schedule': VoiceDestination.route('/student-schedule'),
  'timetable': VoiceDestination.route('/student-schedule'),
  'attendance': VoiceDestination.route('/attendance'),
  'fee': VoiceDestination.route('/fees'),
};

/// Returns the first keyword/destination pair contained in [command], or null.
MapEntry<String, VoiceDestination>? matchVoiceDestination(String command) {
  final lower = command.toLowerCase();
  for (final entry in voiceDestinations.entries) {
    if (lower.contains(entry.key)) return entry;
  }
  return null;
}
