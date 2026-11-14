import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/widgets.dart';

/// Types the host permits a user to change for presentation purposes.
enum TouchValueKind { choice, text, boolean, number, color }

/// A host-approved visual property. It must also exist in the A2UI catalog.
final class TouchProperty {
  const TouchProperty({
    required this.name,
    required this.label,
    required this.kind,
    this.choices = const [],
    this.allowNull = false,
  });

  final String name;
  final String label;
  final TouchValueKind kind;
  final List<String> choices;
  final bool allowNull;

  bool accepts(Object? value) {
    if (value == null) return allowNull;
    return switch (kind) {
      TouchValueKind.choice => value is String && choices.contains(value),
      TouchValueKind.text => value is String,
      TouchValueKind.boolean => value is bool,
      TouchValueKind.number => value is num,
      TouchValueKind.color =>
        value is String &&
            RegExp(r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(value),
    };
  }
}

/// A type and its visual-property allowlist within one catalog.
final class TouchContract {
  TouchContract({
    required this.catalogId,
    required this.componentType,
    required Iterable<TouchProperty> properties,
  }) : properties = Map.unmodifiable({for (final p in properties) p.name: p});

  final String catalogId;
  final String componentType;
  final Map<String, TouchProperty> properties;
}

/// A selected definition and the rendered occurrence that was touched.
final class TouchSelection {
  const TouchSelection({
    required this.surfaceId,
    required this.componentId,
    required this.catalogId,
    required this.componentType,
    required this.instanceId,
    required this.dataPath,
  });

  final String surfaceId;
  final String componentId;
  final String catalogId;
  final String componentType;
  final String instanceId;
  final String dataPath;
}

/// A stable presentation role supplied by the host, not a rendered index.
typedef TouchRoleResolver = String? Function(
  TouchSelection component,
  Map<String, Object?> definition,
);

/// Persistence is owned by the host application and its authorization rules.
abstract interface class TouchStorage {
  Future<TouchProfile?> load();
  Future<void> save(TouchProfile profile);
}

/// Optional host AI service. The package validates the proposed value itself.
typedef TouchPropertyComposer = Future<Object?> Function(
  TouchSelection selection,
  TouchProperty property,
  String instruction,
);

/// Portable saved defaults and role preferences, independent of component IDs.
final class TouchProfile {
  TouchProfile({
    Map<String, Map<String, Object?>> defaults = const {},
    Map<String, Map<String, Object?>> roles = const {},
  }) : defaults = _freeze(defaults),
       roles = _freeze(roles);

  const TouchProfile.empty() : defaults = const {}, roles = const {};

  static Map<String, Map<String, Object?>> _freeze(
    Map<String, Map<String, Object?>> rules,
  ) => Map.unmodifiable({
    for (final entry in rules.entries)
      entry.key: Map<String, Object?>.unmodifiable({
        for (final property in entry.value.entries)
          property.key: _freezeValue(property.value),
      }),
  });

  static Object? _freezeValue(Object? value) {
    if (value is Map) {
      return Map<String, Object?>.unmodifiable({
        for (final entry in value.entries)
          entry.key as String: _freezeValue(entry.value),
      });
    }
    if (value is List) {
      return List<Object?>.unmodifiable(value.map(_freezeValue));
    }
    return value;
  }

  /// Keys are `catalogId\u0000componentType`; values are property maps.
  final Map<String, Map<String, Object?>> defaults;

  /// Keys are `catalogId\u0000componentType\u0000role`.
  final Map<String, Map<String, Object?>> roles;

  Map<String, Object?> toJson() => {
    'formatVersion': 2,
    'defaults': defaults,
    'roles': roles,
  };

  factory TouchProfile.fromJson(Map<String, Object?> json) {
    if (json['formatVersion'] != 2) {
      throw const FormatException('Unsupported Touch profile format.');
    }
    Map<String, Map<String, Object?>> read(Object? raw) {
      if (raw is! Map) throw const FormatException('Invalid Touch profile.');
      final result = <String, Map<String, Object?>>{};
      for (final entry in raw.entries) {
        if (entry.key is! String || entry.value is! Map) {
          throw const FormatException('Invalid Touch profile rule.');
        }
        result[entry.key as String] = Map<String, Object?>.from(
          (entry.value as Map).cast<String, Object?>(),
        );
      }
      return result;
    }

    return TouchProfile(
      defaults: read(json['defaults']),
      roles: read(json['roles']),
    );
  }
}

final class _LocalEdit {
  const _LocalEdit(
    this.selection,
    this.property,
    this.before,
    this.beforeSet,
    this.after,
  );
  final TouchSelection selection;
  final String property;
  final Object? before;
  final bool beforeSet;
  final Object? after;
}

/// Coordinates appearance edits while A2UI owns the actual surface state.
///
/// Call [attachProcessor] before [processAgentMessages]. The host owns and
/// disposes the processor. Feed every agent message through this controller so
/// saved appearance is applied before the processor sees it.
final class GenUiTouchController extends ChangeNotifier {
  GenUiTouchController({
    required Iterable<TouchContract> contracts,
    this.roleFor,
    this.storage,
    this.composer,
    this.onStudioRequested,
    this.showSelectionOutline = true,
    TouchProfile profile = const TouchProfile.empty(),
  }) : _contracts = Map.unmodifiable({
         for (final contract in contracts)
           _typeKey(contract.catalogId, contract.componentType): contract,
       }),
       _savedProfile = profile,
       _profile = profile;

  final Map<String, TouchContract> _contracts;
  final TouchRoleResolver? roleFor;
  final TouchStorage? storage;
  final TouchPropertyComposer? composer;
  VoidCallback? onStudioRequested;
  final bool showSelectionOutline;
  MessageProcessor<ComponentImplementation>? _processor;
  TouchProfile _savedProfile;
  TouchProfile _profile;
  TouchProfile _remoteProfile = const TouchProfile.empty();
  TouchProfile _localProfile = const TouchProfile.empty();
  bool _editingRemote = false;
  Future<void> Function(TouchProfile)? _configurationSaver;
  String? _configurationLabel;
  TouchSelection? _selection;
  final List<_LocalEdit> _undo = [];
  final List<_LocalEdit> _redo = [];
  final Map<String, String> _surfaceCatalogs = {};
  DateTime? _lastTap;
  String? _lastTapped;
  int _tapCount = 0;
  String? _error;
  int _revision = 0;
  int _profileContext = 0;

  MessageProcessor<ComponentImplementation> get processor =>
      _processor ??
      (throw StateError('Attach the A2UI MessageProcessor first.'));
  TouchSelection? get selection => _selection;
  TouchProfile get profile => _profile;
  String? get error => _error;
  int get revision => _revision;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get canPersist => storage != null || _configurationSaver != null;
  bool get hasUnsavedProfileChanges => !identical(_profile, _savedProfile);
  String? get configurationLabel => _configurationLabel;
  Iterable<TouchContract> get contracts => _contracts.values;

  /// Selects independent remote and local appearance layers for one context.
  /// The selected layer is edited and saved; the other layer remains untouched.
  /// The host loads and validates full occasion data separately, then supplies
  /// its profile and a saver for the selected configuration record.
  void useConfigurations({
    required TouchProfile remote,
    required TouchProfile local,
    required bool editRemote,
    required Future<void> Function(TouchProfile) saveEditedProfile,
    String? label,
  }) {
    _profileContext++;
    _remoteProfile = remote;
    _localProfile = local;
    _editingRemote = editRemote;
    _configurationSaver = saveEditedProfile;
    _configurationLabel = label;
    _profile = editRemote ? remote : local;
    _savedProfile = _profile;
    _undo.clear();
    _redo.clear();
    _revision++;
    notifyListeners();
  }

  void attachProcessor(MessageProcessor<ComponentImplementation> value) {
    if (_processor != null) {
      throw StateError('A processor is already attached.');
    }
    _processor = value;
  }

  /// Wraps builders without changing the catalog ID, schema, or action logic.
  CatalogImplementation decorateCatalog(CatalogImplementation source) {
    return source.copyWith(
      components: [
        for (final item in source.components.values)
          if (_contracts.containsKey(_typeKey(source.id, item.name)))
            ComponentImplementation(
              name: item.name,
              schema: item.schema,
              allowedParents: item.allowedParents,
              allowedChildren: item.allowedChildren,
              builder: (context, node, props, buildChild) {
                final child = item.builder(context, node, props, buildChild);
                final surfaceId = A2uiSurface.maybeOf(context)?.id;
                if (surfaceId == null) return child;
                final selected = TouchSelection(
                  surfaceId: surfaceId,
                  componentId: node.componentId,
                  catalogId: source.id,
                  componentType: node.type,
                  instanceId: node.instanceId,
                  dataPath: node.dataPath,
                );
                return _TouchRegion(
                  controller: this,
                  selection: selected,
                  child: child,
                );
              },
            )
          else
            item,
      ],
    );
  }

  TouchContract? contractFor(TouchSelection selected) =>
      _contracts[_typeKey(selected.catalogId, selected.componentType)];

  Map<String, Object?>? component(TouchSelection selected) {
    final model = processor.model
        .getSurface(selected.surfaceId)
        ?.componentsModel
        .get(selected.componentId);
    return model?.toJson().cast<String, Object?>();
  }

  void select(TouchSelection selected, {bool openStudio = false}) {
    if (contractFor(selected) == null || component(selected) == null) return;
    _selection = selected;
    _error = null;
    notifyListeners();
    if (openStudio) onStudioRequested?.call();
  }

  void _tap(TouchSelection selected) {
    final now = DateTime.now();
    final key = '${selected.surfaceId}\u0000${selected.instanceId}';
    if (_lastTapped == key &&
        _lastTap != null &&
        now.difference(_lastTap!) < const Duration(milliseconds: 600)) {
      _tapCount++;
    } else {
      _tapCount = 1;
    }
    _lastTap = now;
    _lastTapped = key;
    if (_tapCount >= 3) {
      _tapCount = 0;
      select(selected, openStudio: true);
    }
  }

  /// Applies v1.0 agent payloads after layering saved appearance on literals.
  void processAgentMessages(Object? payload) {
    final messages = _messages(payload);
    final touched = <String>{};
    final deletedSurfaces = <String>{};
    final patched = <Map<String, Object?>>[];
    for (final message in messages) {
      if (message['version'] != '1.0') {
        throw const FormatException('GenUI Touch requires A2UI version 1.0.');
      }
      final copy = _copy(message);
      final create = copy['createSurface'];
      final update = copy['updateComponents'];
      final body = create is Map
          ? create
          : update is Map
          ? update
          : null;
      if (body != null && body['surfaceId'] is String) {
        final surfaceId = body['surfaceId'] as String;
        if (create is Map && create['catalogId'] is String) {
          _surfaceCatalogs[surfaceId] = create['catalogId'] as String;
        }
        final raw = body['components'];
        if (raw is List) {
          for (final value in raw) {
            if (value is! Map ||
                value['id'] is! String ||
                value['component'] is! String) {
              continue;
            }
            final component = value.cast<String, Object?>();
            touched.add('$surfaceId\u0000${component['id']}');
            _applyProfile(surfaceId, component);
          }
        }
      }
      final deleted = copy['deleteSurface'];
      if (deleted is Map && deleted['surfaceId'] is String) {
        final surfaceId = deleted['surfaceId'] as String;
        _surfaceCatalogs.remove(surfaceId);
        deletedSurfaces.add(surfaceId);
      }
      patched.add(copy);
    }
    processor.processMessages(patched);
    _undo.removeWhere(
      (edit) =>
          deletedSurfaces.contains(edit.selection.surfaceId) ||
          touched.contains(
            '${edit.selection.surfaceId}\u0000${edit.selection.componentId}',
          ),
    );
    _redo.clear();
    if (_selection case final selected?) {
      if (component(selected) == null) _selection = null;
    }
    _revision++;
    notifyListeners();
  }

  /// Changes one permitted literal on the selected component.
  void edit(String property, Object? value) {
    final selected = _selection ?? (throw StateError('No component selected.'));
    final rule = contractFor(selected)?.properties[property];
    if (rule == null || !rule.accepts(value)) {
      throw FormatException(
        'Property $property is not an allowed visual value.',
      );
    }
    final before = component(selected)!;
    final old = before[property];
    if (_isExpression(old)) {
      throw FormatException('Property $property is bound or computed.');
    }
    if (old == value && before.containsKey(property)) return;
    _write(selected, property, value, present: true);
    _undo.add(
      _LocalEdit(selected, property, old, before.containsKey(property), value),
    );
    _redo.clear();
    _error = null;
    _revision++;
    notifyListeners();
  }

  void _write(
    TouchSelection selected,
    String property,
    Object? value, {
    required bool present,
  }) {
    final current =
        component(selected) ??
        (throw StateError('The selected component no longer exists.'));
    if (present) {
      current[property] = value;
    } else {
      current.remove(property);
    }
    processor.processMessages({
      'version': '1.0',
      'updateComponents': {
        'surfaceId': selected.surfaceId,
        'components': [current],
      },
    });
  }

  void undo() {
    if (_undo.isEmpty) return;
    final edit = _undo.last;
    _write(edit.selection, edit.property, edit.before, present: edit.beforeSet);
    _undo.removeLast();
    _redo.add(edit);
    _revision++;
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    final edit = _redo.last;
    _write(edit.selection, edit.property, edit.after, present: true);
    _redo.removeLast();
    _undo.add(edit);
    _revision++;
    notifyListeners();
  }

  /// Runtime Gallery defaults are applied to later agent messages and previews.
  void setGalleryDefault(
    TouchContract contract,
    String property,
    Object? value,
  ) {
    final rule = contract.properties[property];
    if (rule == null || !rule.accepts(value)) {
      throw FormatException(
        'Property $property is not an allowed visual value.',
      );
    }
    final defaults = _nestedCopy(_profile.defaults);
    defaults.putIfAbsent(
      _typeKey(contract.catalogId, contract.componentType),
      () => {},
    )[property] = value;
    _profile = TouchProfile(defaults: defaults, roles: _profile.roles);
    _revision++;
    notifyListeners();
  }

  /// Removes one catalog-wide override so the host's generated value applies.
  void removeGalleryDefault(TouchContract contract, String property) {
    if (!contract.properties.containsKey(property)) {
      throw FormatException('Property $property is not editable.');
    }
    final key = _typeKey(contract.catalogId, contract.componentType);
    if (_profile.defaults[key]?.containsKey(property) != true) return;
    final defaults = _nestedCopy(_profile.defaults);
    defaults[key]!.remove(property);
    if (defaults[key]!.isEmpty) defaults.remove(key);
    _profile = TouchProfile(defaults: defaults, roles: _profile.roles);
    _revision++;
    notifyListeners();
  }

  /// Removes every override for a catalog type.
  void clearGalleryDefaults(TouchContract contract) {
    final key = _typeKey(contract.catalogId, contract.componentType);
    if (!_profile.defaults.containsKey(key)) return;
    final defaults = _nestedCopy(_profile.defaults)..remove(key);
    _profile = TouchProfile(defaults: defaults, roles: _profile.roles);
    _revision++;
    notifyListeners();
  }

  /// Saves the selected literal as a preference for a host-defined stable role.
  /// A local edit alone never changes reusable role preferences.
  void setRoleDefaultForSelection(String property) {
    final selected = _selection ?? (throw StateError('No component selected.'));
    final definition =
        component(selected) ??
        (throw StateError('The selected component no longer exists.'));
    final role = roleFor?.call(selected, definition);
    if (role == null || role.isEmpty) {
      throw StateError('The host has not assigned a stable presentation role.');
    }
    final value = definition[property];
    if (contractFor(selected)?.properties[property]?.accepts(value) != true ||
        _isExpression(value)) {
      throw FormatException(
        'Property $property is not an allowed visual literal.',
      );
    }
    final roles = _nestedCopy(_profile.roles);
    roles.putIfAbsent(
      _roleKey(selected.catalogId, selected.componentType, role),
      () => {},
    )[property] = value;
    _profile = TouchProfile(defaults: _profile.defaults, roles: roles);
    _revision++;
    notifyListeners();
  }

  Future<void> propose(String property, String instruction) async {
    final selected = _selection;
    final propose = composer;
    if (selected == null || propose == null) return;
    final rule = contractFor(selected)?.properties[property];
    if (rule == null) {
      throw FormatException('Property $property is not editable.');
    }
    final started = _revision;
    final value = await propose(selected, rule, instruction);
    if (_revision != started || _selection != selected) {
      throw StateError('The surface changed while the proposal was pending.');
    }
    edit(property, value);
  }

  Future<void> save() async {
    final context = _profileContext;
    final saving = _profile;
    final configurationSaver = _configurationSaver;
    if (configurationSaver != null) {
      await configurationSaver(saving);
      if (context == _profileContext) {
        _savedProfile = saving;
        notifyListeners();
      }
      return;
    }
    final destination =
        storage ??
        (throw StateError('The host has not configured TouchStorage.'));
    await destination.save(saving);
    if (context == _profileContext) {
      _savedProfile = saving;
      notifyListeners();
    }
  }

  Future<void> load() async {
    final context = _profileContext;
    final current = _profile;
    final loaded = await storage?.load();
    if (loaded == null ||
        context != _profileContext ||
        !identical(current, _profile)) {
      return;
    }
    _profileContext++;
    _savedProfile = loaded;
    _profile = loaded;
    _revision++;
    notifyListeners();
  }

  void discardGalleryChanges() {
    _profile = _savedProfile;
    _revision++;
    notifyListeners();
  }

  void _applyProfile(String surfaceId, Map<String, Object?> component) {
    final type = component['component'] as String;
    final catalog =
        (component['catalogId'] as String?) ?? _surfaceCatalogs[surfaceId];
    if (catalog == null) return;
    final contract = _contracts[_typeKey(catalog, type)];
    if (contract == null) return;
    final definition = Map<String, Object?>.from(component);
    final selected = TouchSelection(
      surfaceId: surfaceId,
      componentId: component['id'] as String,
      catalogId: catalog,
      componentType: type,
      instanceId: component['id'] as String,
      dataPath: '',
    );
    final role = roleFor?.call(selected, definition);
    Map<String, Object?> rules(TouchProfile profile) => {
      ...?profile.defaults[_typeKey(catalog, type)],
      if (role != null) ...?profile.roles[_roleKey(catalog, type, role)],
    };
    final remote = _configurationSaver == null
        ? const TouchProfile.empty()
        : _editingRemote
        ? _profile
        : _remoteProfile;
    final local = _configurationSaver == null
        ? _profile
        : _editingRemote
        ? _localProfile
        : _profile;
    final overrides = {...rules(remote), ...rules(local)};
    for (final entry in overrides.entries) {
      if (contract.properties[entry.key]?.accepts(entry.value) == true &&
          !_isExpression(component[entry.key])) {
        component[entry.key] = entry.value;
      }
    }
  }

  static String _typeKey(String catalog, String type) => '$catalog\u0000$type';
  static String _roleKey(String catalog, String type, String role) =>
      '$catalog\u0000$type\u0000$role';
  static bool _isExpression(Object? value) =>
      value is Map &&
      (value.containsKey('@path') || value.containsKey('@call'));
  static Map<String, Map<String, Object?>> _nestedCopy(
    Map<String, Map<String, Object?>> source,
  ) => {
    for (final entry in source.entries) entry.key: {...entry.value},
  };
  static Map<String, Object?> _copy(Map<String, Object?> value) =>
      (jsonDecode(jsonEncode(value)) as Map).cast<String, Object?>();
  static List<Map<String, Object?>> _messages(Object? payload) {
    final raw = payload is List
        ? payload
        : payload is Map && payload['messages'] is List
        ? payload['messages'] as List
        : [payload];
    return [
      for (final value in raw)
        if (value is Map)
          value.cast<String, Object?>()
        else
          throw const FormatException('Invalid A2UI message.'),
    ];
  }
}

final class _TouchRegion extends StatelessWidget {
  const _TouchRegion({
    required this.controller,
    required this.selection,
    required this.child,
  });
  final GenUiTouchController controller;
  final TouchSelection selection;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => controller._tap(selection),
      onLongPress: () => controller.select(selection, openStudio: true),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border:
              controller.showSelectionOutline &&
                  controller.selection?.surfaceId == selection.surfaceId &&
                  controller.selection?.instanceId == selection.instanceId
              ? Border.all(color: const Color(0xFF2962FF), width: 2)
              : null,
        ),
        child: child,
      ),
    ),
  );
}
