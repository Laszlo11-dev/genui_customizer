// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore: deprecated_member_use, see https://github.com/a2ui-project/a2ui/issues/3235
import 'package:flutter/material.dart';
import 'package:genui/genui.dart' show DataPath;
import 'package:genui_customizer/genui_customizer.dart';
import 'package:logging/logging.dart';

import 'agent/recorded_ai_client.dart';
import 'agent/ai_client.dart' show DartanticAiClient;
import 'chat_session.dart';
import 'primitives/app_mode.dart';
import 'primitives/message.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Configure logging for the app.
  Logger.root.level = Level.WARNING;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);
    return MaterialApp(
      title: 'Simple Chat · GenUI Touch',
      theme: ThemeData(colorScheme: colorScheme),
      darkTheme: ThemeData(
        colorScheme: colorScheme.copyWith(brightness: Brightness.dark),
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.aiClient});

  final AiClient? aiClient;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

const String _defaultUserMessage =
    """I'm into rock climbing. Give me a few climbing locations around Las Vegas. I'm a beginner.""";

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController(
    text: _defaultUserMessage,
  );
  final ScrollController _scrollController = ScrollController();
  late ChatSession _chatSession;
  AppMode _appMode = AppMode.customCatalog;
  AiClient? _ownedClient;
  bool _studioOpen = false;
  String? _editingSurfaceId;
  static const bool _live = bool.fromEnvironment('GENUI_CHAT_LIVE');

  @override
  void initState() {
    super.initState();
    _reCreateChatSession(dispose: false);
  }

  void _reCreateChatSession({bool dispose = true}) {
    if (dispose) {
      _chatSession.removeListener(_scrollToBottom);
      _chatSession.dispose();
      _ownedClient?.dispose();
    }
    _ownedClient = widget.aiClient == null
        ? (_live ? DartanticAiClient() : RecordedChatAiClient(mode: _appMode))
        : null;
    _chatSession = ChatSession(
      aiClient: widget.aiClient ?? _ownedClient,
      mode: _appMode,
    );
    final session = _chatSession;
    if (session is A2uiChatSession) {
      session.touch.onEditorRequested = (id) => _openStudio(session, id);
      session.touch.onSurfaceRemoved = (id) {
        if (mounted && _studioOpen && _editingSurfaceId == id) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      };
    }
    // Add a listener to scroll to bottom when messages change.
    _chatSession.addListener(_scrollToBottom);
    _textController.text = _defaultUserMessage;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _chatSession,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Simple Chat · GenUI Touch'),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: DropdownButton<AppMode>(
                  value: _appMode,
                  underline: const SizedBox.shrink(),
                  onChanged: _studioOpen || _chatSession.isProcessing
                      ? null
                      : (mode) {
                          if (mode == null) return;
                          _changeMode(mode);
                        },
                  items: [
                    for (final mode in AppMode.values)
                      DropdownMenuItem(
                        value: mode,
                        child: Text(mode.displayName),
                      ),
                  ],
                ),
              ),
            ],
          ),

          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    widget.aiClient != null
                        ? 'Provided AI client'
                        : _live
                        ? 'Live Gemini chat'
                        : 'Recorded demo · no API key required',
                  ),
                ),
                if (_chatSession is A2uiChatSession)
                  const Text('Saved edits last for this conversation.'),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _chatSession.messages.length,
                    itemBuilder: (context, index) {
                      final Message message = _chatSession.messages[index];
                      // Pass the controller as the host.
                      final session = _chatSession;
                      final id = message.surfaceId;
                      return ListTile(
                        title: MessageView(
                          message,
                          _chatSession.surfaceController,
                        ),
                        subtitle: id != null && session is A2uiChatSession
                            ? Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  icon: const Icon(Icons.tune),
                                  label: const Text('GenUI Touch'),
                                  onPressed:
                                      _studioOpen ||
                                          session.isProcessing ||
                                          session.touch.editorFor(id) == null
                                      ? null
                                      : () => _openStudio(session, id),
                                ),
                              )
                            : null,
                        tileColor: message.isUser
                            ? Colors.blue.withValues(alpha: 0.1)
                            : null,
                      );
                    },
                  ),
                ),

                if (_chatSession.isProcessing)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),

                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          decoration: const InputDecoration(
                            hintText: 'Type your message...',
                          ),
                          enabled: !_chatSession.isProcessing,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _chatSession.isProcessing
                            ? null
                            : _sendMessage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _changeMode(AppMode mode) {
    if (mode == _appMode) return;
    setState(() {
      _appMode = mode;
      _reCreateChatSession();
    });
  }

  Future<void> _openStudio(A2uiChatSession session, String surfaceId) async {
    if (_studioOpen || session.isProcessing || !mounted) return;
    final editor = session.touch.editorFor(surfaceId);
    if (editor == null) return;
    setState(() {
      _studioOpen = true;
      _editingSurfaceId = surfaceId;
    });
    try {
      await showEditableGenUiStudio(
        context: context,
        controller: editor,
        galleryTypes: session.touch.catalog.items.map((item) => item.name),
        galleryCatalog: session.touch.catalog,
        galleryViewModel: Map<String, Object?>.from(
          session.surfaceController
                  .contextFor(surfaceId)
                  .dataModel
                  .getValue<Map>(DataPath.root) ??
              const {},
        ),
        debugSubject: 'Simple Chat · $surfaceId',
        loadDebugData: () async => {
          'surfaceId': surfaceId,
          'saveScope': 'Current conversation only',
          'messages': editor.snapshot.messages,
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _studioOpen = false;
          _editingSurfaceId = null;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final String text = _textController.text;
    if (text.isEmpty) return;
    _textController.clear();
    await _chatSession.sendMessage(text);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _chatSession.dispose();
    _ownedClient?.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
