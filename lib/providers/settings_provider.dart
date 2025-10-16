import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Handles user-facing application preferences and persistence.
class SettingsProvider extends ChangeNotifier {
  static const _prefsKey = 'settings_v1';

  /// Supported measurement systems users can switch between.
  static const Set<String> _allowedUnitSystems = {'metric', 'imperial'};
  bool _darkMode = false;
  bool _notifications = true;
  String _units = 'metric';
  bool _loaded = false;
  String? _appVersion;

  /// Indicates whether the dark theme is enabled.
  bool get darkMode => _darkMode;

  /// Whether push/notification toggles are enabled.
  bool get notifications => _notifications;

  /// Preferred measurement system (`metric` / `imperial`).
  String get units => _units;
  bool get isLoaded => _loaded;
  String? get appVersion => _appVersion;

  /// Loads settings from SharedPreferences and device metadata.
  Future<void> load() async {
    if (_loaded) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        final map = json.decode(raw) as Map<String, dynamic>;
        _darkMode = map['darkMode'] ?? _darkMode;
        _notifications = map['notifications'] ?? _notifications;
        _units = map['units'] ?? _units;
      } catch (_) {}
    }
    try {
      final pi = await PackageInfo.fromPlatform();
      _appVersion = '${pi.version}+${pi.buildNumber}';
    } catch (_) {
      _appVersion = null;
    }
    _loaded = true;
    notifyListeners();
  }

  /// Persists the current settings snapshot to disk.
  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      json.encode({
        'darkMode': _darkMode,
        'notifications': _notifications,
        'units': _units,
      }),
    );
  }

  /// Updates the dark mode toggle and persists the change.
  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    notifyListeners();
    await _persist();
  }

  /// Updates notification preference and persists the change.
  Future<void> setNotifications(bool value) async {
    _notifications = value;
    notifyListeners();
    await _persist();
  }

  /// Sets the preferred unit system, validating it against supported values.
  Future<void> setUnits(String value) async {
    final normalized = value.trim().toLowerCase();
    if (!_allowedUnitSystems.contains(normalized)) {
      throw ArgumentError.value(
        value,
        'value',
        'Units must be one of $_allowedUnitSystems',
      );
    }
    _units = normalized;
    notifyListeners();
    await _persist();
  }
}
