// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tamil (`ta`).
class AppLocalizationsTa extends AppLocalizations {
  AppLocalizationsTa([String locale = 'ta']) : super(locale);

  @override
  String get appTitle => 'Kids: அஆஇஈ தமிழ் எழுத்து';

  @override
  String get watchAgain => 'மீண்டும் பார்';

  @override
  String get startTracing => 'எழுத ஆரம்பி';

  @override
  String get clear => 'அழி';

  @override
  String get nextLetter => 'அடுத்த எழுத்து';

  @override
  String get exampleWordLabel => 'உதாரணச் சொல்';

  @override
  String get scoreLabel => 'மதிப்பெண்';

  @override
  String get encouragementSuccess => 'அருமை!';

  @override
  String get encouragementRetry => 'மீண்டும் முயற்சி செய்!';

  @override
  String get tutorialHint => 'விரலால் புள்ளிகளைத் தொடர்ந்து செல்';

  @override
  String get modeEasy => 'எளிது';

  @override
  String get modeMedium => 'நடுத்தரம்';

  @override
  String get modeHard => 'கடினம்';

  @override
  String get modeSpecial => 'சவால்';

  @override
  String get submit => 'சமர்ப்பி';

  @override
  String get freeDrawHint => 'எழுத்தை நீயே எழுதிப் பார்';

  @override
  String get categoryUyir => 'உயிர் எழுத்து';

  @override
  String get categoryMei => 'மெய் எழுத்து';

  @override
  String get categoryUyirmei => 'உயிர்மெய் எழுத்து';

  @override
  String get games => 'விளையாட்டு';

  @override
  String get gameWordBuilder => 'சொல் கட்டு';

  @override
  String get wordBuilderHint => 'எழுத்தை இழுத்து அதன் இடத்தில் வை';

  @override
  String get wordBuilderDone => 'சொல் முடிந்தது!';

  @override
  String get categoryVadamozhi => 'வடமொழி எழுத்துக்கள்';

  @override
  String groupRow(String letter) {
    return '$letter வரிசை';
  }

  @override
  String get pickAGroup => 'ஒரு வரிசையைத் தேர்ந்தெடு';

  @override
  String get tapALetter => 'எழுத்தைத் தொடு';

  @override
  String get categoryEmpty => 'விரைவில் வரும்';

  @override
  String get tryAgain => 'மீண்டும்';

  @override
  String get playAgain => 'மீண்டும்';

  @override
  String get done => 'சரி';

  @override
  String get coinEarned => '+1';

  @override
  String get needHearts => 'இதயம் வாங்க ஒரு நாணயம்';

  @override
  String get noHearts => 'இதயம் இல்லை';

  @override
  String get tutorialDrag => 'இப்படி இழு';

  @override
  String get wordGame => 'எழுத்து விளையாட்டு';

  @override
  String countedLabel(String label, String count) {
    return '$label ($count)';
  }

  @override
  String appTitleCounted(String title, String count) {
    return '$title — $count';
  }

  @override
  String get quit => 'வெளியேறு';

  @override
  String get parentZone => 'பெற்றோர் பகுதி';

  @override
  String get parentalGateTitle => 'பெற்றோர் அனுமதி';

  @override
  String get parentalGateInstruction => 'சரியான பதிலைத் தேர்ந்தெடு';

  @override
  String parentalGateQuestion(String a, String b) {
    return '$a + $b = ?';
  }

  @override
  String get adPlaying => 'விளம்பரம் ஏற்றப்படுகிறது…';

  @override
  String get watchAdEarnCoin => 'நாணயம் பெற விளம்பரம் பார்';

  @override
  String watchAdEarnCoinHint(String coins) {
    return '$coins நாணயம் கிடைக்கும்';
  }

  @override
  String get adRewardEarned => 'நாணயம் கிடைத்தது!';

  @override
  String get adUnavailable => 'இப்போது விளம்பரம் இல்லை. பிறகு முயற்சி செய்க.';

  @override
  String get certificate => 'சான்றிதழ்';

  @override
  String certificateScoreLine(String score) {
    return '$score / 100';
  }

  @override
  String get certAllStarred => '247 எழுத்துப் பயிற்சி மதிப்பெண்கள்';

  @override
  String get certUyir =>
      'உயிர் எழுத்துக்களை வழிகாட்டுதல் இல்லாமல் முழுமையாக எழுதலாம்';

  @override
  String get certMei =>
      'மெய் எழுத்துக்களை வழிகாட்டுதல் இல்லாமல் முழுமையாக எழுதலாம்';

  @override
  String get certUyirmei =>
      'உயிர்மெய் எழுத்துக்களை வழிகாட்டுதல் இல்லாமல் முழுமையாக எழுதலாம்';

  @override
  String get certGame => 'எழுத்து விளையாட்டுத் தேர்வை முடித்தார்';

  @override
  String certMarksLine(String marks) {
    return '+$marks';
  }

  @override
  String certMarksFraction(String marks, String maxMarks) {
    return '$marks/$maxMarks';
  }

  @override
  String get certificateIntro => 'இது சான்றளிக்கிறது';

  @override
  String get certificateNamePlaceholder => 'பெயரை உள்ளிடவும்';

  @override
  String certificateBody(String title) {
    return '$title பயிற்சியில் ஈடுபட்டு பின்வரும் மதிப்பெண்களைப் பெற்றுள்ளார்';
  }

  @override
  String certificateDateLabel(String date) {
    return 'தேதி: $date';
  }

  @override
  String get certificateHowCalculated => 'மதிப்பெண் எப்படி கணக்கிடப்படுகிறது?';

  @override
  String get certificateHowCalculatedIntro => 'மொத்தம் 100 மதிப்பெண்களில்:';

  @override
  String get certificateExport => 'பதிவிறக்கு';

  @override
  String get certificateExportFailed => 'சான்றிதழைச் சேமிக்க முடியவில்லை';

  @override
  String certificateShareText(String name, String title) {
    return '$name இன் $title சான்றிதழ்';
  }

  @override
  String certificateShareTextNoName(String title) {
    return '$title முன்னேற்றச் சான்றிதழ்';
  }

  @override
  String get themeLight => 'பகல் தீம்';

  @override
  String get themeDark => 'இரவு தீம்';

  @override
  String get projectDetails => 'திட்ட விவரங்கள்';

  @override
  String get privacyPolicy => 'தனியுரிமைக் கொள்கை';

  @override
  String versionLabel(String version) {
    return 'பதிப்பு $version';
  }

  @override
  String copyrightLine(String year) {
    return '© $year அஆஇஈ தமிழ் எழுத்து';
  }

  @override
  String get linkOpenFailed => 'இணைப்பைத் திறக்க முடியவில்லை';

  @override
  String get shareApp => 'ஆப்பைப் பகிர்';

  @override
  String shareAppText(String title, String url) {
    return '$title ஆப்பை முயற்சி செய்யுங்கள்: $url';
  }

  @override
  String get settingsLanguage => 'மொழி';

  @override
  String get settingsMusic => 'பின்னணி இசை';

  @override
  String get settingsSound => 'ஒலி விளைவுகள்';

  @override
  String get replayLetterSound => 'எழுத்தைக் கேள்';
}
