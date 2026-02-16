import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @captionMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Caption maximum is {count} characters'**
  String captionMaxLength(int count);

  /// No description provided for @sharePreview.
  ///
  /// In en, this message translates to:
  /// **'Check out a post by @{username} on SincerelySea{previewSection}\n\nOpen post:\n{postLink}\n\nDo not have SincerelySea yet?\nAndroid: {playStoreUrl}\niOS: {appStoreUrl}'**
  String sharePreview(
    String username,
    String previewSection,
    String postLink,
    String playStoreUrl,
    String appStoreUrl,
  );

  /// No description provided for @shareSubject.
  ///
  /// In en, this message translates to:
  /// **'Check out an interesting post on SincerelySea'**
  String get shareSubject;

  /// No description provided for @deleteCommentTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete comment'**
  String get deleteCommentTitle;

  /// No description provided for @cancelLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelLabel;

  /// No description provided for @deleteLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteLabel;

  /// No description provided for @confirmDeleteComment.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this comment?'**
  String get confirmDeleteComment;

  /// No description provided for @failedToDelete.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete: {error}'**
  String failedToDelete(String error);

  /// No description provided for @failedToLoadImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to load image'**
  String get failedToLoadImage;

  /// No description provided for @usernameCanOnlyChangeOnce.
  ///
  /// In en, this message translates to:
  /// **'Username can only be changed once'**
  String get usernameCanOnlyChangeOnce;

  /// No description provided for @usernameMustBeDifferent.
  ///
  /// In en, this message translates to:
  /// **'New username must be different from current username'**
  String get usernameMustBeDifferent;

  /// No description provided for @usernamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'new_username'**
  String get usernamePlaceholder;

  /// No description provided for @usernameAlreadyChanged.
  ///
  /// In en, this message translates to:
  /// **'Username has already been changed'**
  String get usernameAlreadyChanged;

  /// No description provided for @usernameCanChangeOnce.
  ///
  /// In en, this message translates to:
  /// **'Username can be changed only once'**
  String get usernameCanChangeOnce;

  /// No description provided for @displayNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Display name is required'**
  String get displayNameRequired;

  /// No description provided for @writeCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Write a comment...'**
  String get writeCommentHint;

  /// No description provided for @emptyImageUrl.
  ///
  /// In en, this message translates to:
  /// **'Image URL is empty'**
  String get emptyImageUrl;

  /// No description provided for @invalidImageUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid image URL'**
  String get invalidImageUrl;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter your registered email to reset your password.'**
  String get forgotPasswordDescription;

  /// No description provided for @resetPasswordLinkSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset link has been sent to your email'**
  String get resetPasswordLinkSent;

  /// No description provided for @pleaseEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get pleaseEnterEmail;

  /// No description provided for @invalidEmailFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format'**
  String get invalidEmailFormat;

  /// No description provided for @autoResendIfNotReceived.
  ///
  /// In en, this message translates to:
  /// **'Automatically resend if not received'**
  String get autoResendIfNotReceived;

  /// No description provided for @resendButton.
  ///
  /// In en, this message translates to:
  /// **'Resend ({seconds})'**
  String resendButton(int seconds);

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get sendResetLink;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get backToLogin;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
