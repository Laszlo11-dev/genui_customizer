import 'dart:convert';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

/// Stores the floating Studio's position and size in logical pixels.
abstract interface class StudioBoundsPersistence {
  Future<Rect?> load();
  Future<void> save(Rect bounds);
}

/// The default, app-local Studio bounds persistence.
final class SharedPreferencesStudioBoundsPersistence
    implements StudioBoundsPersistence {
  const SharedPreferencesStudioBoundsPersistence();

  static const _key = 'genui_customizer.studio.bounds.v1';

  @override
  Future<Rect?> load() async {
    final raw = await SharedPreferencesAsync().getString(_key);
    if (raw == null) return null;
    final value = jsonDecode(raw);
    if (value is! Map) return null;
    final left = value['left'];
    final top = value['top'];
    final width = value['width'];
    final height = value['height'];
    if (left is! num ||
        top is! num ||
        width is! num ||
        height is! num ||
        !left.isFinite ||
        !top.isFinite ||
        !width.isFinite ||
        !height.isFinite ||
        width <= 0 ||
        height <= 0) {
      return null;
    }
    return Rect.fromLTWH(
      left.toDouble(),
      top.toDouble(),
      width.toDouble(),
      height.toDouble(),
    );
  }

  @override
  Future<void> save(Rect bounds) => SharedPreferencesAsync().setString(
    _key,
    jsonEncode({
      'left': bounds.left,
      'top': bounds.top,
      'width': bounds.width,
      'height': bounds.height,
    }),
  );
}
