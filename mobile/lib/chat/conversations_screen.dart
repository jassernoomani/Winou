import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/models.dart';
import '../api/providers.dart';
import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';

/// Conversations with finders (about my pets) and with owners (about animals I saw).
class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.messages)),
      body: switch (ref.watch(conversationsProvider)) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(conversationsProvider.future),
          child: value.isEmpty
              ? ListView(
                  children: [
                    FadeSlideIn(
                      child: EmptyState(icon: Icons.forum_rounded, text: l10n.noConversations),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: value.length,
                  itemBuilder: (context, i) => FadeSlideIn(
                    index: i,
                    child: Card(clipBehavior: Clip.antiAlias, child: _ConversationTile(value[i])),
                  ),
                ),
        ),
        AsyncError(:final error) => ErrorView(error: error, onRetry: () => ref.invalidate(conversationsProvider)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile(this.conversation);

  final Conversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = conversation;
    final last = c.lastMessage;
    final unread = c.unread > 0;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox.square(dimension: 56, child: NetworkPhoto(c.sightingPhotoUrl)),
      ),
      title: Text('${c.otherName} · ${c.petName}', style: unread ? const TextStyle(fontWeight: FontWeight.w800) : null),
      subtitle: Text(
        last == null ? l10n.aboutPet(c.petName) : (last.mine ? l10n.youSaid(last.body) : last.body),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 6,
        children: [
          Text(
            timeAgo(l10n, last?.createdAt ?? c.createdAt),
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: unread ? Brand.coralDeep : Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          if (unread)
            Badge(label: Text('${c.unread}'), backgroundColor: Brand.coralDeep)
          else if (c.caseClosed)
            const Icon(Icons.home_rounded, size: 18, color: Brand.green),
        ],
      ),
      onTap: () async {
        await context.push('/conversations/${c.id}');
        ref.invalidate(conversationsProvider); // now read
      },
    );
  }
}
