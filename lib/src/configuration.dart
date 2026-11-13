import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'touch.dart';

/// A saved appearance plus the host's complete, JSON-serializable occasion data.
/// The host owns the meaning and validation of [data].
final class TouchConfiguration {
  TouchConfiguration({
    required this.id,
    required this.name,
    required this.profile,
    this.data = const {},
    this.userId,
    this.scope = 'tree',
    this.preset = false,
    this.active = true,
  }) {
    if (id.isEmpty || name.isEmpty || scope.isEmpty) {
      throw ArgumentError('Configuration id, name and scope must be nonempty.');
    }
    // Reject nonportable values before persistence or a host callback sees them.
    jsonEncode(data);
  }

  final String id;
  final String name;
  final String? userId;
  String get type => userId == null ? 'remote' : 'local';
  final String scope;
  final bool preset;
  final bool active;
  final TouchProfile profile;
  final Map<String, Object?> data;

  TouchConfiguration copyWith({
    TouchProfile? profile,
    Map<String, Object?>? data,
    bool? active,
  }) => TouchConfiguration(
    id: id,
    name: name,
    userId: userId,
    scope: scope,
    preset: preset,
    active: active ?? this.active,
    profile: profile ?? this.profile,
    data: data ?? this.data,
  );

  Map<String, Object?> toJson() => {
    'formatVersion': 1,
    'id': id,
    'name': name,
    'userId': userId,
    'type': type,
    'scope': scope,
    'preset': preset,
    'active': active,
    'profile': profile.toJson(),
    'data': data,
  };

  factory TouchConfiguration.fromJson(Map<String, Object?> json) {
    if (json['formatVersion'] != 1 ||
        json['id'] is! String ||
        json['name'] is! String ||
        json['profile'] is! Map ||
        json['data'] is! Map) {
      throw const FormatException('Invalid Touch configuration.');
    }
    final userId = json['userId'];
    if (userId != null && userId is! String ||
        json['type'] != (userId == null ? 'remote' : 'local')) {
      throw const FormatException('Invalid Touch configuration type.');
    }
    return TouchConfiguration(
      id: json['id'] as String,
      name: json['name'] as String,
      userId: userId as String?,
      scope: json['scope'] as String? ?? 'tree',
      preset: json['preset'] == true,
      active: json['active'] != false,
      profile: TouchProfile.fromJson(
        (json['profile'] as Map).cast<String, Object?>(),
      ),
      data: (json['data'] as Map).cast<String, Object?>(),
    );
  }
}

/// Remote and local stores can be supplied independently by the host.
abstract interface class TouchConfigurationStore {
  Future<List<TouchConfiguration>> list();
  Future<TouchConfiguration?> load(String id);
  Future<void> save(TouchConfiguration configuration);
  Future<void> delete(String id);
}

/// Local operations always carry a user id, even with a host implementation.
abstract interface class TouchLocalConfigurationStore {
  Future<List<TouchConfiguration>> list(String userId);
  Future<TouchConfiguration?> load(String userId, String id);
  Future<void> save(String userId, TouchConfiguration configuration);
  Future<void> delete(String userId, String id);
}

/// Default persistence for remote configurations on this app installation.
final class SharedPreferencesTouchRemoteStore
    implements TouchConfigurationStore {
  const SharedPreferencesTouchRemoteStore();
  static const _prefix = 'genui_touch.remote.v1.';

  @override
  Future<List<TouchConfiguration>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getKeys().where((key) => key.startsWith(_prefix)).toList()
      ..sort();
    return [
      for (final key in ids)
        TouchConfiguration.fromJson(
          (jsonDecode(prefs.getString(key)!) as Map).cast<String, Object?>(),
        ),
    ];
  }

  @override
  Future<TouchConfiguration?> load(String id) async {
    final raw = (await SharedPreferences.getInstance()).getString(
      '$_prefix$id',
    );
    return raw == null
        ? null
        : TouchConfiguration.fromJson(
            (jsonDecode(raw) as Map).cast<String, Object?>(),
          );
  }

  @override
  Future<void> save(TouchConfiguration configuration) async {
    if (configuration.userId != null) {
      throw ArgumentError('Remote configuration must not have a user id.');
    }
    final ok = await (await SharedPreferences.getInstance()).setString(
      '$_prefix${configuration.id}',
      jsonEncode(configuration.toJson()),
    );
    if (!ok) throw StateError('Could not save remote configuration.');
  }

  @override
  Future<void> delete(String id) async {
    await (await SharedPreferences.getInstance()).remove('$_prefix$id');
  }
}

/// Default persistence for user preferences on this app installation.
final class SharedPreferencesTouchLocalStore
    implements TouchLocalConfigurationStore {
  const SharedPreferencesTouchLocalStore();
  static const _prefix = 'genui_touch.local.v1.';
  String _key(String userId, String id) =>
      '$_prefix${Uri.encodeComponent(userId)}.${Uri.encodeComponent(id)}';

  @override
  Future<List<TouchConfiguration>> list(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = '$_prefix${Uri.encodeComponent(userId)}.';
    final keys = prefs.getKeys().where((key) => key.startsWith(prefix)).toList()
      ..sort();
    return [
      for (final key in keys)
        TouchConfiguration.fromJson(
          (jsonDecode(prefs.getString(key)!) as Map).cast<String, Object?>(),
        ),
    ];
  }

  @override
  Future<TouchConfiguration?> load(String userId, String id) async {
    final raw = (await SharedPreferences.getInstance()).getString(
      _key(userId, id),
    );
    return raw == null
        ? null
        : TouchConfiguration.fromJson(
            (jsonDecode(raw) as Map).cast<String, Object?>(),
          );
  }

  @override
  Future<void> save(String userId, TouchConfiguration configuration) async {
    if (configuration.userId != userId) {
      throw ArgumentError('Local configuration belongs to another user.');
    }
    final ok = await (await SharedPreferences.getInstance()).setString(
      _key(userId, configuration.id),
      jsonEncode(configuration.toJson()),
    );
    if (!ok) throw StateError('Could not save local configuration.');
  }

  @override
  Future<void> delete(String userId, String id) async {
    await (await SharedPreferences.getInstance()).remove(_key(userId, id));
  }
}
