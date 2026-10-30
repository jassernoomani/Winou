import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../auth/auth_controller.dart';
import '../theme.dart';
import '../uploads.dart';
import '../widgets/common.dart';
import '../widgets/location.dart';
import '../widgets/photo_upload.dart';

const _maxPhotos = 3;

/// Camera-first: the camera opens right away and the GPS position is taken meanwhile.
/// Gallery photos are allowed too, but then "when" and "where" come from the photo (or the
/// user), never from "now, here": the photo may have been taken days ago, elsewhere.
class SightingCreateScreen extends ConsumerStatefulWidget {
  const SightingCreateScreen({super.key, this.about});

  /// "I saw this pet": the lost report it's about; its owner is told at once.
  final LostReport? about;

  @override
  ConsumerState<SightingCreateScreen> createState() => _SightingCreateScreenState();
}

class _SightingCreateScreenState extends ConsumerState<SightingCreateScreen> {
  final _note = TextEditingController();
  final DateTime _openedAt = DateTime.now();
  List<PickedPhoto> _photos = [];
  late Species _species = widget.about?.species ?? Species.cat;
  Condition _condition = Condition.healthy;
  bool _isStray = false;
  LatLng? _gps; // the phone's position now
  double? _gpsAccuracyM;
  bool _locating = true;
  LatLng? _pickedLocation; // set by hand: wins over everything
  DateTime? _pickedTime;
  String? _progress; // non-null while submitting

  @override
  void initState() {
    super.initState();
    _locate();
    WidgetsBinding.instance.addPostFrameCallback((_) => _firstPhoto());
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _firstPhoto() async {
    final photo = await takePhoto();
    if (photo != null && mounted) setState(() => _photos = [photo]);
    // Cancelled: stay, so the user can choose from the gallery instead
  }

  /// More photos next to the first (up to [_maxPhotos]), from the camera or the gallery.
  Future<void> _addMore() async {
    final added = await addPhotos(context, _maxPhotos - _photos.length);
    if (added.isNotEmpty && mounted) setState(() => _photos = [..._photos, ...added].take(_maxPhotos).toList());
  }

  Iterable<PickedPhoto> get _galleryPhotos => _photos.where((p) => p.fromGallery);

  /// When the animal was seen: set by hand, else from a gallery photo, else now (camera).
  DateTime? get _seenAt =>
      _pickedTime ?? (_galleryPhotos.isEmpty ? _openedAt : _galleryPhotos.map((p) => p.takenAt).nonNulls.firstOrNull);

  /// Where it was seen: set by hand, else from a gallery photo, else the phone's position (camera).
  LatLng? get _location =>
      _pickedLocation ?? (_galleryPhotos.isEmpty ? _gps : _galleryPhotos.map((p) => p.location).nonNulls.firstOrNull);

  String _timeLabel(BuildContext context) {
    final l10n = context.l10n;
    final seenAt = _seenAt;
    if (seenAt == null) return l10n.timeMissing;
    if (_pickedTime != null) return formatDateTime(context, seenAt);
    if (_galleryPhotos.isNotEmpty) return l10n.timeFromPhoto(formatDateTime(context, seenAt));
    return l10n.timeNow;
  }

  String _locationLabel(BuildContext context) {
    final l10n = context.l10n;
    if (_pickedLocation != null) return l10n.locationPicked;
    if (_galleryPhotos.isNotEmpty) return _location != null ? l10n.locationFromPhoto : l10n.locationNeeded;
    if (_locating) return l10n.locating;
    return _gps == null ? l10n.locationMissing : l10n.locationFromGps(_gpsAccuracyM!.round());
  }

  Future<void> _pickTime() async {
    final picked = await pickDateTime(context, _seenAt ?? DateTime.now());
    if (picked != null) setState(() => _pickedTime = picked);
  }

  Future<void> _locate() async {
    final position = await currentPosition();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (position != null) {
        _gps = toLatLng(position);
        _gpsAccuracyM = position.accuracy;
      }
    });
  }

  Future<void> _pickLocation() async {
    FocusScope.of(context).unfocus(); // otherwise the keyboard reopens when we come back
    final picked = await context.push<LatLng>('/pick-location', extra: _location);
    if (picked != null) setState(() => _pickedLocation = picked);
  }

  Future<void> _submit() async {
    final api = ref.read(apiProvider);
    setState(() => _progress = '');
    try {
      final sighting = await api.createSighting(
        species: _species,
        location: _location!,
        seenAt: _seenAt!,
        condition: _condition,
        isStray: _isStray,
        note: _note.text.trim(),
        lostReportId: widget.about?.id,
      );
      if (!mounted) return;
      await uploadPhotos(
        context,
        api,
        ref.read(uploadQueueProvider.notifier),
        '/sightings/${sighting.id}',
        _photos,
        onProgress: (p) => setState(() => _progress = p),
      );
      if (mounted) context.pop('/sightings/${sighting.id}/thanks'); // the caller opens it next
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _progress = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final busy = _progress != null;
    final location = _location;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.iSawAnAnimal)),
      body: AbsorbPointer(
        absorbing: busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          children: [
            if (widget.about case final pet?) ...[_AboutPet(pet), const SizedBox(height: 12)],
            if (_photos.length == 1) ...[
              _BigPhoto(_photos.single, onRetake: _firstPhoto),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _addMore,
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: Text(l10n.addClearPhoto),
                ),
              ),
            ] else ...[
              if (_photos.isEmpty) ...[
                Text(l10n.photoHint, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
              ],
              PhotoPickerStrip(photos: _photos, max: _maxPhotos, onChanged: (p) => setState(() => _photos = p)),
            ],
            const SizedBox(height: 12),
            FieldLabel(l10n.speciesTitle),
            SegmentedButton<Species>(
              segments: [for (final s in Species.values) ButtonSegment(value: s, label: Text(speciesLabel(l10n, s)))],
              selected: {_species},
              onSelectionChanged: (s) => setState(() => _species = s.first),
            ),
            const SizedBox(height: 16),
            FieldLabel(l10n.condition),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in Condition.values)
                  ChoiceChip(
                    label: Text(conditionLabel(l10n, c)),
                    selected: _condition == c,
                    onSelected: (_) => setState(() => _condition = c),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.isStray, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(l10n.isStrayHelp),
              value: _isStray,
              onChanged: (v) => setState(() => _isStray = v),
            ),
            FieldLabel(l10n.noteOptional),
            TextField(
              controller: _note,
              decoration: const InputDecoration(prefixIcon: Icon(LucideIcons.textAlignStart), counterText: ''),
              maxLength: 1000,
              maxLines: 3,
              minLines: 1,
            ),
            const SizedBox(height: 8),
            _Row(icon: LucideIcons.clock, title: _timeLabel(context), action: l10n.change, onPressed: _pickTime),
            _Row(
              icon: LucideIcons.mapPin,
              title: _locationLabel(context),
              subtitle: location == null ? null : l10n.tapToAdjust,
              action: location == null ? l10n.choose : l10n.adjust,
              onPressed: _pickLocation,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton.icon(
            onPressed: busy || _photos.isEmpty || location == null || _seenAt == null ? null : _submit,
            icon: busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const DirectionalIcon(LucideIcons.send),
            label: Text(busy ? l10n.uploading(_progress!) : l10n.postSighting),
          ),
        ),
      ),
    );
  }
}

/// The photo just taken, large, with a "Retake" button on it.
class _BigPhoto extends StatelessWidget {
  const _BigPhoto(this.photo, {required this.onRetake});

  final PickedPhoto photo;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(photo.file.path), fit: BoxFit.cover),
          Positioned(
            right: 12,
            bottom: 12,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: onRetake,
              icon: const Icon(LucideIcons.camera, size: 18),
              label: Text(context.l10n.retake),
            ),
          ),
        ],
      ),
    ),
  );
}

/// "Seen just now · Change", "Location from the photo · Adjust".
class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, this.subtitle, required this.action, required this.onPressed});

  final IconData icon;
  final String title;
  final String? subtitle;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: TextButton(onPressed: onPressed, child: Text(action)),
  );
}

/// Which lost pet this sighting is about, with its photo to compare with.
class _AboutPet extends StatelessWidget {
  const _AboutPet(this.pet);

  final LostReport pet;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = context.tokens.tone(Tone.info);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Row(
        spacing: 12,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox.square(dimension: 52, child: NetworkPhoto(pet.photos.firstOrNull?.url)),
          ),
          Expanded(
            child: Text(
              context.l10n.sightingAboutPet(pet.name),
              style: TextStyle(color: foreground, fontWeight: FontWeight.w700, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
