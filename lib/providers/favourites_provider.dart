import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  static const _remoteTable = 'favourite_recipes';
  final Map<int, FavouriteRecipe> _favourites = {};
  bool _loaded = false;
  String? _currentUserId;
  bool _syncing = false;
  String? _lastError;

  List<FavouriteRecipe> get favourites => _favourites.values.toList()
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  bool get isLoaded => _loaded;
  bool get syncing => _syncing;
  String? get lastError => _lastError;
  String? get currentUserId => _currentUserId;
  bool isFavourite(int id) => _favourites.containsKey(id);

  bool _isValidFavourite(FavouriteRecipe recipe) {
    if (recipe.id <= 0) {
      _lastError = 'Favourite id must be positive.';
      notifyListeners();
      return false;
    }
    if (recipe.title.trim().isEmpty) {
      _lastError = 'Favourite title is required.';
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<void> load() async {
    if (_loaded) return;
    await _loadFor(userId: _currentUserId);
  }

  String _storageKey(String? userId) => '${_prefsKey}_${userId ?? 'anon'}';

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadFor({required String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _storageKey(userId);
    final jsonString = prefs.getString(key) ?? (userId == null ? prefs.getString(_prefsKey) : null);
    _favourites.clear();
    if (jsonString != null) {
      try {
        final List list = json.decode(jsonString);
        for (final item in list) {
          final map = Map<String, dynamic>.from(item as Map);
          final fav = FavouriteRecipe.fromMap(map);
          _favourites[fav.id] = fav;
        }
      } catch (e) {
        if (kDebugMode) {
          print('Favourites load parse error: $e');
        }
      }
    }
    _loaded = true;
    await _persist();
    notifyListeners();
  }

  Future<void> switchUser(String? userId) async {
    if (_currentUserId == userId) return;
    if (_loaded) {
      await _persist();
    }
    _currentUserId = userId;
    _loaded = false;
    _favourites.clear();
    await _loadFor(userId: userId);
    if (_currentUserId != null) {
      unawaited(_pullRemoteMerge());
    }
  }

  Future<void> _persist() async {
    if (!_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey(_currentUserId), json.encode(_favourites.values.map((e)=>e.toMap()).toList()));
  }

  Map<String, dynamic> _mapForRemote(FavouriteRecipe fav) => {
    'user_id': _currentUserId,
    'recipe_id': fav.id,
    'title': fav.title,
    'image': fav.image,
    'ready_in_minutes': fav.readyInMinutes,
  };

  Future<void> _pullRemoteMerge() async {
    final client = _client;
    final userId = _currentUserId;
    if (client == null || userId == null) {
      return;
    }
    _syncing = true;
    _lastError = null;
    notifyListeners();
    try {
      final rows = await client
          .from(_remoteTable)
          .select('recipe_id,title,image,ready_in_minutes')
          .eq('user_id', userId);
      bool changed = false;
      for (final row in rows) {
        final id = row['recipe_id'] as int;
        if (_favourites.containsKey(id)) continue;
        final ready = row['ready_in_minutes'];
        final fav = FavouriteRecipe(
          id: id,
          title: (row['title'] ?? '') as String,
          image: row['image'] as String?,
          readyInMinutes: ready is int
              ? ready
              : (ready is num ? ready.toInt() : null),
        );
        _favourites[id] = fav;
        changed = true;
      }
      if (changed) {
        await _persist();
        notifyListeners();
      }
      await _pushAllRemote();
    } on PostgrestException catch (e) {
      _lastError = e.message;
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> _pushRemote(FavouriteRecipe fav) async {
    final client = _client;
    final userId = _currentUserId;
    if (client == null || userId == null) return;
    try {
      await client.from(_remoteTable).upsert(_mapForRemote(fav));
    } catch (e) {
      if (kDebugMode) {
        print('Favourites remote upsert error: $e');
      }
    }
  }

  Future<void> _deleteRemote(int recipeId) async {
    final client = _client;
    final userId = _currentUserId;
    if (client == null || userId == null) return;
    try {
      await client.from(_remoteTable).delete().match({
        'user_id': userId,
        'recipe_id': recipeId,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Favourites remote delete error: $e');
      }
    }
  }

  Future<void> _clearRemote() async {
    final client = _client;
    final userId = _currentUserId;
    if (client == null || userId == null) return;
    try {
      await client.from(_remoteTable).delete().eq('user_id', userId);
    } catch (e) {
      if (kDebugMode) {
        print('Favourites remote clear error: $e');
      }
    }
  }

  Future<void> _pushAllRemote() async {
    final client = _client;
    final userId = _currentUserId;
    if (client == null || userId == null) return;
    if (_favourites.isEmpty) return;
    try {
      await client
          .from(_remoteTable)
          .upsert(_favourites.values.map(_mapForRemote).toList());
    } catch (e) {
      if (kDebugMode) {
        print('Favourites remote bulk upsert error: $e');
      }
    }
  }

  Future<void> toggle(FavouriteRecipe recipe) async {
    if (!isFavourite(recipe.id) && !_isValidFavourite(recipe)) {
      return;
    }
    if (isFavourite(recipe.id)) {
      _favourites.remove(recipe.id);
      notifyListeners();
      await _persist();
      await _deleteRemote(recipe.id);
      _lastError = null;
    } else {
      _favourites[recipe.id] = recipe;
      notifyListeners();
      await _persist();
      _lastError = null;
      unawaited(_pushRemote(recipe));
    }
  }

  Future<void> remove(int id) async {
    _favourites.remove(id);
    notifyListeners();
    await _persist();
    await _deleteRemote(id);
    _lastError = null;
  }

  Future<void> clear() async {
    _favourites.clear();
    notifyListeners();
    await _persist();
    await _clearRemote();
    _lastError = null;
  }
}
