import 'editor_definition.dart';

/// Value types accepted by a property contract.
///
/// The default property editor currently renders enumeration controls only;
/// other types require a custom integration for user input.
enum EditablePropertyType { enumeration, string, boolean, number }

/// Defines one property the host permits manual or AI patches to change.
final class EditablePropertyContract {
  const EditablePropertyContract({
    required this.name,
    required this.label,
    required this.type,
    this.enumValues = const [],
    this.required = false,
    this.maximumLength,
  });

  final String name;
  final String label;
  final EditablePropertyType type;
  final List<String> enumValues;

  /// Rejects null values when true; does not insert a missing property.
  final bool required;

  /// Maximum Dart string length, applied only to string properties.
  final int? maximumLength;

  /// Checks type and configured constraints, allowing null unless required.
  /// Returns whether [value] satisfies this property's declared type and limits.
  bool accepts(Object? value) {
    if (value == null) return !required;
    return switch (type) {
      EditablePropertyType.enumeration =>
        value is String && enumValues.contains(value),
      EditablePropertyType.string =>
        value is String &&
            (maximumLength == null || value.length <= maximumLength!),
      EditablePropertyType.boolean => value is bool,
      EditablePropertyType.number => value is num,
    };
  }
}

/// Allowlist of editable properties for an A2UI component type.
///
/// Properties absent from [properties] cannot be patched. Explicit entries in
/// [protectedProperties] take precedence over the allowlist.
final class EditableComponentContract {
  EditableComponentContract({
    required this.type,
    required Iterable<EditablePropertyContract> properties,
    this.protectedProperties = const {},
    this.allowChildrenEdit = false,
  }) : properties = Map.unmodifiable({
         for (final property in properties) property.name: property,
       });

  final String type;
  final Map<String, EditablePropertyContract> properties;
  final Set<String> protectedProperties;

  /// Host metadata; setting this does not enable structural editing in sessions.
  final bool allowChildrenEdit;
}

/// Host-owned component contracts and optional property editor definitions.
///
/// Keep [catalogId] stable and change [catalogVersion] when saved appearance
/// rules need a different interpretation. The host owns profile migration.
final class EditableCatalogRegistry {
  EditableCatalogRegistry({
    required this.catalogId,
    required this.catalogVersion,
    required Iterable<EditableComponentContract> components,
    Map<String, EditablePropertyEditorDefinition> customEditors = const {},
  }) : components = Map.unmodifiable({
         for (final component in components) component.type: component,
       }),
       customEditors = Map.unmodifiable(customEditors);

  final String catalogId;
  final int catalogVersion;
  final Map<String, EditableComponentContract> components;
  final Map<String, EditablePropertyEditorDefinition> customEditors;

  /// Returns the contract, or null if the component type is not editable.
  EditableComponentContract? contractFor(String componentType) =>
      components[componentType];

  /// Returns a host-provided editor, or null to use the default editor.
  EditablePropertyEditorDefinition? editorFor(String componentType) =>
      customEditors[componentType];
}
