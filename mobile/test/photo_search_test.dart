import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:winou/api/api_client.dart';
import 'package:winou/api/models.dart';
import 'package:winou/l10n/app_localizations_en.dart';
import 'package:winou/reports/photo_search_screen.dart';
import 'package:winou/sightings/sighting_create_screen.dart';
import 'package:winou/widgets/animations.dart';
import 'package:winou/widgets/common.dart' show initDates;
import 'package:winou/widgets/photo_upload.dart';

import '../tool/screenshots/harness.dart';

/// Search by photo, and the check badge on photos being posted. The fake API's search returns the
/// open reports of the searched species with fixed scores (0.86, 0.74 likely; 0.63 possible).
void main() {
  final l10n = AppLocalizationsEn();
  final dog = File('../design/img/dog.png').absolute.path;
  final noAnimal = ApiException('No cat or dog found.', code: 'no_animal_detected', status: 422);

  setUpAll(() async {
    await initDates();
    mockPlugins(); // the image picker returns the dog photo; the phone is in Tunis
    HttpOverrides.global = FakeHttp();
  });

  FakeApi dogsLost() => FakeApi(
    lost: [
      lostJson(id: 'rocky', name: 'Rocky', species: 'dog'),
      lostJson(id: 'max', name: 'Max', species: 'dog'),
      lostJson(id: 'bella', name: 'Bella', species: 'dog'),
      lostJson(id: 'luna', name: 'Luna'),
    ],
  );

  Future<void> open(WidgetTester tester, Widget screen, FakeApi api) async {
    phoneSize(tester);
    await tester.pumpWidget(app(screen, brightness: Brightness.light, api: api));
    await settle(tester);
  }

  /// The search screen opens the camera/gallery sheet: take a photo.
  Future<void> takePhoto(WidgetTester tester) async {
    await tester.tap(find.text(l10n.camera));
    await settle(tester, rounds: 8);
  }

  group('search by photo', () {
    testWidgets('shows look-alikes, strongest first, and searches the other species on request', (tester) async {
      await open(tester, const PhotoSearchScreen(), dogsLost());
      await takePhoto(tester);

      expect(find.text(l10n.searchResultsCount(3)), findsOneWidget);
      expect(find.text('Rocky'), findsOneWidget);
      expect(find.text(l10n.searchStrongMatch), findsNWidgets(2));
      expect(find.text(l10n.searchPossibleMatch), findsOneWidget);
      expect(find.byType(SimilarityRing), findsNWidgets(3));
      expect(find.text(l10n.searchNearYou), findsOneWidget);
      expect(find.text(l10n.postAsSighting), findsOneWidget);

      await tester.tap(find.text(l10n.speciesCat)); // the detector said dog; the user says cat
      await settle(tester);
      expect(find.text('Luna'), findsOneWidget);
      expect(find.text('Rocky'), findsNothing);
    });

    testWidgets('nothing alike: suggests posting a sighting', (tester) async {
      await open(tester, const PhotoSearchScreen(), FakeApi(lost: []));
      await takePhoto(tester);
      expect(find.text(l10n.searchNoResults), findsOneWidget);
      expect(find.text(l10n.searchNoResultsHelp), findsOneWidget);
    });

    testWidgets('no animal in the photo: offers to retake it', (tester) async {
      await open(tester, const PhotoSearchScreen(), FakeApi(photoError: noAnimal));
      await takePhoto(tester);
      expect(find.text(l10n.searchNoAnimal), findsOneWidget);

      await tester.tap(find.text(l10n.retakePhoto));
      await settle(tester);
      expect(find.text(l10n.camera), findsOneWidget); // the camera/gallery sheet again
    });

    testWidgets('offline: says so and can retry', (tester) async {
      await open(tester, const PhotoSearchScreen(), FakeApi(fail: true));
      await takePhoto(tester);
      expect(find.text(l10n.retry), findsOneWidget);
    });

    testWidgets('closing the sheet without a photo leaves the explanation', (tester) async {
      await open(tester, const PhotoSearchScreen(), dogsLost());
      await tester.tapAt(const Offset(20, 100)); // outside the sheet
      await settle(tester);
      expect(find.text(l10n.searchByPhotoIntro), findsOneWidget);
      expect(find.text(l10n.takeOrChoosePhoto), findsOneWidget);
    });
  });

  group('photo check badge', () {
    Widget strip(Species species) => StatefulBuilder(
      builder: (context, setState) => Scaffold(
        body: PhotoPickerStrip(
          photos: [PickedPhoto(XFile(dog), PhotoSource.camera)],
          max: 4,
          species: species,
          onChanged: (_) {},
        ),
      ),
    );

    testWidgets('names the animal found', (tester) async {
      await open(tester, strip(Species.dog), FakeApi());
      expect(find.text(l10n.speciesDog), findsOneWidget);
    });

    testWidgets('warns when it looks like another species', (tester) async {
      await open(tester, strip(Species.cat), FakeApi());
      expect(find.text(l10n.photoLooksLike(l10n.speciesDog)), findsOneWidget);
    });

    testWidgets('no animal: tap to retake, or keep it', (tester) async {
      await open(tester, strip(Species.dog), FakeApi(photoError: noAnimal));
      expect(find.text(l10n.photoNoAnimal), findsOneWidget);

      await tester.tap(find.text(l10n.photoNoAnimal));
      await settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text(l10n.keepPhoto));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('no badge when the check cannot run', (tester) async {
      await open(tester, strip(Species.dog), FakeApi(fail: true));
      expect(find.text(l10n.speciesDog), findsNothing);
      expect(find.text(l10n.photoNoAnimal), findsNothing);
    });

    testWidgets('a new sighting takes its species from the first photo', (tester) async {
      await open(tester, const SightingCreateScreen(), FakeApi()); // opens the camera: a dog
      final species = tester.widget<SegmentedButton<Species>>(find.byType(SegmentedButton<Species>));
      expect(species.selected, {Species.dog});
    });
  });
}
