// Screenshots of every designed screen, light and dark, with sample data. To compare the app
// with the Figma designs (design/winou-screens.html):
//
//   flutter test tool/screenshots --update-goldens
//
// writes tool/screenshots/out/<screen>_<theme>.png (not committed).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:winou/api/models.dart';
import 'package:winou/auth/auth_controller.dart';
import 'package:winou/auth/auth_screens.dart';
import 'package:winou/auth/suspended_screen.dart';
import 'package:winou/chat/chat_screen.dart';
import 'package:winou/chat/conversations_screen.dart';
import 'package:winou/l10n/app_localizations_en.dart';
import 'package:winou/map/map_screen.dart';
import 'package:winou/me/account_screen.dart';
import 'package:winou/me/admin_screen.dart';
import 'package:winou/me/admin_user_screen.dart';
import 'package:winou/me/association_screen.dart';
import 'package:winou/me/match_detail_screen.dart';
import 'package:winou/me/my_activity_screen.dart';
import 'package:winou/reports/lost_feed_screen.dart';
import 'package:winou/reports/lost_report_create_screen.dart';
import 'package:winou/reports/lost_report_detail_screen.dart';
import 'package:winou/sightings/sighting_create_screen.dart';
import 'package:winou/sightings/sighting_detail_screen.dart';
import 'package:winou/sightings/sighting_thanks_screen.dart';
import 'package:winou/splash_screen.dart';

import 'harness.dart';

typedef Act = Future<void> Function(WidgetTester tester);

final _l10n = AppLocalizationsEn();

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder.first, warnIfMissed: false);
  await settle(tester); // a new tab or sheet loads its data, then fades in
}

Finder _markers() => find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MarkerIcon');

final _scenes = <(String, Widget Function(), FakeApi Function(), Act?)>[
  ('01_splash', () => const SplashScreen(), FakeApi.new, null),
  ('02_sign_in', () => const LoginScreen(), FakeApi.new, null),
  ('03_register', () => const LoginScreen(register: true), FakeApi.new, null),
  ('04_home', () => const LostFeedScreen(), FakeApi.new, null),
  ('05_home_empty', () => const LostFeedScreen(), () => FakeApi(lost: []), null),
  ('06_home_loading', () => const LostFeedScreen(), () => FakeApi(hang: true), null),
  ('07_home_error', () => const LostFeedScreen(), () => FakeApi(fail: true), null),
  ('08_lost_detail', () => const LostReportDetailScreen(id: 'luna'), FakeApi.new, null),
  ('09_report_lost', () => const LostReportCreateScreen(), FakeApi.new, null),
  ('10_sighting_form', () => const SightingCreateScreen(), FakeApi.new, null),
  ('11_thanks', () => const SightingThanksScreen(id: 's1'), FakeApi.new, null),
  ('12_match_pending', () => const MatchDetailScreen(id: 'm1'), FakeApi.new, null),
  (
    '13_match_confirmed',
    () => const MatchDetailScreen(id: 'm1'),
    () => FakeApi(
      matches: [matchJson(status: 'CONFIRMED', conversation: 'c1')],
    ),
    null,
  ),
  (
    '14_match_closed',
    () => const MatchDetailScreen(id: 'm1'),
    () => FakeApi(
      matches: [matchJson(status: 'CONFIRMED', reportStatus: 'FOUND', conversation: 'c1')],
    ),
    null,
  ),
  (
    '16_match_close_dialog',
    () => const MatchDetailScreen(id: 'm1'),
    () => FakeApi(
      matches: [matchJson(status: 'CONFIRMED', conversation: 'c1')],
    ),
    (tester) => _tap(tester, find.text(_l10n.gotPetBack('Luna'))),
  ),
  ('17_map', () => const MapScreen(), FakeApi.new, null),
  ('18_map_filters', () => const MapScreen(), FakeApi.new, (tester) => _tap(tester, find.byTooltip(_l10n.filters))),
  ('19_map_preview', () => const MapScreen(), FakeApi.new, (tester) => _tap(tester, _markers())),
  ('20_activity', () => const MyActivityScreen(), FakeApi.new, null),
  (
    '21_activity_empty',
    () => const MyActivityScreen(),
    () => FakeApi(mine: []),
    (tester) => _tap(tester, find.text(_l10n.tabMyLostPets)),
  ),
  ('22_messages', () => const ConversationsScreen(), FakeApi.new, null),
  ('23_messages_empty', () => const ConversationsScreen(), () => FakeApi(conversations: []), null),
  ('24_chat', () => const ChatScreen(id: 'c1'), FakeApi.new, null),
  (
    '25_chat_closed',
    () => const ChatScreen(id: 'c1'),
    () => FakeApi(conversations: [conversationJson(reportStatus: 'FOUND')]),
    null,
  ),
  ('26_chat_empty', () => const ChatScreen(id: 'c1'), () => FakeApi(messages: []), null),
  // Phase 5: no Figma design yet, so these have no comparison
  (
    '30_stray_injured',
    () => const SightingDetailScreen(id: 's1'),
    () => FakeApi(
      sighting: sightingJson(species: 'dog', stray: true, condition: 'INJURED'),
    ),
    null,
  ),
  (
    '31_stray_helped',
    () => const SightingDetailScreen(id: 's1'),
    () => FakeApi(
      sighting: sightingJson(species: 'dog', stray: true, strayStatus: 'HELPED', helpedBy: 'Refuge de Tunis'),
    ),
    null,
  ),
  (
    '32_report_sheet',
    () => const SightingDetailScreen(id: 's1'),
    () => FakeApi(sighting: sightingJson(species: 'dog', stray: true)),
    (tester) async {
      await _tap(tester, find.byTooltip(_l10n.more));
      await _tap(tester, find.text(_l10n.report));
    },
  ),
  ('33_association_form', () => const AssociationScreen(), FakeApi.new, null),
  ('34_association_pending', () => const AssociationScreen(), () => FakeApi(request: associationRequestJson()), null),
  (
    '35_association_approved',
    () => const AssociationScreen(),
    () => FakeApi(role: 'ASSOCIATION', associationName: 'Refuge de Tunis'),
    null,
  ),
  ('36_admin_requests', () => const AdminScreen(tab: 'requests'), () => FakeApi(role: 'ADMIN'), null),
  ('37_admin_hidden', () => const AdminScreen(tab: 'hidden'), () => FakeApi(role: 'ADMIN'), null),
  (
    '38_chat_association',
    () => const ChatScreen(id: 'c1'),
    () => FakeApi(
      conversations: [conversationJson(association: 'Refuge de Tunis')],
      messages: [
        ...sampleChat,
        messageJson('5', 'Call me on my private number', mine: true, ago: const Duration(minutes: 30), hidden: true),
      ],
    ),
    null,
  ),
  ('40_admin_users', () => const AdminScreen(tab: 'users'), () => FakeApi(role: 'ADMIN'), null),
  ('41_admin_user_banned', () => const AdminUserScreen(id: 'u1'), () => FakeApi(role: 'ADMIN'), null),
  (
    '42_admin_suspend_sheet',
    () => const AdminUserScreen(id: 'u4'),
    () => FakeApi(role: 'ADMIN'),
    (tester) => _tap(tester, find.text(_l10n.suspend)),
  ),
  (
    '43_suspended',
    () => const SuspendedScreen(),
    FakeApi.new,
    (tester) async {
      ProviderScope.containerOf(tester.element(find.byType(SuspendedScreen)))
          .read(authProvider.notifier)
          .banned(
            Ban.fromJson({
              'until': DateTime.now().add(const Duration(days: 6, hours: 20)).toUtc().toIso8601String(),
              'reason': 'Selling animals in sightings',
            }),
          );
      await settle(tester);
    },
  ),
  ('44_admin_reported', () => const AdminScreen(tab: 'reported'), () => FakeApi(role: 'ADMIN'), null),
  ('46_admin_dashboard', () => const AdminScreen(), () => FakeApi(role: 'ADMIN'), null),
  (
    '47_admin_dashboard_week',
    () => const AdminScreen(),
    () => FakeApi(role: 'ADMIN'),
    (tester) async {
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await settle(tester, rounds: 1);
      final chart = tester.getRect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == _l10n.weeklyChartLabel),
      );
      final gesture = await tester.startGesture(chart.center);
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
    },
  ),
  (
    '48_admin_dashboard_table',
    () => const AdminScreen(),
    () => FakeApi(role: 'ADMIN'),
    (tester) async {
      await _tap(tester, find.byTooltip(_l10n.showTable));
      await tester.drag(find.byType(ListView).first, const Offset(0, -420));
      await settle(tester, rounds: 1);
    },
  ),
  ('49_admin_activity', () => const AdminScreen(tab: 'activity'), () => FakeApi(role: 'ADMIN'), null),
  (
    '50_photo_viewer',
    () => const LostReportDetailScreen(id: 'rocky'),
    FakeApi.new,
    (tester) => _tap(tester, find.byType(PageView).first),
  ),
  (
    '45_lost_detail_admin_menu',
    () => const LostReportDetailScreen(id: 'rocky'),
    () => FakeApi(role: 'ADMIN'),
    (tester) => _tap(tester, find.byTooltip(_l10n.more)),
  ),
  ('51_account', () => const AccountScreen(), FakeApi.new, null),
  (
    '52_change_password',
    () => const AccountScreen(),
    FakeApi.new,
    (tester) => _tap(tester, find.text(_l10n.changePassword)),
  ),
  (
    '53_delete_account',
    () => const AccountScreen(),
    FakeApi.new,
    (tester) => _tap(tester, find.text(_l10n.deleteAccount)),
  ),
  (
    '39_activity_menu',
    () => const MyActivityScreen(),
    () => FakeApi(role: 'ADMIN'),
    (tester) => _tap(tester, find.byTooltip(_l10n.more)),
  ),
];

void main() {
  setUpAll(() async {
    await loadFonts();
    mockPlugins();
  });

  for (final (name, screen, api, act) in _scenes) {
    for (final brightness in Brightness.values) {
      testWidgets('$name ${brightness.name}', (tester) async {
        phoneSize(tester);
        await HttpOverridesScope.run(tester, () async {
          await tester.pumpWidget(app(screen(), brightness: brightness, api: api()));
          await settle(tester, rounds: 10); // photos from files take a few real-time rounds to decode
          if (act != null) await act(tester);
          await expectLater(find.byKey(screenshotKey), matchesGoldenFile('out/${name}_${brightness.name}.png'));
          // HIRES=1 also writes a 1080 x 2400 copy to out/hires/ (for the portfolio).
          if (Platform.environment['HIRES'] != null) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(screenshotKey));
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 3);
              final png = await image.toByteData(format: ui.ImageByteFormat.png);
              File('tool/screenshots/out/hires/${name}_${brightness.name}.png')
                ..createSync(recursive: true)
                ..writeAsBytesSync(png!.buffer.asUint8List());
            });
          }
          await tester.pumpWidget(const SizedBox()); // stops the screen's timers
          await settle(tester, rounds: 1);
        });
      });
    }
  }
}

final _http = FakeHttp();

/// Image and tile requests go to [FakeHttp] for the duration of a test.
abstract final class HttpOverridesScope {
  static Future<void> run(WidgetTester tester, Future<void> Function() body) async {
    HttpOverrides.global = _http;
    await HttpOverrides.runWithHttpOverrides(body, _http);
  }
}
