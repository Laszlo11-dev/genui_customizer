import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

/// Shows host-provided generation diagnostics beside the current A2UI JSON.
Future<void> showGenUiDebugDialog({
  required BuildContext context,
  required Future<Map<String, Object?>> Function() load,
  required List<Map<String, Object?>> Function() currentUi,
  String? subject,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      _GenUiDebugDialog(load: load, currentUi: currentUi, subject: subject),
);

final class _GenUiDebugDialog extends StatefulWidget {
  const _GenUiDebugDialog({
    required this.load,
    required this.currentUi,
    required this.subject,
  });

  final Future<Map<String, Object?>> Function() load;
  final List<Map<String, Object?>> Function() currentUi;
  final String? subject;

  @override
  State<_GenUiDebugDialog> createState() => _GenUiDebugDialogState();
}

final class _GenUiDebugDialogState extends State<_GenUiDebugDialog> {
  late Future<Map<String, Object?>> _snapshot;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => _snapshot = widget.load();

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    return Dialog(
      child: SizedBox(
        width: min(1000, max(0, viewport.width - 32)),
        height: min(700, max(0, viewport.height - 32)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.subject == null
                          ? 'GenUI debug'
                          : 'GenUI debug · ${widget.subject}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Reload debug data',
                    onPressed: () => setState(_refresh),
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    tooltip: 'Close debug',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<Map<String, Object?>>(
                  future: _snapshot,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return SelectableText(
                        'Could not load GenUI debug data: ${snapshot.error}',
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final data = snapshot.data!;
                    final generation = data['lastGeneration'];
                    final trace = generation is Map ? generation : const {};
                    final entries = <(String, Object?)>[
                      ('Request', trace['request']),
                      ('Response', trace['response']),
                      ('Model output', trace['modelOutput']),
                      (
                        'Validation',
                        {
                          'status': trace['status'],
                          'result': trace['validation'],
                          'diagnostics': trace['diagnostics'],
                          'error': trace['error'],
                        },
                      ),
                      ('Saved draft', data['savedDraft']),
                      ('Saved accepted', data['savedAccepted']),
                      ('Current UI', widget.currentUi()),
                      if (data.containsKey('savedAppearance'))
                        ('Saved appearance', data['savedAppearance']),
                    ];
                    return DefaultTabController(
                      length: entries.length,
                      initialIndex:
                          trace['status'] == 'failed' &&
                              trace['response'] != null
                          ? 1
                          : 0,
                      child: Column(
                        children: [
                          if (trace['status'] == 'failed')
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: SelectableText(
                                'Generation failed: ${trace['validation'] ?? trace['error'] ?? 'Unknown error'}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            )
                          else if (generation == null)
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text('No captured generation yet.'),
                            ),
                          if (data['storageError'] case final error?)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: SelectableText(
                                'Saved definition read failed: $error',
                              ),
                            ),
                          TabBar(
                            isScrollable: true,
                            tabs: [
                              for (final entry in entries) Tab(text: entry.$1),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                for (final entry in entries)
                                  SingleChildScrollView(
                                    padding: const EdgeInsets.all(12),
                                    child: SelectableText(
                                      entry.$2 == null
                                          ? 'No data yet.'
                                          : const JsonEncoder.withIndent('  ')
                                                .convert(entry.$2),
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
