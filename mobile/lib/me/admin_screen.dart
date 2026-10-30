import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../api/providers.dart';
import '../auth/auth_controller.dart';
import '../reports/lost_report_detail_screen.dart' show confirm;
import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';
import '../widgets/report_sheet.dart';
import 'admin_dashboard.dart';
import 'admin_user_screen.dart' show AdminActionTile;

/// For admins: how Winou is doing, users to look up and ban, reported content to dismiss or hide,
/// association requests to approve or reject, hidden content to restore or delete, and what admins
/// did. The tabs with work waiting show how much. [tab] opens one (from a notification).
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key, this.tab});

  final String? tab; // dashboard, users, reported, requests, hidden or activity

  static const _tabs = ['dashboard', 'users', 'reported', 'requests', 'hidden', 'activity'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final summary = ref.watch(adminSummaryProvider).value;
    Widget counted(String label, int? count) => Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Text(label),
          if (count != null && count > 0) Badge.count(count: count),
        ],
      ),
    );
    return DefaultTabController(
      length: _tabs.length,
      initialIndex: _tabs.indexOf(tab ?? '').clamp(0, _tabs.length - 1),
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.admin),
          bottom: TabBar(
            isScrollable: true, // six tabs, longer in French
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l10n.adminDashboard),
              Tab(text: l10n.adminUsers),
              counted(l10n.adminReported, summary?.reported),
              counted(l10n.adminRequests, summary?.requests),
              counted(l10n.adminHidden, summary?.hidden),
              Tab(text: l10n.adminActivity),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AdminDashboard(),
            _Users(),
            _Content(hidden: false),
            _Requests(),
            _Content(hidden: true),
            _Activity(),
          ],
        ),
      ),
    );
  }
}

/// Everything admins did, newest first. Tap one to see the account it was about.
class _Activity extends ConsumerWidget {
  const _Activity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return _AdminList<AdminActionEntry>(
      provider: adminActionsProvider,
      empty: l10n.noAdminHistory,
      emptyIcon: LucideIcons.history,
      item: (entry) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: entry.userId == null ? null : () => context.push('/admin/users/${entry.userId}'),
          child: Padding(padding: const EdgeInsets.all(14), child: AdminActionTile(entry, showUser: true)),
        ),
      ),
    );
  }
}

/// Search by name or email, newest accounts first.
class _Users extends ConsumerStatefulWidget {
  const _Users();

  @override
  ConsumerState<_Users> createState() => _UsersState();
}

class _UsersState extends ConsumerState<_Users> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _bannedOnly = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _query = text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = adminUsersProvider((_query, _bannedOnly));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _search,
            onChanged: _onSearch,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(prefixIcon: const Icon(LucideIcons.search), hintText: l10n.searchUsers),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilterChip(
              label: Text(l10n.bannedOnly),
              avatar: const Icon(LucideIcons.shieldBan, size: 16),
              selected: _bannedOnly,
              onSelected: (value) => setState(() => _bannedOnly = value),
            ),
          ),
        ),
        Expanded(
          child: _AdminList<AdminUser>(
            provider: provider,
            empty: _bannedOnly ? l10n.noBannedUsers : l10n.noUsersFound,
            emptyIcon: LucideIcons.users,
            item: (u) => Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                leading: UserAvatar(u.displayName),
                title: Text(u.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Text(u.email, maxLines: 1, overflow: TextOverflow.ellipsis),
                    UserPills(u),
                  ],
                ),
                trailing: const ForwardIcon(),
                onTap: () async {
                  await context.push('/admin/users/${u.id}');
                  ref.invalidate(provider); // may have been banned since
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A round initial, for people without a photo.
class UserAvatar extends StatelessWidget {
  const UserAvatar(this.name, {super.key, this.radius = 22});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return CircleAvatar(
      radius: radius,
      backgroundColor: tokens.tonal,
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(color: tokens.accent, fontWeight: FontWeight.w800, fontSize: radius * 0.8),
      ),
    );
  }
}

/// Role, ban and reports at a glance; nothing for a plain user in good standing.
class UserPills extends StatelessWidget {
  const UserPills(this.user, {super.key});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (user.banned) StatusPill(l10n.banned, tone: Tone.lost, icon: LucideIcons.shieldBan),
        if (user.role == Role.admin) StatusPill(l10n.admin, tone: Tone.info, icon: LucideIcons.shieldCheck),
        if (user.associationName != null)
          StatusPill(l10n.association, tone: Tone.found, icon: LucideIcons.heartHandshake),
        if (user.reportsReceived > 0)
          StatusPill(l10n.reportsCount(user.reportsReceived), tone: Tone.injured, icon: LucideIcons.flag),
      ],
    );
  }
}

/// A list from [provider], with pull to refresh, an empty state and an error view.
class _AdminList<T> extends ConsumerWidget {
  const _AdminList({required this.provider, required this.empty, required this.emptyIcon, required this.item});

  final FutureProvider<List<T>> provider;
  final String empty;
  final IconData emptyIcon;
  final Widget Function(T) item;

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (ref.watch(provider)) {
    AsyncData(:final value) => RefreshIndicator(
      onRefresh: () => ref.refresh(provider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: value.isEmpty
            ? [
                FadeSlideIn(
                  child: EmptyState(icon: emptyIcon, text: empty),
                ),
              ]
            : [for (final (i, v) in value.indexed) FadeSlideIn(index: i, child: item(v))],
      ),
    ),
    AsyncError(:final error) => ErrorView(error: error, onRetry: () => ref.invalidate(provider)),
    _ => const Center(child: CircularProgressIndicator()),
  };
}

class _Requests extends ConsumerWidget {
  const _Requests();

  Future<void> _decide(BuildContext context, WidgetRef ref, AssociationRequest r, bool approve) async {
    try {
      await ref.read(apiProvider).decideAssociationRequest(r.id, approve: approve);
      ref
        ..invalidate(pendingAssociationRequestsProvider)
        ..invalidate(adminSummaryProvider);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return _AdminList<AssociationRequest>(
      provider: pendingAssociationRequestsProvider,
      empty: l10n.noPendingRequests,
      emptyIcon: LucideIcons.heartHandshake,
      item: (r) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 4,
            children: [
              Text(r.organisation, style: Theme.of(context).textTheme.titleMedium),
              InfoRow(LucideIcons.mapPin, r.city),
              InfoRow(LucideIcons.phone, r.contact),
              InfoRow(LucideIcons.user, '${r.userName ?? ''} · ${r.userEmail ?? ''}'),
              if (r.note case final note?) InfoRow(LucideIcons.textAlignStart, note),
              Text(timeAgo(l10n, r.createdAt), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: OutlinedButton(onPressed: () => _decide(context, ref, r, false), child: Text(l10n.reject)),
                  ),
                  Expanded(
                    child: FilledButton(onPressed: () => _decide(context, ref, r, true), child: Text(l10n.approve)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reported content: still shown ([hidden] false, dismiss or hide now) or hidden already
/// (restore or delete). Tap a lost report or sighting to open it, the author to see their account.
class _Content extends ConsumerWidget {
  const _Content({required this.hidden});

  final bool hidden;

  FutureProvider<List<HiddenItem>> get _provider => hidden ? hiddenContentProvider : reportedContentProvider;

  Future<void> _act(BuildContext context, WidgetRef ref, Future<void> Function() action, {String? question}) async {
    final l10n = context.l10n;
    if (question != null && !await confirm(context, question, l10n.delete)) return;
    try {
      await action();
      ref
        ..invalidate(reportedContentProvider)
        ..invalidate(hiddenContentProvider)
        ..invalidate(adminSummaryProvider);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final api = ref.read(apiProvider);
    return _AdminList<HiddenItem>(
      provider: _provider,
      empty: hidden ? l10n.noHiddenContent : l10n.noReportedContent,
      emptyIcon: LucideIcons.shieldCheck,
      item: (item) {
        final open = switch (item.type) {
          ReportTarget.lostReport => '/lost/${item.id}',
          ReportTarget.sighting => '/sightings/${item.id}',
          ReportTarget.message => null, // private: only shown here
        };
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: open == null
                ? null
                : () async {
                    await context.push(open);
                    ref
                      ..invalidate(_provider) // may have been acted on from there
                      ..invalidate(adminSummaryProvider);
                  },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  Row(
                    spacing: 12,
                    children: [
                      if (item.type != ReportTarget.message)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox.square(dimension: 56, child: NetworkPhoto(item.photoUrl)),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(switch (item.type) {
                              ReportTarget.lostReport => '${l10n.typeLostOne} · ${item.title ?? ''}',
                              ReportTarget.sighting => l10n.typeSighting,
                              ReportTarget.message => l10n.messageFrom(item.title ?? ''),
                            }, style: Theme.of(context).textTheme.titleMedium),
                            if (item.hiddenAt ?? item.lastReportedAt case final date?)
                              Text(timeAgo(l10n, date), style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      if (open != null) const ForwardIcon(),
                    ],
                  ),
                  if (item.text case final text? when text.isNotEmpty) Text(text, textDirection: textDirectionOf(text)),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      StatusPill(l10n.reportsCount(item.reports), tone: Tone.injured, icon: LucideIcons.flag),
                      for (final reason in item.reasons) StatusPill(reasonLabel(l10n, reason), tone: Tone.neutral),
                    ],
                  ),
                  for (final note in item.notes)
                    Text(
                      '“$note”',
                      textDirection: textDirectionOf(note),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  if ((item.authorId, item.authorName) case (final id?, final name?))
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () => context.push('/admin/users/$id'),
                        icon: const Icon(LucideIcons.user, size: 18),
                        label: Text(l10n.byAuthor(name)),
                      ),
                    ),
                  Row(
                    spacing: 8,
                    children: hidden
                        ? [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _act(
                                  context,
                                  ref,
                                  () => api.deleteContent(item.type, item.id),
                                  question: l10n.deleteForGood,
                                ),
                                child: Text(l10n.delete),
                              ),
                            ),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _act(context, ref, () => api.restoreHidden(item.type, item.id)),
                                child: Text(l10n.restore),
                              ),
                            ),
                          ]
                        : [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _act(context, ref, () => api.dismissReports(item.type, item.id)),
                                child: Text(l10n.dismissReports),
                              ),
                            ),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _act(context, ref, () => api.hideContent(item.type, item.id)),
                                child: Text(l10n.hideNow),
                              ),
                            ),
                          ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
