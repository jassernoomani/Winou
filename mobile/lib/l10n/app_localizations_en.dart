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

  @override
  String get strayStatusTitle => 'What became of it?';

  @override
  String get strayAround => 'Still around';

  @override
  String get strayHelped => 'Helped';

  @override
  String get strayGone => 'Not seen anymore';

  @override
  String get strayAroundHelp =>
      'Seen it again? Tap “Still around”: it keeps the animal on the map.';

  @override
  String get strayUpdated => 'Thanks for the update!';

  @override
  String helpedBy(String name) {
    return 'Helped by $name';
  }

  @override
  String get injuredBanner =>
      'This animal is injured. If you\'re nearby, see if you can help.';

  @override
  String get needsHelpBanner =>
      'This animal needs help. If you\'re nearby, see if you can help.';

  @override
  String get report => 'Report';

  @override
  String get reportWhy => 'Why are you reporting it?';

  @override
  String get reasonSpam => 'Spam or advertising';

  @override
  String get reasonInappropriate => 'Inappropriate or offensive';

  @override
  String get reasonFake => 'Fake or misleading';

  @override
  String get reasonDangerous => 'Dangerous or a scam';

  @override
  String get reasonOther => 'Something else';

  @override
  String get reportNoteHint => 'Anything to add? (optional)';

  @override
  String get sendReport => 'Send report';

  @override
  String get reportThanks => 'Thanks. We\'ll look at it.';

  @override
  String get reportHiddenNow => 'Thanks. It\'s hidden while we look at it.';

  @override
  String get hiddenNotice =>
      'People reported this, so others can\'t see it until we review it.';

  @override
  String get messageHidden => 'Hidden after a report';

  @override
  String get becomeAssociation => 'Become an association';

  @override
  String get associationIntro =>
      'Shelters, rescuers and vets get a verified badge and alerts about injured animals near them. We check every request by hand.';

  @override
  String get organisation => 'Organisation name';

  @override
  String get city => 'City';

  @override
  String get contact => 'Phone, website or social page';

  @override
  String get contactHelp =>
      'So we can check who you are. Never shown to others.';

  @override
  String get associationNote => 'Anything else? (optional)';

  @override
  String get alertArea => 'Where should we alert you?';

  @override
  String get alertAreaHelp => 'Injured animals within 10 km of this place';

  @override
  String get sendRequest => 'Send request';

  @override
  String requestPending(String name) {
    return 'Your request for $name is being reviewed. We\'ll notify you.';
  }

  @override
  String requestApproved(String name) {
    return '$name is a verified association. You\'ll hear about injured animals near you.';
  }

  @override
  String get requestRejected =>
      'We couldn\'t verify your last request. You can send a new one with more details.';

  @override
  String get verifiedAssociation => 'Verified association';

  @override
  String get admin => 'Admin';

  @override
  String get adminRequests => 'Requests';

  @override
  String get adminHidden => 'Hidden';

  @override
  String get noPendingRequests => 'No requests waiting.';

  @override
  String get noHiddenContent => 'Nothing is hidden.';

  @override
  String get approve => 'Approve';

  @override
  String get reject => 'Reject';

  @override
  String get restore => 'Restore';

  @override
  String reportsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reports',
      one: '1 report',
    );
    return '$_temp0';
  }

  @override
  String messageFrom(String name) {
    return 'Message from $name';
  }

  @override
  String get deleteForGood => 'Delete it for good?';

  @override
  String get more => 'More';

  @override
  String get helpNotification => 'An animal needs help near you';

  @override
  String get associationNotification => 'Your association request was answered';

  @override
  String get serverAddress => 'Server address';

  @override
  String get serverHelp =>
      'The laptop running Winou. On your phone\'s hotspot or the same Wi-Fi: its address, e.g. 192.168.43.12. With a USB cable: 127.0.0.1.';

  @override
  String get testConnection => 'Test';

  @override
  String get serverOk => 'Connected';

  @override
  String get serverUnreachable =>
      'Can\'t reach it. Same network? Is the laptop\'s firewall open?';

  @override
  String get save => 'Save';

  @override
  String get errorBanned => 'This account is suspended.';

  @override
  String get suspendedTitle => 'Account suspended';

  @override
  String suspendedUntil(String date) {
    return 'Until $date';
  }

  @override
  String get suspendedForGood => 'For good';

  @override
  String suspendedReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get suspendedHelp =>
      'Your lost pets and sightings are hidden from others meanwhile. If you think this is a mistake, contact the Winou team.';

  @override
  String get checkAgain => 'Check again';

  @override
  String get stillSuspended => 'Still suspended.';

  @override
  String get adminUsers => 'Users';

  @override
  String get searchUsers => 'Name or email';

  @override
  String get bannedOnly => 'Suspended only';

  @override
  String get noUsersFound => 'No one found.';

  @override
  String get noBannedUsers => 'No one is suspended.';

  @override
  String get banned => 'Suspended';

  @override
  String get association => 'Association';

  @override
  String joinedOn(String date) {
    return 'Joined $date';
  }

  @override
  String get statLostPets => 'Lost pets';

  @override
  String get statSightings => 'Sightings';

  @override
  String get statReports => 'Reports';

  @override
  String get suspend => 'Suspend';

  @override
  String suspendWho(String name) {
    return 'Suspend $name?';
  }

  @override
  String get suspendExplain =>
      'They can\'t sign in or post, and what they posted is hidden from others until the suspension ends. They see the reason.';

  @override
  String daysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get forGood => 'For good';

  @override
  String get suspendReasonHint => 'Reason, shown to them (optional)';

  @override
  String get liftSuspension => 'Lift suspension';

  @override
  String liftSuspensionOf(String name) {
    return 'Let $name use Winou again?';
  }

  @override
  String get revokeAssociation => 'Remove association status';

  @override
  String revokeAssociationQuestion(String name) {
    return 'Remove the association status of $name? No more badge or injured-animal alerts. They can apply again.';
  }

  @override
  String get revoke => 'Remove';

  @override
  String userLostPets(int count) {
    return 'Lost pets ($count)';
  }

  @override
  String userSightings(int count) {
    return 'Sightings ($count)';
  }

  @override
  String get hiddenLabel => 'Hidden';

  @override
  String get adminHistory => 'Admin history';

  @override
  String get noAdminHistory => 'No admin actions yet.';

  @override
  String get deletedAdmin => 'A former admin';

  @override
  String get actionApprovedAssociation => 'Association approved';

  @override
  String get actionRejectedAssociation => 'Association request rejected';

  @override
  String get actionRevokedAssociation => 'Association status removed';

  @override
  String actionRestored(String what) {
    return '$what restored';
  }

  @override
  String actionDeleted(String what) {
    return '$what deleted';
  }

  @override
  String get actionBanned => 'Suspended';

  @override
  String get actionUnbanned => 'Suspension lifted';

  @override
  String get targetLostReport => 'Lost pet report';

  @override
  String get targetSighting => 'Sighting';

  @override
  String get targetMessage => 'Message';

  @override
  String get adminReported => 'Reported';

  @override
  String get noReportedContent => 'No reports waiting.';

  @override
  String get dismissReports => 'Dismiss';

  @override
  String get hideNow => 'Hide now';

  @override
  String byAuthor(String name) {
    return 'By $name';
  }

  @override
  String get viewAuthor => 'Who posted it';

  @override
  String get adminDelete => 'Delete (admin)';

  @override
  String get hiddenFromOthers => 'Hidden from everyone but its author.';

  @override
  String get shownAgain => 'Shown again.';

  @override
  String actionHidden(String what) {
    return '$what hidden';
  }

  @override
  String actionDismissed(String what) {
    return 'Reports dismissed · $what';
  }

  @override
  String get close => 'Close';

  @override
  String get adminDashboard => 'Dashboard';

  @override
  String get adminActivity => 'Activity';

  @override
  String aboutUser(String name) {
    return 'About $name';
  }

  @override
  String get statUsers => 'Users';

  @override
  String statNewThisWeek(int count) {
    return '+$count this week';
  }

  @override
  String get statOpenLost => 'Still lost';

  @override
  String statOfTotal(int count) {
    return 'of $count reported';
  }

  @override
  String get statReunited => 'Back home';

  @override
  String statReunionRate(String rate) {
    return '$rate of lost pets';
  }

  @override
  String get statMatchesConfirmed => 'Matches confirmed';

  @override
  String get statStraysOnMap => 'Strays on the map';

  @override
  String get statAssociations => 'Associations';

  @override
  String statStraysHelped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'helped $count strays',
      one: 'helped 1 stray',
    );
    return '$_temp0';
  }

  @override
  String lastWeeks(int count) {
    return 'Last $count weeks';
  }

  @override
  String weekOf(String date) {
    return 'Week of $date';
  }

  @override
  String get seriesLost => 'Lost';

  @override
  String get seriesSightings => 'Sightings';

  @override
  String get seriesReunited => 'Back home';

  @override
  String get showTable => 'Show as a table';

  @override
  String get showChart => 'Show as a chart';

  @override
  String get weekColumn => 'Week';

  @override
  String get weeklyChartLabel =>
      'Lost reports, sightings and pets back home per week. Touch and drag to see a week\'s numbers.';

  @override
  String get errorTooManyAttempts =>
      'Too many attempts. Wait a few minutes and try again.';

  @override
  String get errorWrongPassword => 'The password is wrong.';

  @override
  String get errorSessionExpired => 'Please sign in again.';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get nameHelp => 'Shown to people you talk to';

  @override
  String get account => 'Account';

  @override
  String get changeName => 'Change your name';

  @override
  String get nameChanged => 'Name changed.';

  @override
  String get changePassword => 'Change password';

  @override
  String get changePasswordHelp => 'Your other phones will be signed out.';

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String get passwordChanged =>
      'Password changed. Your other phones were signed out.';

  @override
  String get signOutEverywhere => 'Sign out of all phones';

  @override
  String get signOutEverywhereHelp =>
      'If you lost a phone, or used someone else\'s';

  @override
  String get signOutEverywhereQuestion =>
      'Sign out of Winou on every phone, this one included?';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountHelp => 'Your account and everything you posted';

  @override
  String get deleteAccountQuestion => 'Delete your account?';

  @override
  String get deleteAccountWarning =>
      'Your lost pet reports, sightings, photos and conversations are deleted for good. This can\'t be undone.';

  @override
  String get deleteAccountForGood => 'Delete my account';

  @override
  String get accountDeleted => 'Your account was deleted.';

  @override
  String get or => 'or';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get signedInWithGoogle => 'Signs in with Google';

  @override
  String get setPassword => 'Set a password';

  @override
  String get setPasswordHelp =>
      'To sign in with your email too, not only with Google';

  @override
  String get errorGoogleDisabled =>
      'Google sign-in isn\'t available on this server.';

  @override
  String get errorGoogleNoEmail => 'This Google account has no verified email.';

  @override
  String get errorGoogleFailed => 'Google sign-in didn\'t work. Try again.';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get forgotPasswordTitle => 'Choose a new password';

  @override
  String get forgotPasswordHelp =>
      'Enter your email: we\'ll send you a 6-digit code.';

  @override
  String get sendCode => 'Send the code';

  @override
  String get sendNewCode => 'Send a new code';

  @override
  String get codeSent => 'Code sent. Check your inbox, and your spam.';

  @override
  String get enterCodeTitle => 'Check your email';

  @override
  String enterCodeHelp(String email) {
    return 'Enter the 6-digit code we sent to $email. It works for 15 minutes.';
  }

  @override
  String get code => 'Code';

  @override
  String get codeSixDigits => '6 digits';

  @override
  String get setPasswordAndSignIn => 'Save and sign in';

  @override
  String get confirmEmail => 'Confirm your email';

  @override
  String get confirmEmailHelp =>
      'So you can get a new password if you forget it';

  @override
  String get emailConfirmed => 'Email confirmed.';

  @override
  String get emailConfirmedPill => 'Email confirmed';

  @override
  String get emailNotConfirmed => 'Email not confirmed';

  @override
  String get errorWrongCode => 'This code isn\'t right.';

  @override
  String get errorCodeExpired =>
      'This code expired or was tried too many times. Ask for a new one.';

  @override
  String get errorTooManyCodes =>
      'We already sent several codes. Check your spam, or try again in an hour.';

  @override
  String get sharePosterButton => 'Share a poster';

  @override
  String get helpByShaRing => 'Help by sharing';

  @override
  String sawThisPet(String name) {
    return 'I saw $name';
  }

  @override
  String shareTitle(String name) {
    return 'Share $name';
  }

  @override
  String get shareHelp =>
      'Post it in neighbourhood groups, send it on WhatsApp, or print it. The QR code opens the pet\'s page.';

  @override
  String get sharePoster => 'Share the poster';

  @override
  String get shareLink => 'Share link';

  @override
  String get copyLink => 'Copy link';

  @override
  String get linkCopied => 'Link copied.';

  @override
  String shareLostText(String name, String species, String link) {
    return 'Have you seen $name? Lost $species: see the photos and tell the owner on Winou. $link';
  }

  @override
  String get posterLostCat => 'LOST CAT';

  @override
  String get posterLostDog => 'LOST DOG';

  @override
  String get posterLostPet => 'LOST PET';

  @override
  String get posterSeenIt => 'Seen this pet?';

  @override
  String get posterScan =>
      'Scan the code to see the photos and tell the owner, for free.';

  @override
  String sightingAboutPet(String name) {
    return 'About $name: the owner hears about it at once.';
  }

  @override
  String finderMatchTitle(String name) {
    return 'Someone says they saw $name';
  }

  @override
  String get finderMatchBody =>
      'They recognised your pet from your report. Compare the photos, then write to them.';

  @override
  String get seenByFinder => 'Seen by someone';

  @override
  String get finderMatchTip =>
      'Look closely at markings and features before writing to them: people can be mistaken.';

  @override
  String get tabHome => 'Home';

  @override
  String get tabMe => 'Me';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeSystem => 'Auto';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'The phone\'s language';

  @override
  String get thisPhone => 'This phone';

  @override
  String get permissions => 'Notifications and location';

  @override
  String get permissionsHelp => 'Allow or block them in Android\'s settings';

  @override
  String get about => 'About Winou';

  @override
  String get skip => 'Skip';

  @override
  String get next => 'Next';

  @override
  String get getStarted => 'Get started';

  @override
  String get welcomeLostTitle => 'Find a lost pet';

  @override
  String get welcomeLostBody =>
      'Report your pet with a few photos. Winou compares them with every animal seen nearby and tells you when one looks like yours.';

  @override
  String get welcomeSawTitle => 'Saw an animal?';

  @override
  String get welcomeSawBody =>
      'Take a photo of a loose cat or dog. If someone is looking for it, they hear about it at once, and you can talk without sharing your number.';

  @override
  String get welcomeStraysTitle => 'Help street animals';

  @override
  String get welcomeStraysBody =>
      'Put strays on the map, say when one is hurt, and associations nearby are alerted.';

  @override
  String get welcomePermissionsTitle => 'Two things that help';

  @override
  String get welcomePermissionsBody =>
      'Winou works without them, but works better with them.';

  @override
  String get permissionNotificationsTitle => 'Notifications';

  @override
  String get permissionNotificationsBody =>
      'Hear at once when someone may have seen your pet, or writes to you.';

  @override
  String get permissionLocationTitle => 'Location';

  @override
  String get permissionLocationBody =>
      'Show lost pets near you, and place your sightings. Never shared: other people only see an approximate area of a lost pet.';

  @override
  String get permissionsLater => 'You can change this later in Settings.';

  @override
  String get allow => 'Allow';

  @override
  String get allowed => 'Allowed';

  @override
  String get notAllowed => 'Not allowed';

  @override
  String get offlineBanner => 'No internet connection';

  @override
  String get serverDownBanner => 'Can\'t reach Winou right now';

  @override
  String photosUploading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sending $count photos…',
      one: 'Sending 1 photo…',
    );
    return '$_temp0';
  }

  @override
  String photosWaiting(int count) {
    return '$count waiting';
  }

  @override
  String photosQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos will be sent when the connection is back.',
      one: '1 photo will be sent when the connection is back.',
    );
    return '$_temp0';
  }

  @override
  String reunionTitle(String name) {
    return 'Welcome home, $name!';
  }

  @override
  String get reunionBody =>
      'Thank you for not giving up. Everyone who helped has been told the good news.';

  @override
  String reunionShareText(String name, String species) {
    return 'Good news: $name is back home! Thank you to everyone who shared and looked. Found with Winou.';
  }

  @override
  String get shareGoodNews => 'Share the good news';

  @override
  String get done => 'Done';

  @override
  String get viewCards => 'Cards';

  @override
  String get viewList => 'List';

  @override
  String get viewGrid => 'Grid';

  @override
  String get alertsNearMe => 'Alerts near me';

  @override
  String get alertsIntro =>
      'Choose a place and how far around it. We\'ll tell you when a pet goes missing there, or an animal needs help.';

  @override
  String get changePlace => 'Change the place';

  @override
  String get alertRadius => 'Around it';

  @override
  String get alertLostPets => 'Lost pets';

  @override
  String get alertLostPetsHelp => 'A pet goes missing in this area';

  @override
  String get alertAnimalsInNeed => 'Animals in need';

  @override
  String get alertAnimalsInNeedHelp =>
      'Someone reports an injured animal, or one in need of help';

  @override
  String get turnOnAlerts => 'Turn on alerts';

  @override
  String get saveAlerts => 'Save';

  @override
  String get turnOffAlerts => 'Turn off alerts';

  @override
  String get alertsSaved =>
      'Alerts saved. We\'ll tell you what happens nearby.';

  @override
  String get alertsOff => 'Off';

  @override
  String lostNearbyNotification(String name) {
    return '$name went missing near you.';
  }

  @override
  String kmRadius(int km) {
    return '$km km';
  }
}
