import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
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
    Locale('ar'),
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
  /// **'Try again'**
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
  /// **'{name} is lost'**
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
  /// **'This is a street animal'**
  String get isStray;

  /// No description provided for @isStrayHelp.
  ///
  /// In en, this message translates to:
  /// **'It lives outside and has no owner'**
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
  /// **'Send sighting'**
  String get postSighting;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading photos {progress}'**
  String uploading(String progress);

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

  /// No description provided for @matchNotification.
  ///
  /// In en, this message translates to:
  /// **'Someone may have seen {name}.'**
  String matchNotification(String name);

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @thatsMyPet.
  ///
  /// In en, this message translates to:
  /// **'That\'s my pet'**
  String get thatsMyPet;

  /// No description provided for @notMyPet.
  ///
  /// In en, this message translates to:
  /// **'Not my pet'**
  String get notMyPet;

  /// No description provided for @matchHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden. This sighting won\'t be suggested again.'**
  String get matchHidden;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @matchConfirmedInfo.
  ///
  /// In en, this message translates to:
  /// **'You recognised {name}. The person who saw it has been told.'**
  String matchConfirmedInfo(String name);

  /// No description provided for @messageFinder.
  ///
  /// In en, this message translates to:
  /// **'Message the finder'**
  String get messageFinder;

  /// No description provided for @openConversation.
  ///
  /// In en, this message translates to:
  /// **'Open the conversation'**
  String get openConversation;

  /// No description provided for @gotPetBack.
  ///
  /// In en, this message translates to:
  /// **'I got {name} back'**
  String gotPetBack(String name);

  /// No description provided for @gotPetBackQuestion.
  ///
  /// In en, this message translates to:
  /// **'Is {name} back home? This closes the case: no more matches, and the report leaves the map. You can reopen it later.'**
  String gotPetBackQuestion(String name);

  /// No description provided for @closeCase.
  ///
  /// In en, this message translates to:
  /// **'Close the case'**
  String get closeCase;

  /// No description provided for @petBackHome.
  ///
  /// In en, this message translates to:
  /// **'{name} is back home. The case is closed.'**
  String petBackHome(String name);

  /// No description provided for @matchStatusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get matchStatusConfirmed;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @noConversations.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. When you write to someone who saw your pet, or an owner recognises an animal you saw, the conversation appears here.'**
  String get noConversations;

  /// No description provided for @aboutPet.
  ///
  /// In en, this message translates to:
  /// **'About {name}'**
  String aboutPet(String name);

  /// No description provided for @youSaid.
  ///
  /// In en, this message translates to:
  /// **'You: {text}'**
  String youSaid(String text);

  /// No description provided for @writeMessage.
  ///
  /// In en, this message translates to:
  /// **'Write a message'**
  String get writeMessage;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Say hello and explain how you can help.'**
  String get noMessagesYet;

  /// No description provided for @chatPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Only your display name is shown. Never share your address before you\'re sure.'**
  String get chatPrivacy;

  /// No description provided for @caseClosedChat.
  ///
  /// In en, this message translates to:
  /// **'{name} is back home. This case is closed, but you can still write.'**
  String caseClosedChat(String name);

  /// No description provided for @messageNotification.
  ///
  /// In en, this message translates to:
  /// **'New message from {name}'**
  String messageNotification(String name);

  /// No description provided for @confirmedNotification.
  ///
  /// In en, this message translates to:
  /// **'The owner of {name} recognised the animal you saw.'**
  String confirmedNotification(String name);

  /// No description provided for @foundNotification.
  ///
  /// In en, this message translates to:
  /// **'{name} is back home. Thank you for helping!'**
  String foundNotification(String name);

  /// No description provided for @helpBringThemHome.
  ///
  /// In en, this message translates to:
  /// **'Help bring them home'**
  String get helpBringThemHome;

  /// No description provided for @missingCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No pet missing here} =1{1 pet is missing} other{{count} pets are missing}}'**
  String missingCount(int count);

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} min ago'**
  String minutesAgo(int n);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} h ago'**
  String hoursAgo(int n);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{yesterday} other{{n} days ago}}'**
  String daysAgo(int n);

  /// No description provided for @seenAgo.
  ///
  /// In en, this message translates to:
  /// **'Seen {when}'**
  String seenAgo(String when);

  /// No description provided for @missingCountMore.
  ///
  /// In en, this message translates to:
  /// **'{count}+ pets are missing'**
  String missingCountMore(int count);

  /// No description provided for @possibleVisualMatch.
  ///
  /// In en, this message translates to:
  /// **'Possible visual match'**
  String get possibleVisualMatch;

  /// No description provided for @notConfirmedIdentity.
  ///
  /// In en, this message translates to:
  /// **'A resemblance, not a confirmed identity.'**
  String get notConfirmedIdentity;

  /// No description provided for @addClearPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a clear photo'**
  String get addClearPhoto;

  /// No description provided for @addClearPhotoHelp.
  ///
  /// In en, this message translates to:
  /// **'Camera or gallery'**
  String get addClearPhotoHelp;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'Your email'**
  String get emailHint;

  /// No description provided for @speciesTitle.
  ///
  /// In en, this message translates to:
  /// **'Species'**
  String get speciesTitle;

  /// No description provided for @adjust.
  ///
  /// In en, this message translates to:
  /// **'Adjust'**
  String get adjust;

  /// No description provided for @tapToAdjust.
  ///
  /// In en, this message translates to:
  /// **'Tap Adjust to move it'**
  String get tapToAdjust;

  /// No description provided for @retake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get retake;

  /// No description provided for @thanksTitle.
  ///
  /// In en, this message translates to:
  /// **'Thank you!'**
  String get thanksTitle;

  /// No description provided for @thanksBody.
  ///
  /// In en, this message translates to:
  /// **'Your sighting is on the map. If it looks like a lost pet, we\'ll tell the owner right away.'**
  String get thanksBody;

  /// No description provided for @backToMissingPets.
  ///
  /// In en, this message translates to:
  /// **'Back to missing pets'**
  String get backToMissingPets;

  /// No description provided for @typeLostOne.
  ///
  /// In en, this message translates to:
  /// **'Lost pet'**
  String get typeLostOne;

  /// No description provided for @strayStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'What became of it?'**
  String get strayStatusTitle;

  /// No description provided for @strayAround.
  ///
  /// In en, this message translates to:
  /// **'Still around'**
  String get strayAround;

  /// No description provided for @strayHelped.
  ///
  /// In en, this message translates to:
  /// **'Helped'**
  String get strayHelped;

  /// No description provided for @strayGone.
  ///
  /// In en, this message translates to:
  /// **'Not seen anymore'**
  String get strayGone;

  /// No description provided for @strayAroundHelp.
  ///
  /// In en, this message translates to:
  /// **'Seen it again? Tap “Still around”: it keeps the animal on the map.'**
  String get strayAroundHelp;

  /// No description provided for @strayUpdated.
  ///
  /// In en, this message translates to:
  /// **'Thanks for the update!'**
  String get strayUpdated;

  /// No description provided for @helpedBy.
  ///
  /// In en, this message translates to:
  /// **'Helped by {name}'**
  String helpedBy(String name);

  /// No description provided for @injuredBanner.
  ///
  /// In en, this message translates to:
  /// **'This animal is injured. If you\'re nearby, see if you can help.'**
  String get injuredBanner;

  /// No description provided for @needsHelpBanner.
  ///
  /// In en, this message translates to:
  /// **'This animal needs help. If you\'re nearby, see if you can help.'**
  String get needsHelpBanner;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @reportWhy.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting it?'**
  String get reportWhy;

  /// No description provided for @reasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam or advertising'**
  String get reasonSpam;

  /// No description provided for @reasonInappropriate.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate or offensive'**
  String get reasonInappropriate;

  /// No description provided for @reasonFake.
  ///
  /// In en, this message translates to:
  /// **'Fake or misleading'**
  String get reasonFake;

  /// No description provided for @reasonDangerous.
  ///
  /// In en, this message translates to:
  /// **'Dangerous or a scam'**
  String get reasonDangerous;

  /// No description provided for @reasonOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get reasonOther;

  /// No description provided for @reportNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Anything to add? (optional)'**
  String get reportNoteHint;

  /// No description provided for @sendReport.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get sendReport;

  /// No description provided for @reportThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks. We\'ll look at it.'**
  String get reportThanks;

  /// No description provided for @reportHiddenNow.
  ///
  /// In en, this message translates to:
  /// **'Thanks. It\'s hidden while we look at it.'**
  String get reportHiddenNow;

  /// No description provided for @hiddenNotice.
  ///
  /// In en, this message translates to:
  /// **'People reported this, so others can\'t see it until we review it.'**
  String get hiddenNotice;

  /// No description provided for @messageHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden after a report'**
  String get messageHidden;

  /// No description provided for @becomeAssociation.
  ///
  /// In en, this message translates to:
  /// **'Become an association'**
  String get becomeAssociation;

  /// No description provided for @associationIntro.
  ///
  /// In en, this message translates to:
  /// **'Shelters, rescuers and vets get a verified badge and alerts about injured animals near them. We check every request by hand.'**
  String get associationIntro;

  /// No description provided for @organisation.
  ///
  /// In en, this message translates to:
  /// **'Organisation name'**
  String get organisation;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Phone, website or social page'**
  String get contact;

  /// No description provided for @contactHelp.
  ///
  /// In en, this message translates to:
  /// **'So we can check who you are. Never shown to others.'**
  String get contactHelp;

  /// No description provided for @associationNote.
  ///
  /// In en, this message translates to:
  /// **'Anything else? (optional)'**
  String get associationNote;

  /// No description provided for @alertArea.
  ///
  /// In en, this message translates to:
  /// **'Where should we alert you?'**
  String get alertArea;

  /// No description provided for @alertAreaHelp.
  ///
  /// In en, this message translates to:
  /// **'Injured animals within 10 km of this place'**
  String get alertAreaHelp;

  /// No description provided for @sendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get sendRequest;

  /// No description provided for @requestPending.
  ///
  /// In en, this message translates to:
  /// **'Your request for {name} is being reviewed. We\'ll notify you.'**
  String requestPending(String name);

  /// No description provided for @requestApproved.
  ///
  /// In en, this message translates to:
  /// **'{name} is a verified association. You\'ll hear about injured animals near you.'**
  String requestApproved(String name);

  /// No description provided for @requestRejected.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t verify your last request. You can send a new one with more details.'**
  String get requestRejected;

  /// No description provided for @verifiedAssociation.
  ///
  /// In en, this message translates to:
  /// **'Verified association'**
  String get verifiedAssociation;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @adminRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get adminRequests;

  /// No description provided for @adminHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get adminHidden;

  /// No description provided for @noPendingRequests.
  ///
  /// In en, this message translates to:
  /// **'No requests waiting.'**
  String get noPendingRequests;

  /// No description provided for @noHiddenContent.
  ///
  /// In en, this message translates to:
  /// **'Nothing is hidden.'**
  String get noHiddenContent;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @reportsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 report} other{{count} reports}}'**
  String reportsCount(int count);

  /// No description provided for @messageFrom.
  ///
  /// In en, this message translates to:
  /// **'Message from {name}'**
  String messageFrom(String name);

  /// No description provided for @deleteForGood.
  ///
  /// In en, this message translates to:
  /// **'Delete it for good?'**
  String get deleteForGood;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @helpNotification.
  ///
  /// In en, this message translates to:
  /// **'An animal needs help near you'**
  String get helpNotification;

  /// No description provided for @associationNotification.
  ///
  /// In en, this message translates to:
  /// **'Your association request was answered'**
  String get associationNotification;

  /// No description provided for @serverAddress.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get serverAddress;

  /// No description provided for @serverHelp.
  ///
  /// In en, this message translates to:
  /// **'The laptop running Winou. On your phone\'s hotspot or the same Wi-Fi: its address, e.g. 192.168.43.12. With a USB cable: 127.0.0.1.'**
  String get serverHelp;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get testConnection;

  /// No description provided for @serverOk.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get serverOk;

  /// No description provided for @serverUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach it. Same network? Is the laptop\'s firewall open?'**
  String get serverUnreachable;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @errorBanned.
  ///
  /// In en, this message translates to:
  /// **'This account is suspended.'**
  String get errorBanned;

  /// No description provided for @suspendedTitle.
  ///
  /// In en, this message translates to:
  /// **'Account suspended'**
  String get suspendedTitle;

  /// No description provided for @suspendedUntil.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String suspendedUntil(String date);

  /// No description provided for @suspendedForGood.
  ///
  /// In en, this message translates to:
  /// **'For good'**
  String get suspendedForGood;

  /// No description provided for @suspendedReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String suspendedReason(String reason);

  /// No description provided for @suspendedHelp.
  ///
  /// In en, this message translates to:
  /// **'Your lost pets and sightings are hidden from others meanwhile. If you think this is a mistake, contact the Winou team.'**
  String get suspendedHelp;

  /// No description provided for @checkAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get checkAgain;

  /// No description provided for @stillSuspended.
  ///
  /// In en, this message translates to:
  /// **'Still suspended.'**
  String get stillSuspended;

  /// No description provided for @adminUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get adminUsers;

  /// No description provided for @searchUsers.
  ///
  /// In en, this message translates to:
  /// **'Name or email'**
  String get searchUsers;

  /// No description provided for @bannedOnly.
  ///
  /// In en, this message translates to:
  /// **'Suspended only'**
  String get bannedOnly;

  /// No description provided for @noUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No one found.'**
  String get noUsersFound;

  /// No description provided for @noBannedUsers.
  ///
  /// In en, this message translates to:
  /// **'No one is suspended.'**
  String get noBannedUsers;

  /// No description provided for @banned.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get banned;

  /// No description provided for @association.
  ///
  /// In en, this message translates to:
  /// **'Association'**
  String get association;

  /// No description provided for @joinedOn.
  ///
  /// In en, this message translates to:
  /// **'Joined {date}'**
  String joinedOn(String date);

  /// No description provided for @statLostPets.
  ///
  /// In en, this message translates to:
  /// **'Lost pets'**
  String get statLostPets;

  /// No description provided for @statSightings.
  ///
  /// In en, this message translates to:
  /// **'Sightings'**
  String get statSightings;

  /// No description provided for @statReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get statReports;

  /// No description provided for @suspend.
  ///
  /// In en, this message translates to:
  /// **'Suspend'**
  String get suspend;

  /// No description provided for @suspendWho.
  ///
  /// In en, this message translates to:
  /// **'Suspend {name}?'**
  String suspendWho(String name);

  /// No description provided for @suspendExplain.
  ///
  /// In en, this message translates to:
  /// **'They can\'t sign in or post, and what they posted is hidden from others until the suspension ends. They see the reason.'**
  String get suspendExplain;

  /// No description provided for @daysCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String daysCount(int count);

  /// No description provided for @forGood.
  ///
  /// In en, this message translates to:
  /// **'For good'**
  String get forGood;

  /// No description provided for @suspendReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Reason, shown to them (optional)'**
  String get suspendReasonHint;

  /// No description provided for @liftSuspension.
  ///
  /// In en, this message translates to:
  /// **'Lift suspension'**
  String get liftSuspension;

  /// No description provided for @liftSuspensionOf.
  ///
  /// In en, this message translates to:
  /// **'Let {name} use Winou again?'**
  String liftSuspensionOf(String name);

  /// No description provided for @revokeAssociation.
  ///
  /// In en, this message translates to:
  /// **'Remove association status'**
  String get revokeAssociation;

  /// No description provided for @revokeAssociationQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove the association status of {name}? No more badge or injured-animal alerts. They can apply again.'**
  String revokeAssociationQuestion(String name);

  /// No description provided for @revoke.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get revoke;

  /// No description provided for @userLostPets.
  ///
  /// In en, this message translates to:
  /// **'Lost pets ({count})'**
  String userLostPets(int count);

  /// No description provided for @userSightings.
  ///
  /// In en, this message translates to:
  /// **'Sightings ({count})'**
  String userSightings(int count);

  /// No description provided for @hiddenLabel.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get hiddenLabel;

  /// No description provided for @adminHistory.
  ///
  /// In en, this message translates to:
  /// **'Admin history'**
  String get adminHistory;

  /// No description provided for @noAdminHistory.
  ///
  /// In en, this message translates to:
  /// **'No admin actions yet.'**
  String get noAdminHistory;

  /// No description provided for @deletedAdmin.
  ///
  /// In en, this message translates to:
  /// **'A former admin'**
  String get deletedAdmin;

  /// No description provided for @actionApprovedAssociation.
  ///
  /// In en, this message translates to:
  /// **'Association approved'**
  String get actionApprovedAssociation;

  /// No description provided for @actionRejectedAssociation.
  ///
  /// In en, this message translates to:
  /// **'Association request rejected'**
  String get actionRejectedAssociation;

  /// No description provided for @actionRevokedAssociation.
  ///
  /// In en, this message translates to:
  /// **'Association status removed'**
  String get actionRevokedAssociation;

  /// No description provided for @actionRestored.
  ///
  /// In en, this message translates to:
  /// **'{what} restored'**
  String actionRestored(String what);

  /// No description provided for @actionDeleted.
  ///
  /// In en, this message translates to:
  /// **'{what} deleted'**
  String actionDeleted(String what);

  /// No description provided for @actionBanned.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get actionBanned;

  /// No description provided for @actionUnbanned.
  ///
  /// In en, this message translates to:
  /// **'Suspension lifted'**
  String get actionUnbanned;

  /// No description provided for @targetLostReport.
  ///
  /// In en, this message translates to:
  /// **'Lost pet report'**
  String get targetLostReport;

  /// No description provided for @targetSighting.
  ///
  /// In en, this message translates to:
  /// **'Sighting'**
  String get targetSighting;

  /// No description provided for @targetMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get targetMessage;

  /// No description provided for @adminReported.
  ///
  /// In en, this message translates to:
  /// **'Reported'**
  String get adminReported;

  /// No description provided for @noReportedContent.
  ///
  /// In en, this message translates to:
  /// **'No reports waiting.'**
  String get noReportedContent;

  /// No description provided for @dismissReports.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismissReports;

  /// No description provided for @hideNow.
  ///
  /// In en, this message translates to:
  /// **'Hide now'**
  String get hideNow;

  /// No description provided for @byAuthor.
  ///
  /// In en, this message translates to:
  /// **'By {name}'**
  String byAuthor(String name);

  /// No description provided for @viewAuthor.
  ///
  /// In en, this message translates to:
  /// **'Who posted it'**
  String get viewAuthor;

  /// No description provided for @adminDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete (admin)'**
  String get adminDelete;

  /// No description provided for @hiddenFromOthers.
  ///
  /// In en, this message translates to:
  /// **'Hidden from everyone but its author.'**
  String get hiddenFromOthers;

  /// No description provided for @shownAgain.
  ///
  /// In en, this message translates to:
  /// **'Shown again.'**
  String get shownAgain;

  /// No description provided for @actionHidden.
  ///
  /// In en, this message translates to:
  /// **'{what} hidden'**
  String actionHidden(String what);

  /// No description provided for @actionDismissed.
  ///
  /// In en, this message translates to:
  /// **'Reports dismissed · {what}'**
  String actionDismissed(String what);

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @adminDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get adminDashboard;

  /// No description provided for @adminActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get adminActivity;

  /// No description provided for @aboutUser.
  ///
  /// In en, this message translates to:
  /// **'About {name}'**
  String aboutUser(String name);

  /// No description provided for @statUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get statUsers;

  /// No description provided for @statNewThisWeek.
  ///
  /// In en, this message translates to:
  /// **'+{count} this week'**
  String statNewThisWeek(int count);

  /// No description provided for @statOpenLost.
  ///
  /// In en, this message translates to:
  /// **'Still lost'**
  String get statOpenLost;

  /// No description provided for @statOfTotal.
  ///
  /// In en, this message translates to:
  /// **'of {count} reported'**
  String statOfTotal(int count);

  /// No description provided for @statReunited.
  ///
  /// In en, this message translates to:
  /// **'Back home'**
  String get statReunited;

  /// No description provided for @statReunionRate.
  ///
  /// In en, this message translates to:
  /// **'{rate} of lost pets'**
  String statReunionRate(String rate);

  /// No description provided for @statMatchesConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Matches confirmed'**
  String get statMatchesConfirmed;

  /// No description provided for @statStraysOnMap.
  ///
  /// In en, this message translates to:
  /// **'Strays on the map'**
  String get statStraysOnMap;

  /// No description provided for @statAssociations.
  ///
  /// In en, this message translates to:
  /// **'Associations'**
  String get statAssociations;

  /// No description provided for @statStraysHelped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{helped 1 stray} other{helped {count} strays}}'**
  String statStraysHelped(int count);

  /// No description provided for @lastWeeks.
  ///
  /// In en, this message translates to:
  /// **'Last {count} weeks'**
  String lastWeeks(int count);

  /// No description provided for @weekOf.
  ///
  /// In en, this message translates to:
  /// **'Week of {date}'**
  String weekOf(String date);

  /// No description provided for @seriesLost.
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get seriesLost;

  /// No description provided for @seriesSightings.
  ///
  /// In en, this message translates to:
  /// **'Sightings'**
  String get seriesSightings;

  /// No description provided for @seriesReunited.
  ///
  /// In en, this message translates to:
  /// **'Back home'**
  String get seriesReunited;

  /// No description provided for @showTable.
  ///
  /// In en, this message translates to:
  /// **'Show as a table'**
  String get showTable;

  /// No description provided for @showChart.
  ///
  /// In en, this message translates to:
  /// **'Show as a chart'**
  String get showChart;

  /// No description provided for @weekColumn.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get weekColumn;

  /// No description provided for @weeklyChartLabel.
  ///
  /// In en, this message translates to:
  /// **'Lost reports, sightings and pets back home per week. Touch and drag to see a week\'s numbers.'**
  String get weeklyChartLabel;

  /// No description provided for @errorTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a few minutes and try again.'**
  String get errorTooManyAttempts;

  /// No description provided for @errorWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'The password is wrong.'**
  String get errorWrongPassword;

  /// No description provided for @errorSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again.'**
  String get errorSessionExpired;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @nameHelp.
  ///
  /// In en, this message translates to:
  /// **'Shown to people you talk to'**
  String get nameHelp;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @changeName.
  ///
  /// In en, this message translates to:
  /// **'Change your name'**
  String get changeName;

  /// No description provided for @nameChanged.
  ///
  /// In en, this message translates to:
  /// **'Name changed.'**
  String get nameChanged;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @changePasswordHelp.
  ///
  /// In en, this message translates to:
  /// **'Your other phones will be signed out.'**
  String get changePasswordHelp;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed. Your other phones were signed out.'**
  String get passwordChanged;

  /// No description provided for @signOutEverywhere.
  ///
  /// In en, this message translates to:
  /// **'Sign out of all phones'**
  String get signOutEverywhere;

  /// No description provided for @signOutEverywhereHelp.
  ///
  /// In en, this message translates to:
  /// **'If you lost a phone, or used someone else\'s'**
  String get signOutEverywhereHelp;

  /// No description provided for @signOutEverywhereQuestion.
  ///
  /// In en, this message translates to:
  /// **'Sign out of Winou on every phone, this one included?'**
  String get signOutEverywhereQuestion;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountHelp.
  ///
  /// In en, this message translates to:
  /// **'Your account and everything you posted'**
  String get deleteAccountHelp;

  /// No description provided for @deleteAccountQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountQuestion;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'Your lost pet reports, sightings, photos and conversations are deleted for good. This can\'t be undone.'**
  String get deleteAccountWarning;

  /// No description provided for @deleteAccountForGood.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteAccountForGood;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your account was deleted.'**
  String get accountDeleted;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @signedInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Signs in with Google'**
  String get signedInWithGoogle;

  /// No description provided for @setPassword.
  ///
  /// In en, this message translates to:
  /// **'Set a password'**
  String get setPassword;

  /// No description provided for @setPasswordHelp.
  ///
  /// In en, this message translates to:
  /// **'To sign in with your email too, not only with Google'**
  String get setPasswordHelp;

  /// No description provided for @errorGoogleDisabled.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in isn\'t available on this server.'**
  String get errorGoogleDisabled;

  /// No description provided for @errorGoogleNoEmail.
  ///
  /// In en, this message translates to:
  /// **'This Google account has no verified email.'**
  String get errorGoogleNoEmail;

  /// No description provided for @errorGoogleFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in didn\'t work. Try again.'**
  String get errorGoogleFailed;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordHelp.
  ///
  /// In en, this message translates to:
  /// **'Enter your email: we\'ll send you a 6-digit code.'**
  String get forgotPasswordHelp;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send the code'**
  String get sendCode;

  /// No description provided for @sendNewCode.
  ///
  /// In en, this message translates to:
  /// **'Send a new code'**
  String get sendNewCode;

  /// No description provided for @codeSent.
  ///
  /// In en, this message translates to:
  /// **'Code sent. Check your inbox, and your spam.'**
  String get codeSent;

  /// No description provided for @enterCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get enterCodeTitle;

  /// No description provided for @enterCodeHelp.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code we sent to {email}. It works for 15 minutes.'**
  String enterCodeHelp(String email);

  /// No description provided for @code.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get code;

  /// No description provided for @codeSixDigits.
  ///
  /// In en, this message translates to:
  /// **'6 digits'**
  String get codeSixDigits;

  /// No description provided for @setPasswordAndSignIn.
  ///
  /// In en, this message translates to:
  /// **'Save and sign in'**
  String get setPasswordAndSignIn;

  /// No description provided for @confirmEmail.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email'**
  String get confirmEmail;

  /// No description provided for @confirmEmailHelp.
  ///
  /// In en, this message translates to:
  /// **'So you can get a new password if you forget it'**
  String get confirmEmailHelp;

  /// No description provided for @emailConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Email confirmed.'**
  String get emailConfirmed;

  /// No description provided for @emailConfirmedPill.
  ///
  /// In en, this message translates to:
  /// **'Email confirmed'**
  String get emailConfirmedPill;

  /// No description provided for @emailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Email not confirmed'**
  String get emailNotConfirmed;

  /// No description provided for @errorWrongCode.
  ///
  /// In en, this message translates to:
  /// **'This code isn\'t right.'**
  String get errorWrongCode;

  /// No description provided for @errorCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'This code expired or was tried too many times. Ask for a new one.'**
  String get errorCodeExpired;

  /// No description provided for @errorTooManyCodes.
  ///
  /// In en, this message translates to:
  /// **'We already sent several codes. Check your spam, or try again in an hour.'**
  String get errorTooManyCodes;

  /// No description provided for @sharePosterButton.
  ///
  /// In en, this message translates to:
  /// **'Share a poster'**
  String get sharePosterButton;

  /// No description provided for @helpByShaRing.
  ///
  /// In en, this message translates to:
  /// **'Help by sharing'**
  String get helpByShaRing;

  /// No description provided for @sawThisPet.
  ///
  /// In en, this message translates to:
  /// **'I saw {name}'**
  String sawThisPet(String name);

  /// No description provided for @shareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share {name}'**
  String shareTitle(String name);

  /// No description provided for @shareHelp.
  ///
  /// In en, this message translates to:
  /// **'Post it in neighbourhood groups, send it on WhatsApp, or print it. The QR code opens the pet\'s page.'**
  String get shareHelp;

  /// No description provided for @sharePoster.
  ///
  /// In en, this message translates to:
  /// **'Share the poster'**
  String get sharePoster;

  /// No description provided for @shareLink.
  ///
  /// In en, this message translates to:
  /// **'Share link'**
  String get shareLink;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied.'**
  String get linkCopied;

  /// No description provided for @shareLostText.
  ///
  /// In en, this message translates to:
  /// **'Have you seen {name}? Lost {species}: see the photos and tell the owner on Winou. {link}'**
  String shareLostText(String name, String species, String link);

  /// No description provided for @posterLostCat.
  ///
  /// In en, this message translates to:
  /// **'LOST CAT'**
  String get posterLostCat;

  /// No description provided for @posterLostDog.
  ///
  /// In en, this message translates to:
  /// **'LOST DOG'**
  String get posterLostDog;

  /// No description provided for @posterLostPet.
  ///
  /// In en, this message translates to:
  /// **'LOST PET'**
  String get posterLostPet;

  /// No description provided for @posterSeenIt.
  ///
  /// In en, this message translates to:
  /// **'Seen this pet?'**
  String get posterSeenIt;

  /// No description provided for @posterScan.
  ///
  /// In en, this message translates to:
  /// **'Scan the code to see the photos and tell the owner, for free.'**
  String get posterScan;

  /// No description provided for @sightingAboutPet.
  ///
  /// In en, this message translates to:
  /// **'About {name}: the owner hears about it at once.'**
  String sightingAboutPet(String name);

  /// No description provided for @finderMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Someone says they saw {name}'**
  String finderMatchTitle(String name);

  /// No description provided for @finderMatchBody.
  ///
  /// In en, this message translates to:
  /// **'They recognised your pet from your report. Compare the photos, then write to them.'**
  String get finderMatchBody;

  /// No description provided for @seenByFinder.
  ///
  /// In en, this message translates to:
  /// **'Seen by someone'**
  String get seenByFinder;

  /// No description provided for @finderMatchTip.
  ///
  /// In en, this message translates to:
  /// **'Look closely at markings and features before writing to them: people can be mistaken.'**
  String get finderMatchTip;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabMe.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get tabMe;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'The phone\'s language'**
  String get languageSystem;

  /// No description provided for @thisPhone.
  ///
  /// In en, this message translates to:
  /// **'This phone'**
  String get thisPhone;

  /// No description provided for @permissions.
  ///
  /// In en, this message translates to:
  /// **'Notifications and location'**
  String get permissions;

  /// No description provided for @permissionsHelp.
  ///
  /// In en, this message translates to:
  /// **'Allow or block them in Android\'s settings'**
  String get permissionsHelp;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About Winou'**
  String get about;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @welcomeLostTitle.
  ///
  /// In en, this message translates to:
  /// **'Find a lost pet'**
  String get welcomeLostTitle;

  /// No description provided for @welcomeLostBody.
  ///
  /// In en, this message translates to:
  /// **'Report your pet with a few photos. Winou compares them with every animal seen nearby and tells you when one looks like yours.'**
  String get welcomeLostBody;

  /// No description provided for @welcomeSawTitle.
  ///
  /// In en, this message translates to:
  /// **'Saw an animal?'**
  String get welcomeSawTitle;

  /// No description provided for @welcomeSawBody.
  ///
  /// In en, this message translates to:
  /// **'Take a photo of a loose cat or dog. If someone is looking for it, they hear about it at once, and you can talk without sharing your number.'**
  String get welcomeSawBody;

  /// No description provided for @welcomeStraysTitle.
  ///
  /// In en, this message translates to:
  /// **'Help street animals'**
  String get welcomeStraysTitle;

  /// No description provided for @welcomeStraysBody.
  ///
  /// In en, this message translates to:
  /// **'Put strays on the map, say when one is hurt, and associations nearby are alerted.'**
  String get welcomeStraysBody;

  /// No description provided for @welcomePermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Two things that help'**
  String get welcomePermissionsTitle;

  /// No description provided for @welcomePermissionsBody.
  ///
  /// In en, this message translates to:
  /// **'Winou works without them, but works better with them.'**
  String get welcomePermissionsBody;

  /// No description provided for @permissionNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get permissionNotificationsTitle;

  /// No description provided for @permissionNotificationsBody.
  ///
  /// In en, this message translates to:
  /// **'Hear at once when someone may have seen your pet, or writes to you.'**
  String get permissionNotificationsBody;

  /// No description provided for @permissionLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get permissionLocationTitle;

  /// No description provided for @permissionLocationBody.
  ///
  /// In en, this message translates to:
  /// **'Show lost pets near you, and place your sightings. Never shared: other people only see an approximate area of a lost pet.'**
  String get permissionLocationBody;

  /// No description provided for @permissionsLater.
  ///
  /// In en, this message translates to:
  /// **'You can change this later in Settings.'**
  String get permissionsLater;

  /// No description provided for @allow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get allow;

  /// No description provided for @allowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get allowed;

  /// No description provided for @notAllowed.
  ///
  /// In en, this message translates to:
  /// **'Not allowed'**
  String get notAllowed;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get offlineBanner;

  /// No description provided for @serverDownBanner.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach Winou right now'**
  String get serverDownBanner;

  /// No description provided for @photosUploading.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Sending 1 photo…} other{Sending {count} photos…}}'**
  String photosUploading(int count);

  /// No description provided for @photosWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count} waiting'**
  String photosWaiting(int count);

  /// No description provided for @photosQueued.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo will be sent when the connection is back.} other{{count} photos will be sent when the connection is back.}}'**
  String photosQueued(int count);

  /// No description provided for @reunionTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome home, {name}!'**
  String reunionTitle(String name);

  /// No description provided for @reunionBody.
  ///
  /// In en, this message translates to:
  /// **'Thank you for not giving up. Everyone who helped has been told the good news.'**
  String get reunionBody;

  /// No description provided for @reunionShareText.
  ///
  /// In en, this message translates to:
  /// **'Good news: {name} is back home! Thank you to everyone who shared and looked. Found with Winou.'**
  String reunionShareText(String name, String species);

  /// No description provided for @shareGoodNews.
  ///
  /// In en, this message translates to:
  /// **'Share the good news'**
  String get shareGoodNews;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @viewCards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get viewCards;

  /// No description provided for @viewList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get viewList;

  /// No description provided for @viewGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get viewGrid;

  /// No description provided for @alertsNearMe.
  ///
  /// In en, this message translates to:
  /// **'Alerts near me'**
  String get alertsNearMe;

  /// No description provided for @alertsIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose a place and how far around it. We\'ll tell you when a pet goes missing there, or an animal needs help.'**
  String get alertsIntro;

  /// No description provided for @changePlace.
  ///
  /// In en, this message translates to:
  /// **'Change the place'**
  String get changePlace;

  /// No description provided for @alertRadius.
  ///
  /// In en, this message translates to:
  /// **'Around it'**
  String get alertRadius;

  /// No description provided for @alertLostPets.
  ///
  /// In en, this message translates to:
  /// **'Lost pets'**
  String get alertLostPets;

  /// No description provided for @alertLostPetsHelp.
  ///
  /// In en, this message translates to:
  /// **'A pet goes missing in this area'**
  String get alertLostPetsHelp;

  /// No description provided for @alertAnimalsInNeed.
  ///
  /// In en, this message translates to:
  /// **'Animals in need'**
  String get alertAnimalsInNeed;

  /// No description provided for @alertAnimalsInNeedHelp.
  ///
  /// In en, this message translates to:
  /// **'Someone reports an injured animal, or one in need of help'**
  String get alertAnimalsInNeedHelp;

  /// No description provided for @turnOnAlerts.
  ///
  /// In en, this message translates to:
  /// **'Turn on alerts'**
  String get turnOnAlerts;

  /// No description provided for @saveAlerts.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveAlerts;

  /// No description provided for @turnOffAlerts.
  ///
  /// In en, this message translates to:
  /// **'Turn off alerts'**
  String get turnOffAlerts;

  /// No description provided for @alertsSaved.
  ///
  /// In en, this message translates to:
  /// **'Alerts saved. We\'ll tell you what happens nearby.'**
  String get alertsSaved;

  /// No description provided for @alertsOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get alertsOff;

  /// No description provided for @lostNearbyNotification.
  ///
  /// In en, this message translates to:
  /// **'{name} went missing near you.'**
  String lostNearbyNotification(String name);

  /// No description provided for @kmRadius.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String kmRadius(int km);
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
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
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
