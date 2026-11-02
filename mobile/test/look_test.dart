import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winou/l10n/app_localizations_en.dart';
import 'package:winou/reports/lost_feed_screen.dart';
import 'package:winou/splash_screen.dart';
import 'package:winou/theme.dart';
import 'package:winou/widgets/common.dart';
import 'package:winou/widgets/illustrations.dart';
import 'package:winou/widgets/splash_art.dart';

import '../tool/screenshots/harness.dart';

/// The launch scene, the illustrations, and the home buttons that step aside while scrolling.
void main() {
  final l10n = AppLocalizationsEn();

  setUpAll(() async {
    await initDates();
    mockPlugins();
    HttpOverrides.global = FakeHttp();
  });

  Future<void> show(WidgetTester tester, Widget screen, {FakeApi? api}) async {
    phoneSize(tester);
    await tester.pumpWidget(app(screen, brightness: Brightness.light, api: api ?? FakeApi()));
    await settle(tester);
  }

  testWidgets('the launch scene ends with the name and the tagline', (tester) async {
    await show(tester, const SplashScreen());
    expect(find.byType(SplashArt), findsOneWidget);
    expect(find.byType(Wordmark), findsOneWidget);
    expect(find.text(l10n.tagline), findsOneWidget);
  });

  testWidgets('with reduced motion, the launch scene is still and complete at once', (tester) async {
    phoneSize(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures.allOn;
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(app(const SplashScreen(), brightness: Brightness.dark, api: FakeApi()));
    await tester.pump();
    await tester.pump();
    final words = tester.widget<Opacity>(
      find.ancestor(of: find.text(l10n.tagline), matching: find.byType(Opacity)).first,
    );
    expect(words.opacity, 1); // no fade-in: already there
  });

  testWidgets('the three welcome pictures, and radar rings', (tester) async {
    await show(
      tester,
      const DecoratedBox(
        decoration: BoxDecoration(gradient: Brand.gradient),
        child: SingleChildScrollView(
          child: Column(
            children: [
              WelcomeIllustration(WelcomeArt.lost),
              WelcomeIllustration(WelcomeArt.saw),
              WelcomeIllustration(WelcomeArt.strays),
              RadarRings(color: Colors.white, child: BrandPin()),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(BrandPin), findsNWidgets(2));
    expect(find.byType(RadarRings), findsNWidgets(2));
  });

  testWidgets('a compact button keeps its name for screen readers', (tester) async {
    await show(
      tester,
      Scaffold(
        body: Center(
          child: GradientFab(
            gradient: Brand.lostGradient,
            icon: Icons.campaign,
            label: 'Report a lost pet',
            compact: true,
            onPressed: () {},
          ),
        ),
      ),
    );
    expect(find.text('Report a lost pet'), findsNothing);
    expect(find.bySemanticsLabel('Report a lost pet'), findsOneWidget);
    expect(find.byTooltip('Report a lost pet'), findsOneWidget);
  });

  testWidgets('home: the big buttons shrink while scrolling down, and come back', (tester) async {
    final many = [for (var i = 0; i < 12; i++) lostJson(id: 'pet$i', name: 'Pet $i')];
    await show(tester, const LostFeedScreen(), api: FakeApi(lost: many));
    expect(find.text(l10n.reportLostPet), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await settle(tester);
    expect(find.text(l10n.reportLostPet), findsNothing);
    expect(find.bySemanticsLabel(l10n.reportLostPet), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await settle(tester);
    expect(find.text(l10n.reportLostPet), findsOneWidget);
  });
}
