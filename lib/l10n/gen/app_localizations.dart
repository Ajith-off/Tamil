import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ta.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ta'),
  ];

  /// The app's name, shown as the window/task title.
  ///
  /// In ta, this message translates to:
  /// **'Kids: அஆஇஈ தமிழ் எழுத்து'**
  String get appTitle;

  /// Button that replays the animated stroke-order demo.
  ///
  /// In ta, this message translates to:
  /// **'மீண்டும் பார்'**
  String get watchAgain;

  /// Button that skips or ends the demo and starts tracing.
  ///
  /// In ta, this message translates to:
  /// **'எழுத ஆரம்பி'**
  String get startTracing;

  /// Button that clears the child's trace and starts the letter over.
  ///
  /// In ta, this message translates to:
  /// **'அழி'**
  String get clear;

  /// Button that moves on to the next letter after finishing one.
  ///
  /// In ta, this message translates to:
  /// **'அடுத்த எழுத்து'**
  String get nextLetter;

  /// Label introducing the example word shown for a letter.
  ///
  /// In ta, this message translates to:
  /// **'உதாரணச் சொல்'**
  String get exampleWordLabel;

  /// Label shown before the numeric score, e.g. 'மதிப்பெண்: 42/50'.
  ///
  /// In ta, this message translates to:
  /// **'மதிப்பெண்'**
  String get scoreLabel;

  /// Encouraging message shown after a passing attempt (>=1 star).
  ///
  /// In ta, this message translates to:
  /// **'அருமை!'**
  String get encouragementSuccess;

  /// Gentle message shown after a non-passing attempt (0 stars).
  ///
  /// In ta, this message translates to:
  /// **'மீண்டும் முயற்சி செய்!'**
  String get encouragementRetry;

  /// Hint telling the child to drag their finger along the dots.
  ///
  /// In ta, this message translates to:
  /// **'விரலால் புள்ளிகளைத் தொடர்ந்து செல்'**
  String get tutorialHint;

  /// Label for the Easy mode: letter tube plus dots showing where to drag.
  ///
  /// In ta, this message translates to:
  /// **'எளிது'**
  String get modeEasy;

  /// Label for the Medium mode: letter tube shown, but no dots.
  ///
  /// In ta, this message translates to:
  /// **'நடுத்தரம்'**
  String get modeMedium;

  /// Label for the Hard mode: blank canvas, but the finger is still guided along the hidden path.
  ///
  /// In ta, this message translates to:
  /// **'கடினம்'**
  String get modeHard;

  /// Label for the Special mode: freehand drawing, judged on shape only when submitted.
  ///
  /// In ta, this message translates to:
  /// **'சவால்'**
  String get modeSpecial;

  /// Button that submits a freehand attempt to be scored.
  ///
  /// In ta, this message translates to:
  /// **'சமர்ப்பி'**
  String get submit;

  /// Hint shown in the freehand exam mode, telling the child to write the letter themselves.
  ///
  /// In ta, this message translates to:
  /// **'எழுத்தை நீயே எழுதிப் பார்'**
  String get freeDrawHint;

  /// Title of the uyir (vowel) letter category.
  ///
  /// In ta, this message translates to:
  /// **'உயிர் எழுத்து'**
  String get categoryUyir;

  /// Title of the mei (pure consonant) letter category.
  ///
  /// In ta, this message translates to:
  /// **'மெய் எழுத்து'**
  String get categoryMei;

  /// Title of the uyirmei (consonant-vowel) letter category.
  ///
  /// In ta, this message translates to:
  /// **'உயிர்மெய் எழுத்து'**
  String get categoryUyirmei;

  /// Title of the games section, and the tile that opens it.
  ///
  /// In ta, this message translates to:
  /// **'விளையாட்டு'**
  String get games;

  /// Name of the Word Builder game.
  ///
  /// In ta, this message translates to:
  /// **'சொல் கட்டு'**
  String get gameWordBuilder;

  /// Tells the child to drag a letter tile into its box.
  ///
  /// In ta, this message translates to:
  /// **'எழுத்தை இழுத்து அதன் இடத்தில் வை'**
  String get wordBuilderHint;

  /// Shown when every box of the word has been filled correctly.
  ///
  /// In ta, this message translates to:
  /// **'சொல் முடிந்தது!'**
  String get wordBuilderDone;

  /// Title of the grantha letter category — the six letters ஜ ஷ ஸ ஹ க்ஷ ஸ்ரீ, which are outside the 247.
  ///
  /// In ta, this message translates to:
  /// **'வடமொழி எழுத்துக்கள்'**
  String get categoryVadamozhi;

  /// Names a uyirmei consonant row, e.g. 'க வரிசை' for the 12 letters built on க.
  ///
  /// In ta, this message translates to:
  /// **'{letter} வரிசை'**
  String groupRow(String letter);

  /// Instruction on the uyirmei group screen telling the child to pick one consonant row.
  ///
  /// In ta, this message translates to:
  /// **'ஒரு வரிசையைத் தேர்ந்தெடு'**
  String get pickAGroup;

  /// Instruction on the letter list telling the child to tap a letter to begin.
  ///
  /// In ta, this message translates to:
  /// **'எழுத்தைத் தொடு'**
  String get tapALetter;

  /// Shown in place of the tap-a-letter hint when a category has no letters ready to trace yet.
  ///
  /// In ta, this message translates to:
  /// **'விரைவில் வரும்'**
  String get categoryEmpty;

  /// Prominent button shown after finishing a letter, to write it again.
  ///
  /// In ta, this message translates to:
  /// **'மீண்டும்'**
  String get tryAgain;

  /// Button that replays the same word.
  ///
  /// In ta, this message translates to:
  /// **'மீண்டும்'**
  String get playAgain;

  /// Button that accepts the finished word and goes back.
  ///
  /// In ta, this message translates to:
  /// **'சரி'**
  String get done;

  /// Shown beside a coin when a clean round earned one.
  ///
  /// In ta, this message translates to:
  /// **'+1'**
  String get coinEarned;

  /// Explains that a coin buys more hearts.
  ///
  /// In ta, this message translates to:
  /// **'இதயம் வாங்க ஒரு நாணயம்'**
  String get needHearts;

  /// Shown when there are no hearts left to open a word.
  ///
  /// In ta, this message translates to:
  /// **'இதயம் இல்லை'**
  String get noHearts;

  /// Caption over the opening demonstration: drag like this.
  ///
  /// In ta, this message translates to:
  /// **'இப்படி இழு'**
  String get tutorialDrag;

  /// Title of the word game, on the home picker and its own screen.
  ///
  /// In ta, this message translates to:
  /// **'எழுத்து விளையாட்டு'**
  String get wordGame;

  /// A category name with how many characters are in it, e.g. "உயிர் எழுத்து (13)".
  ///
  /// In ta, this message translates to:
  /// **'{label} ({count})'**
  String countedLabel(String label, String count);

  /// The app name on the home screen with how many characters it teaches, e.g. "அஆஇஈ தமிழ் எழுத்து — 247".
  ///
  /// In ta, this message translates to:
  /// **'{title} — {count}'**
  String appTitleCounted(String title, String count);

  /// Closes the app, from the home screen.
  ///
  /// In ta, this message translates to:
  /// **'வெளியேறு'**
  String get quit;

  /// Title of the Parent Zone tile on the home screen, and of the screen it opens.
  ///
  /// In ta, this message translates to:
  /// **'பெற்றோர் பகுதி'**
  String get parentZone;

  /// Title of the parental gate shown before entering the Parent Zone.
  ///
  /// In ta, this message translates to:
  /// **'பெற்றோர் அனுமதி'**
  String get parentalGateTitle;

  /// Instruction on the parental gate: pick the correct answer to the sum shown.
  ///
  /// In ta, this message translates to:
  /// **'சரியான பதிலைத் தேர்ந்தெடு'**
  String get parentalGateInstruction;

  /// The addition question on the parental gate, e.g. '7 + 8 = ?'.
  ///
  /// In ta, this message translates to:
  /// **'{a} + {b} = ?'**
  String parentalGateQuestion(String a, String b);

  /// Shown in a loading dialog while the rewarded ad is being fetched from AdMob, before it appears full-screen.
  ///
  /// In ta, this message translates to:
  /// **'விளம்பரம் ஏற்றப்படுகிறது…'**
  String get adPlaying;

  /// Parent Zone row: watch a rewarded ad to earn a coin.
  ///
  /// In ta, this message translates to:
  /// **'நாணயம் பெற விளம்பரம் பார்'**
  String get watchAdEarnCoin;

  /// Subtitle under the watch-ad row saying how many coins it pays.
  ///
  /// In ta, this message translates to:
  /// **'{coins} நாணயம் கிடைக்கும்'**
  String watchAdEarnCoinHint(String coins);

  /// Shown after a rewarded ad is watched all the way through.
  ///
  /// In ta, this message translates to:
  /// **'நாணயம் கிடைத்தது!'**
  String get adRewardEarned;

  /// Shown when the rewarded ad fails to load or show (e.g. no fill), so a grown-up gets feedback instead of the row silently doing nothing.
  ///
  /// In ta, this message translates to:
  /// **'இப்போது விளம்பரம் இல்லை. பிறகு முயற்சி செய்க.'**
  String get adUnavailable;

  /// Parent Zone row, and title of the certificate screen it opens.
  ///
  /// In ta, this message translates to:
  /// **'சான்றிதழ்'**
  String get certificate;

  /// The certificate's total, e.g. '62 / 100'.
  ///
  /// In ta, this message translates to:
  /// **'{score} / 100'**
  String certificateScoreLine(String score);

  /// Certificate line: marks earned across all 247 core letters holding at least one star, out of 50.
  ///
  /// In ta, this message translates to:
  /// **'247 எழுத்துப் பயிற்சி மதிப்பெண்கள்'**
  String get certAllStarred;

  /// Certificate line: able to write uyir letters fully without guidance (three stars on every one).
  ///
  /// In ta, this message translates to:
  /// **'உயிர் எழுத்துக்களை வழிகாட்டுதல் இல்லாமல் முழுமையாக எழுதலாம்'**
  String get certUyir;

  /// Certificate line: able to write mei letters fully without guidance (three stars on every one).
  ///
  /// In ta, this message translates to:
  /// **'மெய் எழுத்துக்களை வழிகாட்டுதல் இல்லாமல் முழுமையாக எழுதலாம்'**
  String get certMei;

  /// Certificate line: able to write uyirmei letters fully without guidance (three stars on every one).
  ///
  /// In ta, this message translates to:
  /// **'உயிர்மெய் எழுத்துக்களை வழிகாட்டுதல் இல்லாமல் முழுமையாக எழுதலாம்'**
  String get certUyirmei;

  /// Certificate line: completed the letter game exam (every Word Builder word cleared without a wrong drop).
  ///
  /// In ta, this message translates to:
  /// **'எழுத்து விளையாட்டுத் தேர்வை முடித்தார்'**
  String get certGame;

  /// Marks a certificate line is worth, shown beside it, e.g. '+10'.
  ///
  /// In ta, this message translates to:
  /// **'+{marks}'**
  String certMarksLine(String marks);

  /// Marks actually earned on a certificate line, out of its possible marks, e.g. '1/50'.
  ///
  /// In ta, this message translates to:
  /// **'{marks}/{maxMarks}'**
  String certMarksFraction(String marks, String maxMarks);

  /// Certificate line above the name field: 'This certifies that'.
  ///
  /// In ta, this message translates to:
  /// **'இது சான்றளிக்கிறது'**
  String get certificateIntro;

  /// Placeholder in the certificate's editable name field.
  ///
  /// In ta, this message translates to:
  /// **'பெயரை உள்ளிடவும்'**
  String get certificateNamePlaceholder;

  /// Certificate sentence naming the app and introducing the marks below.
  ///
  /// In ta, this message translates to:
  /// **'{title} பயிற்சியில் ஈடுபட்டு பின்வரும் மதிப்பெண்களைப் பெற்றுள்ளார்'**
  String certificateBody(String title);

  /// Date line at the foot of the certificate.
  ///
  /// In ta, this message translates to:
  /// **'தேதி: {date}'**
  String certificateDateLabel(String date);

  /// Button/dialog title explaining how the certificate's 100 marks are worked out.
  ///
  /// In ta, this message translates to:
  /// **'மதிப்பெண் எப்படி கணக்கிடப்படுகிறது?'**
  String get certificateHowCalculated;

  /// Intro line in the marks-explanation dialog, before the breakdown list.
  ///
  /// In ta, this message translates to:
  /// **'மொத்தம் 100 மதிப்பெண்களில்:'**
  String get certificateHowCalculatedIntro;

  /// Button that exports/shares the certificate as an image.
  ///
  /// In ta, this message translates to:
  /// **'பதிவிறக்கு'**
  String get certificateExport;

  /// Shown when exporting the certificate image fails.
  ///
  /// In ta, this message translates to:
  /// **'சான்றிதழைச் சேமிக்க முடியவில்லை'**
  String get certificateExportFailed;

  /// Text handed to the share sheet when exporting a named certificate.
  ///
  /// In ta, this message translates to:
  /// **'{name} இன் {title} சான்றிதழ்'**
  String certificateShareText(String name, String title);

  /// Text handed to the share sheet when exporting a certificate with no name typed in yet.
  ///
  /// In ta, this message translates to:
  /// **'{title} முன்னேற்றச் சான்றிதழ்'**
  String certificateShareTextNoName(String title);

  /// Tooltip on the home screen's theme toggle when the light (sun) theme is active.
  ///
  /// In ta, this message translates to:
  /// **'பகல் தீம்'**
  String get themeLight;

  /// Tooltip on the home screen's theme toggle when the dark (moon) theme is active.
  ///
  /// In ta, this message translates to:
  /// **'இரவு தீம்'**
  String get themeDark;

  /// Parent Zone row that opens the project details link.
  ///
  /// In ta, this message translates to:
  /// **'திட்ட விவரங்கள்'**
  String get projectDetails;

  /// Parent Zone row that opens the privacy policy link.
  ///
  /// In ta, this message translates to:
  /// **'தனியுரிமைக் கொள்கை'**
  String get privacyPolicy;

  /// The app's version, shown in the Parent Zone.
  ///
  /// In ta, this message translates to:
  /// **'பதிப்பு {version}'**
  String versionLabel(String version);

  /// Copyright line shown in the Parent Zone.
  ///
  /// In ta, this message translates to:
  /// **'© {year} அஆஇஈ தமிழ் எழுத்து'**
  String copyrightLine(String year);

  /// Shown when an outbound link (project details, privacy policy) could not be opened.
  ///
  /// In ta, this message translates to:
  /// **'இணைப்பைத் திறக்க முடியவில்லை'**
  String get linkOpenFailed;

  /// Parent Zone row that opens the platform share sheet to share the app itself.
  ///
  /// In ta, this message translates to:
  /// **'ஆப்பைப் பகிர்'**
  String get shareApp;

  /// The text handed to the platform share sheet when sharing the app, e.g. 'Try AAIE Tamil Ezhuthu: <url>'.
  ///
  /// In ta, this message translates to:
  /// **'{title} ஆப்பை முயற்சி செய்யுங்கள்: {url}'**
  String shareAppText(String title, String url);

  /// Parent Zone row: switches the app between Tamil and English.
  ///
  /// In ta, this message translates to:
  /// **'மொழி'**
  String get settingsLanguage;

  /// Parent Zone row: toggles background music on or off.
  ///
  /// In ta, this message translates to:
  /// **'பின்னணி இசை'**
  String get settingsMusic;

  /// Parent Zone row: toggles click and celebration sound effects, and letter speech, on or off.
  ///
  /// In ta, this message translates to:
  /// **'ஒலி விளைவுகள்'**
  String get settingsSound;

  /// Speaker icon on the tracing screen (uyir only, for now) that replays the letter's pronunciation.
  ///
  /// In ta, this message translates to:
  /// **'எழுத்தைக் கேள்'**
  String get replayLetterSound;
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
      <String>['en', 'ta'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ta':
      return AppLocalizationsTa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
