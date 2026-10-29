import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Find lost pets, help street animals'**
  String get tagline;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get displayName;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'No account yet? Create one'**
  String get noAccount;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get haveAccount;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get invalidEmail;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordTooShort;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server. Check your connection.'**
  String get errorNetwork;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'You\'ve posted a lot recently. Try again later.'**
  String get errorRateLimited;

  /// No description provided for @errorInvalidImage.
  ///
  /// In en, this message translates to:
  /// **'This photo can\'t be read. Use a JPEG, PNG, WebP or HEIC image.'**
  String get errorInvalidImage;

  /// No description provided for @errorImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This photo is too large.'**
  String get errorImageTooLarge;

  /// No description provided for @errorEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered.'**
  String get errorEmailTaken;

  /// No description provided for @errorWrongCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password.'**
  String get errorWrongCredentials;

  /// No description provided for @errorUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get errorUnexpected;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @choose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get choose;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @speciesCat.
  ///
  /// In en, this message translates to:
  /// **'Cat'**
  String get speciesCat;

  /// No description provided for @speciesDog.
  ///
  /// In en, this message translates to:
  /// **'Dog'**
  String get speciesDog;

  /// No description provided for @speciesOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get speciesOther;

  /// No description provided for @conditionHealthy.
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get conditionHealthy;

  /// No description provided for @conditionInjured.
  ///
  /// In en, this message translates to:
  /// **'Injured'**
  String get conditionInjured;

  /// No description provided for @conditionNeedsHelp.
  ///
  /// In en, this message translates to:
  /// **'Needs help'**
  String get conditionNeedsHelp;

  /// No description provided for @statusOpen.
  ///
  /// In en, this message translates to:
  /// **'Still lost'**
  String get statusOpen;

  /// No description provided for @statusFound.
  ///
  /// In en, this message translates to:
  /// **'Found'**
  String get statusFound;

  /// No description provided for @statusClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get statusClosed;

  /// No description provided for @typeLost.
  ///
  /// In en, this message translates to:
  /// **'Lost pets'**
  String get typeLost;

  /// No description provided for @typeSighting.
  ///
  /// In en, this message translates to:
  /// **'Sighting'**
  String get typeSighting;

  /// No description provided for @typeStray.
  ///
  /// In en, this message translates to:
  /// **'Stray'**
  String get typeStray;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @filterShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get filterShow;

  /// No description provided for @filterSpecies.
  ///
  /// In en, this message translates to:
  /// **'Species'**
  String get filterSpecies;

  /// No description provided for @filterCondition.
  ///
  /// In en, this message translates to:
  /// **'Condition (sightings)'**
  String get filterCondition;

  /// No description provided for @filterPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get filterPeriod;

  /// No description provided for @periodAny.
  ///
  /// In en, this message translates to:
  /// **'Any time'**
  String get periodAny;

  /// No description provided for @periodDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String periodDays(int days);

  /// No description provided for @myActivity.
  ///
  /// In en, this message translates to:
  /// **'My activity'**
  String get myActivity;

  /// No description provided for @myLocation.
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get myLocation;

  /// No description provided for @reportLostPet.
  ///
  /// In en, this message translates to:
  /// **'Report a lost pet'**
  String get reportLostPet;

  /// No description provided for @iSawAnAnimal.
  ///
  /// In en, this message translates to:
  /// **'I saw an animal'**
  String get iSawAnAnimal;

  /// No description provided for @lostNamed.
  ///
  /// In en, this message translates to:
  /// **'Lost: {name}'**
  String lostNamed(String name);

  /// No description provided for @sightingOf.
  ///
  /// In en, this message translates to:
  /// **'{species} seen'**
  String sightingOf(String species);

  /// No description provided for @strayOf.
  ///
  /// In en, this message translates to:
  /// **'Stray {species}'**
  String strayOf(String species);

  /// No description provided for @newSighting.
  ///
  /// In en, this message translates to:
  /// **'New sighting'**
  String get newSighting;

  /// No description provided for @photoHint.
  ///
  /// In en, this message translates to:
  /// **'Get close and show the face: it helps us recognise the animal.'**
  String get photoHint;

  /// No description provided for @condition.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get condition;

  /// No description provided for @isStray.
  ///
  /// In en, this message translates to:
  /// **'It\'s a street animal'**
  String get isStray;

  /// No description provided for @isStrayHelp.
  ///
  /// In en, this message translates to:
  /// **'Lives outside rather than lost'**
  String get isStrayHelp;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptional;

  /// No description provided for @locating.
  ///
  /// In en, this message translates to:
  /// **'Getting your location…'**
  String get locating;

  /// No description provided for @locationMissing.
  ///
  /// In en, this message translates to:
  /// **'No location yet: choose it on the map'**
  String get locationMissing;

  /// No description provided for @locationFromGps.
  ///
  /// In en, this message translates to:
  /// **'Your current location (±{meters} m)'**
  String locationFromGps(int meters);

  /// No description provided for @locationPicked.
  ///
  /// In en, this message translates to:
  /// **'Location chosen on the map'**
  String get locationPicked;

  /// No description provided for @postSighting.
  ///
  /// In en, this message translates to:
  /// **'Post sighting'**
  String get postSighting;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading photos {progress}'**
  String uploading(String progress);

  /// No description provided for @sightingThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks! We\'re checking it against lost pets nearby.'**
  String get sightingThanks;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @noAnimalTitle.
  ///
  /// In en, this message translates to:
  /// **'No animal found'**
  String get noAnimalTitle;

  /// No description provided for @noAnimalBody.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find a cat or dog in this photo. A closer photo of the head works best.'**
  String get noAnimalBody;

  /// No description provided for @keepPhoto.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get keepPhoto;

  /// No description provided for @retakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get retakePhoto;

  /// No description provided for @lostPhotosHint.
  ///
  /// In en, this message translates to:
  /// **'Add 1–5 clear photos, ideally of the face from different angles.'**
  String get lostPhotosHint;

  /// No description provided for @petName.
  ///
  /// In en, this message translates to:
  /// **'Pet\'s name'**
  String get petName;

  /// No description provided for @descriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get descriptionOptional;

  /// No description provided for @descriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Collar, markings, temperament…'**
  String get descriptionHint;

  /// No description provided for @lastSeenAt.
  ///
  /// In en, this message translates to:
  /// **'Last seen'**
  String get lastSeenAt;

  /// No description provided for @lastSeenWhere.
  ///
  /// In en, this message translates to:
  /// **'Where was it last seen?'**
  String get lastSeenWhere;

  /// No description provided for @locationPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Others only see an area of about 300 m around it'**
  String get locationPrivacyNote;

  /// No description provided for @publishReport.
  ///
  /// In en, this message translates to:
  /// **'Publish report'**
  String get publishReport;

  /// No description provided for @pickLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the place'**
  String get pickLocationTitle;

  /// No description provided for @pickLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the map where the animal was.'**
  String get pickLocationHint;

  /// No description provided for @confirmLocation.
  ///
  /// In en, this message translates to:
  /// **'Use this place'**
  String get confirmLocation;

  /// No description provided for @markFound.
  ///
  /// In en, this message translates to:
  /// **'Mark as found'**
  String get markFound;

  /// No description provided for @closeReport.
  ///
  /// In en, this message translates to:
  /// **'Close report'**
  String get closeReport;

  /// No description provided for @reopenReport.
  ///
  /// In en, this message translates to:
  /// **'Reopen (still lost)'**
  String get reopenReport;

  /// No description provided for @deleteReportQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete this report and its photos?'**
  String get deleteReportQuestion;

  /// No description provided for @deleteSightingQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete this sighting and its photos?'**
  String get deleteSightingQuestion;

  /// No description provided for @lastSeenOn.
  ///
  /// In en, this message translates to:
  /// **'Last seen {date}'**
  String lastSeenOn(String date);

  /// No description provided for @seenOn.
  ///
  /// In en, this message translates to:
  /// **'Seen {date}'**
  String seenOn(String date);

  /// No description provided for @approximateArea.
  ///
  /// In en, this message translates to:
  /// **'Approximate area, to protect the owner\'s privacy.'**
  String get approximateArea;

  /// No description provided for @photoProcessing.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get photoProcessing;

  /// No description provided for @photoNoAnimal.
  ///
  /// In en, this message translates to:
  /// **'No animal found'**
  String get photoNoAnimal;

  /// No description provided for @photoNotMatched.
  ///
  /// In en, this message translates to:
  /// **'Not used for matching'**
  String get photoNotMatched;

  /// No description provided for @photoFailed.
  ///
  /// In en, this message translates to:
  /// **'Processing failed'**
  String get photoFailed;

  /// No description provided for @tabMatches.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get tabMatches;

  /// No description provided for @tabMyLostPets.
  ///
  /// In en, this message translates to:
  /// **'My lost pets'**
  String get tabMyLostPets;

  /// No description provided for @tabMySightings.
  ///
  /// In en, this message translates to:
  /// **'My sightings'**
  String get tabMySightings;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No possible matches yet. We check every new sighting nearby.'**
  String get noMatches;

  /// No description provided for @noLostReports.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t reported a lost pet.'**
  String get noLostReports;

  /// No description provided for @noSightings.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t posted any sightings.'**
  String get noSightings;

  /// No description provided for @possibleMatch.
  ///
  /// In en, this message translates to:
  /// **'Possible match'**
  String get possibleMatch;

  /// No description provided for @possibleMatchFor.
  ///
  /// In en, this message translates to:
  /// **'Could this be {name}?'**
  String possibleMatchFor(String name);

  /// No description provided for @similarity.
  ///
  /// In en, this message translates to:
  /// **'{percent}% similar'**
  String similarity(int percent);

  /// No description provided for @yourPhoto.
  ///
  /// In en, this message translates to:
  /// **'Your photo'**
  String get yourPhoto;

  /// No description provided for @sightingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Sighting'**
  String get sightingPhoto;

  /// No description provided for @matchExplanation.
  ///
  /// In en, this message translates to:
  /// **'Our model found these photos similar. Look closely at markings and features before contacting the finder.'**
  String get matchExplanation;

  /// No description provided for @matchNotFound.
  ///
  /// In en, this message translates to:
  /// **'This match no longer exists.'**
  String get matchNotFound;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'From gallery'**
  String get chooseFromGallery;

  /// No description provided for @timeNow.
  ///
  /// In en, this message translates to:
  /// **'Seen just now'**
  String get timeNow;

  /// No description provided for @timeFromPhoto.
  ///
  /// In en, this message translates to:
  /// **'Seen {date} (from the photo)'**
  String timeFromPhoto(String date);

  /// No description provided for @timeMissing.
  ///
  /// In en, this message translates to:
  /// **'When did you see it? Set the time'**
  String get timeMissing;

  /// No description provided for @locationFromPhoto.
  ///
  /// In en, this message translates to:
  /// **'Location from the photo'**
  String get locationFromPhoto;

  /// No description provided for @locationNeeded.
  ///
  /// In en, this message translates to:
  /// **'Where did you see it? Choose on the map'**
  String get locationNeeded;

  /// No description provided for @missingPets.
  ///
  /// In en, this message translates to:
  /// **'Missing pets'**
  String get missingPets;

  /// No description provided for @map.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// No description provided for @nearMe.
  ///
  /// In en, this message translates to:
  /// **'Near me'**
  String get nearMe;

  /// No description provided for @everywhere.
  ///
  /// In en, this message translates to:
  /// **'Everywhere'**
  String get everywhere;

  /// No description provided for @allSpecies.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allSpecies;

  /// No description provided for @noMissingPets.
  ///
  /// In en, this message translates to:
  /// **'No missing pets reported. Good news!'**
  String get noMissingPets;

  /// No description provided for @noMissingPetsNearby.
  ///
  /// In en, this message translates to:
  /// **'No missing pets near you. Try “Everywhere”.'**
  String get noMissingPetsNearby;

  /// No description provided for @kmAway.
  ///
  /// In en, this message translates to:
  /// **'{km} km away'**
  String kmAway(String km);

  /// No description provided for @locationOffForNearby.
  ///
  /// In en, this message translates to:
  /// **'Turn on location to see pets near you.'**
  String get locationOffForNearby;
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
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
