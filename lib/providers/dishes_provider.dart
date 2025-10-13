import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Model representing a dish (recipe) the user has marked as made.
class MadeDish {
  final int recipeId;
  final String title;
  final String? image;
  final DateTime madeAt;

  MadeDish({
    required this.recipeId,
    required this.title,
    this.image,
    required this.madeAt,
  });

  MadeDish copyWith({
    String? title,
    String? image,
    DateTime? madeAt,
  }) => MadeDish(
    recipeId: recipeId,
    title: title ?? this.title,
    image: image ?? this.image,
    madeAt: madeAt ?? this.madeAt,
  );

  Map<String, dynamic> toMap() => {
    'recipeId': recipeId,
    'title': title,
    'image': image,
    'madeAt': madeAt.toIso8601String(),
  };

  factory MadeDish.fromMap(Map<String, dynamic> map) => MadeDish(
    recipeId: map['recipeId'] as int,
    title: map['title'] as String,
    image: map['image'] as String?,
    madeAt: DateTime.tryParse(map['madeAt'] as String? ?? '') ?? DateTime.now(),
  );
}

/// Provider handling local persistence + Supabase sync of dishes a user has made.
///
/// Local persistence (per-user) allows offline viewing and optimistic updates.
/// Remote table schema expectation (suggested):
///   Table: dishes_made
///     id (uuid) PK default uuid_generate_v4()
///     user_id uuid references auth.users not null
///     recipe_id int not null
///     title text not null
///     image text null
///     made_at timestamptz not null default now()
///   Unique constraint: user_id, recipe_id keeps only the latest entry per recipe.
class DishesProvider extends ChangeNotifier {
  static const _baseKey = 'dishes_made_v1';
  String? _currentUserId; // null for anon
  bool _loaded = false;
  bool _syncing = false;
  String? _lastError;
  final List<MadeDish> _dishes = [];

  List<MadeDish> get dishes {
    final sorted = [..._dishes]..sort((a, b) => b.madeAt.compareTo(a.madeAt));
    return List.unmodifiable(sorted);
  }

  int get totalCount => _dishes.length;
  bool get isLoaded => _loaded;
  bool get syncing => _syncing;
  String? get lastError => _lastError;

  String _storageKey(String? userId) => '${_baseKey}_${userId ?? 'anon'}';

  bool _isDishDataValid({required int recipeId, required String title}) {
    if (recipeId <= 0) {
      _lastError = 'Recipe id must be positive.';
      notifyListeners();
      return false;
    }
    if (title.trim().isEmpty) {
      _lastError = 'Recipe title is required.';
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<void> load() async {
    if (_loaded) return;
    await _loadFor(_currentUserId);
  }

  Future<void> switchUser(String? userId) async {
    if (_currentUserId == userId) return;
    if (_loaded) {
      await _persist();
    }
    _currentUserId = userId;
    _loaded = false;
    _dishes.clear();
    await _loadFor(userId);
    if (_currentUserId != null) {
      unawaited(_pullRemoteMerge());
    }
  }

  Future<void> markMade({
    required int recipeId,
    required String title,
    String? image,
  }) async {
    if (!_isDishDataValid(recipeId: recipeId, title: title)) {
      return;
    }
    final existingIndex = _dishes.indexWhere((d) => d.recipeId == recipeId);
    // For now, only one record per recipe. If want multiples, remove this block.
    if (existingIndex != -1) {
      // move to top / update timestamp
      final existing = _dishes[existingIndex];
      _dishes[existingIndex] = existing.copyWith(
        title: title,
        image: image,
        madeAt: DateTime.now(),
      );
    } else {
      _dishes.add(
        MadeDish(
          recipeId: recipeId,
          title: title,
          image: image,
          madeAt: DateTime.now(),
        ),
      );
    }
    notifyListeners();
    await _persist();
    _lastError = null;
    if (_currentUserId != null) {
      unawaited(_pushRemoteSingle(recipeId));
    }
  }

  bool isMade(int recipeId) => _dishes.any((d) => d.recipeId == recipeId);

  Future<void> remove(int recipeId) async {
    _dishes.removeWhere((d) => d.recipeId == recipeId);
    notifyListeners();
    await _persist();
    _lastError = null;
    if (_currentUserId != null) {
      unawaited(_deleteRemote(recipeId));
    }
  }

  Future<void> clearLocal() async {
    _dishes.clear();
    notifyListeners();
    await _persist();
    _lastError = null;
  }

  Future<void> _loadFor(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _storageKey(userId);
    String? jsonStr = prefs.getString(key);
    if (jsonStr == null && userId == null) {
      jsonStr = prefs.getString(_baseKey);
    }
    if (jsonStr != null) {
      try {
        final list = json.decode(jsonStr) as List;
        for (final raw in list) {
          _dishes.add(MadeDish.fromMap(Map<String, dynamic>.from(raw as Map)));
        }
      } catch (e) { if (kDebugMode) { print('Dishes load parse error: $e'); } }
    }
    _loaded = true;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    if (!_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey(_currentUserId), json.encode(_dishes.map((d)=>d.toMap()).toList()));
  }

  SupabaseClient? get _client {
    try { return Supabase.instance.client; } catch (_) { return null; }
  }

  Future<void> _pullRemoteMerge() async {
    final client = _client; if (client == null || _currentUserId == null) { return; }
    _syncing = true; _lastError = null; notifyListeners();
    try {
      final rows = await client.from('dishes_made')
        .select('recipe_id,title,image,made_at')
        .eq('user_id', _currentUserId!)
        .order('made_at', ascending: false);
      bool changed = false;
      for (final r in rows) {
        final rid = r['recipe_id'] as int;
        final remoteMadeAt = DateTime.tryParse(r['made_at'] as String? ?? '') ?? DateTime.now();
        final idx = _dishes.indexWhere((d) => d.recipeId == rid);
        if (idx == -1) {
          _dishes.add(MadeDish(
            recipeId: rid,
            title: (r['title'] ?? '') as String,
            image: r['image'] as String?,
            madeAt: remoteMadeAt,
          ));
          changed = true;
        } else {
          final existing = _dishes[idx];
          final updated = existing.copyWith(
            title: (r['title'] ?? existing.title) as String,
            image: r['image'] as String? ?? existing.image,
            madeAt: remoteMadeAt.isAfter(existing.madeAt) ? remoteMadeAt : existing.madeAt,
          );
          if (updated.madeAt != existing.madeAt ||
              updated.title != existing.title ||
              updated.image != existing.image) {
            _dishes[idx] = updated;
            changed = true;
          }
        }
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
    } finally { _syncing = false; notifyListeners(); }
  }

  Map<String, dynamic> _remotePayload(MadeDish dish) => {
    'user_id': _currentUserId,
    'recipe_id': dish.recipeId,
    'title': dish.title,
    'image': dish.image,
    'made_at': dish.madeAt.toIso8601String(),
  };

  Future<void> _pushRemoteSingle(int recipeId) async {
    final client = _client; if (client == null || _currentUserId == null) return;
    final dishIndex = _dishes.indexWhere((d) => d.recipeId == recipeId);
    if (dishIndex == -1) {
      return;
    }
    final dish = _dishes[dishIndex];
    try {
      await client.from('dishes_made').upsert(_remotePayload(dish));
    } catch (e) { if (kDebugMode) { print('Push remote single error: $e'); } }
  }

  Future<void> _deleteRemote(int recipeId) async {
    final client = _client; if (client == null || _currentUserId == null) return;
    try { await client.from('dishes_made').delete().match({'user_id': _currentUserId, 'recipe_id': recipeId}); } catch (_) {}
  }

  Future<void> _pushAllRemote() async {
    final client = _client; if (client == null || _currentUserId == null) return;
    if (_dishes.isEmpty) return;
    try {
      await client.from('dishes_made').upsert(_dishes.map(_remotePayload).toList());
    } catch (e) {
      if (kDebugMode) {
        print('Push remote bulk error: $e');
      }
    }
  }

  MadeDish? dishById(int recipeId) {
    try {
      return _dishes.firstWhere((d) => d.recipeId == recipeId);
    } catch (_) {
      return null;
    }
  }
}
