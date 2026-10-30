import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/models.dart';
import '../auth/auth_controller.dart';
import '../l10n/app_localizations.dart';
import '../reports/lost_report_detail_screen.dart' show confirm;
import 'common.dart';

/// Admin entries for the ⋮ menu of any lost report or sighting: who posted it, hide or restore,
/// delete. On the admin's own content, only hide or restore (the owner's delete is there already).
/// Their values start with "admin:", for [runAdminAction].
List<PopupMenuEntry<String>> adminMenuItems(
  AppLocalizations l10n, {
  required bool hidden,
  required bool mine,
  required String? authorId,
}) => [
  const PopupMenuDivider(),
  if (!mine && authorId != null) PopupMenuItem(value: 'admin:author', child: Text(l10n.viewAuthor)),
  PopupMenuItem(value: hidden ? 'admin:restore' : 'admin:hide', child: Text(hidden ? l10n.restore : l10n.hideNow)),
  if (!mine) PopupMenuItem(value: 'admin:delete', child: Text(l10n.adminDelete)),
];

/// Runs an [adminMenuItems] entry. Returns true when the content is gone, so the screen closes.
Future<bool> runAdminAction(
  BuildContext context,
  WidgetRef ref,
  String action,
  ReportTarget type,
  String id, {
  String? authorId,
}) async {
  final l10n = context.l10n;
  final api = ref.read(apiProvider);
  try {
    switch (action) {
      case 'admin:author':
        await context.push('/admin/users/$authorId');
        return false;
      case 'admin:hide':
        await api.hideContent(type, id);
        if (context.mounted) _say(context, l10n.hiddenFromOthers);
        return false;
      case 'admin:restore':
        await api.restoreHidden(type, id);
        if (context.mounted) _say(context, l10n.shownAgain);
        return false;
      case 'admin:delete':
        if (!await confirm(context, l10n.deleteForGood, l10n.delete)) return false;
        await api.deleteContent(type, id);
        return true;
    }
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
  return false;
}

void _say(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
