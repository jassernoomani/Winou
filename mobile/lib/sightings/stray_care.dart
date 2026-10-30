import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../api/providers.dart';
import '../auth/auth_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// A stray's care card, kept by the neighbourhood: its name, whether it is sterilised and
/// vaccinated, care notes, and how many people feed it. Anyone signed in can update it.
class StrayCareCard extends ConsumerStatefulWidget {
  const StrayCareCard(this.sighting, {super.key});

  final Sighting sighting;

  @override
  ConsumerState<StrayCareCard> createState() => _StrayCareCardState();
}

class _StrayCareCardState extends ConsumerState<StrayCareCard> {
  bool _busy = false;

  StrayCare get _care => widget.sighting.care ?? const StrayCare.empty();

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(sightingProvider(widget.sighting.id));
      if (mounted && done != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final updated = await showModalBottomSheet<StrayCare>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CareForm(_care),
    );
    if (updated == null || !mounted) return;
    final api = ref.read(apiProvider);
    await _run(() => api.updateStrayCare(widget.sighting.id, updated), done: context.l10n.careUpdated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final care = _care;
    String known(bool? value) => switch (value) {
      true => l10n.yes,
      false => l10n.no,
      null => l10n.careUnknown,
    };
    Tone tone(bool? value) => switch (value) {
      true => Tone.found,
      false => Tone.stray,
      null => Tone.neutral,
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Row(
              children: [
                Expanded(child: Text(l10n.careCardTitle, style: theme.textTheme.titleMedium)),
                TextButton.icon(
                  onPressed: _busy ? null : _edit,
                  icon: const Icon(LucideIcons.pencil, size: 16),
                  label: Text(l10n.editCareCard),
                ),
              ],
            ),
            if (care.isEmpty)
              Text(l10n.careEmpty, style: TextStyle(color: context.tokens.muted))
            else ...[
              if (care.nickname case final name?)
                Text(name, style: theme.textTheme.headlineSmall, textDirection: textDirectionOf(name)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusPill(
                    '${l10n.sterilised}: ${known(care.sterilised)}',
                    tone: tone(care.sterilised),
                    icon: LucideIcons.scissors,
                  ),
                  StatusPill(
                    '${l10n.vaccinated}: ${known(care.vaccinated)}',
                    tone: tone(care.vaccinated),
                    icon: LucideIcons.syringe,
                  ),
                ],
              ),
              if (care.notes case final notes?)
                Text(notes, textDirection: textDirectionOf(notes), style: const TextStyle(height: 1.4)),
            ],
            const Divider(height: 8),
            Row(
              spacing: 8,
              children: [
                Icon(LucideIcons.heart, size: 18, color: context.tokens.muted),
                Expanded(child: Text(l10n.fedBy(care.feeders), style: theme.textTheme.bodyMedium)),
                FilterChip(
                  avatar: care.iFeed ? null : const Icon(LucideIcons.utensils, size: 16),
                  label: Text(l10n.iFeedIt),
                  selected: care.iFeed,
                  onSelected: _busy
                      ? null
                      : (feed) => _run(() => ref.read(apiProvider).setFeeding(widget.sighting.id, feed)),
                ),
              ],
            ),
            Text(l10n.careCardIntro, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// The whole card in one form; saving sends it all (blank clears a field).
class _CareForm extends StatefulWidget {
  const _CareForm(this.care);

  final StrayCare care;

  @override
  State<_CareForm> createState() => _CareFormState();
}

class _CareFormState extends State<_CareForm> {
  late final _nickname = TextEditingController(text: widget.care.nickname);
  late final _notes = TextEditingController(text: widget.care.notes);
  late bool? _sterilised = widget.care.sterilised;
  late bool? _vaccinated = widget.care.vaccinated;

  @override
  void dispose() {
    _nickname.dispose();
    _notes.dispose();
    super.dispose();
  }

  Widget _choice(String label, bool? value, ValueChanged<bool?> onChanged) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        Wrap(
          spacing: 8,
          children: [
            for (final (option, text) in [(true, l10n.yes), (false, l10n.no), (null, l10n.careUnknown)])
              ChoiceChip(label: Text(text), selected: value == option, onSelected: (_) => onChanged(option)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: 14,
          children: [
            Text(l10n.careCardTitle, style: Theme.of(context).textTheme.titleLarge),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FieldLabel(l10n.careNickname),
                TextField(
                  controller: _nickname,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: l10n.careNicknameHint,
                    prefixIcon: const Icon(LucideIcons.pawPrint),
                    counterText: '',
                  ),
                ),
              ],
            ),
            _choice(l10n.sterilised, _sterilised, (v) => setState(() => _sterilised = v)),
            _choice(l10n.vaccinated, _vaccinated, (v) => setState(() => _vaccinated = v)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FieldLabel(l10n.careNotes),
                TextField(
                  controller: _notes,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(hintText: l10n.careNotesHint, counterText: ''),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(
                context,
                StrayCare(
                  nickname: _nickname.text.trim().isEmpty ? null : _nickname.text.trim(),
                  sterilised: _sterilised,
                  vaccinated: _vaccinated,
                  notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
                ),
              ),
              icon: const Icon(LucideIcons.check),
              label: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
