import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winou/chat/chat_screen.dart';
import 'package:winou/l10n/app_localizations_en.dart';
import 'package:winou/widgets/common.dart' show PrivateDetailField, initDates;

import '../tool/screenshots/harness.dart';

/// Checking a claim before a handover, the handover tips, and warnings on messages asking for money.
void main() {
  final l10n = AppLocalizationsEn();
  const detail = 'A small white star under her chin';

  setUpAll(() async {
    await initDates();
    mockPlugins();
    HttpOverrides.global = FakeHttp();
  });

  Future<void> openChat(WidgetTester tester, FakeApi api) async {
    phoneSize(tester);
    await tester.pumpWidget(app(const ChatScreen(id: 'c1'), brightness: Brightness.light, api: api));
    await settle(tester);
  }

  FakeApi chat(Map<String, dynamic> conversation, [List<Map<String, dynamic>>? messages]) =>
      FakeApi(conversations: [conversation], messages: messages);

  group('handover card', () {
    testWidgets('the finder sees the owner\'s detail and the tips, and can fold them', (tester) async {
      await openChat(
        tester,
        chat(conversationJson(finder: true, confirmed: true, ownerDetail: detail, microchipped: true)),
      );
      expect(find.text(l10n.checkOwnerTitle), findsOneWidget);
      expect(find.text(l10n.ownerDetailSays(detail)), findsOneWidget);
      expect(find.text(l10n.ownerDetailCheck), findsOneWidget);
      expect(find.text(l10n.microchippedTip), findsOneWidget);
      expect(find.text(l10n.handoverTipNoPay), findsOneWidget);

      await tester.tap(find.text(l10n.checkOwnerTitle));
      await settle(tester);
      expect(find.text(l10n.handoverTipNoPay), findsNothing);
    });

    testWidgets('without a detail, the finder is told what to ask', (tester) async {
      await openChat(tester, chat(conversationJson(finder: true, confirmed: true)));
      expect(find.text(l10n.ownerDetailAsk), findsOneWidget);
      expect(find.text(l10n.microchippedTip), findsNothing);
    });

    testWidgets('the owner gets the tips, folded', (tester) async {
      await openChat(tester, chat(conversationJson(confirmed: true)));
      expect(find.text(l10n.handoverTitle), findsOneWidget);
      expect(find.text(l10n.handoverTipPublic), findsNothing);

      await tester.tap(find.text(l10n.handoverTitle));
      await settle(tester);
      expect(find.text(l10n.handoverTipPublic), findsOneWidget);
      expect(find.text(l10n.handoverTipProof), findsOneWidget);
      expect(find.textContaining('star'), findsNothing);
    });

    testWidgets('not before the owner confirms, nor once the case is closed', (tester) async {
      await openChat(tester, chat(conversationJson(finder: true)));
      expect(find.text(l10n.checkOwnerTitle), findsNothing);

      await openChat(tester, chat(conversationJson(finder: true, confirmed: true, reportStatus: 'FOUND')));
      expect(find.text(l10n.checkOwnerTitle), findsNothing);
    });
  });

  group('scam warnings', () {
    testWidgets('under the other person\'s message, never under mine', (tester) async {
      await openChat(
        tester,
        chat(conversationJson(), [
          messageJson('1', 'Pay 100 dt on D17 first', mine: false, ago: const Duration(minutes: 5), warning: 'payment'),
          messageJson('2', 'Look: https://bit.ly/x', mine: false, ago: const Duration(minutes: 4), warning: 'link'),
          messageJson('3', 'pay?', mine: true, ago: const Duration(minutes: 3), warning: 'payment'),
        ]),
      );
      expect(find.text(l10n.warningPayment), findsOneWidget);
      expect(find.text(l10n.warningLink), findsOneWidget);
    });
  });

  testWidgets('the private detail field explains who sees it', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    phoneSize(tester);
    await tester.pumpWidget(
      app(Scaffold(body: PrivateDetailField(controller)), brightness: Brightness.light, api: FakeApi()),
    );
    await settle(tester);
    expect(find.text(l10n.privateDetailLabel), findsOneWidget);
    expect(find.text(l10n.privateDetailHelp), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), detail);
    expect(controller.text, detail);
  });
}
