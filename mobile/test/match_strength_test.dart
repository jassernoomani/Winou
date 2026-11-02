import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:winou/api/api_client.dart';
import 'package:winou/api/models.dart';
import 'package:winou/l10n/app_localizations_en.dart';
import 'package:winou/widgets/common.dart' show initDates;
import 'package:winou/widgets/photo_upload.dart';

import '../tool/screenshots/harness.dart';

/// The photo strength meter: more usable photos of the animal, better matching.
void main() {
  final l10n = AppLocalizationsEn();
  final dog = PickedPhoto(XFile(File('../design/img/dog.png').absolute.path), PhotoSource.camera);

  setUpAll(() async {
    await initDates();
    mockPlugins();
    HttpOverrides.global = FakeHttp();
  });

  Future<void> show(WidgetTester tester, Widget child, {FakeApi? api}) async {
    phoneSize(tester);
    await tester.pumpWidget(
      app(
        Scaffold(body: child),
        brightness: Brightness.light,
        api: api ?? FakeApi(),
      ),
    );
    await settle(tester);
  }

  for (final (count, text) in [
    (0, l10n.strengthNone),
    (1, l10n.strengthWeak),
    (2, l10n.strengthFair),
    (3, l10n.strengthStrong),
    (5, l10n.strengthStrong),
  ]) {
    testWidgets('$count photos', (tester) async {
      await show(tester, MatchStrength(count));
      expect(find.text(text), findsOneWidget);
      expect(find.text(l10n.strengthTips), count >= 3 ? findsNothing : findsOneWidget);
    });
  }

  testWidgets('a new photo counts once its check finds the animal', (tester) async {
    await show(tester, Consumer(builder: (context, ref, _) => MatchStrength(usablePhotos(ref, 1, [dog]))));
    expect(find.text(l10n.strengthFair), findsOneWidget); // 1 saved + the dog
  });

  testWidgets('a new photo without an animal does not count', (tester) async {
    await show(
      tester,
      Consumer(builder: (context, ref, _) => MatchStrength(usablePhotos(ref, 1, [dog]))),
      api: FakeApi(photoError: ApiException('No animal', code: 'no_animal_detected')),
    );
    expect(find.text(l10n.strengthWeak), findsOneWidget);
  });
}
