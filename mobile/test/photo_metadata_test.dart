import 'package:exif/exif.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winou/widgets/photo_upload.dart';

IfdTag _text(String value) => IfdTag(tag: 0, tagType: 'ASCII', printable: value, values: const IfdNone());

IfdTag _dms(int d, int m, int sNumerator, int sDenominator) => IfdTag(
  tag: 0,
  tagType: 'Ratio',
  printable: '',
  values: IfdRatios([Ratio(d, 1), Ratio(m, 1), Ratio(sNumerator, sDenominator)]),
);

void main() {
  test('reads when the photo was taken', () {
    expect(exifTakenAt({'EXIF DateTimeOriginal': _text('2026:10:25 14:30:12')}), DateTime(2026, 10, 25, 14, 30, 12));
    expect(exifTakenAt({'Image DateTime': _text('2026:10:24 09:05:00')}), DateTime(2026, 10, 24, 9, 5));
  });

  test('ignores missing, unset or future dates', () {
    expect(exifTakenAt({}), isNull);
    expect(exifTakenAt({'EXIF DateTimeOriginal': _text('0000:00:00 00:00:00')}), isNull);
    final future = exifTakenAt({'EXIF DateTimeOriginal': _text('2099:01:01 00:00:00')})!;
    expect(future.isAfter(DateTime.now()), isFalse); // clamped to now
  });

  test('reads GPS degrees/minutes/seconds with hemisphere', () {
    // Tunis: 36° 48' 23.4" N, 10° 10' 53.4" E
    final tunis = exifLocation({
      'GPS GPSLatitude': _dms(36, 48, 234, 10),
      'GPS GPSLatitudeRef': _text('N'),
      'GPS GPSLongitude': _dms(10, 10, 534, 10),
      'GPS GPSLongitudeRef': _text('E'),
    })!;
    expect(tunis.latitude, closeTo(36.8065, 1e-4));
    expect(tunis.longitude, closeTo(10.1815, 1e-4));

    final southWest = exifLocation({
      'GPS GPSLatitude': _dms(33, 52, 0, 1),
      'GPS GPSLatitudeRef': _text('S'),
      'GPS GPSLongitude': _dms(70, 40, 0, 1),
      'GPS GPSLongitudeRef': _text('W'),
    })!;
    expect(southWest.latitude, lessThan(0));
    expect(southWest.longitude, lessThan(0));
  });

  test('no GPS, or the 0,0 placeholder, means no location', () {
    expect(exifLocation({}), isNull);
    expect(
      exifLocation({
        'GPS GPSLatitude': _dms(0, 0, 0, 1),
        'GPS GPSLatitudeRef': _text('N'),
        'GPS GPSLongitude': _dms(0, 0, 0, 1),
        'GPS GPSLongitudeRef': _text('E'),
      }),
      isNull,
    );
  });
}
