import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileProvider extends ChangeNotifier {
  static const _baseKey = 'profile_v1';
  String? _currentUserId; // null for anon
  String _name = '';
  String _bio = '';
  int _avatarColor = Colors.tealAccent.toARGB32();
  bool _loaded = false;
  bool _completed = false;

  String get name => _name;
  String get bio => _bio;
  Color get avatarColor => Color(_avatarColor);
  bool get isLoaded => _loaded;
  bool get isCompleted => _completed;
  String? get userId => _currentUserId;

  String _storageKey(String? userId) => '${_baseKey}_${userId ?? 'anon'}';

  Future<void> load() async { // initial load for anon (pre-auth)
    if (_loaded) return;
    await _loadFor(userId: _currentUserId);
  }

  Future<void> switchUser(String? userId) async {
    if (_currentUserId == userId) return; // no change
    // Persist current user profile before switching
    if (_loaded) {
      await _persist();
    }
    _currentUserId = userId;
    await _loadFor(userId: userId);
  }

  Future<void> _loadFor({required String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _storageKey(userId);
    final jsonString = prefs.getString(key);
    if (jsonString != null) {
      try {
        final map = json.decode(jsonString) as Map<String, dynamic>;
        _name = (map['name'] ?? '') as String;
        _bio = (map['bio'] ?? '') as String;
        _avatarColor = (map['avatarColor'] ?? _avatarColor) as int;
        _completed = (map['completed'] ?? false) as bool;
      } catch (_) {
        _resetToDefaults();
      }
    } else {
      _resetToDefaults();
    }
    _loaded = true;
    notifyListeners();
  }

  void _resetToDefaults() {
    _name = '';
    _bio = '';
    _avatarColor = Colors.tealAccent.toARGB32();
    _completed = false;
  }

  Future<void> _persist() async {
    if (!_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey(_currentUserId), json.encode({
      'name': _name,
      'bio': _bio,
      'avatarColor': _avatarColor,
      'completed': _completed,
    }));
  }

  Future<void> update({String? name, String? bio, Color? avatarColor, bool? completed}) async {
    if (name != null && name.trim().isNotEmpty) _name = name.trim();
    if (bio != null) _bio = bio;
    if (avatarColor != null) _avatarColor = avatarColor.toARGB32();
    if (completed != null) _completed = completed;
    notifyListeners();
    await _persist();
  }
  
  Future<void> completeSetup({required String name, String bio = '', required Color avatarColor}) async {
    _name = name.trim();
    _bio = bio;
    _avatarColor = avatarColor.toARGB32();
    _completed = true;
    notifyListeners();
    await _persist();
  }
}