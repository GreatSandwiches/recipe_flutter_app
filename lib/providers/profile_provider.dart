import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileProvider extends ChangeNotifier {
  static const _baseKey = 'profile_v1';
  static const Color _defaultAvatarColor = Colors.tealAccent;
  String? _currentUserId; // null for anon
  String _name = '';
  String _bio = '';
  int _avatarColor = _encodeColor(_defaultAvatarColor);
  bool _loaded = false;
  bool _completed = false;
  bool _remoteSyncing = false;
  String? _lastRemoteError;

  String get name => _name;
  String get bio => _bio;
  Color get avatarColor => Color(_avatarColor);
  bool get isLoaded => _loaded;
  bool get isCompleted => _completed;
  String? get userId => _currentUserId;
  bool get remoteSyncing => _remoteSyncing;
  String? get lastRemoteError => _lastRemoteError;

  String _storageKey(String? userId) => '${_baseKey}_${userId ?? 'anon'}';

  static int _encodeColor(Color color) {
    return (color.alpha << 24) |
        (color.red << 16) |
        (color.green << 8) |
        color.blue;
  }

  Future<void> load() async {
    // initial load for anon (pre-auth)
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
    _loaded = false;
    await _loadFor(userId: userId);
    // Attempt remote sync for authenticated users
    if (userId != null) {
      unawaited(ensureRemoteRow());
    }
  }

  int _color24() => _avatarColor & 0x00FFFFFF; // strip alpha so it fits in int4

  Future<void> ensureRemoteRow() async {
    if (_currentUserId == null) return;
    final client = _supabaseClient;
    if (client == null) return;
    debugPrint('ENSURE REMOTE ROW: Starting for user $_currentUserId');
    try {
      final existing = await client
          .from('profiles')
          .select('id')
          .eq('id', _currentUserId!)
          .maybeSingle();
      debugPrint('ENSURE REMOTE ROW: Existing row check result: $existing');
      if (existing == null) {
        debugPrint('ENSURE REMOTE ROW: No existing row, inserting...');
        await client.from('profiles').insert({
          'id': _currentUserId,
          'name': _name,
          'bio': _bio,
          'avatar_color': _color24(),
          'completed': _completed,
        });
        debugPrint('ENSURE REMOTE ROW: Insert completed');
        // Skip immediate fetch after insert to avoid overwriting newer local state with defaults
      } else {
        debugPrint('ENSURE REMOTE ROW: Row already exists');
        // Fetch full row (merge) only when a prior row exists
        unawaited(_fetchRemoteAndMerge(_currentUserId!));
      }
    } catch (e) {
      debugPrint('ENSURE REMOTE ROW ERROR: $e');
    }
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
        final colorValue = map['avatarColor'];
        if (colorValue is int) {
          _avatarColor = colorValue; // stored locally as full 32-bit
        } else {
          _avatarColor = _encodeColor(_defaultAvatarColor);
        }
        _completed = (map['completed'] ?? false) as bool;
      } catch (_) {
        _resetDefaults();
      }
    } else {
      _resetDefaults();
    }
    _loaded = true;
    notifyListeners();
  }

  void _resetDefaults() {
    _name = '';
    _bio = '';
    _avatarColor = _encodeColor(_defaultAvatarColor);
    _completed = false;
  }

  Future<void> _persist() async {
    if (!_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey(_currentUserId),
      json.encode({
        'name': _name,
        'bio': _bio,
        'avatarColor': _avatarColor, // store raw 32-bit value locally
        'completed': _completed,
      }),
    );
  }

  Future<void> update({
    String? name,
    String? bio,
    Color? avatarColor,
    bool? completed,
  }) async {
    if (name != null && name.trim().isNotEmpty) _name = name.trim();
    if (bio != null) _bio = bio;
    if (avatarColor != null) _avatarColor = _encodeColor(avatarColor);
    if (completed != null) _completed = completed;
    notifyListeners();
    await _persist();
    if (_currentUserId != null) {
      unawaited(_pushRemote());
    }
  }

  Future<void> completeSetup({
    required String name,
    String bio = '',
    required Color avatarColor,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.length < 2) {
      throw ArgumentError.value(
        name,
        'name',
        'Display name must be at least 2 characters.',
      );
    }
    _name = trimmedName;
    _bio = bio;
    _avatarColor = _encodeColor(avatarColor);
    _completed = true;
    notifyListeners();
    await _persist();
    if (_currentUserId != null) {
      // Try to push to remote, but don't hang the UI indefinitely.
      _remoteSyncing = true;
      _lastRemoteError = null;
      notifyListeners();
      try {
        await _pushRemote().timeout(const Duration(seconds: 8));
      } on TimeoutException {
        _lastRemoteError =
            'Timed out syncing profile to server. Will retry in background.';
      } catch (e) {
        _lastRemoteError = e.toString();
      } finally {
        _remoteSyncing = false;
        notifyListeners();
      }
    }
  }

  SupabaseClient? get _supabaseClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchRemoteAndMerge(String userId) async {
    final client = _supabaseClient;
    if (client == null) return;
    _remoteSyncing = true;
    _lastRemoteError = null;
    notifyListeners();
    try {
      final resp = await client
          .from('profiles')
          .select('name,bio,avatar_color,completed')
          .eq('id', userId)
          .maybeSingle();
      if (resp == null) return;
      bool changed = false;
      final remoteName = (resp['name'] ?? '') as String;
      final remoteBio = (resp['bio'] ?? '') as String;
      final remoteColor = resp['avatar_color'];
      final remoteCompleted = (resp['completed'] ?? false) as bool;
      // Prefer non-empty values and avoid overwriting local with empty remote
      if (remoteName.trim().isNotEmpty && remoteName != _name) {
        _name = remoteName;
        changed = true;
      }
      if (remoteBio != _bio &&
          (remoteBio.trim().isNotEmpty || _bio.trim().isEmpty)) {
        _bio = remoteBio;
        changed = true;
      }
      if (remoteColor is int) {
        final reconstructed = 0xFF000000 | (remoteColor & 0x00FFFFFF);
        if (reconstructed != _avatarColor) {
          _avatarColor = reconstructed;
          changed = true;
        }
      }
      // Never downgrade completion from true to false (avoid race with initial insert)
      if (remoteCompleted && !_completed) {
        _completed = true;
        changed = true;
      }
      if (changed) {
        await _persist();
        notifyListeners();
      }
    } on PostgrestException catch (e) {
      _lastRemoteError = e.message;
      debugPrint('Fetch merge error: ${e.message}');
    } catch (e) {
      _lastRemoteError = e.toString();
      debugPrint('Fetch merge error: $e');
    } finally {
      _remoteSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _pushRemote() async {
    final client = _supabaseClient;
    if (client == null || _currentUserId == null) return;
    debugPrint(
      'PUSH REMOTE: Starting for user $_currentUserId, client available',
    );
    try {
      final data = {
        'id': _currentUserId,
        'name': _name,
        'bio': _bio,
        'avatar_color': _color24(),
        'completed': _completed,
      };
      debugPrint('PUSH REMOTE: Upserting data: $data');
      final result = await client.from('profiles').upsert(data).select();
      debugPrint('PUSH REMOTE: Success, result: $result');
    } on PostgrestException catch (e) {
      _lastRemoteError = e.message;
      debugPrint(
        'PUSH REMOTE ERROR: PostgrestException - ${e.message}, details: ${e.details}, hint: ${e.hint}',
      );
    } catch (e) {
      _lastRemoteError = e.toString();
      debugPrint('PUSH REMOTE ERROR: $e');
    }
  }

  Future<Map<String, dynamic>?> debugFetchRemoteRaw() async {
    final client = _supabaseClient;
    if (client == null || _currentUserId == null) return null;
    try {
      final row = await client
          .from('profiles')
          .select()
          .eq('id', _currentUserId!)
          .maybeSingle();
      debugPrint('REMOTE PROFILE ROW: $row');
      return row;
    } catch (e) {
      debugPrint('REMOTE PROFILE FETCH ERROR: $e');
      return null;
    }
  }

  // Removed hex helpers; DB stores 24-bit int, local keeps full ARGB
}
