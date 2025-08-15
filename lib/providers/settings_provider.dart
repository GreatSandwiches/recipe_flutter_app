import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsProvider extends ChangeNotifier {
  static const _prefsKey = 'settings_v1';
  bool _darkMode = false;
  bool _notifications = true;
  String _units = 'metric';
  bool _loaded = false;
  String? _appVersion;

  bool get darkMode => _darkMode;
  bool get notifications => _notifications;
  String get units => _units;
  bool get isLoaded => _loaded;
  String? get appVersion => _appVersion;

  Future<void> load() async {
    if (_loaded) return;
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

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, json.encode({
      'darkMode': _darkMode,
      'notifications': _notifications,
      'units': _units,
    }));
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setNotifications(bool value) async {
    _notifications = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setUnits(String value) async {
    _units = value;
    notifyListeners();
    await _persist();
  }
}