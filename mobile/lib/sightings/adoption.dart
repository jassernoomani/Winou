import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/models.dart';
import '../api/providers.dart';
import '../auth/auth_controller.dart';
import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';
import '../widgets/location.dart';

/// Digits and a leading "+" only, as phone and WhatsApp links want them.
String dialable(String phone) => phone.replaceAll(RegExp(r'[^+0-9]'), '');

Future<void> callNumber(String phone) => launchUrl(Uri(scheme: 'tel', path: dialable(phone)));

/// WhatsApp wants the international number without "+": a local Tunisian one gets 216 in front.
String whatsAppNumber(String phone) {
  var digits = dialable(phone).replaceFirst('+', '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.length == 8) digits = '216$digits';
  return digits;
}

Future<void> openWhatsApp(String phone) =>
    launchUrl(Uri.parse('https://wa.me/${whatsAppNumber(phone)}'), mode: LaunchMode.externalApplication);

/// On a stray's page. Up for adoption: who offers it, a few words, call or WhatsApp. Adopted: the
/// happy ending. Associations (and admins) offer strays still around, and manage their own offers.
class AdoptionCard extends ConsumerStatefulWidget {
  const AdoptionCard(this.sighting, {super.key});

  final Sighting sighting;

  @override
  ConsumerState<AdoptionCard> createState() => _AdoptionCardState();
}

class _AdoptionCardState extends ConsumerState<AdoptionCard> {
  bool _busy = false;

  Future<void> _run(Future<Object?> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(sightingProvider(widget.sighting.id));
      if (done != null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _offer() async {
    final adoption = widget.sighting.adoption;
    final result = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _OfferSheet(note: adoption?.note, contact: adoption?.contact),
    );
    if (result == null) return;
    final (note, contact) = result;
    await _run(() => ref.read(apiProvider).offerAdoption(widget.sighting.id, note: note, contact: contact));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final adoption = widget.sighting.adoption;
    final me = ref.watch(meProvider).value;
    final canOffer =
        me != null && (me.associationName != null || me.isAdmin) && widget.sighting.strayStatus != StrayStatus.gone;

    if (adoption == null) {
      if (!canOffer) return const SizedBox.shrink();
      return OutlinedButton.icon(
        onPressed: _busy ? null : _offer,
        icon: const Icon(LucideIcons.heartHandshake),
        label: Text(l10n.offerForAdoption),
      );
    }

    if (adoption.adopted) {
      return Note(
        adoption.association == null
            ? '${l10n.adoptedTitle} ${l10n.adoptedBodyNoAssociation}'
            : '${l10n.adoptedTitle} ${l10n.adoptedBody(adoption.association!)}',
        tone: Tone.found,
        icon: LucideIcons.partyPopper,
      );
    }

    final (background, foreground) = tokens.tone(Tone.found);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Row(
            spacing: 10,
            children: [
              Icon(LucideIcons.heartHandshake, color: foreground),
              Expanded(
                child: Text(
                  l10n.upForAdoption,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: foreground),
                ),
              ),
            ],
          ),
          if (adoption.association case final association?)
            Text(l10n.offeredBy(association), style: const TextStyle(fontWeight: FontWeight.w700)),
          if (adoption.note case final note?)
            Text(note, textDirection: textDirectionOf(note), style: const TextStyle(height: 1.4)),
          if (adoption.contact case final contact?)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => callNumber(contact),
                  icon: const Icon(LucideIcons.phone, size: 18),
                  label: Text(l10n.call),
                ),
                OutlinedButton.icon(
                  onPressed: () => openWhatsApp(contact),
                  icon: const Icon(LucideIcons.messageCircle, size: 18),
                  label: Text(l10n.whatsapp),
                ),
              ],
            ),
          if (adoption.mine || (me?.isAdmin ?? false)) ...[
            const Divider(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _busy
                      ? null
                      : () =>
                            _run(() => ref.read(apiProvider).markAdopted(widget.sighting.id), done: l10n.adoptedSnack),
                  icon: const Icon(LucideIcons.partyPopper, size: 18),
                  label: Text(l10n.markAdopted),
                ),
                TextButton(onPressed: _busy ? null : _offer, child: Text(l10n.editOffer)),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() => ref.read(apiProvider).withdrawAdoption(widget.sighting.id)),
                  child: Text(l10n.withdrawOffer),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OfferSheet extends StatefulWidget {
  const _OfferSheet({this.note, this.contact});

  final String? note;
  final String? contact;

  @override
  State<_OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends State<_OfferSheet> {
  final _form = GlobalKey<FormState>();
  late final _note = TextEditingController(text: widget.note);
  late final _contact = TextEditingController(text: widget.contact);

  @override
  void dispose() {
    _note.dispose();
    _contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.offerForAdoption, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            FieldLabel(l10n.adoptionNoteLabel),
            TextFormField(
              controller: _note,
              maxLength: 500,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: l10n.adoptionNoteHint),
            ),
            const SizedBox(height: 8),
            FieldLabel(l10n.adoptionContactLabel),
            TextFormField(
              controller: _contact,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(prefixIcon: Icon(LucideIcons.phone)),
              validator: (v) => RegExp(r'^[+0-9 ()-]{6,20}$').hasMatch((v ?? '').trim()) ? null : l10n.phoneInvalid,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                Navigator.pop(context, (_note.text.trim(), _contact.text.trim()));
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animals up for adoption, nearest first.
final adoptableProvider = FutureProvider.autoDispose<List<Sighting>>((ref) async {
  final position = await currentPosition();
  return ref.watch(apiProvider).adoptable(near: position == null ? null : toLatLng(position));
});

class AdoptionScreen extends ConsumerWidget {
  const AdoptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final strays = ref.watch(adoptableProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.forAdoption)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(adoptableProvider.future),
        child: switch (strays) {
          AsyncData(:final value) when value.isEmpty => ListView(
            children: [
              const SizedBox(height: 80),
              EmptyState(icon: LucideIcons.heartHandshake, text: '${l10n.noAdoptionNearby}\n\n${l10n.adoptionIntro}'),
            ],
          ),
          AsyncData(:final value) => ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: value.length + 1,
            itemBuilder: (context, i) => i == 0
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(l10n.adoptionIntro, style: TextStyle(color: context.tokens.muted)),
                  )
                : FadeSlideIn(
                    index: i - 1,
                    child: _AdoptableRow(value[i - 1], onTap: () => context.push('/sightings/${value[i - 1].id}')),
                  ),
          ),
          AsyncError(:final error) => ErrorView(error: error, onRetry: () => ref.invalidate(adoptableProvider)),
          _ => const SkeletonList(picture: 88),
        },
      ),
    );
  }
}

class _AdoptableRow extends StatelessWidget {
  const _AdoptableRow(this.stray, {required this.onTap});

  final Sighting stray;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final adoption = stray.adoption!;
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
                    child: SizedBox.square(dimension: 88, child: NetworkPhoto(stray.photos.firstOrNull?.url)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        Text(
                          stray.nickname ?? speciesLabel(l10n, stray.species),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        if (adoption.association case final association?)
                          Text(
                            l10n.offeredBy(association),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: tokens.muted),
                          ),
                        if (adoption.note case final note?)
                          Text(
                            note,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textDirection: textDirectionOf(note),
                            style: const TextStyle(fontSize: 13, height: 1.35),
                          ),
                      ],
                    ),
                  ),
                  const Icon(LucideIcons.chevronRight),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
