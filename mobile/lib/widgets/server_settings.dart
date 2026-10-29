import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config.dart';
import '../theme.dart';
import 'common.dart';

const _key = 'api_url';
const _storage = FlutterSecureStorage();

/// The API address saved in the app, if any, replaces the build's default. Call before runApp.
Future<void> loadServerAddress() async {
  try {
    Config.apiUrl = await _storage.read(key: _key) ?? Config.defaultApiUrl;
  } catch (_) {
    // Unreadable storage: keep the build's default
  }
}

/// "192.168.43.12" -> "http://192.168.43.12:8080": the laptop's API port unless one is given.
String normalizeServerAddress(String input) {
  var url = input.trim();
  if (url.isEmpty) return Config.defaultApiUrl;
  if (!url.contains('://')) url = 'http://$url';
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return url;
  final withPort = uri.hasPort || uri.scheme == 'https' ? uri : uri.replace(port: 8080);
  return withPort.toString().replaceFirst(RegExp(r'/+$'), '');
}

Future<bool> _reachable(String url) async {
  try {
    final dio = Dio(
      BaseOptions(connectTimeout: const Duration(seconds: 4), receiveTimeout: const Duration(seconds: 4)),
    );
    return (await dio.get('$url/health')).statusCode == 200;
  } catch (_) {
    return false;
  }
}

/// Edit the API address, e.g. the laptop's address on a phone hotspot. Returns true when changed.
Future<bool> editServerAddress(BuildContext context) async =>
    await showDialog<bool>(context: context, builder: (_) => const _ServerDialog()) ?? false;

class _ServerDialog extends StatefulWidget {
  const _ServerDialog();

  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  late final _address = TextEditingController(text: Config.apiUrl);
  bool? _ok; // result of the last test
  bool _testing = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final url = normalizeServerAddress(_address.text);
    setState(() {
      _address.text = url;
      _testing = true;
      _ok = null;
    });
    final ok = await _reachable(url);
    if (mounted) {
      setState(() {
        _testing = false;
        _ok = ok;
      });
    }
  }

  Future<void> _save() async {
    final url = normalizeServerAddress(_address.text);
    Config.apiUrl = url;
    try {
      if (url == Config.defaultApiUrl) {
        await _storage.delete(key: _key);
      } else {
        await _storage.write(key: _key, value: url);
      }
    } catch (_) {
      // Kept for this session only
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (okBackground, okForeground) = context.tokens.tone(Tone.found);
    final (badBackground, badForeground) = context.tokens.tone(Tone.injured);
    return AlertDialog(
      title: Text(l10n.serverAddress),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text(l10n.serverHelp, style: Theme.of(context).textTheme.bodySmall),
          TextField(
            controller: _address,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(prefixIcon: Icon(LucideIcons.server)),
            onChanged: (_) => setState(() => _ok = null),
            onSubmitted: (_) => _test(),
          ),
          if (_ok != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _ok! ? okBackground : badBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                spacing: 8,
                children: [
                  Icon(
                    _ok! ? LucideIcons.circleCheck : LucideIcons.circleX,
                    size: 18,
                    color: _ok! ? okForeground : badForeground,
                  ),
                  Expanded(
                    child: Text(
                      _ok! ? l10n.serverOk : l10n.serverUnreachable,
                      style: TextStyle(color: _ok! ? okForeground : badForeground),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _testing ? null : _test,
          child: _testing
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.testConnection),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}
