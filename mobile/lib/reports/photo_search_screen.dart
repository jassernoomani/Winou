import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../auth/auth_controller.dart';
import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';
import '../widgets/location.dart';
import '../widgets/photo_upload.dart';

/// Where the search is centred, and why: shown under the photo.
enum _Place { phone, photo, picked }

/// "Is this someone's pet?": a finder photographs an animal and sees the open lost reports nearby
/// that look like it, without posting anything. From here they open a report, or post a sighting
/// with the same photo.
class PhotoSearchScreen extends ConsumerStatefulWidget {
  const PhotoSearchScreen({super.key});

  @override
  ConsumerState<PhotoSearchScreen> createState() => _PhotoSearchScreenState();
}

class _PhotoSearchScreenState extends ConsumerState<PhotoSearchScreen> {
  PickedPhoto? _photo;
  LatLng? _at;
  _Place? _place;
  Species? _species; // chosen by the user after a first result; else detected
  PhotoSearch? _result;
  Object? _error;
  bool _busy = false;
  bool _needsPlace = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _choosePhoto());
  }

  Future<void> _choosePhoto() async {
    final picked = await addPhotos(context, 1);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _photo = picked.first;
      _species = null;
      _result = null;
      _error = null;
    });
    await _locate();
    await _search();
  }

  void _setPlace(LatLng at, _Place place) {
    _at = at;
    _place = place;
    _needsPlace = false;
  }

  /// A gallery photo's own position first (it may have been taken elsewhere), else the phone's.
  Future<void> _locate() async {
    if (_photo?.location case final fromPhoto?) {
      setState(() => _setPlace(fromPhoto, _Place.photo));
      return;
    }
    if (_place == _Place.picked) return; // keep the place the user chose
    setState(() => _busy = true);
    final position = await currentPosition();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (position != null) {
        _setPlace(toLatLng(position), _Place.phone);
      } else {
        _needsPlace = _at == null;
      }
    });
  }

  Future<void> _pickPlace() async {
    final picked = await context.push<LatLng>('/pick-location', extra: _at);
    if (picked == null || !mounted) return;
    setState(() => _setPlace(picked, _Place.picked));
    await _search();
  }

  Future<void> _search() async {
    final photo = _photo;
    final at = _at;
    if (photo == null || at == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(apiProvider).searchByPhoto(photo.file.path, at, species: _species);
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _postAsSighting() => context.push('/sightings/new', extra: _photo);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final photo = _photo;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchByPhoto)),
      body: photo == null ? _intro(context) : _content(context, photo),
      bottomNavigationBar: photo == null || _busy
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton.icon(
                onPressed: _postAsSighting,
                icon: const Icon(LucideIcons.camera),
                label: Text(l10n.postAsSighting),
              ),
            ),
    );
  }

  Widget _intro(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: tokens.tonal, shape: BoxShape.circle),
              child: Icon(LucideIcons.scanSearch, size: 44, color: tokens.accent),
            ),
            Text(
              l10n.searchByPhotoIntro,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.4, color: tokens.muted),
            ),
            FilledButton.icon(
              onPressed: _choosePhoto,
              icon: const Icon(LucideIcons.camera),
              label: Text(l10n.takeOrChoosePhoto),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, PickedPhoto photo) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final result = _result;
    final error = _error;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          spacing: 16,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(File(photo.file.path), width: 112, height: 112, fit: BoxFit.cover),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  if (_place != null)
                    Row(
                      spacing: 6,
                      children: [
                        Icon(LucideIcons.mapPin, size: 16, color: tokens.muted),
                        Expanded(
                          child: Text(switch (_place!) {
                            _Place.phone => l10n.searchNearYou,
                            _Place.photo => l10n.searchNearPhoto,
                            _Place.picked => l10n.searchNearPicked,
                          }, style: TextStyle(fontSize: 13, color: tokens.muted)),
                        ),
                      ],
                    ),
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: _busy ? null : _choosePhoto,
                        icon: const Icon(LucideIcons.refreshCw, size: 16),
                        label: Text(l10n.changePhoto),
                      ),
                      TextButton.icon(
                        onPressed: _busy ? null : _pickPlace,
                        icon: const Icon(LucideIcons.mapPin, size: 16),
                        label: Text(_at == null ? l10n.choose : l10n.adjust),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (result != null && !_busy) ...[
          const SizedBox(height: 12),
          // Wrong species detected (a fluffy dog, a dog-like cat): search the other one
          SegmentedButton<Species>(
            segments: [
              for (final s in [Species.cat, Species.dog]) ButtonSegment(value: s, label: Text(speciesLabel(l10n, s))),
            ],
            selected: {_species ?? result.species},
            onSelectionChanged: (s) {
              setState(() => _species = s.first);
              _search();
            },
          ),
        ],
        const SizedBox(height: 20),
        if (_busy)
          _Waiting(l10n.searchComparing)
        else if (_needsPlace)
          _Message(icon: LucideIcons.mapPin, text: l10n.searchNeedsPlace, action: l10n.choose, onAction: _pickPlace)
        else if (error is ApiException && error.code == 'no_animal_detected')
          _Message(
            icon: LucideIcons.triangleAlert,
            text: l10n.searchNoAnimal,
            action: l10n.retakePhoto,
            onAction: _choosePhoto,
          )
        else if (error != null)
          _Message(icon: LucideIcons.wifiOff, text: errorMessage(context, error), action: l10n.retry, onAction: _search)
        else if (result != null && result.results.isEmpty)
          _Message(icon: LucideIcons.searchX, text: l10n.searchNoResults, detail: l10n.searchNoResultsHelp)
        else if (result != null) ...[
          Text(l10n.searchResultsCount(result.results.length), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(l10n.searchResultsHelp, style: TextStyle(fontSize: 13, height: 1.4, color: tokens.muted)),
          const SizedBox(height: 8),
          for (final (i, hit) in result.results.indexed)
            FadeSlideIn(
              index: i,
              child: _HitCard(hit, onTap: () => context.push('/lost/${hit.report.id}')),
            ),
        ],
      ],
    );
  }
}

class _HitCard extends StatelessWidget {
  const _HitCard(this.hit, {required this.onTap});

  final PhotoSearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final report = hit.report;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(color: tokens.card, borderRadius: BorderRadius.circular(20), boxShadow: cardShadow),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                spacing: 12,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox.square(dimension: 84, child: NetworkPhoto(hit.matchedImageUrl)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        Text(
                          report.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          '${speciesLabel(l10n, report.species)} · ${l10n.seenAgo(timeAgo(l10n, report.lastSeenAt))}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: tokens.muted),
                        ),
                        // Shrinks rather than overflow with long labels or large text
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: StatusPill(
                            hit.likely ? l10n.searchStrongMatch : l10n.searchPossibleMatch,
                            tone: hit.likely ? Tone.found : Tone.stray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SimilarityRing(hit.score, size: 56),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      spacing: 16,
      children: [
        const CircularProgressIndicator(),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.tokens.muted),
        ),
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.detail, this.action, this.onAction});

  final IconData icon;
  final String text;
  final String? detail;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        spacing: 10,
        children: [
          Icon(icon, size: 40, color: tokens.muted),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          if (detail != null)
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.4, color: tokens.muted),
            ),
          if (action != null) OutlinedButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}
