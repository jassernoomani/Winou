import 'dart:io';
import 'dart:ui' as ui;

import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../uploads.dart';
import 'common.dart';

final _picker = ImagePicker();

/// A photo chosen in the app. Gallery photos carry when and where they were taken, if the
/// file says so: a sighting posted later from the gallery must not default to "now, here".
class PickedPhoto {
  const PickedPhoto(this.file, this.source, {this.takenAt, this.location});

  final XFile file;
  final PhotoSource source;
  final DateTime? takenAt;
  final LatLng? location; // often missing: Android hides photo locations from apps by default

  bool get fromGallery => source == PhotoSource.gallery;
}

// Photos are resized on the phone: faster uploads, and the API keeps at most 2048 px anyway.
// image_picker copies the date and GPS tags into the resized file.
const _maxSide = 2048.0;
const _quality = 90;

Future<PickedPhoto?> takePhoto() async {
  final file = await _picker.pickImage(
    source: ImageSource.camera,
    maxWidth: _maxSide,
    maxHeight: _maxSide,
    imageQuality: _quality,
  );
  return file == null ? null : PickedPhoto(file, PhotoSource.camera);
}

Future<List<PickedPhoto>> pickFromGallery(int limit) async {
  final files = limit <= 1
      ? [
          ?(await _picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: _maxSide,
            maxHeight: _maxSide,
            imageQuality: _quality,
          )),
        ]
      : await _picker.pickMultiImage(maxWidth: _maxSide, maxHeight: _maxSide, imageQuality: _quality, limit: limit);
  return Future.wait(files.take(limit).map(_readMetadata));
}

Future<PickedPhoto> _readMetadata(XFile file) async {
  try {
    final tags = await readExifFromBytes(await file.readAsBytes());
    return PickedPhoto(file, PhotoSource.gallery, takenAt: exifTakenAt(tags), location: exifLocation(tags));
  } catch (_) {
    return PickedPhoto(file, PhotoSource.gallery); // unreadable metadata: the user sets time and place
  }
}

/// EXIF "DateTimeOriginal" is the phone's local time when the photo was taken: "2026:10:25 14:30:12".
DateTime? exifTakenAt(Map<String, IfdTag> tags) {
  final raw = (tags['EXIF DateTimeOriginal'] ?? tags['Image DateTime'])?.printable ?? '';
  final m = RegExp(r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})').firstMatch(raw.trim());
  if (m == null) return null;
  final v = [for (var i = 1; i <= 6; i++) int.parse(m.group(i)!)];
  final takenAt = DateTime(v[0], v[1], v[2], v[3], v[4], v[5]);
  if (takenAt.year < 2000) return null; // unset camera clock
  final now = DateTime.now();
  return takenAt.isAfter(now) ? now : takenAt;
}

/// EXIF GPS is degrees, minutes, seconds as fractions, with N/S and E/W in separate tags.
LatLng? exifLocation(Map<String, IfdTag> tags) {
  double? coordinate(String key, String negativeRef) {
    final parts = tags['GPS GPS$key']?.values.toList();
    if (parts == null || parts.length != 3) return null;
    double value(Object part) => switch (part) {
      Ratio(:final numerator, :final denominator) => denominator == 0 ? double.nan : numerator / denominator,
      num n => n.toDouble(),
      _ => double.nan,
    };
    final degrees = value(parts[0]) + value(parts[1]) / 60 + value(parts[2]) / 3600;
    final ref = tags['GPS GPS${key}Ref']?.printable.trim();
    return degrees.isNaN ? null : (ref == negativeRef ? -degrees : degrees);
  }

  final lat = coordinate('Latitude', 'S');
  final lon = coordinate('Longitude', 'W');
  if (lat == null || lon == null || (lat == 0 && lon == 0) || lat.abs() > 90 || lon.abs() > 180) return null;
  return LatLng(lat, lon);
}

/// Uploads the photos, then waits for the matcher to process them all at once. For each photo
/// where no animal is found, offers to retake it with the camera. Reports progress as "i/n".
/// When the connection drops, the photos left wait in [queue] and go once it's back.
Future<void> uploadPhotos(
  BuildContext context,
  WinouApi api,
  UploadQueue queue,
  String ownerPath,
  List<PickedPhoto> photos, {
  required void Function(String progress) onProgress,
}) async {
  final sent = <PickedPhoto>[];
  final uploaded = <String>[];
  var waiting = 0;
  for (var i = 0; i < photos.length; i++) {
    onProgress('${i + 1}/${photos.length}');
    if (waiting == 0) {
      try {
        uploaded.add((await _upload(api, ownerPath, photos[i])).id);
        sent.add(photos[i]);
        continue;
      } on ApiException catch (e) {
        if (e.code != 'network') rethrow;
      }
    }
    await queue.add(ownerPath, photos[i].file.path, photos[i].source);
    waiting++;
  }
  if (waiting > 0 && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.photosQueued(waiting))));
  }
  if (uploaded.isEmpty) return;
  final processed = await Future.wait(uploaded.map(api.waitForPhoto));
  photos = sent;
  for (var i = 0; i < photos.length; i++) {
    var photo = processed[i];
    while (photo.status == 'NO_ANIMAL' && context.mounted && await _askRetake(context, photos[i].file)) {
      final retaken = await takePhoto();
      if (retaken == null) break;
      await api.deletePhoto(photo.id);
      photo = await api.waitForPhoto((await api.uploadPhoto(ownerPath, retaken.file.path, retaken.source)).id);
    }
  }
}

/// A weak connection often fails once and works the next time: two quick retries before queueing.
Future<Photo> _upload(WinouApi api, String ownerPath, PickedPhoto photo) async {
  for (final wait in const [Duration(seconds: 1), Duration(seconds: 3)]) {
    try {
      return await api.uploadPhoto(ownerPath, photo.file.path, photo.source);
    } on ApiException catch (e) {
      if (e.code != 'network') rethrow;
      await Future.delayed(wait);
    }
  }
  return api.uploadPhoto(ownerPath, photo.file.path, photo.source);
}

Future<bool> _askRetake(BuildContext context, XFile file) async {
  final l10n = context.l10n;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.noAnimalTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(file.path), height: 160, fit: BoxFit.cover),
              ),
              const SizedBox(height: 12),
              Text(l10n.noAnimalBody),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.keepPhoto)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.retakePhoto)),
          ],
        ),
      ) ??
      false;
}

/// Asks camera or gallery, then returns the new photos (at most [limit]).
Future<List<PickedPhoto>> addPhotos(BuildContext context, int limit) async {
  final l10n = context.l10n;
  final source = await showModalBottomSheet<PhotoSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(LucideIcons.camera),
            title: Text(l10n.camera),
            onTap: () => Navigator.pop(context, PhotoSource.camera),
          ),
          ListTile(
            leading: const Icon(LucideIcons.images),
            title: Text(l10n.gallery),
            onTap: () => Navigator.pop(context, PhotoSource.gallery),
          ),
        ],
      ),
    ),
  );
  return switch (source) {
    PhotoSource.camera => [?(await takePhoto())],
    PhotoSource.gallery => await pickFromGallery(limit),
    null => [],
  };
}

/// The selected photos with remove buttons, and the guide's "add a photo" control: soft blue, a
/// dashed outline and a camera in a white circle. Full width until there is a photo, then a tile.
class PhotoPickerStrip extends StatelessWidget {
  const PhotoPickerStrip({super.key, required this.photos, required this.max, required this.onChanged});

  final List<PickedPhoto> photos;
  final int max;
  final ValueChanged<List<PickedPhoto>> onChanged;

  Future<void> _add(BuildContext context) async {
    final added = await addPhotos(context, max - photos.length);
    if (added.isNotEmpty) onChanged([...photos, ...added].take(max).toList());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final camera = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: tokens.card, shape: BoxShape.circle),
      child: Icon(LucideIcons.camera, color: tokens.accent),
    );
    Widget dashed({required Widget child, double? width, double? height}) => CustomPaint(
      painter: _DashedOutline(color: tokens.accent, radius: 20),
      child: Material(
        color: tokens.tonal,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _add(context),
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );

    if (photos.isEmpty) {
      return dashed(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            spacing: 12,
            children: [
              camera,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      l10n.addClearPhoto,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: tokens.accent),
                    ),
                    Text(l10n.addClearPhotoHelp, style: TextStyle(fontSize: 12, color: tokens.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final photo in photos)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(File(photo.file.path), width: 96, height: 96, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(LucideIcons.x, size: 16),
                      onPressed: () => onChanged([...photos]..remove(photo)),
                    ),
                  ),
                ],
              ),
            ),
          if (photos.length < max) dashed(width: 96, height: 96, child: Center(child: camera)),
        ],
      ),
    );
  }
}

class _DashedOutline extends CustomPainter {
  _DashedOutline({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final outline =
        ui.Path() // latlong2 has its own Path
          ..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(0.5), Radius.circular(radius)));
    for (final metric in outline.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOutline old) => old.color != color || old.radius != radius;
}

/// Date then time picker; returns null if cancelled. Never later than now.
Future<DateTime?> pickDateTime(BuildContext context, DateTime initial) async {
  FocusScope.of(context).unfocus();
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: now.subtract(const Duration(days: 365)),
    lastDate: now,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
  if (time == null) return null;
  final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  return picked.isAfter(now) ? now : picked;
}
