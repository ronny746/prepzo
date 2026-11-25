/// User-facing strings added for the QA-report fixes.
///
/// The app has no i18n system yet; keeping new copy here (instead of inline)
/// gives one place to migrate to locale files later.
class AppStrings {
  const AppStrings._();

  /// Shown once on the login screen after the server ends the session
  /// (e.g. the same account signed in on another device).
  static const String sessionExpired =
      'Your session has ended because this account was signed in on another device. Please log in again.';

  static const String studyNotInCourseTitle =
      'Study material is not part of your course';
  static const String studyNotInCourseBody =
      'Your current course does not include study material.';

  // Help & Support screen.
  static const String supportTitle = 'Support';
  static const String supportPhone = 'Call us';
  static const String supportEmail = 'Email us';
  static const String supportWebsite = 'Website';
  static const String supportWhatsapp = 'WhatsApp';
  static const String supportUnavailable =
      'Support contact details are not available yet';
  static const String supportCannotOpen = 'Could not open this link.';
}
