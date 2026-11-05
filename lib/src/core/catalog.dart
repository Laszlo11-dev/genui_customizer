import 'editor_definition.dart';

enum EditablePropertyType { enumeration, string, boolean, number }

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
  final bool required;
  final int? maximumLength;

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
  final bool allowChildrenEdit;
}

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

  EditableComponentContract? contractFor(String componentType) =>
      components[componentType];

  EditablePropertyEditorDefinition? editorFor(String componentType) =>
      customEditors[componentType];
}
