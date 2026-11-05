import 'package:genui_customizer/src/core/core.dart';

import 'controller.dart';

abstract final class EditableGenUi {
  static EditableGenUiController attach({
    required GenUiEditSnapshot initial,
    required EditableCatalogRegistry registry,
    EditableGenUiComposer? composer,
    EditableGenUiStorage? storage,
    EditableGenUiPermissions permissions = const EditableGenUiPermissions(),
    EditTrigger trigger = EditTrigger.adaptive,
    void Function(GenUiEditSnapshot snapshot)? onSnapshotChanged,
    void Function()? onEditorRequested,
  }) => EditableGenUiController(
    initial: initial,
    registry: registry,
    composer: composer,
    storage: storage,
    permissions: permissions,
    trigger: trigger,
    onSnapshotChanged: onSnapshotChanged,
    onEditorRequested: onEditorRequested,
  );
}

/// Entry point for embedding the runtime customizer in a GenUI application.
abstract final class GenUiCustomizer {
  static EditableGenUiController attach({
    required GenUiEditSnapshot initial,
    required EditableCatalogRegistry registry,
    EditableGenUiComposer? composer,
    EditableGenUiStorage? storage,
    EditableGenUiPermissions permissions = const EditableGenUiPermissions(),
    EditTrigger trigger = EditTrigger.adaptive,
    void Function(GenUiEditSnapshot snapshot)? onSnapshotChanged,
    void Function()? onEditorRequested,
  }) => EditableGenUi.attach(
    initial: initial,
    registry: registry,
    composer: composer,
    storage: storage,
    permissions: permissions,
    trigger: trigger,
    onSnapshotChanged: onSnapshotChanged,
    onEditorRequested: onEditorRequested,
  );
}
