// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get tagline =>
      'Retrouver les animaux perdus, aider les animaux des rues';

  @override
  String get email => 'E-mail';

  @override
  String get password => 'Mot de passe';

  @override
  String get displayName => 'Votre nom';

  @override
  String get signIn => 'Se connecter';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get noAccount => 'Pas encore de compte ? Créez-en un';

  @override
  String get haveAccount => 'Déjà un compte ? Connectez-vous';

  @override
  String get required => 'Obligatoire';

  @override
  String get invalidEmail => 'Entrez un e-mail valide';

  @override
  String get passwordTooShort => 'Au moins 8 caractères';

  @override
  String get errorNetwork =>
      'Impossible de joindre le serveur. Vérifiez votre connexion.';

  @override
  String get errorRateLimited =>
      'Vous avez beaucoup publié récemment. Réessayez plus tard.';

  @override
  String get errorInvalidImage =>
      'Cette photo est illisible. Utilisez une image JPEG, PNG, WebP ou HEIC.';

  @override
  String get errorImageTooLarge => 'Cette photo est trop grande.';

  @override
  String get errorEmailTaken => 'Cet e-mail est déjà utilisé.';

  @override
  String get errorWrongCredentials => 'E-mail ou mot de passe incorrect.';

  @override
  String get errorUnexpected => 'Une erreur est survenue.';

  @override
  String get retry => 'Réessayer';

  @override
  String get cancel => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get change => 'Modifier';

  @override
  String get choose => 'Choisir';

  @override
  String get apply => 'Appliquer';

  @override
  String get speciesCat => 'Chat';

  @override
  String get speciesDog => 'Chien';

  @override
  String get speciesOther => 'Autre';

  @override
  String get conditionHealthy => 'En bonne santé';

  @override
  String get conditionInjured => 'Blessé';

  @override
  String get conditionNeedsHelp => 'A besoin d\'aide';

  @override
  String get statusOpen => 'Toujours perdu';

  @override
  String get statusFound => 'Retrouvé';

  @override
  String get statusClosed => 'Clôturé';

  @override
  String get typeLost => 'Animaux perdus';

  @override
  String get typeSighting => 'Signalement';

  @override
  String get typeStray => 'Animal des rues';

  @override
  String get filters => 'Filtres';

  @override
  String get filterShow => 'Afficher';

  @override
  String get filterSpecies => 'Espèce';

  @override
  String get filterCondition => 'État (signalements)';

  @override
  String get filterPeriod => 'Période';

  @override
  String get periodAny => 'Toute période';

  @override
  String periodDays(int days) {
    return '$days jours';
  }

  @override
  String get myActivity => 'Mon activité';

  @override
  String get myLocation => 'Ma position';

  @override
  String get reportLostPet => 'Signaler un animal perdu';

  @override
  String get iSawAnAnimal => 'J\'ai vu un animal';

  @override
  String lostNamed(String name) {
    return '$name est perdu(e)';
  }

  @override
  String sightingOf(String species) {
    return '$species aperçu';
  }

  @override
  String strayOf(String species) {
    return '$species des rues';
  }

  @override
  String get photoHint =>
      'Approchez-vous et montrez la tête : cela nous aide à reconnaître l\'animal.';

  @override
  String get condition => 'État';

  @override
  String get isStray => 'C\'est un animal des rues';

  @override
  String get isStrayHelp => 'Il vit dehors et n\'a pas de propriétaire';

  @override
  String get noteOptional => 'Note (facultatif)';

  @override
  String get locating => 'Localisation en cours…';

  @override
  String get locationMissing =>
      'Pas encore de position : choisissez-la sur la carte';

  @override
  String locationFromGps(int meters) {
    return 'Votre position actuelle (±$meters m)';
  }

  @override
  String get locationPicked => 'Position choisie sur la carte';

  @override
  String get postSighting => 'Envoyer le signalement';

  @override
  String uploading(String progress) {
    return 'Envoi des photos $progress';
  }

  @override
  String get camera => 'Appareil photo';

  @override
  String get gallery => 'Galerie';

  @override
  String get noAnimalTitle => 'Aucun animal détecté';

  @override
  String get noAnimalBody =>
      'Nous n\'avons pas trouvé de chat ni de chien sur cette photo. Une photo rapprochée de la tête fonctionne mieux.';

  @override
  String get keepPhoto => 'La garder';

  @override
  String get retakePhoto => 'Reprendre';

  @override
  String get lostPhotosHint =>
      'Ajoutez 1 à 5 photos nettes, idéalement de la tête sous différents angles.';

  @override
  String get petName => 'Nom de l\'animal';

  @override
  String get descriptionOptional => 'Description (facultatif)';

  @override
  String get descriptionHint => 'Collier, signes distinctifs, caractère…';

  @override
  String get lastSeenAt => 'Vu pour la dernière fois';

  @override
  String get lastSeenWhere => 'Où a-t-il été vu pour la dernière fois ?';

  @override
  String get locationPrivacyNote =>
      'Les autres ne voient qu\'une zone d\'environ 300 m autour';

  @override
  String get publishReport => 'Publier l\'avis';

  @override
  String get pickLocationTitle => 'Choisir le lieu';

  @override
  String get pickLocationHint =>
      'Touchez la carte à l\'endroit où se trouvait l\'animal.';

  @override
  String get confirmLocation => 'Utiliser ce lieu';

  @override
  String get markFound => 'Marquer comme retrouvé';

  @override
  String get closeReport => 'Clôturer l\'avis';

  @override
  String get reopenReport => 'Rouvrir (toujours perdu)';

  @override
  String get deleteReportQuestion => 'Supprimer cet avis et ses photos ?';

  @override
  String get deleteSightingQuestion =>
      'Supprimer ce signalement et ses photos ?';

  @override
  String lastSeenOn(String date) {
    return 'Vu pour la dernière fois le $date';
  }

  @override
  String seenOn(String date) {
    return 'Vu le $date';
  }

  @override
  String get approximateArea =>
      'Zone approximative, pour protéger la vie privée du propriétaire.';

  @override
  String get photoProcessing => 'Analyse…';

  @override
  String get photoNoAnimal => 'Aucun animal détecté';

  @override
  String get photoNotMatched => 'Non utilisée pour la comparaison';

  @override
  String get photoFailed => 'Échec de l\'analyse';

  @override
  String get tabMatches => 'Correspondances';

  @override
  String get tabMyLostPets => 'Mes animaux perdus';

  @override
  String get tabMySightings => 'Mes signalements';

  @override
  String get noMatches =>
      'Aucune correspondance pour l\'instant. Nous vérifions chaque nouveau signalement à proximité.';

  @override
  String get noLostReports => 'Vous n\'avez signalé aucun animal perdu.';

  @override
  String get noSightings => 'Vous n\'avez publié aucun signalement.';

  @override
  String get possibleMatch => 'Correspondance possible';

  @override
  String possibleMatchFor(String name) {
    return 'Est-ce $name ?';
  }

  @override
  String similarity(int percent) {
    return '$percent % de similarité';
  }

  @override
  String get yourPhoto => 'Votre photo';

  @override
  String get sightingPhoto => 'Signalement';

  @override
  String get matchExplanation =>
      'Notre modèle trouve ces photos similaires. Vérifiez bien les signes distinctifs avant de contacter la personne.';

  @override
  String get matchNotFound => 'Cette correspondance n\'existe plus.';

  @override
  String get takePhoto => 'Prendre une photo';

  @override
  String get chooseFromGallery => 'Depuis la galerie';

  @override
  String get timeNow => 'Vu à l\'instant';

  @override
  String timeFromPhoto(String date) {
    return 'Vu le $date (d\'après la photo)';
  }

  @override
  String get timeMissing => 'Quand l\'avez-vous vu ? Indiquez l\'heure';

  @override
  String get locationFromPhoto => 'Position d\'après la photo';

  @override
  String get locationNeeded => 'Où l\'avez-vous vu ? Choisissez sur la carte';

  @override
  String get missingPets => 'Animaux perdus';

  @override
  String get map => 'Carte';

  @override
  String get nearMe => 'Près de moi';

  @override
  String get everywhere => 'Partout';

  @override
  String get allSpecies => 'Tous';

  @override
  String get noMissingPets => 'Aucun animal perdu signalé. Bonne nouvelle !';

  @override
  String get noMissingPetsNearby =>
      'Aucun animal perdu près de vous. Essayez « Partout ».';

  @override
  String kmAway(String km) {
    return 'à $km km';
  }

  @override
  String get locationOffForNearby =>
      'Activez la localisation pour voir les animaux près de vous.';

  @override
  String matchNotification(String name) {
    return 'Quelqu\'un a peut-être vu $name.';
  }

  @override
  String get view => 'Voir';

  @override
  String get thatsMyPet => 'C\'est mon animal';

  @override
  String get notMyPet => 'Ce n\'est pas lui';

  @override
  String get matchHidden => 'Masquée. Cette observation ne sera plus proposée.';

  @override
  String get undo => 'Annuler';

  @override
  String matchConfirmedInfo(String name) {
    return 'Vous avez reconnu $name. La personne qui l\'a vu a été prévenue.';
  }

  @override
  String get messageFinder => 'Écrire à la personne';

  @override
  String get openConversation => 'Ouvrir la conversation';

  @override
  String gotPetBack(String name) {
    return 'J\'ai retrouvé $name';
  }

  @override
  String gotPetBackQuestion(String name) {
    return '$name est rentré ? Le dossier sera fermé : plus de correspondances, et l\'annonce quitte la carte. Vous pourrez la rouvrir.';
  }

  @override
  String get closeCase => 'Fermer le dossier';

  @override
  String petBackHome(String name) {
    return '$name est rentré. Le dossier est fermé.';
  }

  @override
  String get matchStatusConfirmed => 'Confirmée';

  @override
  String get messages => 'Messages';

  @override
  String get noConversations =>
      'Aucun message. Quand vous écrivez à quelqu\'un qui a vu votre animal, ou qu\'un propriétaire reconnaît un animal que vous avez vu, la conversation apparaît ici.';

  @override
  String aboutPet(String name) {
    return 'À propos de $name';
  }

  @override
  String youSaid(String text) {
    return 'Vous : $text';
  }

  @override
  String get writeMessage => 'Écrire un message';

  @override
  String get send => 'Envoyer';

  @override
  String get noMessagesYet =>
      'Aucun message. Dites bonjour et expliquez comment vous pouvez aider.';

  @override
  String get chatPrivacy =>
      'Seul votre nom affiché est visible. Ne donnez pas votre adresse avant d\'être sûr.';

  @override
  String caseClosedChat(String name) {
    return '$name est rentré. Le dossier est fermé, mais vous pouvez encore écrire.';
  }

  @override
  String messageNotification(String name) {
    return 'Nouveau message de $name';
  }

  @override
  String confirmedNotification(String name) {
    return 'Le propriétaire de $name a reconnu l\'animal que vous avez vu.';
  }

  @override
  String foundNotification(String name) {
    return '$name est rentré. Merci pour votre aide !';
  }

  @override
  String get helpBringThemHome => 'Aidez-les à rentrer';

  @override
  String missingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count animaux sont perdus',
      one: '1 animal est perdu',
      zero: 'Aucun animal perdu ici',
    );
    return '$_temp0';
  }

  @override
  String get justNow => 'à l\'instant';

  @override
  String minutesAgo(int n) {
    return 'il y a $n min';
  }

  @override
  String hoursAgo(int n) {
    return 'il y a $n h';
  }

  @override
  String daysAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'il y a $n jours',
      one: 'hier',
    );
    return '$_temp0';
  }

  @override
  String seenAgo(String when) {
    return 'Vu $when';
  }

  @override
  String missingCountMore(int count) {
    return '$count+ animaux sont perdus';
  }

  @override
  String get possibleVisualMatch => 'Correspondance visuelle possible';

  @override
  String get notConfirmedIdentity =>
      'Une ressemblance, pas une identité confirmée.';

  @override
  String get addClearPhoto => 'Ajouter une photo nette';

  @override
  String get addClearPhotoHelp => 'Appareil photo ou galerie';

  @override
  String get emailHint => 'Votre e-mail';

  @override
  String get speciesTitle => 'Espèce';

  @override
  String get adjust => 'Ajuster';

  @override
  String get tapToAdjust => 'Touchez Ajuster pour le déplacer';

  @override
  String get retake => 'Reprendre';

  @override
  String get thanksTitle => 'Merci !';

  @override
  String get thanksBody =>
      'Votre signalement est sur la carte. S\'il ressemble à un animal perdu, nous prévenons le propriétaire tout de suite.';

  @override
  String get backToMissingPets => 'Retour aux animaux perdus';

  @override
  String get typeLostOne => 'Animal perdu';

  @override
  String get strayStatusTitle => 'Que devient-il ?';

  @override
  String get strayAround => 'Toujours là';

  @override
  String get strayHelped => 'Aidé';

  @override
  String get strayGone => 'Plus revu';

  @override
  String get strayAroundHelp =>
      'Vous l\'avez revu ? Touchez « Toujours là » : il reste sur la carte.';

  @override
  String get strayUpdated => 'Merci pour la mise à jour !';

  @override
  String helpedBy(String name) {
    return 'Aidé par $name';
  }

  @override
  String get injuredBanner =>
      'Cet animal est blessé. Si vous êtes à proximité, voyez si vous pouvez aider.';

  @override
  String get needsHelpBanner =>
      'Cet animal a besoin d\'aide. Si vous êtes à proximité, voyez si vous pouvez aider.';

  @override
  String get report => 'Signaler';

  @override
  String get reportWhy => 'Pourquoi le signalez-vous ?';

  @override
  String get reasonSpam => 'Spam ou publicité';

  @override
  String get reasonInappropriate => 'Inapproprié ou offensant';

  @override
  String get reasonFake => 'Faux ou trompeur';

  @override
  String get reasonDangerous => 'Dangereux ou arnaque';

  @override
  String get reasonOther => 'Autre chose';

  @override
  String get reportNoteHint => 'Quelque chose à ajouter ? (facultatif)';

  @override
  String get sendReport => 'Envoyer';

  @override
  String get reportThanks => 'Merci. Nous allons vérifier.';

  @override
  String get reportHiddenNow =>
      'Merci. C\'est masqué le temps que nous vérifions.';

  @override
  String get hiddenNotice =>
      'Des personnes l\'ont signalé : les autres ne le voient plus jusqu\'à notre vérification.';

  @override
  String get messageHidden => 'Masqué après un signalement';

  @override
  String get becomeAssociation => 'Devenir une association';

  @override
  String get associationIntro =>
      'Refuges, sauveteurs et vétérinaires reçoivent un badge vérifié et des alertes pour les animaux blessés près d\'eux. Chaque demande est vérifiée à la main.';

  @override
  String get organisation => 'Nom de l\'organisation';

  @override
  String get city => 'Ville';

  @override
  String get contact => 'Téléphone, site web ou page sociale';

  @override
  String get contactHelp =>
      'Pour vérifier qui vous êtes. Jamais montré aux autres.';

  @override
  String get associationNote => 'Autre chose ? (facultatif)';

  @override
  String get alertArea => 'Où devons-nous vous alerter ?';

  @override
  String get alertAreaHelp => 'Animaux blessés à moins de 10 km de ce lieu';

  @override
  String get sendRequest => 'Envoyer la demande';

  @override
  String requestPending(String name) {
    return 'Votre demande pour $name est en cours de vérification. Nous vous préviendrons.';
  }

  @override
  String requestApproved(String name) {
    return '$name est une association vérifiée. Vous serez prévenu des animaux blessés près de vous.';
  }

  @override
  String get requestRejected =>
      'Nous n\'avons pas pu vérifier votre dernière demande. Vous pouvez en envoyer une nouvelle avec plus de détails.';

  @override
  String get verifiedAssociation => 'Association vérifiée';

  @override
  String get admin => 'Admin';

  @override
  String get adminRequests => 'Demandes';

  @override
  String get adminHidden => 'Masqué';

  @override
  String get noPendingRequests => 'Aucune demande en attente.';

  @override
  String get noHiddenContent => 'Rien n\'est masqué.';

  @override
  String get approve => 'Approuver';

  @override
  String get reject => 'Refuser';

  @override
  String get restore => 'Rétablir';

  @override
  String reportsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count signalements',
      one: '1 signalement',
    );
    return '$_temp0';
  }

  @override
  String messageFrom(String name) {
    return 'Message de $name';
  }

  @override
  String get deleteForGood => 'Le supprimer définitivement ?';

  @override
  String get more => 'Plus';

  @override
  String get helpNotification => 'Un animal a besoin d\'aide près de vous';

  @override
  String get associationNotification =>
      'Votre demande d\'association a reçu une réponse';

  @override
  String get serverAddress => 'Adresse du serveur';

  @override
  String get serverHelp =>
      'L\'ordinateur qui fait tourner Winou. Sur le partage de connexion du téléphone ou le même Wi-Fi : son adresse, par ex. 192.168.43.12. Avec un câble USB : 127.0.0.1.';

  @override
  String get testConnection => 'Tester';

  @override
  String get serverOk => 'Connecté';

  @override
  String get serverUnreachable =>
      'Injoignable. Même réseau ? Le pare-feu de l\'ordinateur est-il ouvert ?';

  @override
  String get save => 'Enregistrer';
}
