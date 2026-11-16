import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleai_dart/googleai_dart.dart' as google_ai;

import 'package:a2ui_flutter_touch_example/chat_app.dart';
import 'package:a2ui_flutter_touch_example/chat_session.dart';
import 'package:a2ui_flutter_touch_example/demo_client.dart';
import 'package:a2ui_flutter_touch_example/llm_client.dart';

class _BusyThenDemoClient implements LlmClient {
  int requests = 0;

  @override
  Stream<String> generate(String systemPrompt, List<ChatTurn> turns) async* {
    requests++;
    if (requests == 1) {
      throw const google_ai.ApiException(statusCode: 503, message: 'busy');
    }
    yield* DemoClient().generate(systemPrompt, turns);
  }
}

void main() {
  for (final longPress in [false, true]) {
    testWidgets(
      'Touch opens with ${longPress ? 'long press' : 'triple click'}',
      (tester) async {
        final session = ChatSession(client: DemoClient());
        addTearDown(session.dispose);
        await tester.pumpWidget(ChatApp(session: session));
        await tester.enterText(find.byType(TextField).first, 'Show UI');
        await tester.tap(find.byTooltip('Send'));
        await tester.pumpAndSettle();
        final heading = find.text('A2UI chat surface 1');
        if (longPress) {
          await tester.longPress(heading);
        } else {
          for (var i = 0; i < 3; i++) {
            await tester.tap(heading);
            await tester.pump(const Duration(milliseconds: 80));
          }
        }
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('genui-touch-studio-dialog')),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('demo actions and successive prompts keep the chat usable', (
    tester,
  ) async {
    final session = ChatSession(client: DemoClient());
    addTearDown(session.dispose);
    await tester.pumpWidget(ChatApp(session: session));
    await tester.enterText(find.byType(TextField).first, 'Show UI');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try action'));
    await tester.pumpAndSettle();
    expect(
      find.text('Sent: action demoAction'),
      findsOneWidget,
      reason: session.entries.map((e) => '${e.kind}: ${e.text}').join('\n'),
    );
    expect(
      find.textContaining('The demo action was received.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).first, 'Another UI');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text('A2UI chat surface 1'), findsOneWidget);
    expect(find.text('A2UI chat surface 3'), findsOneWidget);
    expect(
      session.entries.where((e) => e.kind == ChatEntryKind.error),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('official A2UI chat opens a movable, resizable Touch dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = ChatSession(client: DemoClient());
    addTearDown(session.dispose);
    await tester.pumpWidget(ChatApp(session: session));
    await tester.enterText(find.byType(TextField).first, 'Show me UI');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text('A2UI chat surface 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Open GenUI Touch'));
    await tester.pumpAndSettle();
    final dialog = find.byKey(const Key('genui-touch-studio-dialog'));
    expect(dialog, findsOneWidget);
    final before = tester.getRect(dialog);
    expect(before.width, lessThan(1400));
    expect(before.height, lessThan(900));
    await tester.drag(
      find.byKey(const Key('genui-studio-drag')),
      const Offset(-80, -40),
    );
    await tester.pumpAndSettle();
    final moved = tester.getRect(dialog);
    expect(moved.left, lessThan(before.left));
    await tester.drag(
      find.byKey(const Key('genui-studio-resize')),
      const Offset(-100, -80),
    );
    await tester.pumpAndSettle();
    final resized = tester.getRect(dialog);
    expect(resized.width, lessThan(moved.width));
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Default appearance'), findsOneWidget);
  });

  testWidgets('a 503 shows a retry action that can recover the chat', (
    tester,
  ) async {
    final client = _BusyThenDemoClient();
    final session = ChatSession(client: client);
    addTearDown(session.dispose);
    await tester.pumpWidget(ChatApp(session: session));
    await tester.enterText(find.byType(TextField).first, 'Show UI');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.textContaining('temporarily overloaded'), findsOneWidget);
    await tester.tap(find.text('Retry prompt'));
    await tester.pumpAndSettle();
    expect(client.requests, 2);
    expect(find.text('A2UI chat surface 1'), findsOneWidget);
  });
}
