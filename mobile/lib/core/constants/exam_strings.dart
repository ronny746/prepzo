/// User-facing strings for the timed exam player.
///
/// The app has no i18n system yet, so new exam-player copy lives here instead
/// of inline in widgets. Placeholders like `{n}` are filled with [fill].
class ExamStrings {
  const ExamStrings._();

  /// How many times a student may leave the app before auto-submit, used in
  /// the pre-start rules. The real limit only arrives with the start response,
  /// so this mirrors the server default.
  static const int defaultMaxLeaves = 3;

  /// Replaces `{key}` placeholders in [template] with [values].
  static String fill(String template, Map<String, Object> values) {
    var out = template;
    values.forEach((k, v) => out = out.replaceAll('{$k}', v.toString()));
    return out;
  }

  // Start / instructions dialog
  static const startTitle = 'Before you begin';
  static const startDuration = 'Duration: {minutes} minutes';
  static const startQuestions = 'Questions: {count}';
  static const startRuleLeave =
      'Do not switch to another app or press Home during the test. If you '
      'leave the test {max} times it is submitted automatically. You will get '
      'a warning each time.';
  static const startCameraReason =
      'Your front camera takes photos now and then during the test to keep '
      'the exam fair. We will ask for camera permission next, before the '
      'clock starts.';
  static const startButton = 'Start';
  static const cancelButton = 'Cancel';

  // Submit confirmation
  static const submitTitle = 'Submit test?';
  static const submitAnswered = 'Answered: {n}';
  static const submitNotAnswered = 'Not answered: {n}';
  static const submitMarked = 'Marked for review: {n}';
  static const submitWarning = 'You cannot reopen the test after submitting.';
  static const goBack = 'Go back';
  static const submit = 'Submit';

  // Leaving-the-app warnings
  static const warningTitle = 'Warning {n} of {max}';
  static const warningBody =
      'You left the test. If you leave the test again it will be submitted '
      'automatically.';
  static const warningFinalBody =
      'You left the test. This was your final warning. If you leave the test '
      'again it will be submitted automatically.';
  static const warningUnlimitedBody =
      'You left the test. This has been recorded.';
  static const warningTitleUnlimited = 'Warning {n}';
  static const warningOk = 'I understand';
  static const violationTooltip =
      'Times you left the test: {n} of {max}. Leaving {max} times submits '
      'the test automatically.';
  static const violationTooltipUnlimited = 'Times you left the test: {n}.';
  static const autoSubmittedLeaves =
      'Your test was submitted because you left it too many times.';

  // Question palette
  static const notVisited = 'Not Visited';

  // Integer answer box
  static const integerHint = 'Enter a number';
}
