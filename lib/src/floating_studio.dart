import 'dart:math';

import 'package:flutter/material.dart';

import 'bounds.dart';
import 'studio.dart';
import 'touch.dart';

/// Opens the same floating, movable, resizable Studio pattern as the earlier
/// GenUI Touch UI. A2UI changes only the content and controller underneath it.
Future<void> showGenUiTouchStudio({
  required BuildContext context,
  required GenUiTouchController controller,
  required String surfaceId,
  TouchGalleryPreview? galleryPreview,
  TouchStudioBoundsPersistence? boundsPersistence =
      const SharedPreferencesTouchStudioBoundsPersistence(),
}) async {
  Rect? stored;
  try {
    stored = await boundsPersistence?.load();
  } on Object {
    // Local layout storage is optional.
  }
  if (!context.mounted) return;
  await Navigator.of(context, rootNavigator: true).push<void>(
    _TouchStudioRoute(
      themes: InheritedTheme.capture(
        from: context,
        to: Navigator.of(context, rootNavigator: true).context,
      ),
      builder: (_) => _FloatingWindow(
        controller: controller,
        surfaceId: surfaceId,
        galleryPreview: galleryPreview,
        initialBounds: stored,
        boundsPersistence: boundsPersistence,
      ),
    ),
  );
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
    required this.controller,
    required this.surfaceId,
    required this.galleryPreview,
    required this.initialBounds,
    required this.boundsPersistence,
  });

  final GenUiTouchController controller;
  final String surfaceId;
  final TouchGalleryPreview? galleryPreview;
  final Rect? initialBounds;
  final TouchStudioBoundsPersistence? boundsPersistence;

  @override
  State<_FloatingWindow> createState() => _FloatingWindowState();
}

class _FloatingWindowState extends State<_FloatingWindow> {
  Rect? _bounds;
  Size _viewport = Size.zero;

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
                        onMove: _move,
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
