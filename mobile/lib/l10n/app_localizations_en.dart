// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tagline => 'Find lost pets, help street animals';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get displayName => 'Your name';

  @override
  String get signIn => 'Sign in';

  @override
  String get createAccount => 'Create account';

  @override
  String get signOut => 'Sign out';

  @override
  String get noAccount => 'No account yet? Create one';

  @override
  String get haveAccount => 'Already have an account? Sign in';

  @override
  String get required => 'Required';

  @override
  String get invalidEmail => 'Enter a valid email';

  @override
  String get passwordTooShort => 'At least 8 characters';

  @override
  String get errorNetwork => 'Cannot reach the server. Check your connection.';

  @override
  String get errorRateLimited =>
      'You\'ve posted a lot recently. Try again later.';

  @override
  String get errorInvalidImage =>
      'This photo can\'t be read. Use a JPEG, PNG, WebP or HEIC image.';

  @override
  String get errorImageTooLarge => 'This photo is too large.';

  @override
  String get errorEmailTaken => 'This email is already registered.';

  @override
  String get errorWrongCredentials => 'Wrong email or password.';

  @override
  String get errorUnexpected => 'Something went wrong.';

  @override
  String get retry => 'Try again';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get change => 'Change';

  @override
  String get choose => 'Choose';

  @override
  String get apply => 'Apply';

  @override
  String get speciesCat => 'Cat';

  @override
  String get speciesDog => 'Dog';

  @override
  String get speciesOther => 'Other';

  @override
  String get conditionHealthy => 'Healthy';

  @override
  String get conditionInjured => 'Injured';

  @override
  String get conditionNeedsHelp => 'Needs help';

  @override
  String get statusOpen => 'Still lost';

  @override
  String get statusFound => 'Found';

  @override
  String get statusClosed => 'Closed';

  @override
  String get typeLost => 'Lost pets';

  @override
  String get typeSighting => 'Sighting';

  @override
  String get typeStray => 'Stray';

  @override
  String get filters => 'Filters';

  @override
  String get filterShow => 'Show';

  @override
  String get filterSpecies => 'Species';

  @override
  String get filterCondition => 'Condition (sightings)';

  @override
  String get filterPeriod => 'Period';

  @override
  String get periodAny => 'Any time';

  @override
  String periodDays(int days) {
    return '$days days';
  }

  @override
  String get myActivity => 'My activity';

  @override
  String get myLocation => 'My location';

  @override
  String get reportLostPet => 'Report a lost pet';

  @override
  String get iSawAnAnimal => 'I saw an animal';

  @override
  String lostNamed(String name) {
    return '$name is lost';
  }

  @override
  String sightingOf(String species) {
    return '$species seen';
  }

  @override
  String strayOf(String species) {
    return 'Stray $species';
  }

  @override
  String get photoHint =>
      'Get close and show the face: it helps us recognise the animal.';

  @override
  String get condition => 'Condition';

  @override
  String get isStray => 'This is a street animal';

  @override
  String get isStrayHelp => 'It lives outside and has no owner';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get locating => 'Getting your location…';

  @override
  String get locationMissing => 'No location yet: choose it on the map';

  @override
  String locationFromGps(int meters) {
    return 'Your current location (±$meters m)';
  }

  @override
  String get locationPicked => 'Location chosen on the map';

  @override
  String get postSighting => 'Send sighting';

  @override
  String uploading(String progress) {
    return 'Uploading photos $progress';
  }

  @override
  String get camera => 'Camera';

  @override
  String get gallery => 'Gallery';

  @override
  String get noAnimalTitle => 'No animal found';

  @override
  String get noAnimalBody =>
      'We couldn\'t find a cat or dog in this photo. A closer photo of the head works best.';

  @override
  String get keepPhoto => 'Keep it';

  @override
  String get retakePhoto => 'Retake';

  @override
  String get lostPhotosHint =>
      'Add 1–5 clear photos, ideally of the face from different angles.';

  @override
  String get petName => 'Pet\'s name';

  @override
  String get descriptionOptional => 'Description (optional)';

  @override
  String get descriptionHint => 'Collar, markings, temperament…';

  @override
  String get lastSeenAt => 'Last seen';

  @override
  String get lastSeenWhere => 'Where was it last seen?';

  @override
  String get locationPrivacyNote =>
      'Others only see an area of about 300 m around it';

  @override
  String get publishReport => 'Publish report';

  @override
  String get pickLocationTitle => 'Choose the place';

  @override
  String get pickLocationHint => 'Tap the map where the animal was.';

  @override
  String get confirmLocation => 'Use this place';

  @override
  String get markFound => 'Mark as found';

  @override
  String get closeReport => 'Close report';

  @override
  String get reopenReport => 'Reopen (still lost)';

  @override
  String get deleteReportQuestion => 'Delete this report and its photos?';

  @override
  String get deleteSightingQuestion => 'Delete this sighting and its photos?';

  @override
  String lastSeenOn(String date) {
    return 'Last seen $date';
  }

  @override
  String seenOn(String date) {
    return 'Seen $date';
  }

  @override
  String get approximateArea =>
      'Approximate area, to protect the owner\'s privacy.';

  @override
  String get photoProcessing => 'Checking…';

  @override
  String get photoNoAnimal => 'No animal found';

  @override
  String get photoNotMatched => 'Not used for matching';

  @override
  String get photoFailed => 'Processing failed';

  @override
  String get tabMatches => 'Matches';

  @override
  String get tabMyLostPets => 'My lost pets';

  @override
  String get tabMySightings => 'My sightings';

  @override
  String get noMatches =>
      'No possible matches yet. We check every new sighting nearby.';

  @override
  String get noLostReports => 'You haven\'t reported a lost pet.';

  @override
  String get noSightings => 'You haven\'t posted any sightings.';

  @override
  String get possibleMatch => 'Possible match';

  @override
  String possibleMatchFor(String name) {
    return 'Could this be $name?';
  }

  @override
  String similarity(int percent) {
    return '$percent% similar';
  }

  @override
  String get yourPhoto => 'Your photo';

  @override
  String get sightingPhoto => 'Sighting';

  @override
  String get matchExplanation =>
      'Our model found these photos similar. Look closely at markings and features before contacting the finder.';

  @override
  String get matchNotFound => 'This match no longer exists.';

  @override
  String get takePhoto => 'Take a photo';

  @override
  String get chooseFromGallery => 'From gallery';

  @override
  String get timeNow => 'Seen just now';

  @override
  String timeFromPhoto(String date) {
    return 'Seen $date (from the photo)';
  }

  @override
  String get timeMissing => 'When did you see it? Set the time';

  @override
  String get locationFromPhoto => 'Location from the photo';

  @override
  String get locationNeeded => 'Where did you see it? Choose on the map';

  @override
  String get missingPets => 'Missing pets';

  @override
  String get map => 'Map';

  @override
  String get nearMe => 'Near me';

  @override
  String get everywhere => 'Everywhere';

  @override
  String get allSpecies => 'All';

  @override
  String get noMissingPets => 'No missing pets reported. Good news!';

  @override
  String get noMissingPetsNearby =>
      'No missing pets near you. Try “Everywhere”.';

  @override
  String kmAway(String km) {
    return '$km km away';
  }

  @override
  String get locationOffForNearby => 'Turn on location to see pets near you.';

  @override
  String matchNotification(String name) {
    return 'Someone may have seen $name.';
  }

  @override
  String get view => 'View';

  @override
  String get thatsMyPet => 'That\'s my pet';

  @override
  String get notMyPet => 'Not my pet';

  @override
  String get matchHidden => 'Hidden. This sighting won\'t be suggested again.';

  @override
  String get undo => 'Undo';

  @override
  String matchConfirmedInfo(String name) {
    return 'You recognised $name. The person who saw it has been told.';
  }

  @override
  String get messageFinder => 'Message the finder';

  @override
  String get openConversation => 'Open the conversation';

  @override
  String gotPetBack(String name) {
    return 'I got $name back';
  }

  @override
  String gotPetBackQuestion(String name) {
    return 'Is $name back home? This closes the case: no more matches, and the report leaves the map. You can reopen it later.';
  }

  @override
  String get closeCase => 'Close the case';

  @override
  String petBackHome(String name) {
    return '$name is back home. The case is closed.';
  }

  @override
  String get matchStatusConfirmed => 'Confirmed';

  @override
  String get messages => 'Messages';

  @override
  String get noConversations =>
      'No messages yet. When you write to someone who saw your pet, or an owner recognises an animal you saw, the conversation appears here.';

  @override
  String aboutPet(String name) {
    return 'About $name';
  }

  @override
  String youSaid(String text) {
    return 'You: $text';
  }

  @override
  String get writeMessage => 'Write a message';

  @override
  String get send => 'Send';

  @override
  String get noMessagesYet =>
      'No messages yet. Say hello and explain how you can help.';

  @override
  String get chatPrivacy =>
      'Only your display name is shown. Never share your address before you\'re sure.';

  @override
  String caseClosedChat(String name) {
    return '$name is back home. This case is closed, but you can still write.';
  }

  @override
  String messageNotification(String name) {
    return 'New message from $name';
  }

  @override
  String confirmedNotification(String name) {
    return 'The owner of $name recognised the animal you saw.';
  }

  @override
  String foundNotification(String name) {
    return '$name is back home. Thank you for helping!';
  }

  @override
  String get helpBringThemHome => 'Help bring them home';

  @override
  String missingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pets are missing',
      one: '1 pet is missing',
      zero: 'No pet missing here',
    );
    return '$_temp0';
  }

  @override
  String get justNow => 'just now';

  @override
  String minutesAgo(int n) {
    return '$n min ago';
  }

  @override
  String hoursAgo(int n) {
    return '$n h ago';
  }

  @override
  String daysAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days ago',
      one: 'yesterday',
    );
    return '$_temp0';
  }

  @override
  String seenAgo(String when) {
    return 'Seen $when';
  }

  @override
  String missingCountMore(int count) {
    return '$count+ pets are missing';
  }

  @override
  String get possibleVisualMatch => 'Possible visual match';

  @override
  String get notConfirmedIdentity => 'A resemblance, not a confirmed identity.';

  @override
  String get addClearPhoto => 'Add a clear photo';

  @override
  String get addClearPhotoHelp => 'Camera or gallery';

  @override
  String get emailHint => 'Your email';

  @override
  String get speciesTitle => 'Species';

  @override
  String get adjust => 'Adjust';

  @override
  String get tapToAdjust => 'Tap Adjust to move it';

  @override
  String get retake => 'Retake';

  @override
  String get thanksTitle => 'Thank you!';

  @override
  String get thanksBody =>
      'Your sighting is on the map. If it looks like a lost pet, we\'ll tell the owner right away.';

  @override
  String get backToMissingPets => 'Back to missing pets';

  @override
  String get typeLostOne => 'Lost pet';
}
