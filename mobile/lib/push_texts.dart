// Written by tool/push_texts.py from the Android push texts: run it again after changing them.
import 'l10n/app_localizations.dart';

/// The text of a push key (as the backend sends it, e.g. "match_title"), filled with [args], in the
/// app's language. null for a key this version of the app doesn't know.
String? pushText(AppLocalizations l10n, String? key, List<String> args) {
  String arg(int i) => i < args.length ? args[i] : '';
  return switch (key) {
    'match_title' => l10n.pushMatchTitle,
    'match_body' => l10n.pushMatchBody(arg(0)),
    'confirmed_title' => l10n.pushConfirmedTitle,
    'confirmed_body' => l10n.pushConfirmedBody(arg(0)),
    'found_title' => l10n.pushFoundTitle(arg(0)),
    'found_body' => l10n.pushFoundBody(arg(0)),
    'message_title' => l10n.pushMessageTitle(arg(0), arg(1)),
    'help_title' => l10n.pushHelpTitle,
    'help_injured_body' => l10n.pushHelpInjuredBody,
    'help_needs_help_body' => l10n.pushHelpNeedsHelpBody,
    'association_approved_title' => l10n.pushAssociationApprovedTitle,
    'association_approved_body' => l10n.pushAssociationApprovedBody(arg(0)),
    'association_rejected_title' => l10n.pushAssociationRejectedTitle,
    'association_rejected_body' => l10n.pushAssociationRejectedBody(arg(0)),
    'nearby_lost_title' => l10n.pushNearbyLostTitle,
    'nearby_lost_cat_body' => l10n.pushNearbyLostCatBody(arg(0)),
    'nearby_lost_dog_body' => l10n.pushNearbyLostDogBody(arg(0)),
    'nearby_lost_pet_body' => l10n.pushNearbyLostPetBody(arg(0)),
    'admin_hidden_title' => l10n.pushAdminHiddenTitle,
    'admin_hidden_lost_body' => l10n.pushAdminHiddenLostBody,
    'admin_hidden_sighting_body' => l10n.pushAdminHiddenSightingBody,
    'admin_hidden_message_body' => l10n.pushAdminHiddenMessageBody,
    'admin_request_title' => l10n.pushAdminRequestTitle,
    'admin_request_body' => l10n.pushAdminRequestBody(arg(0)),
    _ => null,
  };
}
