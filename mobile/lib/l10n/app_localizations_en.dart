// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get courseLoadFailed => 'Could not load course details.';

  @override
  String get courseRetry => 'Retry';

  @override
  String get courseEnrollFailed => 'Enrollment failed. Please try again.';

  @override
  String get examLoadFailedTitle => 'Couldn\'t load your exams';

  @override
  String get examLoadFailedMessage =>
      'Something went wrong while loading your exams. Check your connection and pull down to retry.';

  @override
  String get notificationDetailTitle => 'Notification Details';

  @override
  String get profileUpdateFailed => 'Failed to update profile.';

  @override
  String get profileAvatarUploadFailed =>
      'Your profile was saved, but the photo could not be uploaded.';

  @override
  String get studyPdfLoadFailed =>
      'Could not load this document. Check your connection and try again.';
}
