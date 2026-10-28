// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get tagline => 'Retrouver les animaux perdus, aider les animaux des rues';

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
  String get errorNetwork => 'Impossible de joindre le serveur. Vérifiez votre connexion.';

  @override
  String get errorRateLimited => 'Vous avez beaucoup publié récemment. Réessayez plus tard.';

  @override
  String get errorInvalidImage => 'Cette photo est illisible. Utilisez une image JPEG, PNG, WebP ou HEIC.';

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
    return 'Perdu : $name';
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
  String get newSighting => 'Nouveau signalement';

  @override
  String get photoHint => 'Approchez-vous et montrez la tête : cela nous aide à reconnaître l\'animal.';

  @override
  String get condition => 'État';

  @override
  String get isStray => 'C\'est un animal des rues';

  @override
  String get isStrayHelp => 'Vit dehors plutôt que perdu';

  @override
  String get noteOptional => 'Note (facultatif)';

  @override
  String get locating => 'Localisation en cours…';

  @override
  String get locationMissing => 'Pas encore de position : choisissez-la sur la carte';

  @override
  String locationFromGps(int meters) {
    return 'Votre position actuelle (±$meters m)';
  }

  @override
  String get locationPicked => 'Position choisie sur la carte';

  @override
  String get postSighting => 'Publier le signalement';

  @override
  String uploading(String progress) {
    return 'Envoi des photos $progress';
  }

  @override
  String get sightingThanks => 'Merci ! Nous le comparons aux animaux perdus à proximité.';

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
  String get lostPhotosHint => 'Ajoutez 1 à 5 photos nettes, idéalement de la tête sous différents angles.';

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
  String get locationPrivacyNote => 'Les autres ne voient qu\'une zone d\'environ 300 m autour';

  @override
  String get publishReport => 'Publier l\'avis';

  @override
  String get pickLocationTitle => 'Choisir le lieu';

  @override
  String get pickLocationHint => 'Touchez la carte à l\'endroit où se trouvait l\'animal.';

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
  String get deleteSightingQuestion => 'Supprimer ce signalement et ses photos ?';

  @override
  String lastSeenOn(String date) {
    return 'Vu pour la dernière fois le $date';
  }

  @override
  String seenOn(String date) {
    return 'Vu le $date';
  }

  @override
  String get approximateArea => 'Zone approximative, pour protéger la vie privée du propriétaire.';

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
  String get noMissingPetsNearby => 'Aucun animal perdu près de vous. Essayez « Partout ».';

  @override
  String kmAway(String km) {
    return 'à $km km';
  }

  @override
  String get locationOffForNearby => 'Activez la localisation pour voir les animaux près de vous.';
}
