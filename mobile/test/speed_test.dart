import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winou/api/api_client.dart';
import 'package:winou/chat/chat_screen.dart';
import 'package:winou/l10n/app_localizations_en.dart';
import 'package:winou/widgets/animations.dart';
import 'package:winou/widgets/common.dart';

import '../tool/screenshots/harness.dart';

/// Right-sized photos, messages shown before the server answers, and skeletons while lists load.
void main() {
  final l10n = AppLocalizationsEn();

  setUpAll(() async {
    await initDates();
    mockPlugins();
    HttpOverrides.global = FakeHttp();
  });

  group('photo sizes', () {
    test('the smallest width that covers the box', () {
      expect(sizedPhotoWidth(76 * 3), 320);
      expect(sizedPhotoWidth(160), 160);
      expect(sizedPhotoWidth(161), 320);
      expect(sizedPhotoWidth(360 * 2.75), 1080);
      expect(sizedPhotoWidth(1440 * 3), isNull); // bigger than any copy: the full photo
      expect(sizedPhotoWidth(0), isNull);
    });

    test('only Winou photo URLs get a width', () {
      expect(
        sizedPhotoUrl('https://winou.duckdns.org/photos/abc/image', 320),
        'https://winou.duckdns.org/photos/abc/image?w=320',
      );
      expect(
        sizedPhotoUrl('https://winou.duckdns.org/photos/abc/crop', 320),
        'https://winou.duckdns.org/photos/abc/crop',
      );
      expect(
        sizedPhotoUrl('https://winou.duckdns.org/photos/abc/image?w=640', 320),
        'https://winou.duckdns.org/photos/abc/image?w=640',
      );
      expect(
        sizedPhotoUrl('https://tile.openstreetmap.org/1/2/3.png', 320),
        'https://tile.openstreetmap.org/1/2/3.png',
      );
    });

    testWidgets('a photo box asks for its own size', (tester) async {
      phoneSize(tester); // 2x density
      await tester.pumpWidget(
        app(
          const Center(child: SizedBox(width: 76, height: 76, child: NetworkPhoto('https://x/photos/p1/image'))),
          brightness: Brightness.light,
          api: FakeApi(),
        ),
      );
      await settle(tester);
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as ResizeImage).width, 160); // 76 x 2 = 152 px: the 160 copy
      expect(((image.image as ResizeImage).imageProvider as NetworkImage).url, 'https://x/photos/p1/image?w=160');
    });
  });

  group('chat sends at once', () {
    Future<FakeApi> openChat(WidgetTester tester) async {
      final api = FakeApi(conversations: [conversationJson()], messages: []);
      phoneSize(tester);
      await tester.pumpWidget(
        app(
          const ChatScreen(id: 'c1'),
          brightness: Brightness.light,
          api: api,
        ),
      );
      await settle(tester);
      return api;
    }

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.tap(find.byTooltip(l10n.send));
      await tester.pump();
    }

    testWidgets('shown as "Sending…", then as sent', (tester) async {
      final api = await openChat(tester);
      api.sendGate = Completer();
      await type(tester, 'On my way!');
      expect(find.text('On my way!'), findsOneWidget);
      expect(find.text(l10n.chatSending), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);

      api.sendGate!.complete();
      await settle(tester);
      expect(find.text('On my way!'), findsOneWidget);
      expect(find.text(l10n.chatSending), findsNothing);
      expect(api.sent, ['On my way!']);
    });

    testWidgets('kept when it fails, and sent on retry', (tester) async {
      final api = await openChat(tester);
      api.sendError = ApiException('Cannot reach the server.', code: 'network');
      await type(tester, 'Are you there?');
      await settle(tester);
      expect(find.text(l10n.chatNotSent), findsOneWidget);
      expect(find.text('Are you there?'), findsOneWidget);

      api.sendError = null;
      await tester.tap(find.text(l10n.chatNotSent));
      await settle(tester);
      expect(find.text(l10n.chatNotSent), findsNothing);
      expect(api.sent, ['Are you there?']);
    });

    testWidgets('several in a row arrive in order', (tester) async {
      final api = await openChat(tester);
      api.sendGate = Completer();
      await type(tester, 'one');
      await type(tester, 'two');
      expect(find.text(l10n.chatSending), findsNWidgets(2));
      api.sendGate!.complete();
      await settle(tester);
      expect(api.sent, ['one', 'two']);
    });
  });

  testWidgets('skeleton rows while a list loads', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(
      app(
        const Scaffold(body: SkeletonList(rows: 4)),
        brightness: Brightness.dark,
        api: FakeApi(),
      ),
    );
    await tester.pump(); // the harness opens the screen after the first frame
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SkeletonList), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // disposed cleanly
  });
}
