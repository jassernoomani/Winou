import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../api/models.dart';
import '../config.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// The page a shared link opens: the app if installed (Android App Links), a web page otherwise.
String lostPetLink(String reportId) => '${Config.apiUrl}/lost/$reportId';

/// Share a lost pet: a poster image for WhatsApp, Facebook or printing, or just the link.
Future<void> shareLostPet(BuildContext context, LostReport report) =>
    showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => _ShareSheet(report));

String _shareText(AppLocalizations l10n, LostReport report) =>
    l10n.shareLostText(report.name, speciesLabel(l10n, report.species).toLowerCase(), lostPetLink(report.id));

class _ShareSheet extends StatefulWidget {
  const _ShareSheet(this.report);

  final LostReport report;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _poster = GlobalKey();
  bool _ready = false; // the photo is loaded, so the image won't have a blank in its place
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final url = widget.report.photos.firstOrNull?.url;
    if (url == null) {
      _ready = true;
    } else if (!_ready) {
      precacheImage(NetworkImage(url), context).whenComplete(() {
        if (mounted) setState(() => _ready = true);
      });
    }
  }

  Future<void> _shareImage() async {
    setState(() => _busy = true);
    final l10n = context.l10n;
    final box = context.findRenderObject() as RenderBox?;
    try {
      final boundary = _poster.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1080 / _Poster.width); // 1080 px wide, for print too
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('${Directory.systemTemp.path}/winou-${widget.report.id}.png')
        ..writeAsBytesSync(png!.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: _shareText(l10n, widget.report),
          sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareLink() => SharePlus.instance.share(ShareParams(text: _shareText(context.l10n, widget.report)));

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: lostPetLink(widget.report.id)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.linkCopied)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Text(l10n.shareTitle(widget.report.name), style: Theme.of(context).textTheme.titleLarge),
            Text(l10n.shareHelp, style: TextStyle(color: context.tokens.muted)),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.45),
                child: FittedBox(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(blurRadius: 16, color: Colors.black26)],
                    ),
                    child: RepaintBoundary(key: _poster, child: _Poster(widget.report)),
                  ),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _ready && !_busy ? _shareImage : null,
              icon: _busy || !_ready
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(LucideIcons.imageUp),
              label: Text(l10n.sharePoster),
            ),
            Row(
              spacing: 8,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareLink,
                    icon: const Icon(LucideIcons.share2),
                    label: Text(l10n.shareLink),
                  ),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyLink,
                    icon: const Icon(LucideIcons.copy),
                    label: Text(l10n.copyLink),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The poster: always light (it gets printed), 3:4, big photo, name, when, and a QR code to the pet's page.
class _Poster extends StatelessWidget {
  const _Poster(this.report);

  static const width = 360.0;
  static const _coral = Color(0xFFBE123C);
  static const _ink = Brand.ink;
  static const _muted = Color(0xFF526079);

  final LostReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = dateLocale(context);
    final seen = DateFormat.yMMMMd(locale).add_Hm().format(report.lastSeenAt);
    return Theme(
      data: winouTheme(Brightness.light),
      child: Container(
        width: width,
        height: width * 4 / 3,
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: _coral,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                switch (report.species) {
                  Species.cat => l10n.posterLostCat,
                  Species.dog => l10n.posterLostDog,
                  Species.other => l10n.posterLostPet,
                },
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
            SizedBox(height: 200, child: NetworkPhoto(report.photos.firstOrNull?.url)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _ink, fontSize: 30, fontWeight: FontWeight.w900, height: 1.1),
                    ),
                    Text(
                      l10n.lastSeenOn(seen),
                      style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    if (report.description case final description?)
                      Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _ink, fontSize: 12.5, height: 1.3),
                      ),
                    const Spacer(),
                    Row(
                      spacing: 12,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 4,
                            children: [
                              Text(
                                l10n.posterSeenIt,
                                style: const TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w900),
                              ),
                              Text(l10n.posterScan, style: const TextStyle(color: _muted, fontSize: 11, height: 1.3)),
                              const Wordmark(size: 20, color: Color(0xFF3884FF)),
                            ],
                          ),
                        ),
                        QrImageView(
                          data: lostPetLink(report.id),
                          size: 92,
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: _ink),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: _ink,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
