import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winou/auth/auth_screens.dart';
import 'package:winou/l10n/app_localizations.dart';
import 'package:winou/splash_screen.dart';
import 'package:winou/theme.dart';
import 'package:winou/widgets/common.dart';

/// The screens shown before signing in render at phone size, in both themes and languages,
/// without overflowing (a layout error fails the test).
void main() {
  Future<void> show(
    WidgetTester tester,
    Widget screen, {
    required Brightness brightness,
    required Locale locale,
  }) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: winouTheme(brightness),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: screen,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1)); // entrance animations
  }

  for (final brightness in Brightness.values) {
    for (final locale in const [Locale('en'), Locale('fr')]) {
      final variant = '${brightness.name}, ${locale.languageCode}';

      testWidgets('sign in ($variant)', (tester) async {
        await show(tester, const LoginScreen(), brightness: brightness, locale: locale);
        expect(find.byType(Wordmark), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(2));
      });

      testWidgets('register ($variant)', (tester) async {
        await show(tester, const LoginScreen(register: true), brightness: brightness, locale: locale);
        expect(find.byType(TextFormField), findsNWidgets(3));
      });

      testWidgets('splash ($variant)', (tester) async {
        await show(tester, const SplashScreen(), brightness: brightness, locale: locale);
        expect(find.byType(Wordmark), findsOneWidget);
      });
    }
  }
}
