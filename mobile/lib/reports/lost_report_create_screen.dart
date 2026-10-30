import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../api/providers.dart';
import '../auth/auth_controller.dart';
import '../uploads.dart';
import '../widgets/common.dart';
import '../widgets/location.dart';
import '../widgets/photo_upload.dart';

const _maxPhotos = 5;

/// Reports a lost pet, or with [editing], changes one: the same form, filled in, where photos
/// can also be removed.
class LostReportCreateScreen extends ConsumerStatefulWidget {
  const LostReportCreateScreen({super.key, this.editing});

  final LostReport? editing;

  @override
  ConsumerState<LostReportCreateScreen> createState() => _LostReportCreateScreenState();
}

class _LostReportCreateScreenState extends ConsumerState<LostReportCreateScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.editing?.name);
  late final _description = TextEditingController(text: widget.editing?.description);
  late final _reward = TextEditingController(text: widget.editing?.rewardTnd?.toString());
  late final _phone = TextEditingController(text: widget.editing?.contactPhone);
  late Species _species = widget.editing?.species ?? Species.cat;
  late DateTime _lastSeenAt = widget.editing?.lastSeenAt ?? DateTime.now();
  late LatLng? _lastSeen = widget.editing?.lastSeen;
  late bool? _microchipped = widget.editing?.microchipped; // null: not said
  late List<Photo> _kept = [...?widget.editing?.photos]; // photos already on the report, editing
  List<PickedPhoto> _photos = [];
  String? _progress;

  bool get _editing => widget.editing != null;

  @override
  void dispose() {
    for (final controller in [_name, _description, _reward, _phone]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLocation() async {
    FocusScope.of(context).unfocus(); // otherwise the keyboard reopens when we come back
    // Start from the phone's position: people often report from home, close to where the pet went missing
    final start = _lastSeen ?? (await currentPosition().then((p) => p == null ? null : toLatLng(p)));
    if (!mounted) return;
    final picked = await context.push<LatLng>('/pick-location', extra: start);
    if (picked != null) setState(() => _lastSeen = picked);
  }

  Future<void> _pickDateTime() async {
    final picked = await pickDateTime(context, _lastSeenAt);
    if (picked != null) setState(() => _lastSeenAt = picked);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final api = ref.read(apiProvider);
    final reward = int.tryParse(_reward.text.trim());
    setState(() => _progress = '');
    try {
      final String id;
      if (widget.editing case final report?) {
        id = report.id;
        await api.updateLostReport(
          id,
          name: _name.text.trim(),
          species: _species,
          description: _description.text.trim(),
          // Only when moved: moving the place or the time matches the pet again
          lastSeen: _lastSeen == report.lastSeen ? null : _lastSeen,
          lastSeenAt: _lastSeenAt == report.lastSeenAt ? null : _lastSeenAt,
          rewardTnd: reward ?? 0,
          microchipped: _microchipped,
          contactPhone: _phone.text.trim(),
        );
        for (final removed in report.photos.where((p) => !_kept.contains(p))) {
          await api.deletePhoto(removed.id);
        }
      } else {
        id = (await api.createLostReport(
          name: _name.text.trim(),
          species: _species,
          description: _description.text.trim(),
          lastSeen: _lastSeen!,
          lastSeenAt: _lastSeenAt,
          rewardTnd: reward,
          microchipped: _microchipped,
          contactPhone: _phone.text.trim(),
        )).id;
      }
      if (!mounted) return;
      await uploadPhotos(
        context,
        api,
        ref.read(uploadQueueProvider.notifier),
        '/lost-reports/$id',
        _photos,
        onProgress: (p) => setState(() => _progress = p),
      );
      ref
        ..invalidate(lostReportProvider(id))
        ..invalidate(myLostReportsProvider);
      if (!mounted) return;
      _editing ? context.pop() : context.pop('/lost/$id'); // a new report opens next
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
    final photoCount = _kept.length + _photos.length;
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? l10n.editReport : l10n.reportLostPet)),
      body: AbsorbPointer(
        absorbing: busy,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.lostPhotosHint, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              if (_kept.isNotEmpty) ...[
                _KeptPhotos(_kept, onRemove: (photo) => setState(() => _kept = [..._kept]..remove(photo))),
                const SizedBox(height: 8),
              ],
              if (_kept.length < _maxPhotos)
                PhotoPickerStrip(
                  photos: _photos,
                  max: _maxPhotos - _kept.length,
                  onChanged: (p) => setState(() => _photos = p),
                ),
              const SizedBox(height: 20),
              FieldLabel(l10n.petName),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(prefixIcon: Icon(LucideIcons.pawPrint), counterText: ''),
                maxLength: 80,
                validator: (v) => (v ?? '').trim().isEmpty ? l10n.required : null,
              ),
              const SizedBox(height: 16),
              FieldLabel(l10n.speciesTitle),
              SegmentedButton<Species>(
                segments: [for (final s in Species.values) ButtonSegment(value: s, label: Text(speciesLabel(l10n, s)))],
                selected: {_species},
                onSelectionChanged: (s) => setState(() => _species = s.first),
              ),
              const SizedBox(height: 16),
              FieldLabel(l10n.descriptionOptional),
              TextFormField(
                controller: _description,
                decoration: InputDecoration(hintText: l10n.descriptionHint, counterText: ''),
                maxLength: 2000,
                maxLines: 4,
                minLines: 2,
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.clock),
                title: Text(l10n.lastSeenAt),
                subtitle: Text(formatDateTime(context, _lastSeenAt)),
                trailing: TextButton(onPressed: _pickDateTime, child: Text(l10n.change)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.mapPin),
                title: Text(l10n.lastSeenWhere),
                subtitle: Text(_lastSeen == null ? l10n.locationMissing : l10n.locationPrivacyNote),
                trailing: TextButton(
                  onPressed: _pickLocation,
                  child: Text(_lastSeen == null ? l10n.choose : l10n.change),
                ),
              ),
              if (_lastSeen != null) LocationPreview(_lastSeen!, height: 140),
              const SizedBox(height: 24),
              Text(l10n.moreDetails, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              FieldLabel(l10n.rewardOptional),
              TextFormField(
                controller: _reward,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                decoration: InputDecoration(prefixIcon: const Icon(LucideIcons.gift), suffixText: l10n.currencyTnd),
                validator: (v) => (int.tryParse(v ?? '') ?? 1) > 100000 ? l10n.rewardTooHigh : null,
              ),
              const SizedBox(height: 16),
              FieldLabel(l10n.microchipQuestion),
              Wrap(
                spacing: 8,
                children: [
                  for (final (value, label) in [(true, l10n.yes), (false, l10n.no), (null, l10n.notSure)])
                    ChoiceChip(
                      label: Text(label),
                      selected: _microchipped == value,
                      onSelected: (_) => setState(() => _microchipped = value),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FieldLabel(l10n.phoneOptional),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: InputDecoration(prefixIcon: const Icon(LucideIcons.phone), helperText: l10n.phoneHelp),
                validator: (v) => (v ?? '').trim().isEmpty || RegExp(r'^[+0-9 ()-]{6,20}$').hasMatch(v!.trim())
                    ? null
                    : l10n.phoneInvalid,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: busy || photoCount == 0 || _lastSeen == null ? null : _submit,
            icon: busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_editing ? LucideIcons.check : LucideIcons.megaphone),
            label: Text(busy ? l10n.uploading(_progress!) : (_editing ? l10n.saveChanges : l10n.publishReport)),
          ),
        ),
      ),
    );
  }
}

/// Photos already on the report, each with a button to remove it.
class _KeptPhotos extends StatelessWidget {
  const _KeptPhotos(this.photos, {required this.onRemove});

  final List<Photo> photos;
  final ValueChanged<Photo> onRemove;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 88,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: photos.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, i) => Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox.square(dimension: 88, child: NetworkPhoto(photos[i].url)),
          ),
          PositionedDirectional(
            top: 4,
            end: 4,
            child: IconButton.filled(
              tooltip: context.l10n.removePhoto,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
              onPressed: () => onRemove(photos[i]),
              icon: const Icon(LucideIcons.x, size: 16),
            ),
          ),
        ],
      ),
    ),
  );
}
