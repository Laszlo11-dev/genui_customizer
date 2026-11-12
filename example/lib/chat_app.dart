// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/basic_catalog.dart';
// ignore: deprecated_member_use, see https://github.com/a2ui-project/a2ui/issues/3235
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:genui_customizer/genui_customizer.dart';
import 'package:url_launcher/url_launcher.dart';

import 'chat_session.dart';

/// A chat app showing the entries of [session], newest at the bottom, above
/// a text field for the user's next turn.
class ChatApp extends StatefulWidget {
  const ChatApp({super.key, required this.session});

  final ChatSession session;

  @override
  State<ChatApp> createState() => _ChatAppState();
}

class _ChatAppState extends State<ChatApp> {
  final TextEditingController _input = TextEditingController();

  void _openStudio(BuildContext context) {
    final selectedId = widget.session.touch.selection?.surfaceId;
    SurfaceModel<ComponentImplementation>? surface;
    if (selectedId != null) {
      surface = widget.session.processor.model.getSurface(selectedId);
    }
    for (final entry in widget.session.entries.reversed) {
      surface ??= entry.surface;
      if (surface != null) break;
    }
    if (surface == null) return;
    unawaited(
      showGenUiTouchStudio(
        context: context,
        controller: widget.session.touch,
        surfaceId: surface.id,
        galleryPreview: (context, contract, values) => Text(
          'Sample ${contract.componentType}',
          style: values['variant'] == 'caption'
              ? Theme.of(context).textTheme.bodySmall
              : Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }

  void _send() {
    final String text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    unawaited(widget.session.send(text));
  }

  void _retryLastPrompt() {
    for (final entry in widget.session.entries.reversed) {
      if (entry.kind == ChatEntryKind.user) {
        unawaited(widget.session.send(entry.text));
        return;
      }
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'A2UI chat',
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    home: Builder(
      builder: (appContext) {
        widget.session.touch.onStudioRequested = () => _openStudio(appContext);
        return Scaffold(
          appBar: AppBar(
            title: const Text('A2UI chat'),
            actions: [
              IconButton(
                tooltip: 'Open GenUI Touch',
                onPressed: () => _openStudio(appContext),
                icon: const Icon(Icons.tune),
              ),
            ],
          ),
          body: ListenableBuilder(
            listenable: widget.session,
            builder: (context, _) => Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final ChatEntry entry in widget.session.entries)
                          _buildEntry(context, entry, _retryLastPrompt),
                      ],
                    ),
                  ),
                ),
                if (widget.session.busy) const LinearProgressIndicator(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          decoration: const InputDecoration(
                            hintText: 'Ask for some UI',
                          ),
                          onEditingComplete: _send,
                        ),
                      ),
                      TextFieldTapRegion(
                        child: IconButton(
                          tooltip: 'Send',
                          icon: const Icon(Icons.send),
                          onPressed: _send,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Widget _buildEntry(
  BuildContext context,
  ChatEntry entry,
  VoidCallback onRetry,
) {
  final ColorScheme colors = Theme.of(context).colorScheme;
  if (entry.surface case final SurfaceModel<ComponentImplementation> surface) {
    return Card.outlined(
      key: ObjectKey(surface),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: A2uiMarkdown(
          builder: _markdown,
          child: A2uiSurface(surface: surface),
        ),
      ),
    );
  }
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: switch (entry.kind) {
      ChatEntryKind.user => Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(entry.text),
        ),
      ),
      ChatEntryKind.sent => Text(
        'Sent: ${entry.text}',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: colors.outline,
        ),
      ),
      ChatEntryKind.error => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.text, style: TextStyle(color: colors.error)),
          if (entry.text.startsWith('Gemini is temporarily overloaded'))
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry prompt'),
            ),
        ],
      ),
      _ => MarkdownBody(data: entry.text, onTapLink: _openLink),
    },
  );
}

/// Renders [markdown] with [style] as its paragraph style, and opens a
/// tapped link.
Widget _markdown(BuildContext context, String markdown, TextStyle style) =>
    MarkdownBody(
      data: markdown,
      onTapLink: _openLink,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
          .copyWith(p: style),
    );

/// Opens [href] with `url_launcher`.
void _openLink(String text, String? href, String title) {
  final Uri? uri = href == null ? null : Uri.tryParse(href);
  if (uri != null) launchUrl(uri).ignore();
}
