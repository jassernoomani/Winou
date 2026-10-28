import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../api/models.dart';
import '../auth/auth_controller.dart';
import '../widgets/common.dart';
import '../widgets/location.dart';
import '../widgets/photo_upload.dart';

const _maxPhotos = 5;

class LostReportCreateScreen extends ConsumerStatefulWidget {
  const LostReportCreateScreen({super.key});

  @override
  ConsumerState<LostReportCreateScreen> createState() => _LostReportCreateScreenState();
}

class _LostReportCreateScreenState extends ConsumerState<LostReportCreateScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  Species _species = Species.cat;
  DateTime _lastSeenAt = DateTime.now();
  LatLng? _lastSeen;
  List<PickedPhoto> _photos = [];
  String? _progress;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
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
    setState(() => _progress = '');
    try {
      final report = await api.createLostReport(
        name: _name.text.trim(),
        species: _species,
        description: _description.text.trim(),
        lastSeen: _lastSeen!,
        lastSeenAt: _lastSeenAt,
      );
      if (!mounted) return;
      await uploadPhotos(
        context,
        api,
        '/lost-reports/${report.id}',
        _photos,
        onProgress: (p) => setState(() => _progress = p),
      );
      if (mounted) context.pop('/lost/${report.id}'); // the map opens it next
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
      appBar: AppBar(title: Text(l10n.reportLostPet)),
      body: AbsorbPointer(
        absorbing: busy,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.lostPhotosHint, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              PhotoPickerStrip(photos: _photos, max: _maxPhotos, onChanged: (p) => setState(() => _photos = p)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: l10n.petName, border: const OutlineInputBorder()),
                maxLength: 80,
                validator: (v) => (v ?? '').trim().isEmpty ? l10n.required : null,
              ),
              SegmentedButton<Species>(
                segments: [for (final s in Species.values) ButtonSegment(value: s, label: Text(speciesLabel(l10n, s)))],
                selected: {_species},
                onSelectionChanged: (s) => setState(() => _species = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                decoration: InputDecoration(
                  labelText: l10n.descriptionOptional,
                  hintText: l10n.descriptionHint,
                  border: const OutlineInputBorder(),
                ),
                maxLength: 2000,
                maxLines: 4,
                minLines: 2,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(l10n.lastSeenAt),
                subtitle: Text(formatDateTime(context, _lastSeenAt)),
                trailing: TextButton(onPressed: _pickDateTime, child: Text(l10n.change)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place_outlined),
                title: Text(l10n.lastSeenWhere),
                subtitle: Text(_lastSeen == null ? l10n.locationMissing : l10n.locationPrivacyNote),
                trailing: TextButton(
                  onPressed: _pickLocation,
                  child: Text(_lastSeen == null ? l10n.choose : l10n.change),
                ),
              ),
              if (_lastSeen != null) LocationPreview(_lastSeen!, height: 140),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: busy || _photos.isEmpty || _lastSeen == null ? null : _submit,
            icon: busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.campaign_outlined),
            label: Text(busy ? l10n.uploading(_progress!) : l10n.publishReport),
          ),
        ),
      ),
    );
  }
}
