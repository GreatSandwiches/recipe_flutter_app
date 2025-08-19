import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileProvider extends ChangeNotifier {
  static const _prefsKey = 'profile_v1';
  String _name = '';
  String _bio = '';
  int _avatarColor = Colors.tealAccent.toARGB32();
  bool _loaded = false;
  bool _completed = false; // new flag

  String get name => _name;
  String get bio => _bio;
  Color get avatarColor => Color(_avatarColor);
  bool get isLoaded => _loaded;
  bool get isCompleted => _completed;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefsKey);
    if (jsonString != null) {
      try {
        final map = json.decode(jsonString) as Map<String, dynamic>;
        _name = map['name'] ?? _name;
        _bio = map['bio'] ?? _bio;
        _avatarColor = map['avatarColor'] ?? _avatarColor;
        _completed = map['completed'] ?? false;
      } catch (_) {}
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> update({String? name, String? bio, Color? avatarColor, bool? completed}) async {
    if (name != null) _name = name.trim().isEmpty ? _name : name.trim();
    if (bio != null) _bio = bio;
    if (avatarColor != null) _avatarColor = avatarColor.toARGB32();
    if (completed != null) _completed = completed;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, json.encode({
      'name': _name,
      'bio': _bio,
      'avatarColor': _avatarColor,
      'completed': _completed,
    }));
  }
  
  Future<void> completeSetup({required String name, String bio = '', required Color avatarColor}) async {
    _name = name.trim();
    _bio = bio;
    _avatarColor = avatarColor.toARGB32();
    _completed = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, json.encode({
      'name': _name,
      'bio': _bio,
      'avatarColor': _avatarColor,
      'completed': _completed,
    }));
  }
}