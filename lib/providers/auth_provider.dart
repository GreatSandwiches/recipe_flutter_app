import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const int _minPasswordLength = 8;
  SupabaseClient? _client; // nullable until initialized
  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  String? _lastError;
  StreamSubscription<AuthState>? _sub;
  AuthChangeEvent? _lastAuthEvent;
  DateTime? _lastEventTime;

  AuthProvider() {
    try {
      _client = Supabase.instance.client;
    } catch (_) {
      _client = null; // Supabase not initialized
      _status = AuthStatus.unconfigured;
      return;
    }
    _user = _client!.auth.currentUser;
    _status = _user == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    _sub = _client!.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final now = DateTime.now();
      // Suppress rapid transient signedOut right after signedIn (session recovery jitter)
      if (event == AuthChangeEvent.signedOut &&
          _lastAuthEvent == AuthChangeEvent.signedIn &&
          _lastEventTime != null &&
          now.difference(_lastEventTime!) < const Duration(seconds: 2)) {
        if (kDebugMode) {
          print('AuthProvider: Suppressed transient signedOut event');
        }
        return; // ignore
      }
      final session = data.session;
      _user = session?.user;
      _status = _user == null ? AuthStatus.signedOut : AuthStatus.signedIn;
      _lastAuthEvent = event;
      _lastEventTime = now;
      if (kDebugMode) {
        print('AuthProvider: processed auth event $event user=${_user?.id}');
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  bool get isLoggedIn => _user != null;
  bool get isConfigured => _client != null;
  User? get user => _user;
  String? get email => _user?.email;
  AuthStatus get status => _status;
  String? get lastError => _lastError;

  bool _validateCredentials({required String email, required String password}) {
    final trimmedEmail = email.trim();
    if (!_emailRegex.hasMatch(trimmedEmail)) {
      _lastError = 'Enter a valid email address.';
      notifyListeners();
      return false;
    }

    if (password.trim().length < _minPasswordLength) {
      _lastError = 'Password must be at least $_minPasswordLength characters.';
      notifyListeners();
      return false;
    }

    return true;
  }

  Future<bool> signIn(String email, String password) async {
    if (_client == null) {
      _lastError = 'Auth not configured';
      notifyListeners();
      return false;
    }
    if (!_validateCredentials(email: email, password: password)) {
      return false;
    }
    _lastError = null;
    try {
      await _client!.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return true;
    } on AuthException catch (e) {
      _lastError = e.message;
    } catch (e) {
      _lastError = e.toString();
    }
    notifyListeners();
    return false;
  }

  Future<bool> signUp(String email, String password) async {
    if (_client == null) {
      _lastError = 'Auth not configured';
      notifyListeners();
      return false;
    }
    if (!_validateCredentials(email: email, password: password)) {
      return false;
    }
    _lastError = null;
    try {
      await _client!.auth.signUp(email: email.trim(), password: password);
      // Assume immediate usability
      return true;
    } on AuthException catch (e) {
      _lastError = e.message;
    } catch (e) {
      _lastError = e.toString();
    }
    notifyListeners();
    return false;
  }

  Future<void> signOut() async {
    if (_client == null) return;
    try {
      await _client!.auth.signOut();
    } catch (_) {}
  }

  Future<void> login(String email, String password) => signIn(email, password);
  void logout() {
    signOut();
  }
}

enum AuthStatus { unknown, signedIn, signedOut, unconfigured }