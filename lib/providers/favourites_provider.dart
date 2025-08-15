import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavouriteRecipe {
  final int id;
  final String title;
  final String? image;
  final int? readyInMinutes;

  FavouriteRecipe({required this.id, required this.title, this.image, this.readyInMinutes});

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'image': image,
    'readyInMinutes': readyInMinutes,
  };

  factory FavouriteRecipe.fromMap(Map<String, dynamic> map) => FavouriteRecipe(
    id: map['id'],
    title: map['title'],
    image: map['image'],
    readyInMinutes: map['readyInMinutes'],
  );
}

class FavouritesProvider extends ChangeNotifier {
  static const _prefsKey = 'favourites_v1';
  final Map<int, FavouriteRecipe> _favourites = {};
  bool _loaded = false;

  List<FavouriteRecipe> get favourites => _favourites.values.toList()
    ..sort((a,b)=>a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  bool get isLoaded => _loaded;
  bool isFavourite(int id) => _favourites.containsKey(id);

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefsKey);
    if (jsonString != null) {
      try {
        final List list = json.decode(jsonString);
        for (final item in list) {
          final map = Map<String, dynamic>.from(item as Map);
            _favourites[map['id']] = FavouriteRecipe.fromMap(map);
        }
      } catch (_) {/* ignore */}
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, json.encode(_favourites.values.map((e)=>e.toMap()).toList()));
  }

  Future<void> toggle(FavouriteRecipe recipe) async {
    if (isFavourite(recipe.id)) {
      _favourites.remove(recipe.id);
    } else {
      _favourites[recipe.id] = recipe;
    }
    notifyListeners();
    await _persist();
  }

  Future<void> remove(int id) async {
    _favourites.remove(id);
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    _favourites.clear();
    notifyListeners();
    await _persist();
  }
}