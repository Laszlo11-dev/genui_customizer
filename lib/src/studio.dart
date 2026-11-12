import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/material.dart';

import 'touch.dart';

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
    this.onMove,
    this.onMoveEnd,
    this.onClose,
  });

  final GenUiTouchController controller;
  final String surfaceId;
  final TouchGalleryPreview? galleryPreview;
  final GestureDragUpdateCallback? onMove;
  final VoidCallback? onMoveEnd;
  final VoidCallback? onClose;

  @override
  State<GenUiTouchStudio> createState() => _GenUiTouchStudioState();
}

class _GenUiTouchStudioState extends State<GenUiTouchStudio> {
  int tab = 0;
  TouchContract? galleryContract;
  double splitFraction = 0.42;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          leading: widget.onClose == null
              ? null
              : IconButton(
                  tooltip: 'Close editor',
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
              child: const SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('GenUI Touch'),
                ),
              ),
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Undo',
              onPressed: widget.controller.canUndo
                  ? widget.controller.undo
                  : null,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: 'Redo',
              onPressed: widget.controller.canRedo
                  ? widget.controller.redo
                  : null,
              icon: const Icon(Icons.redo),
            ),
            IconButton(
              tooltip: 'Save profile',
              onPressed: !widget.controller.canPersist
                  ? null
                  : () async {
                      try {
                        await widget.controller.save();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Appearance saved')),
                          );
                        }
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('$error')));
                        }
                      }
                    },
              icon: const Icon(Icons.save_outlined),
            ),
          ],
        ),
        body: DefaultTabController(
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
              Expanded(child: tab == 0 ? _surface(context) : _gallery(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _surface(BuildContext context) {
    final surface = widget.controller.processor.model.getSurface(
      widget.surfaceId,
    );
    if (surface == null)
      return const Center(child: Text('Surface unavailable'));
    final selected = widget.controller.selection;
    final contract = selected?.surfaceId == widget.surfaceId
        ? widget.controller.contractFor(selected!)
        : null;
    final componentList = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Components', style: TextStyle(fontSize: 18)),
        for (final component in surface.componentsModel.all)
          if (_contractFor(surface, component) case final matching?)
            ListTile(
              title: Text(component.type),
              subtitle: Text(component.id),
              selected: selected?.componentId == component.id,
              onTap: () => widget.controller.select(
                TouchSelection(
                  surfaceId: surface.id,
                  componentId: component.id,
                  catalogId: matching.catalogId,
                  componentType: component.type,
                  instanceId: component.id,
                  dataPath: '',
                ),
              ),
            ),
      ],
    );
    final editor = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (contract != null && selected != null) ...[
          Text(
            '${selected.componentType} · ${selected.componentId}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          _propertyList(
            contract,
            widget.controller.component(selected) ?? const {},
            (name, value) => widget.controller.edit(name, value),
            saveRole:
                widget.controller.roleFor
                        ?.call(
                          selected,
                          widget.controller.component(selected) ?? const {},
                        )
                        ?.isNotEmpty ==
                    true
                ? widget.controller.setRoleDefaultForSelection
                : null,
          ),
        ] else
          const Text('Select a component to edit its appearance.'),
      ],
    );
    return _split(componentList, editor);
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
    final current =
        galleryContract ?? (contracts.isEmpty ? null : contracts.first);
    if (current == null)
      return const Center(child: Text('No editable components'));
    final key = '${current.catalogId}\u0000${current.componentType}';
    final defaults =
        widget.controller.profile.defaults[key] ?? const <String, Object?>{};
    final galleryList = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Editable components', style: TextStyle(fontSize: 18)),
        for (final contract in contracts)
          ListTile(
            title: Text(contract.componentType),
            subtitle: Text(
              contract.catalogId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            selected: identical(contract, current),
            onTap: () => setState(() => galleryContract = contract),
          ),
      ],
    );
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
          'Default appearance for new ${current.componentType} components',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        _propertyList(
          current,
          defaults,
          (name, value) =>
              widget.controller.setGalleryDefault(current, name, value),
        ),
        TextButton(
          onPressed: widget.controller.discardGalleryChanges,
          child: const Text('Discard unsaved defaults'),
        ),
      ],
    );
    return _split(galleryList, editor);
  }

  Widget _split(Widget left, Widget right) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 700) {
        return Column(
          children: [
            SizedBox(height: constraints.maxHeight * 0.36, child: left),
            const Divider(height: 1),
            Expanded(child: right),
          ],
        );
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
  }) => Column(
    children: [
      for (final property in contract.properties.values)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: saveRole == null
              ? _field(property, values[property.name], change)
              : Row(
                  children: [
                    Expanded(
                      child: _field(property, values[property.name], change),
                    ),
                    IconButton(
                      tooltip: 'Use ${property.label} for matching roles',
                      onPressed: () => saveRole(property.name),
                      icon: const Icon(Icons.bookmark_add_outlined),
                    ),
                  ],
                ),
        ),
    ],
  );

  Widget _field(
    TouchProperty property,
    Object? value,
    void Function(String, Object?) change,
  ) {
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
      case TouchValueKind.text:
      case TouchValueKind.number:
        return TextFormField(
          key: ValueKey('${property.name}:$value'),
          initialValue: value?.toString(),
          decoration: InputDecoration(labelText: property.label),
          keyboardType: property.kind == TouchValueKind.number
              ? TextInputType.number
              : TextInputType.text,
          onFieldSubmitted: (next) {
            final parsed = property.kind == TouchValueKind.number
                ? num.tryParse(next)
                : next;
            if (parsed != null) change(property.name, parsed);
          },
        );
    }
  }
}
