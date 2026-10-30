import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../api/providers.dart';
import '../auth/auth_controller.dart';
import '../push.dart';
import '../push_texts.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';

/// Every notification the user was sent, newest first. Opening the list marks them read; tapping
/// one opens what it was about.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Seen now: the bell's count goes, while this list still shows which ones were new
    ref.read(apiProvider).markNotificationsRead().then((_) {
      if (mounted) ref.invalidate(unreadNotificationsProvider);
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notifications)),
      body: switch (ref.watch(notificationsProvider)) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(notificationsProvider.future),
          child: value.items.isEmpty
              ? ListView(
                  children: [
                    FadeSlideIn(
                      child: EmptyState(icon: LucideIcons.bellOff, text: l10n.noNotifications),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: value.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => FadeSlideIn(index: i, child: _Item(value.items[i])),
                ),
        ),
        AsyncError(:final error) => ErrorView(error: error, onRetry: () => ref.invalidate(notificationsProvider)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Item extends StatelessWidget {
  const _Item(this.item);

  final AppNotification item;

  static IconData _icon(String? type) => switch (type) {
    'match' => LucideIcons.search,
    'confirmed' || 'found' => LucideIcons.house,
    'message' => LucideIcons.messageCircle,
    'help' => LucideIcons.heartPulse,
    'lost' => LucideIcons.megaphone,
    'association' => LucideIcons.heartHandshake,
    'admin' => LucideIcons.shieldCheck,
    _ => LucideIcons.bell,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final title = pushText(l10n, item.titleKey, item.titleArgs) ?? l10n.notifications;
    final body = item.body ?? pushText(l10n, item.bodyKey, item.bodyArgs);
    final route = routeOfData(item.data);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: route == null ? null : () => context.push(route),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(shape: BoxShape.circle, color: tokens.tonal),
                child: Icon(_icon(item.data['type']), size: 20, color: tokens.accent),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 3,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    if (body != null)
                      Text(
                        body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textDirection: item.body != null ? textDirectionOf(body) : null, // a message as written
                        style: TextStyle(color: tokens.muted, height: 1.35),
                      ),
                    Text(timeAgo(l10n, item.createdAt), style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (!item.read)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: tokens.accent),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
