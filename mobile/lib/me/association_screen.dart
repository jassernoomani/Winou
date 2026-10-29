import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../api/providers.dart';
import '../auth/auth_controller.dart';
import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';
import '../widgets/location.dart';

/// Ask to be shown as an association (an admin checks it), or see where the request stands.
class AssociationScreen extends ConsumerWidget {
  const AssociationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final me = ref.watch(meProvider);
    final request = ref.watch(myAssociationRequestProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.becomeAssociation)),
      body: switch ((me, request)) {
        (AsyncData(value: final user), AsyncData(value: final last)) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            if (user.associationName case final name?)
              FadeSlideIn(
                child: Note(l10n.requestApproved(name), tone: Tone.found, icon: LucideIcons.badgeCheck),
              )
            else if (last?.status == RequestStatus.pending)
              FadeSlideIn(
                child: Note(l10n.requestPending(last!.organisation), tone: Tone.info, icon: LucideIcons.clock),
              )
            else ...[
              Text(l10n.associationIntro, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 16),
              if (last?.status == RequestStatus.rejected) ...[
                Note(l10n.requestRejected, tone: Tone.neutral, icon: LucideIcons.info),
                const SizedBox(height: 16),
              ],
              const _RequestForm(),
            ],
          ],
        ),
        (AsyncError(:final error), _) || (_, AsyncError(:final error)) => ErrorView(
          error: error,
          onRetry: () => ref
            ..invalidate(meProvider)
            ..invalidate(myAssociationRequestProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _RequestForm extends ConsumerStatefulWidget {
  const _RequestForm();

  @override
  ConsumerState<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends ConsumerState<_RequestForm> {
  final _form = GlobalKey<FormState>();
  final _organisation = TextEditingController();
  final _city = TextEditingController();
  final _contact = TextEditingController();
  final _note = TextEditingController();
  LatLng? _location;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Most associations ask from where they work: start from here, they can move it
    currentPosition().then((p) {
      if (p != null && mounted && _location == null) setState(() => _location = toLatLng(p));
    });
  }

  @override
  void dispose() {
    _organisation.dispose();
    _city.dispose();
    _contact.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    FocusScope.of(context).unfocus();
    final picked = await context.push<LatLng>('/pick-location', extra: _location);
    if (picked != null) setState(() => _location = picked);
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(apiProvider)
          .requestAssociation(
            organisation: _organisation.text.trim(),
            city: _city.text.trim(),
            contact: _contact.text.trim(),
            note: _note.text.trim(),
            location: _location!,
          );
      ref.invalidate(myAssociationRequestProvider);
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String? required(String? v) => (v ?? '').trim().isEmpty ? l10n.required : null;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldLabel(l10n.organisation),
          TextFormField(
            controller: _organisation,
            maxLength: 120,
            decoration: const InputDecoration(prefixIcon: Icon(LucideIcons.heartHandshake), counterText: ''),
            textInputAction: TextInputAction.next,
            validator: required,
          ),
          const SizedBox(height: 12),
          FieldLabel(l10n.city),
          TextFormField(
            controller: _city,
            maxLength: 80,
            decoration: const InputDecoration(prefixIcon: Icon(LucideIcons.mapPin), counterText: ''),
            textInputAction: TextInputAction.next,
            validator: required,
          ),
          const SizedBox(height: 12),
          FieldLabel(l10n.contact),
          TextFormField(
            controller: _contact,
            maxLength: 200,
            decoration: InputDecoration(
              prefixIcon: const Icon(LucideIcons.phone),
              helperText: l10n.contactHelp,
              helperMaxLines: 2,
              counterText: '',
            ),
            textInputAction: TextInputAction.next,
            validator: required,
          ),
          const SizedBox(height: 12),
          FieldLabel(l10n.associationNote),
          TextFormField(
            controller: _note,
            maxLength: 1000,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(counterText: ''),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(LucideIcons.bell),
            title: Text(l10n.alertArea),
            subtitle: Text(_location == null ? l10n.locationMissing : l10n.alertAreaHelp),
            trailing: TextButton(onPressed: _pickLocation, child: Text(_location == null ? l10n.choose : l10n.change)),
          ),
          if (_location != null) LocationPreview(_location!, height: 140, approximateRadiusM: 10000),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _sending || _location == null ? null : _send,
            icon: _sending
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(LucideIcons.send),
            label: Text(l10n.sendRequest),
          ),
        ],
      ),
    );
  }
}
