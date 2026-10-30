import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../api/providers.dart';
import '../auth/auth_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/location.dart';
import '../widgets/photo_upload.dart' show pickDateTime;

/// A pet from "My pets" went missing: only when and where are asked, the rest is already known.
class MarkLostScreen extends ConsumerStatefulWidget {
  const MarkLostScreen({super.key, required this.pet});

  final Pet pet;

  @override
  ConsumerState<MarkLostScreen> createState() => _MarkLostScreenState();
}

class _MarkLostScreenState extends ConsumerState<MarkLostScreen> {
  final _form = GlobalKey<FormState>();
  final _reward = TextEditingController();
  final _phone = TextEditingController();
  DateTime _lastSeenAt = DateTime.now();
  LatLng? _lastSeen;
  bool _busy = false;

  @override
  void dispose() {
    _reward.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final start = _lastSeen ?? (await currentPosition().then((p) => p == null ? null : toLatLng(p)));
    if (!mounted) return;
    final picked = await context.push<LatLng>('/pick-location', extra: start);
    if (picked != null) setState(() => _lastSeen = picked);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final report = await ref
          .read(apiProvider)
          .markPetLost(
            widget.pet.id,
            lastSeen: _lastSeen!,
            lastSeenAt: _lastSeenAt,
            rewardTnd: int.tryParse(_reward.text.trim()),
            contactPhone: _phone.text.trim(),
          );
      ref
        ..invalidate(myPetsProvider)
        ..invalidate(myLostReportsProvider);
      if (mounted) context.pop('/lost/${report.id}'); // the report opens next
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pet = widget.pet;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.markNamedLost(pet.name))),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  spacing: 12,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox.square(dimension: 64, child: NetworkPhoto(pet.photos.firstOrNull?.url)),
                    ),
                    Expanded(
                      child: Text(
                        l10n.markLostIntro(pet.photos.length),
                        style: TextStyle(color: context.tokens.muted, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.clock),
              title: Text(l10n.lastSeenAt),
              subtitle: Text(formatDateTime(context, _lastSeenAt)),
              trailing: TextButton(
                onPressed: () async {
                  final picked = await pickDateTime(context, _lastSeenAt);
                  if (picked != null) setState(() => _lastSeenAt = picked);
                },
                child: Text(l10n.change),
              ),
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
            const SizedBox(height: 16),
            FieldLabel(l10n.rewardOptional),
            TextFormField(
              controller: _reward,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              decoration: InputDecoration(prefixIcon: const Icon(LucideIcons.gift), suffixText: l10n.currencyTnd),
              validator: (v) => (int.tryParse(v ?? '') ?? 1) > 100000 ? l10n.rewardTooHigh : null,
            ),
            const SizedBox(height: 16),
            FieldLabel(l10n.phoneOptional),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(prefixIcon: const Icon(LucideIcons.phone), helperText: l10n.phoneHelp),
              validator: (v) => (v ?? '').trim().isEmpty || RegExp(r'^[+0-9 ()-]{6,20}$').hasMatch(v!.trim())
                  ? null
                  : l10n.phoneInvalid,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: const BoxDecoration(
              gradient: Brand.lostGradient,
              borderRadius: BorderRadius.all(Radius.circular(26)),
            ),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
              onPressed: _busy || _lastSeen == null ? null : _submit,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(LucideIcons.megaphone),
              label: Text(l10n.publishReport),
            ),
          ),
        ),
      ),
    );
  }
}
