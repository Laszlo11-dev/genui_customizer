// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' hide Catalog;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:genui/genui.dart';
import 'package:genui_a2a/genui_a2a.dart';
import 'package:genui_customizer/genui_customizer.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'primitives.dart';

const String defaultServerUrl = 'http://localhost:10002';

// https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json
// https://a2ui.org/specification/v0_9/standard_catalog.json

class RestaurantSession extends ChangeNotifier {
  RestaurantSession({
    String serverUrl = defaultServerUrl,
    this.onEditorRequested,
    this.useRecordedResponses = true,
  }) {
    final agentUri = Uri.parse(serverUrl);
    if (!useRecordedResponses &&
        (agentUri.scheme != 'http' ||
            !{'localhost', '127.0.0.1'}.contains(agentUri.host))) {
      throw ArgumentError.value(
        serverUrl,
        'serverUrl',
        'The optional live agent must use a loopback HTTP URL.',
      );
    }
    editor = GenUiCustomizer.attach(
      initial: const GenUiEditSnapshot(revision: 1, messages: []),
      registry: editableRegistry,
      storage: CallbackEditableGenUiStorage(
        onLoad: () async => _baseline,
        onSave: _saveAppearance,
      ),
      onSnapshotChanged: _renderEditedSnapshot,
      onEditorRequested: onEditorRequested,
    );
    final basic = BasicCatalogItems.asCatalog().copyWith(
      catalogId: _agentCatalogId,
    );
    final List<Catalog> catalogs = [
      basic.copyWith(
        newItems: [
          for (final item in basic.items)
            decorateEditableCatalogItem(item, editor),
        ],
      ),
    ];
    _connector = A2uiAgentConnector(url: agentUri);
    _surfaceController = SurfaceController(catalogs: catalogs);
    _init();
    _profileReady = _loadAppearance();
  }

  final VoidCallback? onEditorRequested;

  /// Uses recorded responses from the official Restaurant Finder agent.
  final bool useRecordedResponses;
  late final EditableGenUiController editor;
  late final Future<void> _profileReady;
  GenUiAppearanceProfile? _profile;
  GenUiEditSnapshot? _baseline;
  static const _profileKey = 'restaurant_finder_appearance_v1';
  static const _defaultsKey = 'restaurant_finder_gallery_defaults_v1';
  final Map<String, Map<String, Object?>> _galleryDefaults = {};
  Future<void>? _defaultsWrite;

  static final editableRegistry = EditableCatalogRegistry(
    catalogId: _agentCatalogId,
    catalogVersion: 1,
    components: [
      for (final item in BasicCatalogItems.asCatalog().items)
        if (item.name != 'Image' && item.name != 'Text')
          EditableComponentContract(type: item.name, properties: const []),
      EditableComponentContract(
        type: 'Image',
        properties: const [
          EditablePropertyContract(
            name: 'variant',
            label: 'Image size',
            type: EditablePropertyType.enumeration,
            enumValues: [
              'icon',
              'avatar',
              'smallFeature',
              'mediumFeature',
              'largeFeature',
              'header',
            ],
          ),
        ],
        protectedProperties: const {'url', 'child', 'children'},
      ),
      EditableComponentContract(
        type: 'Text',
        properties: const [
          EditablePropertyContract(
            name: 'variant',
            label: 'Text style',
            type: EditablePropertyType.enumeration,
            enumValues: ['h1', 'h2', 'h3', 'h4', 'h5', 'caption', 'body'],
          ),
        ],
        protectedProperties: const {'text'},
      ),
    ],
  );

  static String? componentRole(Map<String, Object?> component) {
    if (component['component'] == 'Text' && component['text'] == 'Book Now') {
      return 'restaurant-book-label';
    }
    final binding = switch (component['component']) {
      'Image' => component['url'],
      'Text' => component['text'],
      _ => null,
    };
    if (binding is! Map || binding['path'] is! String) return null;
    final path = binding['path'] as String;
    if (component['component'] == 'Image' && path.endsWith('imageUrl')) {
      return 'restaurant-image';
    }
    if (component['component'] == 'Text') {
      for (final field in const [
        'title',
        'name',
        'rating',
        'detail',
        'infoLink',
      ]) {
        if (path.split('/').last == field) return 'restaurant-$field';
      }
    }
    return null;
  }

  Future<void> _loadAppearance() async {
    final preferences = SharedPreferencesAsync();
    final saved = await preferences.getString(_profileKey);
    try {
      if (saved != null) {
        final profile = GenUiAppearanceProfile.fromJson(
          Map<String, Object?>.from(jsonDecode(saved) as Map),
        );
        if (profile.catalogId == editableRegistry.catalogId &&
            profile.catalogVersion == editableRegistry.catalogVersion) {
          _profile = profile;
        }
      }
    } on FormatException {
      // A stale profile must not prevent the agent-generated UI from loading.
    }
    final savedDefaults = await preferences.getString(_defaultsKey);
    if (savedDefaults == null) return;
    try {
      final decoded = jsonDecode(savedDefaults);
      if (decoded is! Map) return;
      for (final entry in decoded.entries) {
        if (entry.key is! String || entry.value is! Map) continue;
        final contract = editableRegistry.contractFor(entry.key as String);
        if (contract == null) continue;
        final values = <String, Object?>{};
        for (final property in (entry.value as Map).entries) {
          if (property.key is! String) continue;
          if (contract.properties[property.key]?.accepts(property.value) ==
              true) {
            values[property.key as String] = property.value;
          }
        }
        _galleryDefaults[entry.key as String] = values;
      }
    } on FormatException {
      // Ignore stale gallery defaults.
    }
  }

  Future<void> get appearanceReady => _profileReady;

  Map<String, Map<String, Object?>> galleryDefaults() => {
    for (final entry in _galleryDefaults.entries) entry.key: {...entry.value},
  };

  void saveGalleryDefaults(String type, Map<String, Object?> values) {
    final contract = editableRegistry.contractFor(type);
    if (contract == null ||
        values.entries.any(
          (entry) =>
              contract.properties[entry.key]?.accepts(entry.value) != true,
        )) {
      throw const FormatException('Invalid gallery appearance defaults.');
    }
    _galleryDefaults[type] = {...values};
    _defaultsWrite = SharedPreferencesAsync().setString(
      _defaultsKey,
      jsonEncode(_galleryDefaults),
    );
  }

  Future<void> flushGalleryDefaults() async => await _defaultsWrite;

  Map<String, Object?> _applyGalleryDefaults(Map<String, Object?> message) {
    if (_galleryDefaults.isEmpty) return message;
    final copy = Map<String, Object?>.from(
      jsonDecode(jsonEncode(message)) as Map,
    );
    final update = copy['updateComponents'];
    if (update is! Map || update['components'] is! List) return copy;
    for (final value in update['components'] as List) {
      if (value is! Map || value['component'] is! String) continue;
      final defaults = _galleryDefaults[value['component']];
      if (defaults != null) value.addAll(defaults);
    }
    return copy;
  }

  Future<void> _saveAppearance(GenUiEditSnapshot snapshot) async {
    final baseline = _baseline;
    if (baseline == null) return;
    final profile = GenUiAppearanceProfile.capture(
      before: baseline,
      after: snapshot,
      registry: editableRegistry,
      roleFor: componentRole,
      previous: _profile,
    );
    if (jsonEncode(profile.toJson()) == jsonEncode(_profile?.toJson())) {
      throw const FormatException(
        'This widget has no reusable appearance role; its style was not saved.',
      );
    }
    await SharedPreferencesAsync().setString(
      _profileKey,
      jsonEncode(profile.toJson()),
    );
    _profile = profile;
    _baseline = snapshot;
  }

  Future<void> resetAppearance() async {
    await _defaultsWrite;
    final preferences = SharedPreferencesAsync();
    await preferences.remove(_profileKey);
    await preferences.remove(_defaultsKey);
    _profile = null;
    _galleryDefaults.clear();
    notifyListeners();
  }

  void _renderEditedSnapshot(GenUiEditSnapshot snapshot) {
    for (final message in snapshot.messages) {
      if (message['updateComponents'] == null) continue;
      _surfaceController.handleMessage(A2uiMessage.fromJson(message));
    }
    notifyListeners();
  }

  // The agent advertises its catalog under this id (see the Python
  // BasicCatalog provider). The Dart `BasicCatalogItems.asCatalog()` defaults
  // to `.../standard_catalog.json`, so we override the id to match.
  //
  // Catalog id is already fixed in genui at main branch, so, as soon
  // as this fix gets released, the override will no longer be needed.
  static const String _agentCatalogId =
      'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';

  late final A2uiAgentConnector _connector;
  late final SurfaceController _surfaceController;

  SurfaceHost get surfaceHost => _surfaceController;

  bool _isRequesting = false;
  bool get isRequesting => _isRequesting;

  bool _isDisposed = false;

  bool _hasSentMessage = false;
  bool get hasSentMessage => _hasSentMessage;

  final LoadingTexts _loadingTexts = LoadingTexts();
  String get loadingText => _loadingTexts.current;

  String? _error;
  String? get error => _error;

  Iterable<String> get activeSurfaceIds => _surfaceController.activeSurfaceIds;

  final _logger = Logger('RestaurantSession');
  Timer? _loadingTimer;
  int _searchCount = 0;
  String? _lastRequestText;
  final List<Map<String, Object?>> _lastResponse = [];

  Future<Map<String, Object?>> debugData() async => {
    'lastGeneration': _lastRequestText == null
        ? null
        : {
            'status': useRecordedResponses ? 'recorded' : 'received',
            'request': {'text': _lastRequestText},
            'response': _lastResponse,
          },
    'savedDraft': null,
    'savedAccepted': null,
    'savedAppearance': {
      'profile': _profile?.toJson(),
      'galleryDefaults': galleryDefaults(),
    },
  };

  late final StreamSubscription<A2uiMessage> _a2uiSub;
  late final StreamSubscription<String> _textSub;
  late final StreamSubscription<ChatMessage> _submitSub;
  late final StreamSubscription<Object> _errorSub;
  late final StreamSubscription<SurfaceUpdate> _surfaceSub;

  void _init() {
    _a2uiSub = _connector.stream.listen(_handleUiFromAgent);
    _textSub = _connector.textStream.listen(_handleTextFromAgent);
    _submitSub = _surfaceController.onSubmit.listen(_handleSubmitFromSurface);
    _errorSub = _connector.errorStream.listen(_handleError);
    _surfaceSub = _surfaceController.surfaceUpdates.listen(_onSurfaceChanged);
  }

  void _handleSubmitFromSurface(ChatMessage message) {
    _sendMessageToAgent(message);
  }

  void _handleUiFromAgent(A2uiMessage message) {
    _lastResponse.add(Map<String, Object?>.from(message.toJson()));
    if (message is UpdateComponentsMessage) {
      final raw = _applyGalleryDefaults(
        Map<String, Object?>.from(message.toJson()),
      );
      final profiled =
          _profile?.applyToMessage(
            message: raw,
            registry: editableRegistry,
            roleFor: componentRole,
          ) ??
          raw;
      _baseline = GenUiEditSnapshot(revision: 1, messages: [profiled]);
      editor.setSurfaceSnapshot(_baseline!);
    } else {
      _surfaceController.handleMessage(message);
    }
  }

  void _handleTextFromAgent(String text) {
    _logger.info('Text from agent: $text');
  }

  void _handleError(Object err) {
    _error = err.toString();
    _logger.severe('Error from agent', err, StackTrace.current);
    notifyListeners();
  }

  void _onSurfaceChanged(SurfaceUpdate _) {
    notifyListeners();
  }

  void _startLoadingAnimation() {
    _loadingTexts.reset();
    _loadingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _loadingTexts.advance();
      notifyListeners();
    });
  }

  void _stopLoadingAnimation() {
    _loadingTimer?.cancel();
    _loadingTimer = null;
  }

  Future<void> sendMessage(String text) async {
    if (text.isEmpty) return;
    await _sendMessageToAgent(ChatMessage.user(text), requestText: text);
  }

  Future<void> _sendMessageToAgent(
    ChatMessage message, {
    String? requestText,
  }) async {
    if (_isRequesting) return;
    await _profileReady;
    _isRequesting = true;
    _hasSentMessage = true;
    _error = null;
    _lastRequestText = requestText ?? '[surface action]';
    _lastResponse.clear();
    _startLoadingAnimation();

    // Clear existing surfaces on each new request.
    for (final String id in [..._surfaceController.activeSurfaceIds]) {
      _surfaceController.handleMessage(DeleteSurfaceMessage(surfaceId: id));
    }
    _baseline = null;
    editor.setSurfaceSnapshot(
      const GenUiEditSnapshot(revision: 1, messages: []),
    );

    notifyListeners();
    try {
      if (useRecordedResponses) {
        final file = _searchCount++ == 0
            ? 'assets/first_search.json'
            : 'assets/next_search.json';
        final response = jsonDecode(await rootBundle.loadString(file)) as List;
        for (final value in response) {
          _handleUiFromAgent(
            A2uiMessage.fromJson(Map<String, dynamic>.from(value as Map)),
          );
        }
      } else {
        await _connector.connectAndSend(
          message,
          clientCapabilities: _surfaceController.clientCapabilities,
        );
      }
    } catch (e, st) {
      _error = e.toString();
      _logger.severe('Error sending message', e, st);
    } finally {
      _isRequesting = false;
      _stopLoadingAnimation();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _a2uiSub.cancel();
    _textSub.cancel();
    _submitSub.cancel();
    _errorSub.cancel();
    _surfaceSub.cancel();
    _loadingTimer?.cancel();
    _surfaceController.dispose();
    editor.dispose();
    _connector.dispose();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }
}
