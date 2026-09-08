// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Kids: AAIE Tamil Ezhuthu';

  @override
  String get watchAgain => 'Watch again';

  @override
  String get startTracing => 'Start writing';

  @override
  String get clear => 'Clear';

  @override
  String get nextLetter => 'Next letter';

  @override
  String get exampleWordLabel => 'Example word';

  @override
  String get scoreLabel => 'Score';

  @override
  String get encouragementSuccess => 'Great job!';

  @override
  String get encouragementRetry => 'Try again!';

  @override
  String get tutorialHint => 'Drag your finger along the dots';

  @override
  String get modeEasy => 'Easy';

  @override
  String get modeMedium => 'Medium';

  @override
  String get modeHard => 'Hard';

  @override
  String get modeSpecial => 'Challenge';

  @override
  String get submit => 'Submit';

  @override
  String get freeDrawHint => 'Write the letter yourself';

  @override
  String get categoryUyir => 'Uyir letters';

  @override
  String get categoryMei => 'Mei letters';

  @override
  String get categoryUyirmei => 'Uyirmei letters';

  @override
  String get games => 'Games';

  @override
  String get gameWordBuilder => 'Word Builder';

  @override
  String get wordBuilderHint => 'Drag a letter into its box';

  @override
  String get wordBuilderDone => 'Word complete!';

  @override
  String get categoryVadamozhi => 'Grantha letters';

  @override
  String groupRow(String letter) {
    return '$letter row';
  }

  @override
  String get pickAGroup => 'Pick a row to begin';

  @override
  String get tapALetter => 'Tap a letter to begin';

  @override
  String get categoryEmpty => 'Coming soon';

  @override
  String get tryAgain => 'Again';

  @override
  String get playAgain => 'Again';

  @override
  String get done => 'Done';

  @override
  String get coinEarned => '+1';

  @override
  String get needHearts => 'One coin buys three hearts';

  @override
  String get noHearts => 'No hearts left';

  @override
  String get tutorialDrag => 'Drag like this';

  @override
  String get wordGame => 'Letter Game';

  @override
  String countedLabel(String label, String count) {
    return '$label ($count)';
  }

  @override
  String appTitleCounted(String title, String count) {
    return '$title — $count';
  }

  @override
  String get quit => 'Quit';

  @override
  String get parentZone => 'Parent Zone';

  @override
  String get parentalGateTitle => 'Parental permission';

  @override
  String get parentalGateInstruction => 'Choose the correct answer';

  @override
  String parentalGateQuestion(String a, String b) {
    return '$a + $b = ?';
  }

  @override
  String get adPlaying => 'Loading ad…';

  @override
  String get watchAdEarnCoin => 'Watch an ad to earn a coin';

  @override
  String watchAdEarnCoinHint(String coins) {
    return 'Earn $coins coin';
  }

  @override
  String get adRewardEarned => 'Coin earned!';

  @override
  String get adUnavailable =>
      'No ad available right now. Please try again later.';

  @override
  String get certificate => 'Certificate';

  @override
  String certificateScoreLine(String score) {
    return '$score / 100';
  }

  @override
  String get certAllStarred => '247-character practice marks';

  @override
  String get certUyir => 'Can write uyir letters fully without guidance';

  @override
  String get certMei => 'Can write mei letters fully without guidance';

  @override
  String get certUyirmei => 'Can write uyirmei letters fully without guidance';

  @override
  String get certGame => 'Completed the letter game exam';

  @override
  String certMarksLine(String marks) {
    return '+$marks';
  }

  @override
  String certMarksFraction(String marks, String maxMarks) {
    return '$marks/$maxMarks';
  }

  @override
  String get certificateIntro => 'This certifies that';

  @override
  String get certificateNamePlaceholder => 'Enter name';

  @override
  String certificateBody(String title) {
    return 'has taken part in $title and earned the marks below';
  }

  @override
  String certificateDateLabel(String date) {
    return 'Date: $date';
  }

  @override
  String get certificateHowCalculated => 'How are marks calculated?';

  @override
  String get certificateHowCalculatedIntro => 'Out of 100 marks total:';

  @override
  String get certificateExport => 'Download';

  @override
  String get certificateExportFailed => 'Couldn\'t save the certificate';

  @override
  String certificateShareText(String name, String title) {
    return '$name\'s $title certificate';
  }

  @override
  String certificateShareTextNoName(String title) {
    return '$title progress certificate';
  }

  @override
  String get themeLight => 'Light theme';

  @override
  String get themeDark => 'Dark theme';

  @override
  String get projectDetails => 'Project Details';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String copyrightLine(String year) {
    return '© $year AAIE Tamil Ezhuthu';
  }

  @override
  String get linkOpenFailed => 'Couldn\'t open the link';

  @override
  String get shareApp => 'Share the app';

  @override
  String shareAppText(String title, String url) {
    return 'Try $title: $url';
  }

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsMusic => 'Background music';

  @override
  String get settingsSound => 'Sound effects';

  @override
  String get replayLetterSound => 'Hear the letter';
}
