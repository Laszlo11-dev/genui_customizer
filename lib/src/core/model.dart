enum GenUiEditOrigin { manual, ai }

final class GenUiComponentSelection {
  const GenUiComponentSelection({
    required this.surfaceId,
    required this.componentId,
    required this.componentType,
    required this.definitionRevision,
    this.dataPath,
  });

  final String surfaceId;
  final String componentId;
  final String componentType;
  final int definitionRevision;

  /// Data context of the clicked instance, including template indices.
  final String? dataPath;

  GenUiComponentSelection atRevision(int revision) => GenUiComponentSelection(
    surfaceId: surfaceId,
    componentId: componentId,
    componentType: componentType,
    definitionRevision: revision,
    dataPath: dataPath,
  );
}

final class GenUiEditSnapshot {
  const GenUiEditSnapshot({required this.revision, required this.messages});

  final int revision;
  final List<Map<String, Object?>> messages;
}

final class GenUiPropertyPatch {
  const GenUiPropertyPatch({
    required this.expectedRevision,
    required this.componentId,
    required this.changes,
    required this.origin,
  });

  final int expectedRevision;
  final String componentId;
  final Map<String, Object?> changes;
  final GenUiEditOrigin origin;
}

final class GenUiEditConstraints {
  const GenUiEditConstraints({
    required this.componentType,
    required this.editableProperties,
    required this.protectedProperties,
  });

  final String componentType;
  final Map<String, Object?> editableProperties;
  final Set<String> protectedProperties;
}

abstract interface class EditableGenUiComposer {
  Future<GenUiPropertyPatch> propose({
    required GenUiEditSnapshot snapshot,
    required GenUiComponentSelection selection,
    required String instruction,
    required GenUiEditConstraints constraints,
  });
}

abstract interface class EditableGenUiStorage {
  Future<GenUiEditSnapshot?> load();
  Future<void> save(GenUiEditSnapshot snapshot);
}

final class CallbackEditableGenUiStorage implements EditableGenUiStorage {
  const CallbackEditableGenUiStorage({
    required this.onLoad,
    required this.onSave,
  });

  final Future<GenUiEditSnapshot?> Function() onLoad;
  final Future<void> Function(GenUiEditSnapshot snapshot) onSave;

  @override
  Future<GenUiEditSnapshot?> load() => onLoad();

  @override
  Future<void> save(GenUiEditSnapshot snapshot) => onSave(snapshot);
}
