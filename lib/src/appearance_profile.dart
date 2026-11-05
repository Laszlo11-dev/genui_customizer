import 'dart:convert';

import 'core/core.dart';

/// Gives a generated component a stable, application-defined presentation role.
/// For example, two restaurant result templates may both be `restaurant-image`.
typedef GenUiComponentRole = String? Function(Map<String, Object?> component);

/// A saved visual choice, independent of component IDs and generated content.
final class GenUiAppearanceRule {
  const GenUiAppearanceRule({
    required this.role,
    required this.componentType,
    required this.properties,
  });

  final String role;
  final String componentType;
  final Map<String, Object?> properties;

  Map<String, Object?> toJson() => {
    'role': role,
    'componentType': componentType,
    'properties': properties,
  };
}

/// Portable preferences for one version of one GenUI catalog.
final class GenUiAppearanceProfile {
  const GenUiAppearanceProfile({
    required this.catalogId,
    required this.catalogVersion,
    required this.rules,
  });

  final String catalogId;
  final int catalogVersion;
  final List<GenUiAppearanceRule> rules;

  Map<String, Object?> toJson() => {
    'formatVersion': 1,
    'catalogId': catalogId,
    'catalogVersion': catalogVersion,
    'rules': [for (final rule in rules) rule.toJson()],
  };

  factory GenUiAppearanceProfile.fromJson(Map<String, Object?> json) {
    if (json['formatVersion'] != 1 ||
        json['catalogId'] is! String ||
        json['catalogVersion'] is! int ||
        json['rules'] is! List) {
      throw const FormatException('Invalid GenUI appearance profile.');
    }
    final rules = <GenUiAppearanceRule>[];
    for (final value in json['rules'] as List) {
      if (value is! Map ||
          value['role'] is! String ||
          value['componentType'] is! String ||
          value['properties'] is! Map) {
        throw const FormatException('Invalid GenUI appearance rule.');
      }
      rules.add(
        GenUiAppearanceRule(
          role: value['role'] as String,
          componentType: value['componentType'] as String,
          properties: Map<String, Object?>.from(value['properties'] as Map),
        ),
      );
    }
    return GenUiAppearanceProfile(
      catalogId: json['catalogId'] as String,
      catalogVersion: json['catalogVersion'] as int,
      rules: List.unmodifiable(rules),
    );
  }

  /// Records only changed, approved properties. Existing rules are retained.
  static GenUiAppearanceProfile capture({
    required GenUiEditSnapshot before,
    required GenUiEditSnapshot after,
    required EditableCatalogRegistry registry,
    required GenUiComponentRole roleFor,
    GenUiAppearanceProfile? previous,
  }) {
    if (previous != null) previous._checkCatalog(registry);
    validateEditableTransition(
      baseMessages: before.messages,
      editedMessages: after.messages,
      registry: registry,
    );
    final original = _componentsById(before.messages);
    final edited = _componentsById(after.messages);
    final rules = <String, GenUiAppearanceRule>{
      if (previous != null)
        for (final rule in previous.rules)
          '${rule.role}\u0000${rule.componentType}': rule,
    };
    for (final entry in edited.entries) {
      final old = original[entry.key];
      if (old == null) continue;
      final component = entry.value;
      final type = component['component'];
      if (type is! String) continue;
      final contract = registry.contractFor(type);
      if (contract == null) continue;
      final changes = <String, Object?>{};
      for (final property in contract.properties.values) {
        if (contract.protectedProperties.contains(property.name)) continue;
        final value = component[property.name];
        if (_same(old[property.name], value)) continue;
        if (!property.accepts(value)) {
          throw FormatException(
            'Invalid appearance property ${property.name}.',
          );
        }
        changes[property.name] = value;
      }
      if (changes.isEmpty) continue;
      final role = roleFor(component);
      if (role == null || role.isEmpty) continue;
      final key = '$role\u0000$type';
      final existing = rules[key];
      rules[key] = GenUiAppearanceRule(
        role: role,
        componentType: type,
        properties: {...?existing?.properties, ...changes},
      );
    }
    return GenUiAppearanceProfile(
      catalogId: registry.catalogId,
      catalogVersion: registry.catalogVersion,
      rules: List.unmodifiable(rules.values),
    );
  }

  /// Applies visual preferences to a fresh A2UI message before rendering it.
  /// Data model updates, actions and bindings remain untouched.
  Map<String, Object?> applyToMessage({
    required Map<String, Object?> message,
    required EditableCatalogRegistry registry,
    required GenUiComponentRole roleFor,
  }) {
    _checkCatalog(registry);
    final copy = _copy(message);
    final update = copy['updateComponents'];
    if (update is! Map || update['components'] is! List) return copy;
    final indexed = {
      for (final rule in rules) '${rule.role}\u0000${rule.componentType}': rule,
    };
    for (final value in update['components'] as List) {
      if (value is! Map) continue;
      final component = value.cast<String, Object?>();
      final type = component['component'];
      if (type is! String) continue;
      final role = roleFor(component);
      if (role == null) continue;
      final rule = indexed['$role\u0000$type'];
      if (rule == null) continue;
      final contract = registry.contractFor(type);
      if (contract == null) continue;
      for (final entry in rule.properties.entries) {
        if (contract.protectedProperties.contains(entry.key) ||
            contract.properties[entry.key]?.accepts(entry.value) != true) {
          throw FormatException(
            'Invalid saved appearance property ${entry.key}.',
          );
        }
        component[entry.key] = entry.value;
      }
    }
    return copy;
  }

  void _checkCatalog(EditableCatalogRegistry registry) {
    if (catalogId != registry.catalogId ||
        catalogVersion != registry.catalogVersion) {
      throw const FormatException(
        'The appearance profile uses another catalog version.',
      );
    }
  }
}

Map<String, Map<String, Object?>> _componentsById(
  List<Map<String, Object?>> messages,
) {
  final result = <String, Map<String, Object?>>{};
  for (final message in messages) {
    final update = message['updateComponents'];
    if (update is! Map || update['components'] is! List) continue;
    final surfaceId = update['surfaceId'];
    if (surfaceId is! String) continue;
    for (final value in update['components'] as List) {
      if (value is! Map || value['id'] is! String) continue;
      result['$surfaceId\u0000${value['id']}'] = Map<String, Object?>.from(
        value,
      );
    }
  }
  return result;
}

Map<String, Object?> _copy(Map<String, Object?> value) =>
    Map<String, Object?>.from(jsonDecode(jsonEncode(value)) as Map);

bool _same(Object? left, Object? right) =>
    jsonEncode(left) == jsonEncode(right);
