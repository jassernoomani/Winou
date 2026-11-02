import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/models.dart';
import '../api/providers.dart';
import '../auth/auth_controller.dart';
import '../push.dart';
import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';
import '../widgets/location.dart';
import '../widgets/photo_upload.dart' show pickFromGallery, takePhoto;
import '../widgets/photo_viewer.dart';
import '../widgets/report_sheet.dart';

/// Messages between a pet's owner and a finder. New messages arrive by push while the screen is
/// open, and a slow poll covers phones with notifications turned off.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const _poll = Duration(seconds: 15);

  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _olderLoading = false;
  bool _hasOlder = true;
  bool _sending = false;
  Object? _error;
  final Set<String> _arrived = {}; // received or sent while open: these pop in
  Timer? _timer;
  StreamSubscription<String>? _incoming;

  @override
  void initState() {
    super.initState();
    openConversations.add(widget.id);
    _incoming = incomingMessages.stream.where((id) => id == widget.id).listen((_) => _refresh());
    _timer = Timer.periodic(_poll, (_) => _refresh());
    _scroll.addListener(() {
      // The list is reversed: the end of the scroll is the oldest message
      if (_scroll.position.extentAfter < 200) _loadOlder();
    });
    _refresh();
    // A "new message" banner for this chat is answered by opening it
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    });
  }

  @override
  void dispose() {
    openConversations.remove(widget.id);
    _incoming?.cancel();
    _timer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The newest page, merged with what is already loaded. Also marks the conversation read.
  Future<void> _refresh() async {
    try {
      final newest = await ref.read(apiProvider).messages(widget.id);
      if (!mounted) return;
      setState(() {
        if (!_loading) _arrived.addAll(newest.map((m) => m.id).where((id) => !_messages.any((m) => m.id == id)));
        _messages = _merge(_messages, newest);
        _loading = false;
        _error = null;
        if (newest.length < 50) _hasOlder = false;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _messages.isEmpty ? e : null);
    }
  }

  Future<void> _loadOlder() async {
    if (_olderLoading || !_hasOlder || _messages.isEmpty) return;
    _olderLoading = true;
    try {
      final older = await ref.read(apiProvider).messages(widget.id, before: _messages.first.createdAt);
      if (!mounted) return;
      setState(() {
        _messages = _merge(older, _messages);
        _hasOlder = older.length == 50;
      });
    } catch (_) {
      // Scrolling up again retries
    } finally {
      _olderLoading = false;
    }
  }

  static List<ChatMessage> _merge(List<ChatMessage> a, List<ChatMessage> b) {
    final byId = {for (final m in a) m.id: m, for (final m in b) m.id: m};
    return byId.values.toList()..sort((x, y) => x.createdAt.compareTo(y.createdAt));
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    await _deliver(() => ref.read(apiProvider).sendMessage(widget.id, body: text), clearInput: true);
  }

  /// Camera, gallery, or "share a place" (where the animal is right now).
  Future<void> _attach() async {
    final l10n = context.l10n;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: Text(l10n.camera),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.images),
              title: Text(l10n.gallery),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.mapPin),
              title: Text(l10n.sharePlace),
              subtitle: Text(l10n.sharePlaceHelp),
              onTap: () => Navigator.pop(context, 'place'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    final api = ref.read(apiProvider);
    if (choice == 'place') {
      final here = await currentPosition();
      if (!mounted) return;
      final place = await context.push<LatLng>('/pick-location', extra: here == null ? null : toLatLng(here));
      if (place != null) await _deliver(() => api.sendMessage(widget.id, location: place));
      return;
    }
    final photo = choice == 'camera' ? await takePhoto() : (await pickFromGallery(1)).firstOrNull;
    if (photo != null) await _deliver(() => api.sendChatPhoto(widget.id, photo.file.path));
  }

  Future<void> _deliver(Future<ChatMessage> Function() send, {bool clearInput = false}) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final sent = await send();
      if (clearInput) _input.clear();
      if (mounted) {
        setState(() {
          _arrived.add(sent.id);
          _messages = _merge(_messages, [sent]);
        });
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Long press on the other person's message. Reported, it disappears from this side at once.
  Future<void> _report(ChatMessage message) async {
    if (await reportContent(context, ref, ReportTarget.message, message.id) == true && mounted) {
      setState(() => _messages = _messages.where((m) => m.id != message.id).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final conversation = ref.watch(conversationProvider(widget.id)).value;
    return Scaffold(
      appBar: AppBar(
        title: conversation == null
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    spacing: 6,
                    children: [
                      Flexible(child: Text(conversation.otherName, overflow: TextOverflow.ellipsis)),
                      if (conversation.otherAssociation case final association?)
                        AssociationBadge(association, size: 18),
                    ],
                  ),
                  Text(l10n.aboutPet(conversation.petName), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
        actions: [
          if (conversation != null)
            IconButton(
              icon: const Icon(LucideIcons.pawPrint),
              tooltip: conversation.petName,
              // The owner sees the match; the finder sees the (public) lost report
              onPressed: () => context.push(
                conversation.isOwner && conversation.matchId != null
                    ? '/matches/${conversation.matchId}'
                    : '/lost/${conversation.lostReportId}',
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (conversation != null && conversation.caseClosed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Note(l10n.caseClosedChat(conversation.petName), tone: Tone.found, icon: LucideIcons.house),
            ),
          if (conversation != null && conversation.matchConfirmed && !conversation.caseClosed)
            Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 0), child: HandoverCard(conversation)),
          Expanded(child: _body(context)),
          _Composer(controller: _input, sending: _sending, onSend: _send, onAttach: _attach),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = context.l10n;
    if (_error != null) return ErrorView(error: _error!, onRetry: _refresh);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_messages.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: FadeSlideIn(
            child: EmptyState(icon: LucideIcons.hand, text: '${l10n.noMessagesYet}\n\n${l10n.chatPrivacy}'),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      reverse: true, // newest at the bottom, and the list stays there as messages arrive
      padding: const EdgeInsets.all(12),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final message = _messages[_messages.length - 1 - i];
        final bubble = _Bubble(message, onReport: message.mine ? null : () => _report(message));
        return _arrived.contains(message.id)
            ? FadeSlideIn(
                key: ValueKey(message.id),
                offset: Offset(message.mine ? 0.15 : -0.15, 0.2),
                scale: 0.85,
                duration: const Duration(milliseconds: 300),
                child: bubble,
              )
            : bubble;
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.message, {this.onReport});

  static const _mediaWidth = 220.0;

  final ChatMessage message;
  final VoidCallback? onReport; // the other person's messages: long press to report

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    final time = DateFormat.Hm(dateLocale(context)).format(message.createdAt.toLocal());
    final media = message.photoPath != null || message.location != null;
    final bubble = Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: media ? const EdgeInsets.fromLTRB(5, 5, 5, 7) : const EdgeInsets.fromLTRB(14, 9, 14, 7),
          decoration: BoxDecoration(
            color: mine ? Brand.blue : context.tokens.card,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(mine ? 20 : 6),
              bottomRight: Radius.circular(mine ? 6 : 20),
            ),
            boxShadow: mine
                ? [BoxShadow(color: Brand.blue.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (message.photoPath case final path?) _ChatPhoto(path, width: _mediaWidth),
              if (message.location case final place?) _Place(place, width: _mediaWidth, mine: mine),
              // The other person's messages answer a long press with "Report" instead of selecting text
              if (message.body case final body?)
                Padding(
                  padding: media ? const EdgeInsets.fromLTRB(9, 6, 9, 0) : EdgeInsets.zero,
                  child: onReport == null
                      ? SelectableText(
                          body,
                          textDirection: textDirectionOf(body),
                          style: TextStyle(color: mine ? Brand.ink : null, fontSize: 15),
                        )
                      : Text(body, textDirection: textDirectionOf(body), style: const TextStyle(fontSize: 15)),
                ),
              const SizedBox(height: 2),
              Padding(
                padding: media ? const EdgeInsetsDirectional.only(end: 9) : EdgeInsets.zero,
                child: Text(
                  time,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: mine ? Brand.ink.withValues(alpha: 0.7) : null),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (message.hidden) {
      return Opacity(
        opacity: 0.55,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            bubble,
            Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 4),
              child: Text(context.l10n.messageHidden, style: Theme.of(context).textTheme.labelSmall),
            ),
          ],
        ),
      );
    }
    final shown = onReport == null ? bubble : GestureDetector(onLongPress: onReport, child: bubble);
    final warning = switch (message.warning) {
      'payment' => context.l10n.warningPayment,
      'link' => context.l10n.warningLink,
      _ => null,
    };
    if (warning == null || mine) return shown;
    // A scam pattern in the other person's message: say so right under it
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shown,
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Brand.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Brand.amber.withValues(alpha: 0.6)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                const Icon(LucideIcons.shieldAlert, size: 16, color: Brand.amber),
                Expanded(child: Text(warning, style: const TextStyle(fontSize: 12.5, height: 1.35))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Once the owner confirmed the match. The finder: the owner's private detail to check on the
/// animal, and the handover tips (open). The owner: the tips (closed, to keep the chat in view).
class HandoverCard extends StatelessWidget {
  const HandoverCard(this.conversation, {super.key});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final finder = !conversation.isOwner;
    Widget line(IconData icon, String text, {bool strong = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Icon(icon, size: 18, color: tokens.accent),
          Expanded(
            child: Text(
              text,
              textDirection: textDirectionOf(text),
              style: TextStyle(fontSize: 14, height: 1.35, fontWeight: strong ? FontWeight.w800 : null),
            ),
          ),
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(color: tokens.card, borderRadius: BorderRadius.circular(20), boxShadow: cardShadow),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: finder,
          shape: const RoundedRectangleBorder(),
          leading: Icon(finder ? LucideIcons.shieldCheck : LucideIcons.handshake, color: tokens.accent),
          title: Text(
            finder ? l10n.checkOwnerTitle : l10n.handoverTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          children: [
            if (finder) ...[
              if (conversation.ownerDetail case final detail?) ...[
                line(LucideIcons.lock, l10n.ownerDetailSays(detail), strong: true),
                line(LucideIcons.scanEye, l10n.ownerDetailCheck),
              ] else
                line(LucideIcons.messageCircleQuestion, l10n.ownerDetailAsk),
              if (conversation.microchipped == true) line(LucideIcons.cpu, l10n.microchippedTip),
            ],
            line(LucideIcons.sun, l10n.handoverTipPublic),
            line(LucideIcons.images, l10n.handoverTipProof),
            line(LucideIcons.banknote, l10n.handoverTipNoPay),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.sending, required this.onSend, required this.onAttach});

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 4, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: l10n.chatAttach,
              onPressed: sending ? null : onAttach,
              icon: const Icon(LucideIcons.circlePlus),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l10n.writeMessage,
                  counterText: '',
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 6),
            DecoratedBox(
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Brand.blue),
              child: IconButton(
                tooltip: l10n.send,
                onPressed: sending ? null : onSend,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: sending
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Brand.ink),
                        )
                      : const DirectionalIcon(LucideIcons.send, color: Brand.ink),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A chat photo, loaded with the user's token (only the two participants may see it). Tap: full screen.
class _ChatPhoto extends ConsumerWidget {
  const _ChatPhoto(this.path, {required this.width});

  final String path;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(messagePhotoProvider(path));
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: width,
        height: width * 1.15,
        child: switch (bytes) {
          AsyncData(:final value) => GestureDetector(
            onTap: () => openImageViewer(context, [MemoryImage(value)]),
            child: Image.memory(value, fit: BoxFit.cover, gaplessPlayback: true),
          ),
          AsyncError() => const NetworkPhoto(null),
          _ => ColoredBox(
            color: Colors.black12,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        },
      ),
    );
  }
}

/// A place shared in the chat: a small map, and a button to open it in the phone's maps app.
class _Place extends StatelessWidget {
  const _Place(this.point, {required this.width, required this.mine});

  final LatLng point;
  final double width;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final at = '${point.latitude},${point.longitude}';
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IgnorePointer(child: LocationPreview(point, height: 130)),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: mine ? Brand.ink : null),
            onPressed: () => launchUrl(Uri.parse('geo:$at?q=$at'), mode: LaunchMode.externalApplication),
            icon: const Icon(LucideIcons.map, size: 18),
            label: Text(l10n.openInMaps),
          ),
        ],
      ),
    );
  }
}
