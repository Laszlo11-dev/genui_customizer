import 'dart:async';

import 'package:a2ui_flutter_touch_example/chat_session.dart';
import 'package:a2ui_flutter_touch_example/demo_client.dart';
import 'package:a2ui_flutter_touch_example/llm_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _StreamClient implements LlmClient {
  final controller = StreamController<String>();
  final started = Completer<void>();
  int requests = 0;

  @override
  Stream<String> generate(String systemPrompt, List<ChatTurn> turns) {
    requests++;
    started.complete();
    return controller.stream;
  }
}

void main() {
  test('ignores blank input and input after disposal', () async {
    final session = ChatSession(client: DemoClient());
    await session.send('   ');
    expect(session.entries, isEmpty);
    session.dispose();
    await session.send('Show UI');
    expect(session.entries, isEmpty);
    expect(session.busy, isFalse);
  });

  test('cancels a failed stream even when the producer stays open', () async {
    final client = _StreamClient();
    final session = ChatSession(client: client);
    addTearDown(session.dispose);
    final cancelled = Completer<void>();
    client.controller.onCancel = cancelled.complete;
    final turn = session.send('Show UI');
    await client.started.future;
    client.controller.addError(StateError('Connection lost'));
    await turn;
    expect(cancelled.isCompleted, isTrue);
    expect(session.busy, isFalse);
    expect(session.entries.last.kind, ChatEntryKind.error);
    await client.controller.close();
  });

  test('disposal cancels the active reply and skips queued requests', () async {
    final client = _StreamClient();
    final session = ChatSession(client: client);
    final first = session.send('First');
    await client.started.future;
    final second = session.send('Second');
    session.dispose();
    await Future.wait([first, second]);
    expect(client.requests, 1);
    expect(client.controller.hasListener, isFalse);
    expect(session.busy, isFalse);
    await client.controller.close();
  });
}
