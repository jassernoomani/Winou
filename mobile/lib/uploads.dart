import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';
import 'api/models.dart';
import 'api/providers.dart';
import 'auth/auth_controller.dart';

const _key = 'pending_uploads';

/// A photo that couldn't be sent: a copy kept in the app's files until it is.
class PendingUpload {
  const PendingUpload({required this.id, required this.ownerPath, required this.file, required this.source});

  PendingUpload.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      ownerPath = json['owner'],
      file = json['file'],
      source = PhotoSource.values.firstWhere((s) => s.api == json['source']);

  final String id;
  final String ownerPath; // "/lost-reports/{id}" or "/sightings/{id}"
  final String file;
  final PhotoSource source;

  Map<String, dynamic> toJson() => {'id': id, 'owner': ownerPath, 'file': file, 'source': source.api};
}

/// Photos waiting for a connection. Kept on the phone, so they survive closing the app; sent when
/// the network or the server comes back, when the app starts, and every minute while some wait.
class UploadQueue extends Notifier<List<PendingUpload>> {
  bool _sending = false;
  Timer? _retry;

  @override
  List<PendingUpload> build() {
    ref.onDispose(() => _retry?.cancel());
    _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      if (saved == null) return;
      state = [for (final item in jsonDecode(saved) as List) PendingUpload.fromJson(item)];
      send();
    } catch (e) {
      debugPrint('pending uploads unreadable: $e');
    }
  }

  Future<void> _save() async {
    try {
      final store = await SharedPreferences.getInstance();
      state.isEmpty ? await store.remove(_key) : await store.setString(_key, jsonEncode(state));
    } catch (e) {
      debugPrint('pending uploads not saved: $e');
    }
  }

  /// Keeps a copy of [filePath] (the picker's file may be cleaned up) to send later.
  Future<void> add(String ownerPath, String filePath, PhotoSource source) async {
    final id = '${DateTime.now().microsecondsSinceEpoch}';
    final folder = Directory('${(await getApplicationSupportDirectory()).path}/pending')..createSync(recursive: true);
    final copy = await File(filePath).copy('${folder.path}/$id.jpg');
    state = [...state, PendingUpload(id: id, ownerPath: ownerPath, file: copy.path, source: source)];
    await _save();
    _scheduleRetry();
  }

  /// Sends what waits, in order, until the connection fails again.
  Future<void> send() async {
    if (_sending || state.isEmpty || !ref.read(authProvider).signedIn) return;
    _sending = true;
    try {
      final api = ref.read(apiProvider);
      while (state.isNotEmpty) {
        final next = state.first;
        try {
          if (File(next.file).existsSync()) await api.uploadPhoto(next.ownerPath, next.file, next.source);
        } on ApiException catch (e) {
          if (e.code == 'network') break; // still no connection: try again later
          debugPrint('pending photo dropped: ${e.message}'); // refused (report deleted, too many photos...)
        }
        _forget(next);
        await _save();
        ref
          ..invalidate(myLostReportsProvider)
          ..invalidate(mySightingsProvider);
      }
    } finally {
      _sending = false;
      _scheduleRetry();
    }
  }

  void _forget(PendingUpload upload) {
    state = [
      for (final u in state)
        if (u.id != upload.id) u,
    ];
    try {
      File(upload.file).deleteSync();
    } catch (_) {}
  }

  void _scheduleRetry() {
    _retry?.cancel();
    if (state.isNotEmpty) _retry = Timer(const Duration(minutes: 1), send);
  }
}

final uploadQueueProvider = NotifierProvider<UploadQueue, List<PendingUpload>>(UploadQueue.new);
