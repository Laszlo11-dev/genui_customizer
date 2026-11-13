import 'dart:convert';
import 'dart:math';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/link.dart';

import 'touch.dart';
import 'color_field.dart';

/// Host-supplied live component preview for a Gallery entry.
typedef TouchGalleryPreview = Widget Function(
  BuildContext context,
  TouchContract contract,
  Map<String, Object?> values,
);

/// Runtime editor for an A2UI surface and its reusable component defaults.
///
/// Mount this in the host app and open it from [GenUiTouchController.onStudioRequested].
/// The Gallery is available to users of the running app, not only developers.
class GenUiTouchStudio extends StatefulWidget {
  const GenUiTouchStudio({
    super.key,
    required this.controller,
    required this.surfaceId,
    this.galleryPreview,
    this.galleryOnly = false,
    this.onGalleryChanged,
    this.onMove,
    this.onMoveEnd,
    this.onClose,
  });

  final GenUiTouchController controller;
  final String surfaceId;
  final TouchGalleryPreview? galleryPreview;
  final bool galleryOnly;
  final VoidCallback? onGalleryChanged;
  final GestureDragUpdateCallback? onMove;
  final VoidCallback? onMoveEnd;
  final VoidCallback? onClose;

  @override
  State<GenUiTouchStudio> createState() => _GenUiTouchStudioState();
}

class _GenUiTouchStudioState extends State<GenUiTouchStudio> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int tab = 0;
  TouchContract? galleryContract;
  TouchSelection? _lastSelection;
  double splitFraction = 0.42;

  void _closeDrawer() {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final collapseTree = constraints.maxWidth < 700;
        final colors = Theme.of(context).colorScheme;
        final toolbarIconStyle = IconButton.styleFrom(
          foregroundColor: colors.onInverseSurface,
          disabledForegroundColor: colors.onInverseSurface.withValues(
            alpha: 0.38,
          ),
        );
        return AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) => Scaffold(
            key: _scaffoldKey,
            drawer: collapseTree
                ? Drawer(
                    width: min(360, constraints.maxWidth - 48),
                    child: SafeArea(
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(
                              widget.galleryOnly || tab == 1
                                  ? 'Component types'
                                  : 'Components',
                            ),
                            trailing: IconButton(
                              tooltip: 'Close component list',
                              onPressed: _closeDrawer,
                              icon: const Icon(Icons.close),
                            ),
                          ),
                          Expanded(
                            child: widget.galleryOnly || tab == 1
                                ? _galleryList(showHeading: false)
                                : _componentList(showHeading: false),
                          ),
                        ],
                      ),
                    ),
                  )
                : null,
            appBar: AppBar(
              toolbarHeight: 48,
              backgroundColor: colors.inverseSurface,
              foregroundColor: colors.onInverseSurface,
              surfaceTintColor: Colors.transparent,
              iconTheme: IconThemeData(color: colors.onInverseSurface),
              actionsIconTheme: IconThemeData(color: colors.onInverseSurface),
              titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.onInverseSurface,
                fontWeight: FontWeight.w600,
              ),
              titleSpacing: compact ? 0 : null,
              leading: widget.onClose == null
                  ? null
                  : IconButton(
                      tooltip: 'Close editor',
                      style: toolbarIconStyle,
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close),
                    ),
              title: MouseRegion(
                cursor: widget.onMove == null
                    ? MouseCursor.defer
                    : SystemMouseCursors.move,
                child: GestureDetector(
                  key: const Key('genui-studio-drag'),
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: widget.onMove,
                  onPanEnd: widget.onMoveEnd == null
                      ? null
                      : (_) => widget.onMoveEnd!(),
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
              actions: [
                if (collapseTree)
                  IconButton(
                    key: const Key('genui-studio-open-components'),
                    tooltip: widget.galleryOnly || tab == 1
                        ? 'Open component types'
                        : 'Open components',
                    style: toolbarIconStyle,
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    icon: const Icon(Icons.menu),
                  ),
                if (!compact && !widget.galleryOnly) ...[
                  IconButton(
                    tooltip: 'Undo',
                    style: toolbarIconStyle,
                    onPressed: widget.controller.canUndo
                        ? widget.controller.undo
                        : null,
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(
                    tooltip: 'Redo',
                    style: toolbarIconStyle,
                    onPressed: widget.controller.canRedo
                        ? widget.controller.redo
                        : null,
                    icon: const Icon(Icons.redo),
                  ),
                ],
                if (!compact) ...[
                  IconButton(
                    tooltip: 'Save profile',
                    style: toolbarIconStyle,
                    onPressed:
                        !widget.controller.canPersist ||
                            !widget.controller.hasUnsavedProfileChanges
                        ? null
                        : () => _saveProfile(context),
                    icon: const Icon(Icons.save_outlined),
                  ),
                ],
                PopupMenuButton<String>(
                  key: const Key('genui-studio-menu'),
                  tooltip: 'GenUI Touch menu',
                  onSelected: (action) {
                    switch (action) {
                      case 'about':
                        showAboutDialog(
                          context: context,
                          applicationName: 'GenUI Touch',
                          children: [
                            const Text('Make generated UI your own.'),
                            const SizedBox(height: 12),
                            Link(
                              uri: Uri.https(
                                'pub.dev',
                                '/packages/genui_customizer',
                              ),
                              target: LinkTarget.blank,
                              builder: (context, followLink) => Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: followLink,
                                  icon: const Icon(Icons.open_in_new),
                                  label: const Text('pub.dev package'),
                                ),
                              ),
                            ),
                          ],
                        );
                      case 'debug':
                        _showDebug(context);
                      case 'undo':
                        widget.controller.undo();
                      case 'redo':
                        widget.controller.redo();
                      case 'save':
                        _saveProfile(context);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'debug',
                      child: Text('GenUI debug'),
                    ),
                    const PopupMenuItem(value: 'about', child: Text('About')),
                    if (compact) ...[
                      const PopupMenuDivider(),
                      if (!widget.galleryOnly) ...[
                        PopupMenuItem(
                          value: 'undo',
                          enabled: widget.controller.canUndo,
                          child: const Text('Undo'),
                        ),
                        PopupMenuItem(
                          value: 'redo',
                          enabled: widget.controller.canRedo,
                          child: const Text('Redo'),
                        ),
                      ],
                      PopupMenuItem(
                        value: 'save',
                        enabled:
                            widget.controller.canPersist &&
                            widget.controller.hasUnsavedProfileChanges,
                        child: const Text('Save profile'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            body: widget.galleryOnly
                ? _gallery(context)
                : DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        TabBar(
                          tabs: const [
                            Tab(text: 'Surface'),
                            Tab(text: 'Gallery'),
                          ],
                          onTap: (value) => setState(() => tab = value),
                        ),
                        Expanded(
                          child: tab == 0
                              ? _surface(context)
                              : _gallery(context),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Future<void> _saveProfile(BuildContext context) async {
    try {
      await widget.controller.save();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Appearance saved')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  void _showDebug(BuildContext context) {
    final surface = widget.controller.processor.model.getSurface(
      widget.surfaceId,
    );
    final data = {
      'surfaceId': widget.surfaceId,
      'components': [
        if (surface != null)
          for (final component in surface.componentsModel.all)
            component.toJson(),
      ],
      'selectedComponent': widget.controller.selection?.componentId,
      'profile': widget.controller.profile.toJson(),
      'revision': widget.controller.revision,
      'error': widget.controller.error,
    };
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('GenUI debug'),
        content: SizedBox(
          width: 760,
          height: 520,
          child: SingleChildScrollView(
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(data),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _surface(BuildContext context) {
    final surface = widget.controller.processor.model.getSurface(
      widget.surfaceId,
    );
    if (surface == null) {
      return const Center(child: Text('Surface unavailable'));
    }
    final selected = widget.controller.selection;
    final contract = selected?.surfaceId == widget.surfaceId
        ? widget.controller.contractFor(selected!)
        : null;
    final selectedValues = selected == null
        ? const <String, Object?>{}
        : widget.controller.component(selected) ?? const <String, Object?>{};
    final role = selected == null
        ? null
        : widget.controller.roleFor?.call(selected, selectedValues);
    final editor = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (contract != null && selected != null) ...[
          Text(
            '${selected.componentType} · ${selected.componentId}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (role != null && role.isNotEmpty)
            Text(
              'The bookmark beside a value reuses it for "$role" when this surface is regenerated. Press Save profile to keep it after restart.',
            ),
          _propertyList(
            contract,
            selectedValues,
            (name, value) => widget.controller.edit(name, value),
            saveRole: role != null && role.isNotEmpty
                ? widget.controller.setRoleDefaultForSelection
                : null,
            roleLabel: role,
          ),
        ] else
          const Text('Select a component to edit its appearance.'),
      ],
    );
    return _split(_componentList(), editor);
  }

  Widget _componentList({bool showHeading = true}) {
    final surface = widget.controller.processor.model.getSurface(
      widget.surfaceId,
    );
    if (surface == null) return const SizedBox.shrink();
    final selected = widget.controller.selection;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (showHeading)
          const Text('Components', style: TextStyle(fontSize: 18)),
        for (final component in surface.componentsModel.all)
          if (_contractFor(surface, component) case final matching?)
            ListTile(
              title: Text(component.type),
              subtitle: Text(component.id),
              selected: selected?.componentId == component.id,
              onTap: () {
                widget.controller.select(
                  TouchSelection(
                    surfaceId: surface.id,
                    componentId: component.id,
                    catalogId: matching.catalogId,
                    componentType: component.type,
                    instanceId: component.id,
                    dataPath: '',
                  ),
                );
                _closeDrawer();
              },
            ),
      ],
    );
  }

  TouchContract? _contractFor(
    SurfaceModel<ComponentImplementation> surface,
    ComponentModel component,
  ) {
    final catalogId = component.catalog ?? surface.defaultCatalog?.id;
    if (catalogId == null) return null;
    for (final contract in widget.controller.contracts) {
      if (contract.catalogId == catalogId &&
          contract.componentType == component.type) {
        return contract;
      }
    }
    return null;
  }

  Widget _gallery(BuildContext context) {
    final contracts = widget.controller.contracts.toList();
    final selected = widget.controller.selection;
    if (!identical(selected, _lastSelection)) {
      galleryContract = null;
      _lastSelection = selected;
    }
    final selectedContract = selected == null
        ? null
        : widget.controller.contractFor(selected);
    final current =
        galleryContract ??
        selectedContract ??
        (contracts.isEmpty ? null : contracts.first);
    if (current == null) {
      return const Center(child: Text('No editable components'));
    }
    final key = '${current.catalogId}\u0000${current.componentType}';
    final defaults =
        widget.controller.profile.defaults[key] ?? const <String, Object?>{};
    final displayValues = <String, Object?>{};
    if (widget.galleryOnly) {
      final surface = widget.controller.processor.model.getSurface(
        widget.surfaceId,
      );
      if (surface != null) {
        for (final component in surface.componentsModel.all) {
          if (component.type == current.componentType &&
              (component.catalog ?? surface.defaultCatalog?.id) ==
                  current.catalogId) {
            displayValues.addAll(component.toJson().cast<String, Object?>());
            break;
          }
        }
      }
    }
    displayValues.addAll(defaults);
    final editor = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.galleryPreview case final preview?)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: preview(context, current, defaults),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          widget.galleryOnly
              ? 'Appearance for all ${current.componentType} components'
              : 'Default appearance for new ${current.componentType} components',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (widget.galleryOnly) ...[
          const SizedBox(height: 8),
          const Text(
            'Changing a value updates every current and future component of this type. Save to keep it after restart.',
          ),
        ],
        _propertyList(
          current,
          displayValues,
          (name, value) {
            widget.controller.setGalleryDefault(current, name, value);
            widget.onGalleryChanged?.call();
          },
          overridden: defaults.keys.toSet(),
          reset: (name) {
            widget.controller.removeGalleryDefault(current, name);
            widget.onGalleryChanged?.call();
          },
        ),
        if (defaults.isNotEmpty)
          TextButton.icon(
            onPressed: () {
              widget.controller.clearGalleryDefaults(current);
              widget.onGalleryChanged?.call();
            },
            icon: const Icon(Icons.restart_alt),
            label: Text('Restore original ${current.componentType} appearance'),
          ),
        TextButton(
          onPressed: widget.controller.hasUnsavedProfileChanges
              ? () {
                  widget.controller.discardGalleryChanges();
                  widget.onGalleryChanged?.call();
                }
              : null,
          child: const Text('Discard unsaved defaults'),
        ),
      ],
    );
    return _split(_galleryList(), editor);
  }

  Widget _galleryList({bool showHeading = true}) {
    final contracts = widget.controller.contracts.toList();
    final selected = widget.controller.selection;
    final current =
        galleryContract ??
        (selected == null ? null : widget.controller.contractFor(selected)) ??
        (contracts.isEmpty ? null : contracts.first);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (showHeading)
          Text(
            widget.galleryOnly ? 'Component types' : 'Editable components',
            style: const TextStyle(fontSize: 18),
          ),
        for (final contract in contracts)
          ListTile(
            title: Text(contract.componentType),
            subtitle: Text(
              contract.catalogId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            selected: identical(contract, current),
            onTap: () {
              setState(() => galleryContract = contract);
              _closeDrawer();
            },
          ),
      ],
    );
  }

  Widget _split(Widget left, Widget right) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 700) {
        return right;
      }
      final available = constraints.maxWidth - 12;
      return Row(
        children: [
          SizedBox(width: available * splitFraction, child: left),
          MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: GestureDetector(
              key: const Key('genui-studio-splitter'),
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) => setState(() {
                splitFraction = (splitFraction + details.delta.dx / available)
                    .clamp(0.25, 0.7);
              }),
              child: SizedBox(
                width: 12,
                height: double.infinity,
                child: Center(
                  child: VerticalDivider(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: right),
        ],
      );
    },
  );

  Widget _propertyList(
    TouchContract contract,
    Map<String, Object?> values,
    void Function(String, Object?) change, {
    void Function(String)? saveRole,
    String? roleLabel,
    Set<String> overridden = const {},
    void Function(String)? reset,
  }) => Column(
    children: [
      for (final property in contract.properties.values)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: saveRole == null && reset == null
              ? _field(property, values[property.name], change)
              : Row(
                  children: [
                    Expanded(
                      child: _field(
                        property,
                        values[property.name],
                        change,
                        onReset:
                            reset != null && overridden.contains(property.name)
                            ? () => reset(property.name)
                            : null,
                      ),
                    ),
                    if (saveRole != null)
                      IconButton(
                        tooltip:
                            'Reuse ${property.label} for "$roleLabel" on new surfaces',
                        onPressed: property.accepts(values[property.name])
                            ? () => saveRole(property.name)
                            : null,
                        icon: const Icon(Icons.bookmark_add_outlined),
                      ),
                    if (reset != null && overridden.contains(property.name))
                      IconButton(
                        tooltip: 'Restore original ${property.label}',
                        onPressed: () => reset(property.name),
                        icon: const Icon(Icons.restart_alt),
                      ),
                  ],
                ),
        ),
    ],
  );

  Widget _field(
    TouchProperty property,
    Object? value,
    void Function(String, Object?) change, {
    VoidCallback? onReset,
  }) {
    if (value is Map &&
        (value.containsKey('@path') || value.containsKey('@call'))) {
      return ListTile(
        title: Text(property.label),
        subtitle: const Text('Bound value'),
      );
    }
    switch (property.kind) {
      case TouchValueKind.choice:
        return DropdownButtonFormField<String>(
          key: ValueKey('${property.name}:$value'),
          initialValue: value is String && property.choices.contains(value)
              ? value
              : null,
          decoration: InputDecoration(labelText: property.label),
          items: [
            for (final choice in property.choices)
              DropdownMenuItem(value: choice, child: Text(choice)),
          ],
          onChanged: (next) => change(property.name, next),
        );
      case TouchValueKind.boolean:
        return SwitchListTile(
          title: Text(property.label),
          value: value == true,
          onChanged: (next) => change(property.name, next),
        );
      case TouchValueKind.color:
        return TouchColorField(
          name: property.name,
          label: property.label,
          value: value is String ? value : null,
          onChanged: (next) => change(property.name, next),
          onReset: onReset,
        );
      case TouchValueKind.text:
      case TouchValueKind.number:
        return _LiveValueField(
          key: ValueKey(property.name),
          property: property,
          value: value,
          change: change,
        );
    }
  }
}

class _LiveValueField extends StatefulWidget {
  const _LiveValueField({
    super.key,
    required this.property,
    required this.value,
    required this.change,
  });

  final TouchProperty property;
  final Object? value;
  final void Function(String, Object?) change;

  @override
  State<_LiveValueField> createState() => _LiveValueFieldState();
}

class _LiveValueFieldState extends State<_LiveValueField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString());
  }

  @override
  void didUpdateWidget(_LiveValueField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final next = widget.value?.toString() ?? '';
      if (_controller.text != next) {
        _controller.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: _controller,
    decoration: InputDecoration(labelText: widget.property.label),
    keyboardType: widget.property.kind == TouchValueKind.number
        ? TextInputType.number
        : TextInputType.text,
    onChanged: (next) {
      final value = widget.property.kind == TouchValueKind.number
          ? num.tryParse(next)
          : next;
      if (value != null) widget.change(widget.property.name, value);
    },
  );
}
