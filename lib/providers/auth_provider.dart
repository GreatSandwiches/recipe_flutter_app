import 'package:flutter/foundation.dart';

class AuthProvider extends ChangeNotifier {
  bool _loggedIn = false;
  String? _email; // stored for display only (not secure storage)

  bool get isLoggedIn => _loggedIn;
  String? get email => _email;

  Future<void> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 500)); // simulate delay
    _email = email.trim();
    _loggedIn = true;
    notifyListeners();
  }

  void logout() {
    _loggedIn = false;
    _email = null;
    notifyListeners();
  }
}