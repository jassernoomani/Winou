import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winou/api/models.dart';
import 'package:winou/config.dart';
import 'package:winou/l10n/app_localizations_en.dart';
import 'package:winou/map/map_screen.dart';
import 'package:winou/sightings/adoption.dart';
import 'package:winou/sightings/sighting_detail_screen.dart';
import 'package:winou/widgets/common.dart' show initDates;

import '../tool/screenshots/harness.dart';

/// Adoption for strays, and vets and shelters on the map.
void main() {
  final l10n = AppLocalizationsEn();

  setUpAll(() async {
    await initDates();
    mockPlugins();
    HttpOverrides.global = FakeHttp();
  });

  Map<String, dynamic> stray({Map<String, dynamic>? adoption, String status = 'AROUND'}) => sightingJson(
    stray: true,
    strayStatus: status,
    care: {'nickname': 'Mimi', 'feeders': 0, 'i_feed': false},
    adoption: adoption,
  );

  Map<String, dynamic> offer({String status = 'AVAILABLE', bool mine = false, String? association = 'Refuge'}) => {
    'status': status,
    'note': 'Gentle, two years old',
    'contact': '+216 20 123 456',
    'association': association,
    'mine': mine,
    'since': DateTime.now().toUtc().toIso8601String(),
  };

  Future<void> open(WidgetTester tester, Widget screen, FakeApi api) async {
    phoneSize(tester);
    await tester.pumpWidget(app(screen, brightness: Brightness.light, api: api));
    await settle(tester);
  }

  group('adoption on a stray\'s page', () {
    testWidgets('up for adoption: who offers it, call or WhatsApp', (tester) async {
      await open(tester, const SightingDetailScreen(id: 's1'), FakeApi(sighting: stray(adoption: offer())));
      expect(find.text(l10n.upForAdoption), findsOneWidget);
      expect(find.text(l10n.offeredBy('Refuge')), findsOneWidget);
      expect(find.text('Gentle, two years old'), findsOneWidget);
      expect(find.text(l10n.call), findsOneWidget);
      expect(find.text(l10n.whatsapp), findsOneWidget);
      expect(find.text(l10n.markAdopted), findsNothing); // not their offer
    });

    testWidgets('the offering association marks it adopted', (tester) async {
      final api = FakeApi(
        sighting: stray(adoption: offer(mine: true)),
        role: 'USER',
        associationName: 'Refuge',
      );
      await open(tester, const SightingDetailScreen(id: 's1'), api);
      await tester.ensureVisible(find.text(l10n.markAdopted));
      await tester.tap(find.text(l10n.markAdopted));
      await settle(tester);
      expect(api.adoptionCalls, ['adopted']);

      await tester.ensureVisible(find.text(l10n.withdrawOffer));
      await tester.tap(find.text(l10n.withdrawOffer));
      await settle(tester);
      expect(api.adoptionCalls, ['adopted', 'withdraw']);
    });

    testWidgets('adopted: the happy ending', (tester) async {
      await open(
        tester,
        const SightingDetailScreen(id: 's1'),
        FakeApi(
          sighting: stray(adoption: offer(status: 'ADOPTED')),
        ),
      );
      expect(find.text('${l10n.adoptedTitle} ${l10n.adoptedBody('Refuge')}'), findsOneWidget);
      expect(find.text(l10n.call), findsNothing);
    });

    testWidgets('an association offers a stray', (tester) async {
      final api = FakeApi(sighting: stray(), associationName: 'Refuge');
      await open(tester, const SightingDetailScreen(id: 's1'), api);
      await tester.ensureVisible(find.text(l10n.offerForAdoption));
      await tester.tap(find.text(l10n.offerForAdoption));
      await settle(tester);

      await tester.tap(find.text(l10n.save)); // no phone yet: refused
      await settle(tester);
      expect(find.text(l10n.phoneInvalid), findsOneWidget);

      final fields = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextFormField));
      await tester.enterText(fields.first, 'Very gentle');
      await tester.enterText(fields.last, '20 123 456');
      await tester.tap(find.text(l10n.save));
      await settle(tester);
      expect(api.adoptionCalls, ['offer Very gentle 20 123 456']);
    });

    testWidgets('nothing for other people, nor for strays gone', (tester) async {
      await open(tester, const SightingDetailScreen(id: 's1'), FakeApi(sighting: stray()));
      expect(find.text(l10n.offerForAdoption), findsNothing);

      await open(
        tester,
        const SightingDetailScreen(id: 's1'),
        FakeApi(
          sighting: stray(status: 'GONE'),
          associationName: 'Refuge',
        ),
      );
      expect(find.text(l10n.offerForAdoption), findsNothing);
    });
  });

  group('adoption list', () {
    testWidgets('lists the animals up for adoption', (tester) async {
      await open(tester, const AdoptionScreen(), FakeApi(sightings: [stray(adoption: offer())]));
      expect(find.text('Mimi'), findsOneWidget);
      expect(find.text(l10n.offeredBy('Refuge')), findsOneWidget);
    });

    testWidgets('says when there are none nearby', (tester) async {
      await open(tester, const AdoptionScreen(), FakeApi(sightings: []));
      expect(find.textContaining(l10n.noAdoptionNearby), findsOneWidget);
    });
  });

  test('WhatsApp numbers are international', () {
    expect(whatsAppNumber('20 123 456'), '21620123456');
    expect(whatsAppNumber('+216 20 123 456'), '21620123456');
    expect(whatsAppNumber('00216 20 123 456'), '21620123456');
    expect(dialable('+216 (20) 123-456'), '+21620123456');
  });

  group('vets and shelters', () {
    testWidgets('a place: name, hours, call and directions', (tester) async {
      final vet = Place.fromJson({
        'id': 'node/1',
        'kind': 'VET',
        'name': 'Clinique du Lac',
        'phone': '+216 71 000 000',
        'opening_hours': 'Mo-Sa 09:00-19:00',
        'location': {'lat': Config.defaultLat, 'lon': Config.defaultLon},
      });
      await open(tester, Scaffold(body: PlaceSheet(vet)), FakeApi());
      expect(find.text('Clinique du Lac'), findsOneWidget);
      expect(find.text(l10n.placeVet), findsOneWidget);
      expect(find.text(l10n.openingHours('Mo-Sa 09:00-19:00')), findsOneWidget);
      expect(find.text(l10n.call), findsOneWidget);
      expect(find.text(l10n.directions), findsOneWidget);

      final shelter = Place.fromJson({
        'id': 'way/2',
        'kind': 'SHELTER',
        'name': null,
        'phone': null,
        'opening_hours': null,
        'location': {'lat': Config.defaultLat, 'lon': Config.defaultLon},
      });
      await open(tester, Scaffold(body: PlaceSheet(shelter)), FakeApi());
      expect(find.text(l10n.placeShelter), findsOneWidget); // no name: the kind instead
      expect(find.text(l10n.call), findsNothing);
    });

    testWidgets('the map layer turns on and off', (tester) async {
      await open(tester, const MapScreen(), FakeApi());
      expect(find.byType(PlaceMarker), findsNothing);
      await tester.tap(find.text(l10n.vetsAndShelters));
      await settle(tester);
      expect(find.byType(PlaceMarker), findsNWidgets(2));

      await tester.tap(find.byType(PlaceMarker).first);
      await settle(tester);
      expect(find.byType(PlaceSheet), findsOneWidget);
      Navigator.of(tester.element(find.byType(PlaceSheet))).pop();
      await settle(tester);

      await tester.tap(find.text(l10n.vetsAndShelters));
      await settle(tester);
      expect(find.byType(PlaceMarker), findsNothing);
    });
  });
}
