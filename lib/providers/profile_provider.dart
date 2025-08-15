import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileProvider extends ChangeNotifier {
  static const _prefsKey = 'profile_v1';
  String _name = 'Calum Taylor';
  String _bio = 'Home cook & flavour explorer';
  int _avatarColor = Colors.tealAccent.toARGB32();
  bool _loaded = false;

  String get name => _name;
  String get bio => _bio;
  Color get avatarColor => Color(_avatarColor);
  bool get isLoaded => _loaded;

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
      } catch (_) {}
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> update({String? name, String? bio, Color? avatarColor}) async {
    if (name != null) _name = name.trim().isEmpty ? _name : name.trim();
    if (bio != null) _bio = bio;
    if (avatarColor != null) _avatarColor = avatarColor.toARGB32();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, json.encode({
      'name': _name,
      'bio': _bio,
      'avatarColor': _avatarColor,
    }));
  }
}