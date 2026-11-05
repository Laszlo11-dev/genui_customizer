import 'package:genui_customizer/src/core/core.dart';
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

import 'controller.dart';

CatalogItem decorateEditableCatalogItem(
  CatalogItem item,
  EditableGenUiController controller,
) => CatalogItem(
  name: item.name,
  dataSchema: item.dataSchema,
  exampleData: item.exampleData,
  isImplicitlyFlexible: item.isImplicitlyFlexible,
  widgetBuilder: (context) {
    final child = item.widgetBuilder(context);
    if (!controller.canSelect(context.type)) return child;
    return _EditableComponentRegion(
      controller: controller,
      selection: GenUiComponentSelection(
        surfaceId: context.surfaceId,
        componentId: context.id,
        componentType: context.type,
        definitionRevision: controller.snapshot.revision,
      ),
      child: child,
    );
  },
);

final class _EditableComponentRegion extends StatelessWidget {
  const _EditableComponentRegion({
    required this.controller,
    required this.selection,
    required this.child,
  });

  final EditableGenUiController controller;
  final GenUiComponentSelection selection;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: child,
    builder: (context, child) {
      final selected =
          controller.selection?.componentId == selection.componentId;
      return Listener(
        onPointerDown: (event) =>
            controller.handlePointerDown(event, selection),
        onPointerMove: controller.handlePointerMove,
        onPointerUp: (event) => controller.handlePointerUp(event, selection),
        onPointerCancel: controller.handlePointerCancel,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: selected
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  )
                : null,
            borderRadius: selected ? BorderRadius.circular(14) : null,
          ),
          child: child,
        ),
      );
    },
  );
}
