import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../api/providers.dart';
import '../auth/auth_controller.dart';
import '../l10n/app_localizations.dart';
import '../reports/lost_report_detail_screen.dart' show confirm;
import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';
import 'admin_screen.dart' show UserAvatar, UserPills;

/// For admins: one account, what they posted (hidden too), and what admins did about them.
/// Suspend or lift a suspension, take back association status.
class AdminUserScreen extends ConsumerWidget {
  const AdminUserScreen({super.key, required this.id});

  final String id;

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action) async {
    try {
      await action();
      ref.invalidate(adminUserProvider(id));
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _ban(BuildContext context, WidgetRef ref, AdminUser user) async {
    final ban = await showModalBottomSheet<(int?, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BanSheet(name: user.displayName),
    );
    if (ban == null || !context.mounted) return;
    await _run(context, ref, () => ref.read(apiProvider).banUser(id, days: ban.$1, reason: ban.$2));
  }

  Future<void> _unban(BuildContext context, WidgetRef ref, AdminUser user) async {
    final l10n = context.l10n;
    if (!await confirm(context, l10n.liftSuspensionOf(user.displayName), l10n.liftSuspension)) return;
    if (context.mounted) await _run(context, ref, () => ref.read(apiProvider).unbanUser(id));
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref, AdminUser user) async {
    final l10n = context.l10n;
    if (!await confirm(context, l10n.revokeAssociationQuestion(user.associationName!), l10n.revoke)) return;
    if (context.mounted) await _run(context, ref, () => ref.read(apiProvider).revokeAssociation(id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final detail = ref.watch(adminUserProvider(id));
    return Scaffold(
      appBar: AppBar(title: Text(detail.value?.user.displayName ?? l10n.adminUsers)),
      body: switch (detail) {
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: () => ref.refresh(adminUserProvider(id).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              FadeSlideIn(child: _Header(value.user)),
              const SizedBox(height: 12),
              FadeSlideIn(index: 1, child: _actions(context, ref, value.user)),
              _Section(
                title: l10n.userLostPets(value.lostReports.length),
                index: 2,
                children: [
                  for (final r in value.lostReports)
                    _ContentTile(
                      photoUrl: r.photos.firstOrNull?.url,
                      title: r.name,
                      date: r.lastSeenAt,
                      pill: StatusPill(
                        statusLabel(l10n, r.status),
                        tone: reportStatusTone(r.status),
                        icon: reportStatusIcon(r.status),
                      ),
                      hidden: r.hidden,
                      onTap: () => context.push('/lost/${r.id}'),
                    ),
                ],
              ),
              _Section(
                title: l10n.userSightings(value.sightings.length),
                index: 3,
                children: [
                  for (final s in value.sightings)
                    _ContentTile(
                      photoUrl: s.photos.firstOrNull?.url,
                      title: s.isStray
                          ? l10n.strayOf(speciesLabel(l10n, s.species))
                          : l10n.sightingOf(speciesLabel(l10n, s.species)),
                      date: s.seenAt,
                      hidden: s.hidden,
                      onTap: () => context.push('/sightings/${s.id}'),
                    ),
                ],
              ),
              _Section(
                title: l10n.adminHistory,
                index: 4,
                empty: l10n.noAdminHistory,
                children: [for (final a in value.history) AdminActionTile(a)],
              ),
            ],
          ),
        ),
        AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(adminUserProvider(id))),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _actions(BuildContext context, WidgetRef ref, AdminUser user) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        if (user.banned) ...[
          Note(
            [
              user.bannedForever
                  ? l10n.suspendedForGood
                  : l10n.suspendedUntil(formatDateTime(context, user.bannedUntil!)),
              if (user.banReason case final reason?) l10n.suspendedReason(reason),
            ].join('\n'),
            tone: Tone.lost,
            icon: LucideIcons.shieldBan,
          ),
          FilledButton.icon(
            onPressed: () => _unban(context, ref, user),
            icon: const Icon(LucideIcons.shieldCheck),
            label: Text(l10n.liftSuspension),
          ),
        ] else if (user.role != Role.admin)
          OutlinedButton.icon(
            onPressed: () => _ban(context, ref, user),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.tokens.tone(Tone.lost).$2,
              side: BorderSide(color: context.tokens.tone(Tone.lost).$2),
            ),
            icon: const Icon(LucideIcons.shieldBan),
            label: Text(l10n.suspend),
          ),
        if (user.associationName != null)
          OutlinedButton.icon(
            onPressed: () => _revoke(context, ref, user),
            icon: const Icon(LucideIcons.heartOff),
            label: Text(l10n.revokeAssociation),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.user);

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final joined = DateFormat.yMMMd(dateLocale(context)).format(user.createdAt);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Row(
              spacing: 14,
              children: [
                UserAvatar(user.displayName, radius: 28),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName, style: theme.textTheme.titleLarge),
                      SelectableText(user.email, style: theme.textTheme.bodyMedium?.copyWith(color: tokens.muted)),
                      Text(l10n.joinedOn(joined), style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted)),
                    ],
                  ),
                ),
              ],
            ),
            if (user.associationName case final name?) AssociationBadge(name),
            UserPills(user),
            Row(
              children: [
                _Count(user.lostReports, l10n.statLostPets),
                _Count(user.sightings, l10n.statSightings),
                _Count(user.reportsReceived, l10n.statReports),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.value, this.label);

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text('$value', style: Theme.of(context).textTheme.headlineSmall),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.tokens.muted)),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.index, required this.children, this.empty});

  final String title;
  final int index;
  final List<Widget> children;
  final String? empty; // shown when there's nothing; without it, an empty section is left out

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty && empty == null) return const SizedBox.shrink();
    return FadeSlideIn(
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (children.isEmpty)
              Text(empty!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.tokens.muted))
            else
              ...children,
          ],
        ),
      ),
    );
  }
}

class _ContentTile extends StatelessWidget {
  const _ContentTile({
    required this.photoUrl,
    required this.title,
    required this.date,
    required this.hidden,
    required this.onTap,
    this.pill,
  });

  final String? photoUrl;
  final String title;
  final DateTime date;
  final bool hidden;
  final VoidCallback onTap;
  final Widget? pill;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox.square(dimension: 48, child: NetworkPhoto(photoUrl)),
        ),
        title: Text(title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ?pill,
              if (hidden) StatusPill(l10n.hiddenLabel, tone: Tone.injured, icon: LucideIcons.eyeOff),
              Text(timeAgo(l10n, date)),
            ],
          ),
        ),
        trailing: const ForwardIcon(),
        onTap: onTap,
      ),
    );
  }
}

String adminActionLabel(AppLocalizations l10n, AdminActionEntry entry) => switch (entry.action) {
  AdminAction.approveAssociation => l10n.actionApprovedAssociation,
  AdminAction.rejectAssociation => l10n.actionRejectedAssociation,
  AdminAction.revokeAssociation => l10n.actionRevokedAssociation,
  AdminAction.hideContent => l10n.actionHidden(_targetLabel(l10n, entry.targetType)),
  AdminAction.restoreContent => l10n.actionRestored(_targetLabel(l10n, entry.targetType)),
  AdminAction.dismissReports => l10n.actionDismissed(_targetLabel(l10n, entry.targetType)),
  AdminAction.deleteContent => l10n.actionDeleted(_targetLabel(l10n, entry.targetType)),
  AdminAction.banUser => l10n.actionBanned,
  AdminAction.unbanUser => l10n.actionUnbanned,
};

String _targetLabel(AppLocalizations l10n, String type) => switch (type) {
  'LOST_REPORT' => l10n.targetLostReport,
  'SIGHTING' => l10n.targetSighting,
  'MESSAGE' => l10n.targetMessage,
  _ => type,
};

IconData _actionIcon(AdminAction action) => switch (action) {
  AdminAction.approveAssociation => LucideIcons.heartHandshake,
  AdminAction.rejectAssociation || AdminAction.revokeAssociation => LucideIcons.heartOff,
  AdminAction.hideContent => LucideIcons.eyeOff,
  AdminAction.restoreContent => LucideIcons.eye,
  AdminAction.dismissReports => LucideIcons.flagOff,
  AdminAction.deleteContent => LucideIcons.trash2,
  AdminAction.banUser => LucideIcons.shieldBan,
  AdminAction.unbanUser => LucideIcons.shieldCheck,
};

/// One admin action: what, by whom, when. [showUser] adds who it was about.
class AdminActionTile extends StatelessWidget {
  const AdminActionTile(this.entry, {super.key, this.showUser = false});

  final AdminActionEntry entry;
  final bool showUser;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(color: context.tokens.muted);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Icon(_actionIcon(entry.action), size: 20, color: context.tokens.accent),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(adminActionLabel(l10n, entry)),
              if (showUser && entry.userName != null)
                Text(l10n.aboutUser(entry.userName!), style: Theme.of(context).textTheme.titleSmall),
              if (entry.note case final note?) Text(note, textDirection: textDirectionOf(note), style: muted),
              Text('${entry.adminName ?? l10n.deletedAdmin} · ${timeAgo(l10n, entry.createdAt)}', style: muted),
            ],
          ),
        ),
      ],
    );
  }
}

/// How long, and why (shown to the user). Returns (days, reason); days null = for good.
class _BanSheet extends StatefulWidget {
  const _BanSheet({required this.name});

  final String name;

  @override
  State<_BanSheet> createState() => _BanSheetState();
}

class _BanSheetState extends State<_BanSheet> {
  static const _durations = <int?>[1, 7, 30, null];

  final _reason = TextEditingController();
  int? _days = 7;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
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
            spacing: 12,
            children: [
              Text(l10n.suspendWho(widget.name), style: Theme.of(context).textTheme.titleLarge),
              Text(l10n.suspendExplain, style: TextStyle(color: context.tokens.muted)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final days in _durations)
                    ChoiceChip(
                      label: Text(days == null ? l10n.forGood : l10n.daysCount(days)),
                      selected: _days == days,
                      onSelected: (_) => setState(() => _days = days),
                    ),
                ],
              ),
              TextField(
                controller: _reason,
                maxLength: 500,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(hintText: l10n.suspendReasonHint, counterText: ''),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, (_days, _reason.text.trim())),
                // The deep coral of the "lost" button, so the white label stays readable
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFBE123C), foregroundColor: Colors.white),
                icon: const Icon(LucideIcons.shieldBan),
                label: Text(l10n.suspend),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
