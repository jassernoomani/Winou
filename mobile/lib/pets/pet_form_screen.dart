import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../api/providers.dart';
import '../auth/auth_controller.dart';
import '../reports/lost_report_detail_screen.dart' show confirm;
import '../theme.dart';
import '../uploads.dart';
import '../widgets/common.dart';
import '../widgets/photo_upload.dart';

const _maxPhotos = 5;

/// Adds a pet to "My pets", or with [editing] changes one: name, species, what it looks like,
/// microchip, and up to five photos (clear ones of the face help most if it ever goes missing).
class PetFormScreen extends ConsumerStatefulWidget {
  const PetFormScreen({super.key, this.editing});

  final Pet? editing;

  @override
  ConsumerState<PetFormScreen> createState() => _PetFormScreenState();
}

class _PetFormScreenState extends ConsumerState<PetFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.editing?.name);
  late final _description = TextEditingController(text: widget.editing?.description);
  late Species _species = widget.editing?.species ?? Species.cat;
  late bool? _microchipped = widget.editing?.microchipped;
  late List<Photo> _kept = [...?widget.editing?.photos];
  List<PickedPhoto> _photos = [];
  String? _progress;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final api = ref.read(apiProvider);
    setState(() => _progress = '');
    try {
      final pet = await api.savePet(
        id: widget.editing?.id,
        name: _name.text.trim(),
        species: _species,
        description: _description.text.trim(),
        microchipped: _microchipped,
      );
      for (final removed in [...?widget.editing?.photos].where((p) => !_kept.contains(p))) {
        await api.deletePhoto(removed.id);
      }
      if (!mounted) return;
      await uploadPhotos(
        context,
        api,
        ref.read(uploadQueueProvider.notifier),
        '/pets/${pet.id}',
        _photos,
        onProgress: (p) => setState(() => _progress = p),
      );
      ref.invalidate(myPetsProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _progress = null);
      }
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    if (!await confirm(context, l10n.deletePetQuestion(widget.editing!.name), l10n.delete)) return;
    try {
      await ref.read(apiProvider).deletePet(widget.editing!.id);
      ref.invalidate(myPetsProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final busy = _progress != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing == null ? l10n.addPet : widget.editing!.name),
        actions: [
          if (widget.editing != null)
            IconButton(tooltip: l10n.delete, onPressed: busy ? null : _delete, icon: const Icon(LucideIcons.trash2)),
        ],
      ),
      body: AbsorbPointer(
        absorbing: busy,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Note(l10n.petProfileIntro, tone: Tone.info, icon: LucideIcons.shieldCheck),
              const SizedBox(height: 16),
              Text(l10n.lostPhotosHint, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              if (_kept.isNotEmpty) ...[
                SizedBox(
                  height: 88,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _kept.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox.square(dimension: 88, child: NetworkPhoto(_kept[i].url)),
                        ),
                        PositionedDirectional(
                          top: 4,
                          end: 4,
                          child: IconButton.filled(
                            tooltip: l10n.removePhoto,
                            visualDensity: VisualDensity.compact,
                            style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                            onPressed: () => setState(() => _kept = [..._kept]..removeAt(i)),
                            icon: const Icon(LucideIcons.x, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (_kept.length < _maxPhotos)
                PhotoPickerStrip(
                  photos: _photos,
                  max: _maxPhotos - _kept.length,
                  species: _species,
                  onChanged: (p) => setState(() => _photos = p),
                ),
              const SizedBox(height: 20),
              FieldLabel(l10n.petName),
              TextFormField(
                controller: _name,
                maxLength: 80,
                decoration: const InputDecoration(prefixIcon: Icon(LucideIcons.pawPrint), counterText: ''),
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
                maxLength: 2000,
                maxLines: 4,
                minLines: 2,
                decoration: InputDecoration(hintText: l10n.descriptionHint, counterText: ''),
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
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: busy ? null : _save,
            icon: busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(LucideIcons.check),
            label: Text(busy ? l10n.uploading(_progress!) : l10n.save),
          ),
        ),
      ),
    );
  }
}
