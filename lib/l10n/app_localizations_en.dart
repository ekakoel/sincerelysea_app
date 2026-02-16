// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String captionMaxLength(int count) {
    return 'Caption maximum is $count characters';
  }

  @override
  String sharePreview(
    String username,
    String previewSection,
    String postLink,
    String playStoreUrl,
    String appStoreUrl,
  ) {
    return 'Check out a post by @$username on SincerelySea$previewSection\n\nOpen post:\n$postLink\n\nDo not have SincerelySea yet?\nAndroid: $playStoreUrl\niOS: $appStoreUrl';
  }

  @override
  String get shareSubject => 'Check out an interesting post on SincerelySea';

  @override
  String get deleteCommentTitle => 'Delete comment';

  @override
  String get cancelLabel => 'Cancel';

  @override
  String get deleteLabel => 'Delete';

  @override
  String get confirmDeleteComment =>
      'Are you sure you want to delete this comment?';

  @override
  String failedToDelete(String error) {
    return 'Failed to delete: $error';
  }

  @override
  String get failedToLoadImage => 'Failed to load image';

  @override
  String get usernameCanOnlyChangeOnce => 'Username can only be changed once';

  @override
  String get usernameMustBeDifferent =>
      'New username must be different from current username';

  @override
  String get usernamePlaceholder => 'new_username';

  @override
  String get usernameAlreadyChanged => 'Username has already been changed';

  @override
  String get usernameCanChangeOnce => 'Username can be changed only once';

  @override
  String get displayNameRequired => 'Display name is required';

  @override
  String get writeCommentHint => 'Write a comment...';

  @override
  String get emptyImageUrl => 'Image URL is empty';

  @override
  String get invalidImageUrl => 'Invalid image URL';

  @override
  String get forgotPasswordTitle => 'Forgot Password';

  @override
  String get forgotPasswordDescription =>
      'Enter your registered email to reset your password.';

  @override
  String get resetPasswordLinkSent =>
      'Password reset link has been sent to your email';

  @override
  String get pleaseEnterEmail => 'Please enter your email';

  @override
  String get invalidEmailFormat => 'Invalid email format';

  @override
  String get autoResendIfNotReceived => 'Automatically resend if not received';

  @override
  String resendButton(int seconds) {
    return 'Resend ($seconds)';
  }

  @override
  String get sendResetLink => 'Send Reset Link';

  @override
  String get backToLogin => 'Back to Login';
}
