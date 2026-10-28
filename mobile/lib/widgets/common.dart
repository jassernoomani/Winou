import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../l10n/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

String speciesLabel(AppLocalizations l10n, Species species) => switch (species) {
  Species.cat => l10n.speciesCat,
  Species.dog => l10n.speciesDog,
  Species.other => l10n.speciesOther,
};

String conditionLabel(AppLocalizations l10n, Condition condition) => switch (condition) {
  Condition.healthy => l10n.conditionHealthy,
  Condition.injured => l10n.conditionInjured,
  Condition.needsHelp => l10n.conditionNeedsHelp,
};

String statusLabel(AppLocalizations l10n, ReportStatus status) => switch (status) {
  ReportStatus.open => l10n.statusOpen,
  ReportStatus.found => l10n.statusFound,
  ReportStatus.closed => l10n.statusClosed,
};

String formatDateTime(BuildContext context, DateTime date) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toString()).add_Hm().format(date);

/// Opens a screen and completes when the user is back. A screen may return the next location
/// to show, e.g. a create form returns its new report, so callers can reload once at the end.
Future<void> pushChain(BuildContext context, String location) async {
  String? next = location;
  while (next != null && context.mounted) {
    next = await context.push<String>(next);
  }
}

/// A user-facing message for any error, translated where the API gives a known code.
String errorMessage(BuildContext context, Object error) {
  final l10n = context.l10n;
  if (error is ApiException) {
    return switch (error.code) {
      'network' => l10n.errorNetwork,
      'rate_limited' => l10n.errorRateLimited,
      'invalid_image' || 'unsupported_format' => l10n.errorInvalidImage,
      'file_too_large' || 'image_too_large' => l10n.errorImageTooLarge,
      'email_taken' => l10n.errorEmailTaken,
      _ => error.status == 401 ? l10n.errorWrongCredentials : error.message,
    };
  }
  return l10n.errorUnexpected;
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(context, error))));
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(errorMessage(context, error), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: Text(context.l10n.retry)),
          ],
        ),
      ),
    );
  }
}

class NetworkPhoto extends StatelessWidget {
  const NetworkPhoto(this.url, {super.key, this.fit = BoxFit.cover});

  final String? url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.pets, size: 32)),
    );
    if (url == null) return placeholder;
    return Image.network(url!, fit: fit, errorBuilder: (_, _, _) => placeholder);
  }
}

/// Swipeable photos of a report or sighting, with a badge on photos that are not usable for matching.
class PhotoGallery extends StatelessWidget {
  const PhotoGallery(this.photos, {super.key, this.showStatus = false});

  final List<Photo> photos;
  final bool showStatus; // owners see processing state

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: photos.isEmpty
          ? const NetworkPhoto(null)
          : PageView(
              children: [
                for (final (i, photo) in photos.indexed)
                  Stack(
                    fit: StackFit.expand,
                    children: [
                      NetworkPhoto(photo.url),
                      if (photos.length > 1) // shows there is more to swipe to
                        Positioned(
                          right: 8,
                          top: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              child: Text('${i + 1}/${photos.length}', style: const TextStyle(color: Colors.white)),
                            ),
                          ),
                        ),
                      if (showStatus && photo.status != 'READY')
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: Chip(
                            avatar: photo.isProcessing
                                ? const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.info_outline, size: 18),
                            label: Text(switch (photo.status) {
                              'NO_ANIMAL' => l10n.photoNoAnimal,
                              'SKIPPED' => l10n.photoNotMatched,
                              'FAILED' => l10n.photoFailed,
                              _ => l10n.photoProcessing,
                            }),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
    );
  }
}

/// Label + value row used on detail screens.
class InfoRow extends StatelessWidget {
  const InfoRow(this.icon, this.text, {super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
