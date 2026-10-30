import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';
import 'auth_controller.dart';

/// Shown instead of the app while an admin has suspended the account: until when, and why.
class SuspendedScreen extends ConsumerStatefulWidget {
  const SuspendedScreen({super.key});

  @override
  ConsumerState<SuspendedScreen> createState() => _SuspendedScreenState();
}

class _SuspendedScreenState extends ConsumerState<SuspendedScreen> {
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      final lifted = await ref.read(authProvider.notifier).checkBan();
      if (!lifted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.stillSuspended)));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);
    final ban = auth.ban;
    if (ban == null) return const Scaffold(); // lifted: the router moves on
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: FadeSlideIn(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 16,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: context.tokens.tone(Tone.lost).$1),
                        child: Icon(LucideIcons.shieldBan, size: 44, color: context.tokens.tone(Tone.lost).$2),
                      ),
                    ),
                    Text(l10n.suspendedTitle, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                    Text(
                      ban.permanent ? l10n.suspendedForGood : l10n.suspendedUntil(formatDateTime(context, ban.until!)),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(color: context.tokens.muted),
                    ),
                    if (ban.reason case final reason?)
                      Note(l10n.suspendedReason(reason), tone: Tone.neutral, icon: LucideIcons.messageSquareText),
                    Text(
                      l10n.suspendedHelp,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: context.tokens.muted),
                    ),
                    const SizedBox(height: 8),
                    if (!ban.permanent && auth.signedIn)
                      FilledButton.icon(
                        onPressed: _checking ? null : _check,
                        icon: const Icon(LucideIcons.refreshCw),
                        label: Text(l10n.checkAgain),
                      ),
                    OutlinedButton.icon(
                      // The server refuses the account's requests, so it isn't told about the logout
                      onPressed: () => ref.read(authProvider.notifier).logout(expired: true),
                      icon: const Icon(LucideIcons.logOut),
                      label: Text(l10n.signOut),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
