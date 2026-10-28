import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../api/models.dart';
import '../auth/auth_controller.dart';
import '../widgets/common.dart';
import '../widgets/location.dart';
import '../widgets/photo_upload.dart';

const _maxPhotos = 3;

/// Camera-first: the camera opens right away and the GPS position is taken meanwhile.
/// Gallery photos are allowed too, but then "when" and "where" come from the photo (or the
/// user), never from "now, here": the photo may have been taken days ago, elsewhere.
class SightingCreateScreen extends ConsumerStatefulWidget {
  const SightingCreateScreen({super.key});

  @override
  ConsumerState<SightingCreateScreen> createState() => _SightingCreateScreenState();
}

class _SightingCreateScreenState extends ConsumerState<SightingCreateScreen> {
  final _note = TextEditingController();
  final DateTime _openedAt = DateTime.now();
  List<PickedPhoto> _photos = [];
  Species _species = Species.cat;
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

  Future<void> _fromGallery() async {
    final picked = await pickFromGallery(_maxPhotos);
    if (picked.isNotEmpty && mounted) setState(() => _photos = picked);
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
    final l10n = context.l10n;
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
      );
      if (!mounted) return;
      await uploadPhotos(
        context,
        api,
        '/sightings/${sighting.id}',
        _photos,
        onProgress: (p) => setState(() => _progress = p),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.sightingThanks)));
      context.pop('/sightings/${sighting.id}'); // the map opens it next
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.newSighting)),
      body: AbsorbPointer(
        absorbing: busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(leading: const Icon(Icons.center_focus_strong), title: Text(l10n.photoHint)),
            ),
            const SizedBox(height: 12),
            if (_photos.isEmpty)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _firstPhoto,
                      icon: const Icon(Icons.photo_camera),
                      label: Text(l10n.takePhoto),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _fromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: Text(l10n.chooseFromGallery),
                    ),
                  ),
                ],
              )
            else
              PhotoPickerStrip(photos: _photos, max: _maxPhotos, onChanged: (p) => setState(() => _photos = p)),
            const SizedBox(height: 20),
            SegmentedButton<Species>(
              segments: [for (final s in Species.values) ButtonSegment(value: s, label: Text(speciesLabel(l10n, s)))],
              selected: {_species},
              onSelectionChanged: (s) => setState(() => _species = s.first),
            ),
            const SizedBox(height: 16),
            Text(l10n.condition, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final c in Condition.values)
                  ChoiceChip(
                    label: Text(conditionLabel(l10n, c)),
                    selected: _condition == c,
                    onSelected: (_) => setState(() => _condition = c),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.isStray),
              subtitle: Text(l10n.isStrayHelp),
              value: _isStray,
              onChanged: (v) => setState(() => _isStray = v),
            ),
            TextField(
              controller: _note,
              decoration: InputDecoration(labelText: l10n.noteOptional, border: const OutlineInputBorder()),
              maxLength: 1000,
              maxLines: 3,
              minLines: 1,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(_timeLabel(context)),
              trailing: TextButton(onPressed: _pickTime, child: Text(l10n.change)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place_outlined),
              title: Text(_locationLabel(context)),
              trailing: TextButton(onPressed: _pickLocation, child: Text(l10n.change)),
            ),
            if (_location != null) LocationPreview(_location!, height: 140),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: busy || _photos.isEmpty || _location == null || _seenAt == null ? null : _submit,
            icon: busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
            label: Text(busy ? l10n.uploading(_progress!) : l10n.postSighting),
          ),
        ),
      ),
    );
  }
}
