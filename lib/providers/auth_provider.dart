import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Maintains Supabase authentication state and exposes top-level auth actions.
class AuthProvider extends ChangeNotifier {
  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const int _minPasswordLength = 8;
  SupabaseClient? _supabaseClient; // nullable until initialized
  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  String? _lastError;
  StreamSubscription<AuthState>? _authStateSubscription;
  AuthChangeEvent? _lastAuthEvent;
  DateTime? _lastEventTime;

  AuthProvider() {
    try {
      _supabaseClient = Supabase.instance.client;
    } catch (_) {
      _supabaseClient = null; // Supabase not initialized
      _status = AuthStatus.unconfigured;
      return;
    }
    _user = _supabaseClient!.auth.currentUser;
    _status = _user == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    _authStateSubscription = _supabaseClient!.auth.onAuthStateChange.listen((
      data,
    ) {
      final event = data.event;
      final now = DateTime.now();
      // Suppress rapid transient signedOut right after signedIn (session
      // recovery jitter)
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
    _authStateSubscription?.cancel();
    super.dispose();
  }

  bool get isLoggedIn => _user != null;
  bool get isConfigured => _supabaseClient != null;
  User? get user => _user;
  String? get email => _user?.email;
  AuthStatus get status => _status;
  String? get lastError => _lastError;

  /// Validates the email/password inputs before attempting auth calls.
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

  /// Signs in the user using Supabase email/password authentication.
  Future<bool> signIn(String email, String password) async {
    if (_supabaseClient == null) {
      _lastError = 'Auth not configured';
      notifyListeners();
      return false;
    }
    if (!_validateCredentials(email: email, password: password)) {
      return false;
    }
    _lastError = null;
    try {
      await _supabaseClient!.auth.signInWithPassword(
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

  /// Creates a new Supabase email/password account and signs the user in.
  Future<bool> signUp(String email, String password) async {
    if (_supabaseClient == null) {
      _lastError = 'Auth not configured';
      notifyListeners();
      return false;
    }
    if (!_validateCredentials(email: email, password: password)) {
      return false;
    }
    _lastError = null;
    try {
      await _supabaseClient!.auth.signUp(
        email: email.trim(),
        password: password,
      );
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

  /// Signs the current user out. Silently returns if auth is unconfigured.
  Future<void> signOut() async {
    if (_supabaseClient == null) {
      return;
    }
    try {
      await _supabaseClient!.auth.signOut();
    } catch (_) {}
  }

  /// Convenience alias for `signIn` used by legacy callers.
  Future<bool> login(String email, String password) => signIn(email, password);

  /// Convenience alias for `signOut` used by legacy callers.
  void logout() {
    signOut();
  }
}

enum AuthStatus { unknown, signedIn, signedOut, unconfigured }
