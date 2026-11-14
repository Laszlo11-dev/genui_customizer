import 'dart:math';

import 'package:flutter/material.dart';

import 'bounds.dart';
import 'color_field.dart';
import 'studio.dart';
import 'touch.dart';

final _openStudios = Expando<_OpenStudio>();

class _OpenStudio {
  _OpenStudio(_StudioRequest initial)
    : request = ValueNotifier(initial),
      selection = initial.controller.selection;

  final ValueNotifier<_StudioRequest> request;
  TouchSelection? selection;
  bool prompting = false;
}

class _StudioRequest {
  const _StudioRequest({
    required this.controller,
    required this.surfaceId,
    required this.galleryPreview,
    required this.galleryOnly,
    required this.colorPalette,
    required this.onGalleryChanged,
    required this.boundsPersistence,
  });

  final GenUiTouchController controller;
  final String surfaceId;
  final TouchGalleryPreview? galleryPreview;
  final bool galleryOnly;
  final List<TouchColorSwatch>? colorPalette;
  final VoidCallback? onGalleryChanged;
  final TouchStudioBoundsPersistence? boundsPersistence;
}

/// Opens the same floating, movable, resizable Studio pattern as the earlier
/// GenUI Touch UI. A2UI changes only the content and controller underneath it.
Future<void> showGenUiTouchStudio({
  required BuildContext context,
  required GenUiTouchController controller,
  required String surfaceId,
  TouchGalleryPreview? galleryPreview,
  bool galleryOnly = false,
  List<TouchColorSwatch>? colorPalette,
  VoidCallback? onGalleryChanged,
  TouchStudioBoundsPersistence? boundsPersistence =
      const SharedPreferencesTouchStudioBoundsPersistence(),
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final request = _StudioRequest(
    controller: controller,
    surfaceId: surfaceId,
    galleryPreview: galleryPreview,
    galleryOnly: galleryOnly,
    colorPalette: colorPalette,
    onGalleryChanged: onGalleryChanged,
    boundsPersistence: boundsPersistence,
  );
  final existing = _openStudios[navigator];
  if (existing != null) {
    final previousRequest = existing.request.value;
    final previousController = previousRequest.controller;
    if (existing.prompting) {
      if (existing.selection case final previous?) {
        previousController.select(previous);
      }
      return;
    }
    final nextSelection = controller.selection;
    if (identical(controller, previousController) &&
        surfaceId == previousRequest.surfaceId &&
        galleryOnly == previousRequest.galleryOnly &&
        nextSelection?.surfaceId == existing.selection?.surfaceId &&
        nextSelection?.componentId == existing.selection?.componentId &&
        nextSelection?.instanceId == existing.selection?.instanceId) {
      return;
    }
    if (previousController.hasUnsavedProfileChanges) {
      existing.prompting = true;
      // Keep the current editor content in place while the user decides.
      if (existing.selection case final previous?) {
        previousController.select(previous);
      }
      final choice = await showDialog<String>(
        context: navigator.context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Unsaved appearance changes'),
          content: const Text(
            'Save your changes before switching to another component?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('discard'),
              child: const Text('Discard changes'),
            ),
            FilledButton(
              onPressed: previousController.canPersist
                  ? () => Navigator.of(dialogContext).pop('save')
                  : null,
              child: const Text('Save changes'),
            ),
          ],
        ),
      );
      existing.prompting = false;
      if (choice == null || choice == 'cancel') return;
      if (choice == 'save') {
        try {
          await previousController.save();
        } catch (error) {
          if (navigator.mounted) {
            ScaffoldMessenger.of(navigator.context)
                .showSnackBar(SnackBar(content: Text('$error')));
          }
          return;
        }
      } else {
        previousController.discardGalleryChanges();
        previousRequest.onGalleryChanged?.call();
      }
    }
    if (nextSelection != null) {
      controller.select(nextSelection);
    }
    existing.selection = nextSelection;
    existing.request.value = request;
    return;
  }
  final session = _OpenStudio(request);
  _openStudios[navigator] = session;
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  Rect? stored;
  try {
    stored = await boundsPersistence?.load();
  } on Object {
    // Local layout storage is optional.
  }
  if (!context.mounted || !navigator.mounted) {
    _openStudios[navigator] = null;
    session.request.dispose();
    return;
  }
  try {
    await navigator.push<void>(
      _TouchStudioRoute(
        themes: themes,
        builder: (_) => ValueListenableBuilder<_StudioRequest>(
          valueListenable: session.request,
          builder: (context, current, _) => _FloatingWindow(
            key: ValueKey((
              current.controller,
              current.surfaceId,
              current.galleryOnly,
            )),
            controller: current.controller,
            surfaceId: current.surfaceId,
            galleryPreview: current.galleryPreview,
            galleryOnly: current.galleryOnly,
            colorPalette: current.colorPalette,
            onGalleryChanged: current.onGalleryChanged,
            initialBounds: stored,
            boundsPersistence: current.boundsPersistence,
          ),
        ),
      ),
    );
  } finally {
    if (identical(_openStudios[navigator], session)) {
      _openStudios[navigator] = null;
    }
    session.request.dispose();
  }
}

final class _TouchStudioRoute extends RawDialogRoute<void> {
  _TouchStudioRoute({
    required CapturedThemes themes,
    required WidgetBuilder builder,
  }) : super(
         barrierDismissible: false,
         pageBuilder: (context, animation, secondaryAnimation) =>
             themes.wrap(SafeArea(child: Builder(builder: builder))),
       );

  @override
  Widget buildModalBarrier() => const SizedBox.shrink();
}

class _FloatingWindow extends StatefulWidget {
  const _FloatingWindow({
    super.key,
    required this.controller,
    required this.surfaceId,
    required this.galleryPreview,
    required this.galleryOnly,
    required this.colorPalette,
    required this.onGalleryChanged,
    required this.initialBounds,
    required this.boundsPersistence,
  });

  final GenUiTouchController controller;
  final String surfaceId;
  final TouchGalleryPreview? galleryPreview;
  final bool galleryOnly;
  final List<TouchColorSwatch>? colorPalette;
  final VoidCallback? onGalleryChanged;
  final Rect? initialBounds;
  final TouchStudioBoundsPersistence? boundsPersistence;

  @override
  State<_FloatingWindow> createState() => _FloatingWindowState();
}

class _FloatingWindowState extends State<_FloatingWindow> {
  Rect? _bounds;

  @override
  void initState() {
    super.initState();
    _bounds = widget.initialBounds;
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

  Rect _fit(Rect bounds, Size viewport) {
    final maxWidth = max(0.0, viewport.width - 48);
    final maxHeight = max(0.0, viewport.height - 64);
    final width = bounds.width.clamp(min(360.0, maxWidth), maxWidth).toDouble();
    final height = bounds.height
        .clamp(min(360.0, maxHeight), maxHeight)
        .toDouble();
    final left = bounds.left.clamp(
      24.0,
      max(24.0, viewport.width - width - 24),
    );
    final top = bounds.top.clamp(
      32.0,
      max(32.0, viewport.height - height - 32),
    );
    return Rect.fromLTWH(left.toDouble(), top.toDouble(), width, height);
  }

  void _move(DragUpdateDetails details, Rect bounds, Size viewport) {
    setState(() {
      _bounds = _fit(bounds.shift(details.delta), viewport);
    });
  }

  void _resize(DragUpdateDetails details, Rect bounds, Size viewport) {
    setState(() {
      final maxWidth = max(0.0, viewport.width - bounds.left - 24);
      final maxHeight = max(0.0, viewport.height - bounds.top - 32);
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
    if (bounds != null) {
      try {
        widget.boundsPersistence?.save(bounds).ignore();
      } on Object {
        // The editor remains usable if app-local storage is unavailable.
      }
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final viewport = constraints.biggest;
      final bounds = _fit(_bounds ?? _initial(viewport), viewport);
      final colors = Theme.of(context).colorScheme;
      return Stack(
        children: [
          Positioned.fromRect(
            rect: bounds,
            child: Dialog(
              insetPadding: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              backgroundColor: colors.surface,
              elevation: 24,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: colors.outline, width: 1.5),
              ),
              child: SizedBox(
                key: const Key('genui-touch-studio-dialog'),
                width: bounds.width,
                height: bounds.height,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GenUiTouchStudio(
                        controller: widget.controller,
                        surfaceId: widget.surfaceId,
                        galleryPreview: widget.galleryPreview,
                        galleryOnly: widget.galleryOnly,
                        colorPalette: widget.colorPalette,
                        onGalleryChanged: widget.onGalleryChanged,
                        onMove: (details) => _move(details, bounds, viewport),
                        onMoveEnd: _remember,
                        onClose: () => Navigator.of(context).pop(),
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
                          onPanUpdate: (details) =>
                              _resize(details, bounds, viewport),
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
