import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../auth/auth_controller.dart';
import '../l10n/app_localizations.dart';
import 'common.dart';

String reasonLabel(AppLocalizations l10n, ReportReason reason) => switch (reason) {
  ReportReason.spam => l10n.reasonSpam,
  ReportReason.inappropriate => l10n.reasonInappropriate,
  ReportReason.fake => l10n.reasonFake,
  ReportReason.dangerous => l10n.reasonDangerous,
  ReportReason.other => l10n.reasonOther,
};

/// The "Report" button's sheet: a reason and an optional note. Returns true once sent and hidden
/// (the caller may then leave the screen), false once sent, null if cancelled.
Future<bool?> reportContent(BuildContext context, WidgetRef ref, ReportTarget type, String id) async {
  final hidden = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReportSheet(type: type, id: id, ref: ref),
  );
  if (hidden != null && context.mounted) {
    final l10n = context.l10n;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(hidden ? l10n.reportHiddenNow : l10n.reportThanks)));
  }
  return hidden;
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.type, required this.id, required this.ref});

  final ReportTarget type;
  final String id;
  final WidgetRef ref;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _note = TextEditingController();
  ReportReason? _reason;
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      final hidden = await widget.ref
          .read(apiProvider)
          .report(widget.type, widget.id, _reason!, note: _note.text.trim());
      if (mounted) Navigator.pop(context, hidden);
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom), // above the keyboard
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.reportWhy, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              RadioGroup<ReportReason>(
                groupValue: _reason,
                onChanged: (reason) => setState(() => _reason = reason),
                child: Column(
                  children: [
                    for (final reason in ReportReason.values)
                      RadioListTile<ReportReason>(
                        contentPadding: EdgeInsets.zero,
                        value: reason,
                        title: Text(reasonLabel(l10n, reason)),
                      ),
                  ],
                ),
              ),
              TextField(
                controller: _note,
                maxLength: 500,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(hintText: l10n.reportNoteHint, counterText: ''),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _reason == null || _sending ? null : _send,
                icon: _sending
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(LucideIcons.flag),
                label: Text(l10n.sendReport),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
