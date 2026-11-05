import 'dart:convert';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the Restaurant Finder Studio window in logical screen coordinates.
final class RestaurantStudioBoundsStore {
  RestaurantStudioBoundsStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _key = 'restaurant_finder.studio.bounds.v1';
  static const _splitKey = 'restaurant_finder.studio.split.v1';

  final SharedPreferencesAsync _preferences;
  Future<void> _pending = Future<void>.value();
  Rect? _bounds;
  double? _splitFraction;

  Rect? get bounds => _bounds;
  double? get splitFraction => _splitFraction;

  Future<void> load() async {
    await _pending;
    try {
      final split = await _preferences.getDouble(_splitKey);
      if (split != null && split.isFinite && split > 0 && split < 1) {
        _splitFraction = split;
      }
    } on Object {
      // Storage may be unavailable without disabling the editor.
    }
    try {
      final raw = await _preferences.getString(_key);
      if (raw == null) return;
      final value = jsonDecode(raw);
      if (value is! Map) return;
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
        return;
      }
      _bounds = Rect.fromLTWH(
        left.toDouble(),
        top.toDouble(),
        width.toDouble(),
        height.toDouble(),
      );
    } on Object {
      // Storage may be unavailable without disabling the editor.
    }
  }

  void save(Rect bounds) {
    _bounds = bounds;
    final encoded = jsonEncode({
      'left': bounds.left,
      'top': bounds.top,
      'width': bounds.width,
      'height': bounds.height,
    });
    _pending = _pending.then((_) async {
      try {
        await _preferences.setString(_key, encoded);
      } on Object {
        // Keep the in-memory bounds for this app session.
      }
    });
  }

  void saveSplitFraction(double fraction) {
    if (!fraction.isFinite || fraction <= 0 || fraction >= 1) return;
    _splitFraction = fraction;
    _pending = _pending.then((_) async {
      try {
        await _preferences.setDouble(_splitKey, fraction);
      } on Object {
        // Keep the in-memory split for this app session.
      }
    });
  }

  Future<void> flush() => _pending;
}
