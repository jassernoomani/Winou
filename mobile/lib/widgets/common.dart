import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';

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
/// [extra] goes to the first screen (e.g. the report already loaded, so it shows at once).
Future<void> pushChain(BuildContext context, String location, {Object? extra}) async {
  String? next = await context.push<String>(location, extra: extra);
  while (next != null) {
    if (!context.mounted) return;
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
      child: EmptyState(
        icon: LucideIcons.cloudOff,
        text: errorMessage(context, error),
        action: OutlinedButton(onPressed: onRetry, child: Text(context.l10n.retry)),
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
    final colors = Theme.of(context).colorScheme;
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primaryContainer.withValues(alpha: 0.6), colors.surfaceContainerHighest],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(child: Icon(LucideIcons.pawPrint, size: 32, color: colors.primary.withValues(alpha: 0.5))),
    );
    if (url == null) return placeholder;
    return Image.network(
      url!,
      fit: fit,
      errorBuilder: (_, _, _) => placeholder,
      // Fades in over the placeholder once loaded (cached images show at once)
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) => wasSynchronouslyLoaded
          ? child
          : Stack(
              fit: StackFit.expand,
              children: [
                placeholder,
                AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                  child: child,
                ),
              ],
            ),
    );
  }
}

/// Swipeable photos of a report or sighting, with a badge on photos that are not usable for matching.
/// The first photo flies in from the list when [heroTag] matches the list's thumbnail.
class PhotoGallery extends StatefulWidget {
  const PhotoGallery(this.photos, {super.key, this.showStatus = false, this.heroTag});

  final List<Photo> photos;
  final bool showStatus; // owners see processing state
  final String? heroTag;

  @override
  State<PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final photos = widget.photos;
    Widget hero(int i, Widget child) =>
        i == 0 && widget.heroTag != null ? Hero(tag: widget.heroTag!, child: child) : child;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: photos.isEmpty
          ? hero(0, const NetworkPhoto(null))
          : Stack(
              fit: StackFit.expand,
              children: [
                PageView(
                  onPageChanged: (page) => setState(() => _page = page),
                  children: [
                    for (final (i, photo) in photos.indexed)
                      Stack(
                        fit: StackFit.expand,
                        children: [
                          hero(i, NetworkPhoto(photo.url)),
                          if (widget.showStatus && photo.status != 'READY')
                            Positioned(
                              left: 12,
                              top: 12,
                              child: Chip(
                                avatar: photo.isProcessing
                                    ? const SizedBox.square(
                                        dimension: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(LucideIcons.info, size: 18),
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
                if (photos.length > 1) // shows there is more to swipe to
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 6,
                      children: [
                        for (var i = 0; i < photos.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                            width: i == _page ? 20 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: i == _page ? 1 : 0.6),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)],
                            ),
                          ),
                      ],
                    ),
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

/// The app icon, rounded, for the splash and sign-in screens.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * 0.28),
      boxShadow: [
        BoxShadow(color: Brand.indigo.withValues(alpha: 0.35), blurRadius: size * 0.3, offset: Offset(0, size * 0.08)),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Image.asset('assets/icon/icon.png', width: size, height: size),
    ),
  );
}

extension TokensContext on BuildContext {
  WinouTokens get tokens => Theme.of(this).extension<WinouTokens>()!;
}

/// A status label, 32 high: tonal background, darker foreground, and always an icon so colour
/// never carries the meaning alone.
class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, required this.tone, this.icon});

  final String text;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = context.tokens.tone(tone);
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          if (icon != null) Icon(icon, size: 16, color: foreground),
          Text(
            text,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: foreground),
          ),
        ],
      ),
    );
  }
}

Tone reportStatusTone(ReportStatus status) => switch (status) {
  ReportStatus.open => Tone.lost,
  ReportStatus.found => Tone.found,
  ReportStatus.closed => Tone.neutral,
};

IconData reportStatusIcon(ReportStatus status) => switch (status) {
  ReportStatus.open => LucideIcons.search,
  ReportStatus.found => LucideIcons.house,
  ReportStatus.closed => LucideIcons.archive,
};

/// A tinted note: a tip (info), "you recognised her" (found), a warning.
class Note extends StatelessWidget {
  const Note(this.text, {super.key, required this.tone, required this.icon});

  final String text;
  final Tone tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = context.tokens.tone(tone);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Row(
        spacing: 10,
        children: [
          Icon(icon, size: 20, color: foreground),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, height: 1.4, color: foreground)),
          ),
        ],
      ),
    );
  }
}

/// A friendly empty or "nothing here yet" state.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action; // e.g. "Try again"

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(shape: BoxShape.circle, color: tokens.tonal),
            child: Icon(icon, size: 44, color: tokens.accent),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: tokens.muted),
          ),
          if (action case final action?) ...[const SizedBox(height: 20), action],
        ],
      ),
    );
  }
}

/// The two main actions (lost pet, I saw an animal): a solid 52-high pill on a deep gradient,
/// white label. The gradients are dark enough for white text everywhere (WCAG AA).
class GradientFab extends StatelessWidget {
  const GradientFab({
    super.key,
    required this.gradient,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final LinearGradient gradient;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    decoration: BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(999),
      boxShadow: [
        BoxShadow(color: gradient.colors.last.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6)),
      ],
    ),
    child: Material(
      type: MaterialType.transparency,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The "winou" wordmark: lowercase, Nunito Black.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 22, this.color});

  final double size;
  final Color? color; // default: the accessible blue

  @override
  Widget build(BuildContext context) => Text(
    'winou',
    style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, height: 1, color: color ?? context.tokens.accent),
  );
}

/// A form field's label, above the field (the guide keeps labels out of the box so long French
/// labels can wrap).
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

/// "just now", "5 min ago", "3 h ago", "yesterday", "4 days ago", then the date.
String timeAgo(AppLocalizations l10n, DateTime date) {
  final elapsed = DateTime.now().difference(date);
  if (elapsed.inMinutes < 1) return l10n.justNow;
  if (elapsed.inHours < 1) return l10n.minutesAgo(elapsed.inMinutes);
  if (elapsed.inDays < 1) return l10n.hoursAgo(elapsed.inHours);
  if (elapsed.inDays < 14) return l10n.daysAgo(elapsed.inDays);
  return DateFormat.yMMMd(l10n.localeName).format(date);
}
