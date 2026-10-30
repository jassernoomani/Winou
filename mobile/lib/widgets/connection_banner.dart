import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../connection.dart';
import '../theme.dart';
import '../uploads.dart';
import 'common.dart';

/// A slim bar above every screen while Winou can't be reached, or photos wait to be sent. The
/// screens move down under it rather than being covered.
class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final connection = ref.watch(connectionProvider);
    final waiting = ref.watch(uploadQueueProvider).length;
    final (String? text, IconData icon, Color color) = switch (connection) {
      Connection(online: false) => (l10n.offlineBanner, LucideIcons.wifiOff, const Color(0xFF526079)),
      Connection(serverReached: false) => (l10n.serverDownBanner, LucideIcons.serverOff, const Color(0xFF526079)),
      _ when waiting > 0 => (l10n.photosUploading(waiting), LucideIcons.cloudUpload, Brand.blue),
      _ => (null, LucideIcons.wifi, Brand.blue),
    };
    final media = MediaQuery.of(context);
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: text == null
              ? const SizedBox(width: double.infinity)
              : Material(
                  color: color,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, media.padding.top + 6, 16, 6),
                    child: Row(
                      spacing: 8,
                      children: [
                        Icon(icon, size: 16, color: Colors.white),
                        Expanded(
                          child: Text(
                            text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (waiting > 0 && text != l10n.photosUploading(waiting))
                          Text(
                            l10n.photosWaiting(waiting),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
        Expanded(
          // The bar took the status bar's place: screens below don't pad for it again
          child: text == null ? child : MediaQuery.removePadding(context: context, removeTop: true, child: child),
        ),
      ],
    );
  }
}
