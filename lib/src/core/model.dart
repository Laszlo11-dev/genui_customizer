/// Describes who proposed a patch; both origins use the same validation rules.
enum GenUiEditOrigin { manual, ai }

/// Identifies a selected component and its rendered instance's data context.
///
/// The current session resolves components by ID, so use separate sessions for
/// surfaces that reuse component IDs even though selections carry a surface ID.
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

  /// Copies this selection with the revision of a new editing state.
  GenUiComponentSelection atRevision(int revision) => GenUiComponentSelection(
    surfaceId: surfaceId,
    componentId: componentId,
    componentType: componentType,
    definitionRevision: revision,
    dataPath: dataPath,
  );
}

/// A revision and JSON-serializable A2UI message envelopes to edit.
///
/// This value does not copy constructor arguments. Sessions copy snapshots on
/// entry and when exposing current state; callers should not mutate shared data.
final class GenUiEditSnapshot {
  const GenUiEditSnapshot({required this.revision, required this.messages});

  /// Editing-state revision. Undo/redo can restore an earlier revision, so this
  /// is not a globally increasing request or event identifier.
  final int revision;
  final List<Map<String, Object?>> messages;
}

/// Atomic property changes for one component at [expectedRevision].
///
/// A session rejects stale revisions, protected or invalid properties, and
/// patches that do not change any value.
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

/// Host-supplied property constraints passed to an AI composer.
///
/// These guide generation; the session validates the returned patch separately.
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

/// Adapter to a host's AI service for scoped visual-property proposals.
///
/// The host owns credentials and transport. Return a patch for the supplied
/// selection and snapshot revision; the controller rejects mismatched targets
/// and responses whose editing state changed while the request was pending.
abstract interface class EditableGenUiComposer {
  Future<GenUiPropertyPatch> propose({
    required GenUiEditSnapshot snapshot,
    required GenUiComponentSelection selection,
    required String instruction,
    required GenUiEditConstraints constraints,
  });
}

/// Host-defined loading and saving of editable snapshots.
///
/// Implementations may persist data or maintain conversation-local checkpoints.
/// This interface does not automatically transfer styles to new generated UI;
/// use appearance profiles and host-defined roles for that purpose.
abstract interface class EditableGenUiStorage {
  /// Returns a saved snapshot, or null when none is available.
  Future<GenUiEditSnapshot?> load();

  /// Completes when this snapshot has been saved, or throws on failure.
  Future<void> save(GenUiEditSnapshot snapshot);
}

/// Connects storage callbacks without requiring a separate adapter class.
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
