import 'dart:convert';
import 'dart:math';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:genui_customizer/src/core/core.dart';
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:url_launcher/link.dart';

import 'controller.dart';
import 'debug_dialog.dart';
import 'property_editor.dart';
import 'studio_bounds_persistence.dart';

enum _StudioCloseChoice { save, discard }

/// Opens the floating editor and optional catalog gallery.
///
/// Gallery types without a contract in [controller]'s registry are omitted.
/// Pass [boundsPersistence] as null to disable the default bounds storage.
/// Existing [loadBounds] and [saveBounds] callbacks override it together.
Future<void> showEditableGenUiStudio({
  required BuildContext context,
  required EditableGenUiController controller,
  required Iterable<String> galleryTypes,
  Catalog? galleryCatalog,
  Map<String, Object?> galleryViewModel = const {},
  StudioBoundsPersistence? boundsPersistence =
      const SharedPreferencesStudioBoundsPersistence(),
  Rect? Function()? loadBounds,
  void Function(Rect bounds)? saveBounds,
  double? Function()? loadSplitFraction,
  void Function(double fraction)? saveSplitFraction,
  Map<String, Map<String, Object?>> Function()? loadDefaults,
  void Function(String type, Map<String, Object?> values)? saveDefaults,
  List<String> presentationTagOptions = const [],
  List<String> initialPresentationTags = const [],
  String initialPresentationRequest = '',
  String Function(String tag)? presentationTagLabel,
  Future<String?> Function(List<String> tags, String request)?
  onGenerateProposal,
  bool canPublishEditors = false,
  Future<EditablePropertyEditorDefinition> Function(String type, String prompt)?
  onGenerateEditor,
  Future<void> Function(
    String type,
    EditablePropertyEditorDefinition definition,
  )?
  onPublishEditor,
  Future<Map<String, Object?>> Function()? loadDebugData,
  String? debugSubject,
}) async {
  final useDefaultBounds = loadBounds == null && saveBounds == null;
  Rect? storedBounds;
  Future<void> pendingBoundsSave = Future<void>.value();
  if (useDefaultBounds && boundsPersistence != null) {
    try {
      storedBounds = await boundsPersistence.load();
    } on Object {
      // Unavailable or invalid app storage does not prevent editing.
    }
  }
  if (!context.mounted) return;
  await Navigator.of(context, rootNavigator: true).push<void>(
    _StudioRoute(
      themes: InheritedTheme.capture(
        from: context,
        to: Navigator.of(context, rootNavigator: true).context,
      ),
      builder: (_) => _StudioWindow(
        controller: controller,
        galleryTypes: galleryTypes
            .where((type) => controller.registry.contractFor(type) != null)
            .toList(growable: false),
        galleryCatalog: galleryCatalog,
        galleryViewModel: galleryViewModel,
        loadBounds: useDefaultBounds ? () => storedBounds : loadBounds,
        saveBounds: useDefaultBounds && boundsPersistence != null
            ? (bounds) {
                pendingBoundsSave = pendingBoundsSave.then((_) async {
                  try {
                    await boundsPersistence.save(bounds);
                  } on Object {
                    // Keep editing available when app storage cannot be written.
                  }
                });
              }
            : saveBounds,
        loadSplitFraction: loadSplitFraction,
        saveSplitFraction: saveSplitFraction,
        loadDefaults: loadDefaults,
        saveDefaults: saveDefaults,
        presentationTagOptions: presentationTagOptions,
        initialPresentationTags: initialPresentationTags,
        initialPresentationRequest: initialPresentationRequest,
        presentationTagLabel: presentationTagLabel,
        onGenerateProposal: onGenerateProposal,
        canPublishEditors: canPublishEditors,
        onGenerateEditor: onGenerateEditor,
        onPublishEditor: onPublishEditor,
        loadDebugData: loadDebugData,
        debugSubject: debugSubject,
      ),
    ),
  );
  await pendingBoundsSave;
}

// Leave the surface outside the floating editor interactive.
final class _StudioRoute extends RawDialogRoute<void> {
  _StudioRoute({required CapturedThemes themes, required WidgetBuilder builder})
    : super(
        barrierDismissible: false,
        pageBuilder: (context, animation, secondaryAnimation) =>
            themes.wrap(SafeArea(child: Builder(builder: builder))),
      );

  @override
  Widget buildModalBarrier() => const SizedBox.shrink();
}

final class _StudioWindow extends StatefulWidget {
  const _StudioWindow({
    required this.controller,
    required this.galleryTypes,
    required this.galleryCatalog,
    required this.galleryViewModel,
    required this.loadBounds,
    required this.saveBounds,
    required this.loadSplitFraction,
    required this.saveSplitFraction,
    required this.loadDefaults,
    required this.saveDefaults,
    required this.presentationTagOptions,
    required this.initialPresentationTags,
    required this.initialPresentationRequest,
    required this.presentationTagLabel,
    required this.onGenerateProposal,
    required this.canPublishEditors,
    this.onGenerateEditor,
    this.onPublishEditor,
    required this.loadDebugData,
    required this.debugSubject,
  });

  final EditableGenUiController controller;
  final List<String> galleryTypes;
  final Catalog? galleryCatalog;
  final Map<String, Object?> galleryViewModel;
  final Rect? Function()? loadBounds;
  final void Function(Rect)? saveBounds;
  final double? Function()? loadSplitFraction;
  final void Function(double)? saveSplitFraction;
  final Map<String, Map<String, Object?>> Function()? loadDefaults;
  final void Function(String, Map<String, Object?>)? saveDefaults;
  final List<String> presentationTagOptions;
  final List<String> initialPresentationTags;
  final String initialPresentationRequest;
  final String Function(String)? presentationTagLabel;
  final Future<String?> Function(List<String>, String)? onGenerateProposal;
  final bool canPublishEditors;
  final Future<EditablePropertyEditorDefinition> Function(String, String)?
  onGenerateEditor;
  final Future<void> Function(String, EditablePropertyEditorDefinition)?
  onPublishEditor;
  final Future<Map<String, Object?>> Function()? loadDebugData;
  final String? debugSubject;

  @override
  State<_StudioWindow> createState() => _StudioWindowState();
}

final class _StudioWindowState extends State<_StudioWindow> {
  Rect? _bounds;
  Size _viewport = Size.zero;

  @override
  void initState() {
    super.initState();
    widget.controller.setStudioVisible(true);
    try {
      _bounds = widget.loadBounds?.call();
    } on Object {
      // Unavailable browser storage should not prevent editing.
    }
  }

  @override
  void dispose() {
    widget.controller.setStudioVisible(false);
    super.dispose();
  }

  Rect _fit(Rect bounds, Size viewport) {
    final maxWidth = max(0.0, viewport.width - 48);
    final maxHeight = max(0.0, viewport.height - 64);
    final width = bounds.width.clamp(min(360.0, maxWidth), maxWidth);
    final height = bounds.height.clamp(min(360.0, maxHeight), maxHeight);
    final left = bounds.left.clamp(
      24.0,
      max(24.0, viewport.width - width - 24),
    );
    final top = bounds.top.clamp(
      32.0,
      max(32.0, viewport.height - height - 32),
    );
    return Rect.fromLTWH(
      left.toDouble(),
      top.toDouble(),
      width.toDouble(),
      height.toDouble(),
    );
  }

  Rect _initial(Size viewport) {
    final width = min(1280.0, max(0.0, viewport.width - 48));
    final height = min(820.0, max(0.0, viewport.height - 64));
    return Rect.fromLTWH(
      (viewport.width - width) / 2,
      (viewport.height - height) / 2,
      width,
      height,
    );
  }

  void _move(DragUpdateDetails details) {
    setState(() {
      _bounds = _fit(
        (_bounds ?? _initial(_viewport)).shift(details.delta),
        _viewport,
      );
    });
  }

  void _resize(DragUpdateDetails details) {
    setState(() {
      final bounds = _bounds ?? _initial(_viewport);
      final maxWidth = max(0.0, _viewport.width - bounds.left - 24);
      final maxHeight = max(0.0, _viewport.height - bounds.top - 32);
      _bounds = Rect.fromLTWH(
        bounds.left,
        bounds.top,
        (bounds.width + details.delta.dx).clamp(min(360.0, maxWidth), maxWidth),
        (bounds.height + details.delta.dy).clamp(
          min(360.0, maxHeight),
          maxHeight,
        ),
      );
    });
  }

  void _remember() {
    final bounds = _bounds;
    if (bounds == null) return;
    try {
      widget.saveBounds?.call(bounds);
    } on Object {
      // Layout persistence is optional.
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _viewport = constraints.biggest;
      final bounds = _fit(_bounds ?? _initial(_viewport), _viewport);
      _bounds = bounds;
      final colors = Theme.of(context).colorScheme;
      return Stack(
        children: [
          Positioned.fromRect(
            rect: bounds,
            child: Dialog(
              insetPadding: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              backgroundColor: colors.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 24,
              shadowColor: colors.shadow.withValues(alpha: 0.55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: colors.outline, width: 1.5),
              ),
              child: SizedBox(
                key: const Key('editable-genui-studio-dialog'),
                width: bounds.width,
                height: bounds.height,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _EditableGenUiStudio(
                        controller: widget.controller,
                        galleryTypes: widget.galleryTypes,
                        galleryCatalog: widget.galleryCatalog,
                        galleryViewModel: widget.galleryViewModel,
                        loadDefaults: widget.loadDefaults,
                        saveDefaults: widget.saveDefaults,
                        loadSplitFraction: widget.loadSplitFraction,
                        saveSplitFraction: widget.saveSplitFraction,
                        presentationTagOptions: widget.presentationTagOptions,
                        initialPresentationTags: widget.initialPresentationTags,
                        initialPresentationRequest:
                            widget.initialPresentationRequest,
                        presentationTagLabel: widget.presentationTagLabel,
                        onGenerateProposal: widget.onGenerateProposal,
                        canPublishEditors: widget.canPublishEditors,
                        onGenerateEditor: widget.onGenerateEditor,
                        onPublishEditor: widget.onPublishEditor,
                        loadDebugData: widget.loadDebugData,
                        debugSubject: widget.debugSubject,
                        onMove: _move,
                        onMoveEnd: _remember,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeDownRight,
                        child: GestureDetector(
                          key: const Key('genui-studio-resize'),
                          behavior: HitTestBehavior.opaque,
                          onPanUpdate: _resize,
                          onPanEnd: (_) => _remember(),
                          child: const SizedBox(
                            width: 28,
                            height: 28,
                            child: Icon(Icons.open_in_full, size: 15),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

final class _EditableGenUiStudio extends StatefulWidget {
  const _EditableGenUiStudio({
    required this.controller,
    required this.galleryTypes,
    required this.galleryCatalog,
    required this.galleryViewModel,
    required this.loadDefaults,
    required this.saveDefaults,
    required this.loadSplitFraction,
    required this.saveSplitFraction,
    required this.presentationTagOptions,
    required this.initialPresentationTags,
    required this.initialPresentationRequest,
    required this.presentationTagLabel,
    required this.onGenerateProposal,
    required this.canPublishEditors,
    required this.onMove,
    required this.onMoveEnd,
    this.onGenerateEditor,
    this.onPublishEditor,
    required this.loadDebugData,
    required this.debugSubject,
  });

  final EditableGenUiController controller;
  final List<String> galleryTypes;
  final Catalog? galleryCatalog;
  final Map<String, Object?> galleryViewModel;
  final Map<String, Map<String, Object?>> Function()? loadDefaults;
  final void Function(String, Map<String, Object?>)? saveDefaults;
  final double? Function()? loadSplitFraction;
  final void Function(double)? saveSplitFraction;
  final List<String> presentationTagOptions;
  final List<String> initialPresentationTags;
  final String initialPresentationRequest;
  final String Function(String)? presentationTagLabel;
  final Future<String?> Function(List<String>, String)? onGenerateProposal;
  final bool canPublishEditors;
  final GestureDragUpdateCallback onMove;
  final VoidCallback onMoveEnd;
  final Future<EditablePropertyEditorDefinition> Function(String, String)?
  onGenerateEditor;
  final Future<void> Function(String, EditablePropertyEditorDefinition)?
  onPublishEditor;
  final Future<Map<String, Object?>> Function()? loadDebugData;
  final String? debugSubject;

  @override
  State<_EditableGenUiStudio> createState() => _EditableGenUiStudioState();
}

final class _EditableGenUiStudioState extends State<_EditableGenUiStudio> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _selectedTreeNodeKey = GlobalKey();
  final Set<String> _expandedNodes = {};
  bool _treeExpansionInitialized = false;
  bool _galleryMode = false;
  final TextEditingController _prompt = TextEditingController();
  final TextEditingController _editorPrompt = TextEditingController();
  late final TextEditingController _presentationPrompt;
  late final Set<String> _presentationTags;
  bool _generatingProposal = false;
  String? _proposalError;
  String? _galleryType;
  EditableGenUiController? _gallerySample;
  SurfaceController? _gallerySurface;
  SurfaceController? _selectedPreviewSurface;
  String? _selectedPreviewKey;
  final Set<String> _previewTypes = {};
  final Map<String, Map<String, Object?>> _previewRoots = {};
  final Map<String, List<Map<String, Object?>>> _previewComponents = {};
  EditablePropertyEditorDefinition? _draftEditor;
  bool _editorBusy = false;
  String? _editorError;
  Map<String, Map<String, Object?>> _defaults = {};
  double _splitFraction = 0.6;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _presentationPrompt = TextEditingController(
      text: widget.initialPresentationRequest,
    );
    _presentationTags = widget.initialPresentationTags.toSet();
    try {
      final saved = widget.loadSplitFraction?.call();
      if (saved != null && saved.isFinite && saved > 0 && saved < 1) {
        _splitFraction = saved;
      }
    } on Object {
      // Layout persistence is optional.
    }
    try {
      _defaults = widget.loadDefaults?.call() ?? {};
    } on Object {
      _defaults = {};
    }
    _prepareGalleryPreviews();
    _galleryType = widget.galleryTypes.firstOrNull;
    if (_galleryType case final type?) _gallerySample = _sampleFor(type);
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelection());
  }

  void _setGalleryMode(bool value) {
    if (_galleryMode == value) return;
    _scaffoldKey.currentState?.closeDrawer();
    setState(() => _galleryMode = value);
    if (!value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelection());
    }
  }

  void _revealSelection() {
    final selected = _selectedTreeNodeKey.currentContext;
    if (selected != null) {
      Scrollable.ensureVisible(selected, alignment: 0.4);
    }
  }

  Future<void> _requestClose() async {
    if (_closing ||
        widget.controller.busy ||
        _editorBusy ||
        _generatingProposal) {
      return;
    }
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      _scaffoldKey.currentState?.closeDrawer();
      return;
    }
    _closing = true;
    try {
      final controller = widget.controller;
      final galleryDirty = _gallerySample?.isDirty == true;
      if (controller.isDirty || galleryDirty) {
        final canSave =
            (!controller.isDirty ||
                (controller.permissions.canSave &&
                    controller.storage != null)) &&
            (!galleryDirty || widget.saveDefaults != null);
        final choice = await showDialog<_StudioCloseChoice>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Save changes?'),
            content: const Text('You have unsaved changes in GenUI Touch.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Keep editing'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(_StudioCloseChoice.discard),
                child: const Text('Discard changes'),
              ),
              if (canSave)
                FilledButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(_StudioCloseChoice.save),
                  child: const Text('Save and close'),
                ),
            ],
          ),
        );
        if (!mounted || choice == null) return;
        if (choice == _StudioCloseChoice.save) {
          if (controller.isDirty) {
            try {
              await controller.save();
            } on Object {
              return;
            }
          }
          if (galleryDirty) _saveGalleryDefaults();
          if (controller.isDirty || _gallerySample?.isDirty == true) return;
        } else {
          controller.cancel();
        }
      }
      if (!mounted) return;
      controller.close();
      Navigator.of(context).pop();
    } finally {
      _closing = false;
    }
  }

  @override
  void dispose() {
    _prompt.dispose();
    _editorPrompt.dispose();
    _presentationPrompt.dispose();
    _gallerySample?.dispose();
    _gallerySurface?.dispose();
    _selectedPreviewSurface?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 820;
      final collapseTree = constraints.maxWidth < 600;
      final colors = Theme.of(context).colorScheme;
      final toolbarIconStyle = IconButton.styleFrom(
        foregroundColor: colors.onInverseSurface,
        disabledForegroundColor: colors.onInverseSurface.withValues(
          alpha: 0.38,
        ),
      );
      return AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final controller = widget.controller;
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _requestClose();
            },
            child: Scaffold(
              key: _scaffoldKey,
              drawer: collapseTree
                  ? Drawer(
                      width: min(360, constraints.maxWidth - 48),
                      child: SafeArea(
                        child: Column(
                          children: [
                            ListTile(
                              title: const Text('Structure'),
                              trailing: IconButton(
                                tooltip: 'Close structure',
                                onPressed: () =>
                                    _scaffoldKey.currentState?.closeDrawer(),
                                icon: const Icon(Icons.close),
                              ),
                            ),
                            Expanded(
                              child: _galleryMode ? _gallery() : _surfaceTree(),
                            ),
                          ],
                        ),
                      ),
                    )
                  : null,
              onDrawerChanged: (open) {
                if (open) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _revealSelection(),
                  );
                }
              },
              appBar: AppBar(
                toolbarHeight: 48,
                leadingWidth: compact ? 44 : null,
                titleSpacing: compact ? 0 : null,
                backgroundColor: colors.inverseSurface,
                foregroundColor: colors.onInverseSurface,
                surfaceTintColor: Colors.transparent,
                iconTheme: IconThemeData(color: colors.onInverseSurface),
                actionsIconTheme: IconThemeData(color: colors.onInverseSurface),
                titleTextStyle: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(
                      color: colors.onInverseSurface,
                      fontWeight: FontWeight.w600,
                    ),
                title: MouseRegion(
                  cursor: SystemMouseCursors.move,
                  child: GestureDetector(
                    key: const Key('genui-studio-drag'),
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: widget.onMove,
                    onPanEnd: (_) => widget.onMoveEnd(),
                    child: SizedBox(
                      height: 48,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: compact
                            ? const Text(
                                'GenUI Touch',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.tune_rounded,
                                    size: 20,
                                    color: colors.inversePrimary,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('GenUI Touch'),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
                leading: IconButton(
                  tooltip: 'Close editor',
                  style: toolbarIconStyle,
                  onPressed: controller.busy ? null : _requestClose,
                  icon: const Icon(Icons.close),
                ),
                actions: [
                  if (!compact) ...[
                    IconButton(
                      tooltip: 'Undo',
                      style: toolbarIconStyle,
                      onPressed: controller.canUndo && !controller.busy
                          ? controller.undo
                          : null,
                      icon: const Icon(Icons.undo),
                    ),
                    IconButton(
                      tooltip: 'Redo',
                      style: toolbarIconStyle,
                      onPressed: controller.canRedo && !controller.busy
                          ? controller.redo
                          : null,
                      icon: const Icon(Icons.redo),
                    ),
                    TextButton(
                      onPressed: controller.busy ? null : controller.cancel,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.onInverseSurface,
                      ),
                      child: const Text('Discard changes'),
                    ),
                  ],
                  PopupMenuButton<String>(
                    key: const Key('genui-studio-menu'),
                    tooltip: 'GenUI Touch menu',
                    onSelected: (action) {
                      switch (action) {
                        case 'structure':
                          _scaffoldKey.currentState?.openDrawer();
                        case 'gallery':
                          _setGalleryMode(!_galleryMode);
                        case 'undo':
                          controller.undo();
                        case 'redo':
                          controller.redo();
                        case 'discard':
                          controller.cancel();
                        case 'about':
                          showAboutDialog(
                            context: context,
                            applicationName: 'GenUI Touch',
                            children: [
                              const Text('Make generated UI your own.'),
                              const SizedBox(height: 12),
                              Link(
                                uri: Uri.https(
                                  'github.com',
                                  '/Laszlo11-dev/genui_customizer',
                                ),
                                target: LinkTarget.blank,
                                builder: (context, followLink) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: followLink,
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('GitHub repository'),
                                  ),
                                ),
                              ),
                            ],
                          );
                        case 'debug':
                          final load = widget.loadDebugData;
                          if (load != null) {
                            showGenUiDebugDialog(
                              context: context,
                              load: load,
                              subject: widget.debugSubject,
                              currentUi: () => controller.snapshot.messages,
                            );
                          }
                      }
                    },
                    itemBuilder: (_) => [
                      if (collapseTree)
                        const PopupMenuItem(
                          value: 'structure',
                          child: Text('Open structure'),
                        ),
                      CheckedPopupMenuItem(
                        value: 'gallery',
                        checked: _galleryMode,
                        child: const Text('Gallery view'),
                      ),
                      if (widget.loadDebugData != null)
                        const PopupMenuItem(
                          value: 'debug',
                          child: Text('GenUI debug'),
                        ),
                      const PopupMenuItem(value: 'about', child: Text('About')),
                      if (compact) const PopupMenuDivider(),
                      if (compact) ...[
                        PopupMenuItem(
                          value: 'undo',
                          enabled: controller.canUndo && !controller.busy,
                          child: const Text('Undo'),
                        ),
                        PopupMenuItem(
                          value: 'redo',
                          enabled: controller.canRedo && !controller.busy,
                          child: const Text('Redo'),
                        ),
                        PopupMenuItem(
                          value: 'discard',
                          enabled: !controller.busy,
                          child: const Text('Discard changes'),
                        ),
                      ],
                    ],
                  ),
                  if (compact)
                    IconButton(
                      tooltip: 'Save',
                      style: toolbarIconStyle,
                      onPressed:
                          controller.permissions.canSave &&
                              controller.isDirty &&
                              !controller.busy
                          ? () => _save(controller)
                          : null,
                      icon: const Icon(Icons.save_outlined),
                    )
                  else
                    FilledButton(
                      onPressed:
                          controller.permissions.canSave &&
                              controller.isDirty &&
                              !controller.busy
                          ? () => _save(controller)
                          : null,
                      child: const Text('Save'),
                    ),
                  SizedBox(width: compact ? 4 : 12),
                ],
              ),
              body: collapseTree
                  ? (_galleryMode ? _galleryEditor() : _surfaceEditor())
                  : LayoutBuilder(
                      builder: (context, bodyConstraints) {
                        final available = bodyConstraints.maxWidth - 12;
                        final minFraction = 220 / available;
                        final maxFraction = 1 - 320 / available;
                        final fraction = _splitFraction.clamp(
                          minFraction,
                          maxFraction,
                        );
                        return Row(
                          children: [
                            SizedBox(
                              width: available * fraction,
                              child: _galleryMode ? _gallery() : _surfaceTree(),
                            ),
                            MouseRegion(
                              cursor: SystemMouseCursors.resizeLeftRight,
                              child: GestureDetector(
                                key: const Key('genui-studio-splitter'),
                                behavior: HitTestBehavior.opaque,
                                onHorizontalDragUpdate: (details) =>
                                    setState(() {
                                      _splitFraction =
                                          (_splitFraction +
                                                  details.delta.dx / available)
                                              .clamp(minFraction, maxFraction);
                                    }),
                                onHorizontalDragEnd: (_) {
                                  try {
                                    widget.saveSplitFraction?.call(
                                      _splitFraction,
                                    );
                                  } on Object {
                                    // Layout persistence is optional.
                                  }
                                },
                                child: SizedBox(
                                  width: 12,
                                  height: double.infinity,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Center(
                                        child: VerticalDivider(
                                          width: 1,
                                          thickness: 1,
                                          color: colors.outlineVariant,
                                        ),
                                      ),
                                      Container(
                                        width: 4,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: colors.outline,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: _galleryMode
                                  ? _galleryEditor()
                                  : _surfaceEditor(),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          );
        },
      );
    },
  );

  Future<void> _save(EditableGenUiController controller) async {
    try {
      await controller.save();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Presentation saved.')));
      }
    } on Object {
      // The controller displays the save error in the panel.
    }
  }

  Widget _gallery() => ListView(
    key: const Key('genui-gallery'),
    padding: const EdgeInsets.all(8),
    children: [
      for (final type in widget.galleryTypes)
        Card(
          child: InkWell(
            onTap: () => setState(() {
              _galleryType = type;
              _gallerySample?.dispose();
              _gallerySample = _sampleFor(type);
              _draftEditor = null;
              _editorError = null;
              _scaffoldKey.currentState?.closeDrawer();
            }),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: Text(type),
                    subtitle: Text(
                      widget.controller.editorFor(type) == null
                          ? 'No custom editor'
                          : 'Custom editor available',
                    ),
                    selected: _galleryType == type,
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );

  Widget _surfaceTree() {
    final root = buildGenUiSurfaceTree(widget.controller.snapshot);
    if (root == null) {
      return const Center(child: Text('No A2UI surface is available.'));
    }
    if (!_treeExpansionInitialized) {
      _treeExpansionInitialized = true;
      _expandedNodes.add(root.id);
      final selectedId = widget.controller.selection?.componentId;
      bool reveal(GenUiSurfaceNode node) {
        if (node.id == selectedId) return true;
        final containsSelection = node.children.any(reveal);
        if (containsSelection) _expandedNodes.add(node.id);
        return containsSelection;
      }

      reveal(root);
    }
    return ListView(
      key: const Key('genui-surface-tree'),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      children: [_treeNode(root, 0)],
    );
  }

  void _prepareGalleryPreviews() {
    final catalog = widget.galleryCatalog;
    if (catalog == null || catalog.catalogId == null) return;
    final surface = SurfaceController(catalogs: [catalog]);
    for (final item in catalog.items) {
      try {
        final components = item.exampleData.isNotEmpty
            ? (jsonDecode(item.exampleData.first()) as List)
                  .whereType<Map>()
                  .map((value) => value.cast<String, Object?>())
                  .toList()
            : <Map<String, Object?>>[
                if (item.name == 'ReviewLayout')
                  {'id': 'preview-text', 'component': 'Text', 'text': 'Review'},
                {
                  'id': 'root',
                  'component': item.name,
                  if (item.name == 'ReviewLayout') 'children': ['preview-text'],
                },
              ];
        if (!components.any((value) => value['id'] == 'root')) continue;
        _previewRoots[item.name] = Map<String, Object?>.from(
          components.firstWhere((value) => value['id'] == 'root'),
        );
        _previewComponents[item.name] = components;
        final surfaceId = 'gallery-${item.name}';
        surface.handleMessage(
          core.UpdateComponentsMessage(
            surfaceId: surfaceId,
            components: components,
          ),
        );
        surface.handleMessage(
          core.CreateSurfaceMessage(
            surfaceId: surfaceId,
            catalogId: catalog.catalogId!,
            sendDataModel: false,
          ),
        );
        surface.handleMessage(
          core.UpdateDataModelMessage(
            surfaceId: surfaceId,
            value: widget.galleryViewModel,
          ),
        );
        _previewTypes.add(item.name);
      } on Object {
        // Keep the type selectable if its example cannot be rendered.
      }
    }
    _gallerySurface = surface;
  }

  Widget _treeNode(GenUiSurfaceNode node, int depth) {
    final controller = widget.controller;
    final selectable = controller.canSelect(node.type);
    final selected = controller.selection?.componentId == node.id;
    final preview = _textPreview(node);
    final branch = node.children.isNotEmpty;
    final expanded = _expandedNodes.contains(node.id);
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          key: Key('genui-tree-node-${node.id}'),
          color: selected ? colors.secondaryContainer : Colors.transparent,
          child: InkWell(
            key: selected ? _selectedTreeNodeKey : null,
            onTap: selectable
                ? () {
                    controller.select(
                      GenUiComponentSelection(
                        surfaceId: _surfaceId(controller.snapshot),
                        componentId: node.id,
                        componentType: node.type,
                        definitionRevision: controller.snapshot.revision,
                      ),
                    );
                    _scaffoldKey.currentState?.closeDrawer();
                  }
                : branch
                ? () => _toggleNode(node.id)
                : null,
            child: SizedBox(
              height: 28,
              child: Row(
                children: [
                  SizedBox(width: depth == 0 ? 0 : 4),
                  if (branch)
                    InkWell(
                      key: Key('genui-tree-toggle-${node.id}'),
                      onTap: () => _toggleNode(node.id),
                      child: SizedBox(
                        width: 20,
                        height: 28,
                        child: Icon(
                          expanded ? Icons.arrow_drop_down : Icons.arrow_right,
                          size: 20,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 20),
                  Icon(
                    _treeIcon(node.type),
                    size: 14,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Tooltip(
                      message:
                          '${node.type} · ${node.id}${preview == null ? '' : ' · $preview'}',
                      child: Text(
                        node.type == 'Text' && preview != null
                            ? preview
                            : '${_treeLabel(node.type)} · ${node.id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: selected ? FontWeight.w600 : null,
                          color: selected ? colors.onSecondaryContainer : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (branch && expanded)
          Padding(
            padding: const EdgeInsets.only(left: 15),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: colors.outlineVariant)),
              ),
              child: Column(
                children: [
                  for (final child in node.children)
                    _treeNode(child, depth + 1),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _toggleNode(String id) => setState(() {
    if (!_expandedNodes.add(id)) _expandedNodes.remove(id);
  });

  IconData _treeIcon(String type) => switch (type) {
    'Text' => Icons.text_fields,
    'Column' => Icons.view_column_outlined,
    'Row' => Icons.view_stream_outlined,
    'Card' => Icons.crop_square,
    'Tabs' => Icons.tab_outlined,
    'Image' => Icons.image_outlined,
    _ => Icons.widgets_outlined,
  };

  String _treeLabel(String type) {
    final words = type.replaceAllMapped(
      RegExp(r'(?<=[a-z])(?=[A-Z])'),
      (_) => ' ',
    );
    return words[0] + words.substring(1).toLowerCase();
  }

  DataPath _nodeDataPath(String id) {
    DataPath? visit(GenUiSurfaceNode node, DataPath path) {
      if (node.id == id) return path;
      final children = widget.controller.component(node.id)?['children'];
      var childPath = path;
      if (children is Map && children['path'] is String) {
        final binding = DataPath(children['path'] as String);
        childPath = binding.isAbsolute ? binding : path.join(binding);
        final value = _modelValue(childPath);
        final key = value is List && value.isNotEmpty
            ? '0'
            : value is Map && value.isNotEmpty
            ? value.keys.first.toString()
            : null;
        if (key != null) childPath = childPath.join(DataPath(key));
      }
      for (final child in node.children) {
        final found = visit(child, childPath);
        if (found != null) return found;
      }
      return null;
    }

    final root = buildGenUiSurfaceTree(widget.controller.snapshot);
    return root == null
        ? DataPath.root
        : visit(root, DataPath.root) ?? DataPath.root;
  }

  Object? _modelValue(DataPath path) {
    Object? value = widget.galleryViewModel;
    for (final segment in path.segments) {
      final key = segment.replaceAll('~1', '/').replaceAll('~0', '~');
      if (value is Map) {
        value = value[key];
      } else if (value is List) {
        final index = int.tryParse(key);
        value = index != null && index >= 0 && index < value.length
            ? value[index]
            : null;
      } else {
        return null;
      }
    }
    return value;
  }

  String? _textPreview(GenUiSurfaceNode node) {
    if (node.type != 'Text') return null;
    final raw = widget.controller.component(node.id)?['text'];
    Object? value = raw;
    if (raw is Map && raw['path'] is String) {
      var path = DataPath(raw['path'] as String);
      // Older callers may supply a view model without the /data prefix.
      if (path.segments.firstOrNull == 'data' &&
          !widget.galleryViewModel.containsKey('data')) {
        path = DataPath('/' + path.segments.skip(1).join('/'));
      }
      value = _modelValue(
        path.isAbsolute ? path : _nodeDataPath(node.id).join(path),
      );
      value ??= raw['path'];
    }
    if (value is! String || value.trim().isEmpty) return null;
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return compact.length > 100 ? '${compact.substring(0, 100)}…' : compact;
  }

  Widget _previewFrame(Widget child) => Container(
    key: const Key('genui-widget-preview'),
    height: 126,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Preview', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        Expanded(
          child: ClipRect(child: SingleChildScrollView(child: child)),
        ),
      ],
    ),
  );

  Widget _galleryPreview(String type) {
    if (!_previewTypes.contains(type) || _gallerySurface == null) {
      return _previewFrame(Text(type));
    }
    return _previewFrame(
      Surface(
        surfaceContext: _gallerySurface!.contextFor('gallery-$type'),
        defaultBuilder: (_) => Text(type),
      ),
    );
  }

  Widget _selectedPreview(GenUiComponentSelection selection) {
    final catalog = widget.galleryCatalog;
    if (catalog == null || catalog.catalogId == null) {
      return _previewFrame(Text(selection.componentType));
    }
    final key =
        '${selection.componentId}:${selection.dataPath}:'
        '${widget.controller.snapshot.revision}';
    if (_selectedPreviewSurface == null || _selectedPreviewKey != key) {
      _selectedPreviewSurface?.dispose();
      _selectedPreviewSurface = null;
      _selectedPreviewKey = key;
      final root = buildGenUiSurfaceTree(widget.controller.snapshot);
      GenUiSurfaceNode? findNode(GenUiSurfaceNode? node) {
        if (node == null) return null;
        if (node.id == selection.componentId) return node;
        for (final child in node.children) {
          final found = findNode(child);
          if (found != null) return found;
        }
        return null;
      }

      final selected = findNode(root);
      if (selected != null) {
        final components = <Map<String, Object?>>[];
        final selectedPath = selection.dataPath != null
            ? DataPath(selection.dataPath!)
            : _nodeDataPath(selected.id);
        void addNode(GenUiSurfaceNode node, {bool rebase = true}) {
          final source = widget.controller.component(node.id);
          if (source == null) return;
          Object? bindPaths(Object? value) {
            if (value is List) return value.map(bindPaths).toList();
            if (value is Map) {
              return <String, Object?>{
                for (final entry in value.entries)
                  entry.key
                      as String: entry.key == 'path' && entry.value is String
                      ? ((entry.value as String).startsWith('/')
                            ? entry.value
                            : selectedPath
                                  .join(DataPath(entry.value as String))
                                  .toString())
                      : bindPaths(entry.value),
              };
            }
            return value;
          }

          components.add({
            ...(rebase ? bindPaths(source) as Map<String, Object?> : source),
            if (node.id == selected.id) 'id': 'root',
          });
          // Template children establish their own context for every instance.
          final children = source['children'];
          final hasTemplate = children is Map && children['path'] is String;
          for (final child in node.children) {
            addNode(child, rebase: rebase && !hasTemplate);
          }
        }

        addNode(selected);
        try {
          final surface = SurfaceController(catalogs: [catalog]);
          const surfaceId = 'studio-selected-preview';
          surface.handleMessage(
            core.UpdateComponentsMessage(
              surfaceId: surfaceId,
              components: components,
            ),
          );
          surface.handleMessage(
            core.CreateSurfaceMessage(
              surfaceId: surfaceId,
              catalogId: catalog.catalogId!,
              sendDataModel: false,
            ),
          );
          surface.handleMessage(
            core.UpdateDataModelMessage(
              surfaceId: surfaceId,
              value: widget.galleryViewModel,
            ),
          );
          _selectedPreviewSurface = surface;
        } on Object {
          _selectedPreviewSurface?.dispose();
          _selectedPreviewSurface = null;
        }
      }
    }
    final surface = _selectedPreviewSurface;
    return _previewFrame(
      surface == null
          ? Text(selection.componentType)
          : Surface(
              surfaceContext: surface.contextFor('studio-selected-preview'),
              defaultBuilder: (_) => Text(selection.componentType),
            ),
    );
  }

  Widget _galleryEditor() {
    final type = _galleryType;
    if (type == null) return const Center(child: Text('Select a widget type.'));
    final definition = _draftEditor ?? widget.controller.editorFor(type);
    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const Key('genui-gallery-editor'),
            padding: const EdgeInsets.all(12),
            children: [
              _galleryPreview(type),
              const SizedBox(height: 8),
              Text(
                '$type defaults',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (_gallerySample case final sample?) ...[
                AnimatedBuilder(
                  animation: sample,
                  builder: (context, _) =>
                      EditableGenUiPropertyEditor(controller: sample),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    key: const Key('genui-save-defaults'),
                    onPressed: sample.isDirty && widget.saveDefaults != null
                        ? _saveGalleryDefaults
                        : null,
                    child: const Text('Save defaults'),
                  ),
                ),
                Text(
                  'Applies to new widgets only.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (definition != null) ...[
                const SizedBox(height: 12),
                Text(
                  _draftEditor == null
                      ? 'Custom editor: ${definition.id}'
                      : 'Generated editor preview: ${definition.id}',
                ),
                if (_draftEditor != null && widget.onPublishEditor != null)
                  FilledButton(
                    onPressed: _editorBusy ? null : _publishEditor,
                    child: const Text('Publish editor for BCO users'),
                  ),
              ],
              if (_editorError case final error?)
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        if (widget.canPublishEditors && widget.onGenerateEditor != null)
          _askAiFooter(
            prompt: _editorPrompt,
            key: const Key('genui-editor-ai-prompt'),
            hint: 'Describe a custom editor…',
            actionLabel: 'Ask GenUI to make an editor',
            onPressed: _editorBusy ? null : _generateEditor,
          ),
      ],
    );
  }

  Future<void> _generateEditor() async {
    final type = _galleryType;
    final generate = widget.onGenerateEditor;
    if (type == null || generate == null) return;
    setState(() {
      _editorBusy = true;
      _editorError = null;
    });
    try {
      final definition = await generate(type, _editorPrompt.text);
      if (mounted) {
        setState(() {
          _draftEditor = definition;
          _gallerySample?.setSharedEditors({type: definition});
        });
      }
    } on Object catch (error) {
      if (mounted) setState(() => _editorError = error.toString());
    } finally {
      if (mounted) setState(() => _editorBusy = false);
    }
  }

  EditableGenUiController _sampleFor(String type) {
    final contract = widget.controller.registry.contractFor(type);
    final preview = _previewRoots[type];
    final properties = <String, Object?>{
      for (final property
          in contract?.properties.values ?? const <EditablePropertyContract>[])
        if (property.type == EditablePropertyType.enumeration &&
            property.enumValues.isNotEmpty)
          property.name: preview?[property.name] ?? property.enumValues.first,
    };
    for (final entry
        in _defaults[type]?.entries ?? const <MapEntry<String, Object?>>[]) {
      final property = contract?.properties[entry.key];
      if (property != null && property.accepts(entry.value)) {
        properties[entry.key] = entry.value;
      }
    }
    final sample = EditableGenUiController(
      initial: GenUiEditSnapshot(
        revision: 1,
        messages: [
          {
            'updateComponents': {
              'surfaceId': 'gallery-sample',
              'components': [
                {'id': 'sample', 'component': type, ...properties},
              ],
            },
            'createSurface': {'surfaceId': 'gallery-sample'},
          },
        ],
      ),
      registry: widget.controller.registry,
      onSnapshotChanged: (snapshot) => _updateGalleryPreview(type, snapshot),
    );
    if (widget.controller.editorFor(type) case final editor?) {
      sample.setSharedEditors({type: editor});
    }
    sample.select(
      GenUiComponentSelection(
        surfaceId: 'gallery-sample',
        componentId: 'sample',
        componentType: type,
        definitionRevision: 1,
      ),
    );
    return sample;
  }

  void _saveGalleryDefaults() {
    final type = _galleryType;
    final sample = _gallerySample;
    if (type == null || sample == null) return;
    final contract = widget.controller.registry.contractFor(type);
    final component = sample.component('sample');
    if (contract == null || component == null) return;
    final values = <String, Object?>{
      for (final name in contract.properties.keys)
        if (component.containsKey(name)) name: component[name],
    };
    try {
      widget.saveDefaults?.call(type, values);
      setState(() {
        _defaults[type] = values;
        sample.dispose();
        _gallerySample = _sampleFor(type);
      });
    } on Object catch (error) {
      setState(() => _editorError = error.toString());
    }
  }

  void _updateGalleryPreview(String type, GenUiEditSnapshot snapshot) {
    if (mounted) setState(() {});
    final surface = _gallerySurface;
    final root = _previewRoots[type];
    final components = _previewComponents[type];
    if (surface == null || root == null || components == null) return;
    final update = snapshot.messages.first['updateComponents'];
    if (update is! Map || update['components'] is! List) return;
    final sample = (update['components'] as List).whereType<Map>().firstOrNull;
    if (sample == null) return;
    final contract = widget.controller.registry.contractFor(type);
    final changed = <String, Object?>{
      for (final name in contract?.properties.keys ?? const <String>[])
        if (sample.containsKey(name)) name: sample[name],
    };
    surface.handleMessage(
      core.UpdateComponentsMessage(
        surfaceId: 'gallery-$type',
        components: [
          for (final component in components)
            if (component['id'] == 'root') {...root, ...changed} else component,
        ],
      ),
    );
  }

  Future<void> _publishEditor() async {
    final type = _galleryType;
    final definition = _draftEditor;
    final publish = widget.onPublishEditor;
    if (type == null || definition == null || publish == null) return;
    setState(() {
      _editorBusy = true;
      _editorError = null;
    });
    try {
      await publish(type, definition);
      widget.controller.setSharedEditors({
        for (final name in widget.galleryTypes)
          name: ?widget.controller.editorFor(name),
        type: definition,
      });
      if (mounted) setState(() => _draftEditor = null);
    } on Object catch (error) {
      if (mounted) setState(() => _editorError = error.toString());
    } finally {
      if (mounted) setState(() => _editorBusy = false);
    }
  }

  Widget _surfaceEditor() {
    final controller = widget.controller;
    final selection = controller.selection;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (selection != null) ...[
                _selectedPreview(selection),
                const SizedBox(height: 8),
              ],
              if (widget.onGenerateProposal != null) ...[
                _presentationPanel(),
                const SizedBox(height: 12),
              ],
              if (selection != null) ...[
                Text(
                  'Edit ${selection.componentType}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                EditableGenUiPropertyEditor(controller: controller),
                if (controller.error case final error?)
                  Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 12),
              ] else
                const Text('Select a surface widget to edit it.'),
            ],
          ),
        ),
        if (selection != null &&
            controller.permissions.canUseAi &&
            controller.composer != null)
          _askAiFooter(
            prompt: _prompt,
            key: const Key('editable-genui-ai-prompt'),
            hint: 'Ask AI to edit this widget…',
            actionLabel: 'Apply AI edit',
            onPressed: controller.busy
                ? null
                : () => controller.prompt(_prompt.text),
          ),
      ],
    );
  }

  Widget _presentationPanel() => Container(
    key: const Key('genui-presentation-request-panel'),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'What should change?',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        TextField(
          key: const Key('observer-presentation-request'),
          controller: _presentationPrompt,
          minLines: 1,
          maxLines: 2,
          maxLength: 600,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Describe the presentation you want…',
            isDense: true,
            counterText: '',
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PopupMenuButton<String>(
              key: const Key('genui-presentation-tags'),
              tooltip: 'Choose presentation preferences',
              onSelected: (tag) => setState(() {
                if (!_presentationTags.add(tag)) {
                  _presentationTags.remove(tag);
                } else {
                  if (_presentationTags.length > 4) {
                    _presentationTags.remove(tag);
                  } else if (tag == 'less_text') {
                    _presentationTags.remove('more_detail');
                  } else if (tag == 'more_detail') {
                    _presentationTags.remove('less_text');
                  }
                }
              }),
              itemBuilder: (_) => [
                for (final tag in widget.presentationTagOptions)
                  CheckedPopupMenuItem(
                    value: tag,
                    checked: _presentationTags.contains(tag),
                    child: Text(widget.presentationTagLabel?.call(tag) ?? tag),
                  ),
              ],
              child: Chip(
                avatar: const Icon(Icons.sell_outlined, size: 16),
                label: Text(
                  _presentationTags.isEmpty
                      ? 'Preferences'
                      : 'Preferences (${_presentationTags.length})',
                ),
              ),
            ),
            FilledButton.icon(
              key: const Key('genui-generate-proposal'),
              onPressed:
                  _generatingProposal ||
                      (_presentationTags.isEmpty &&
                          _presentationPrompt.text.trim().isEmpty)
                  ? null
                  : _generateProposal,
              icon: _generatingProposal
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined, size: 18),
              label: const Text('Generate proposal'),
            ),
          ],
        ),
        if (_proposalError case final error?)
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
  );

  Future<void> _generateProposal() async {
    final generate = widget.onGenerateProposal;
    if (generate == null) return;
    setState(() {
      _generatingProposal = true;
      _proposalError = null;
    });
    try {
      final error = await generate(
        _presentationTags.toList(growable: false),
        _presentationPrompt.text.trim(),
      );
      if (!mounted) return;
      if (error == null) {
        Navigator.of(context).pop();
      } else {
        setState(() => _proposalError = error);
      }
    } on Object catch (error) {
      if (mounted) setState(() => _proposalError = error.toString());
    } finally {
      if (mounted) setState(() => _generatingProposal = false);
    }
  }

  Widget _askAiFooter({
    required TextEditingController prompt,
    required Key key,
    required String hint,
    required String actionLabel,
    required VoidCallback? onPressed,
  }) => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: key,
          controller: prompt,
          minLines: 1,
          maxLines: 2,
          maxLength: 600,
          decoration: const InputDecoration(
            hintText: 'Ask AI…',
            prefixIcon: Icon(Icons.auto_awesome_outlined),
            border: InputBorder.none,
            isDense: true,
            counterText: '',
          ).copyWith(hintText: hint),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            onPressed: onPressed,
            icon: const Icon(Icons.arrow_upward, size: 16),
            label: Text(actionLabel),
          ),
        ),
      ],
    ),
  );
}

String _surfaceId(GenUiEditSnapshot snapshot) {
  for (final message in snapshot.messages) {
    final create = message['createSurface'];
    if (create is Map && create['surfaceId'] is String) {
      return create['surfaceId'] as String;
    }
  }
  return '';
}
