import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _isSignUp = false; // add mode toggle

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    setState(() { _loading = true; });
    bool ok;
    final isSignUpFlow = _isSignUp;
    if (_isSignUp) {
      ok = await auth.signUp(_emailCtrl.text, _passwordCtrl.text);
    } else {
      ok = await auth.signIn(_emailCtrl.text, _passwordCtrl.text);
    }
    if (!mounted) return;
    setState(() { _loading = false; });
    if (ok) {
      if (isSignUpFlow) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created. Set up profile.')));
        Navigator.pushReplacementNamed(context, '/profile_setup');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged in')));
        // Close login if possible; if this is the root, MainApp will swap UI anyway
        await Navigator.of(context).maybePop();
      }
    } else {
      final err = context.read<AuthProvider>().lastError ?? 'Unknown error';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.lock_outline, size: 72, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(_isSignUp ? 'Create an account' : 'Welcome back', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(_isSignUp ? 'Sign up with email & password. Verification may be required.' : 'Login with your credentials.', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter email';
                      if (!v.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter password';
                      if (v.length < 4) return 'Too short';
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _loading ? null : _submit,
                    icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(_isSignUp ? Icons.person_add : Icons.login),
                    label: Text(_loading ? (_isSignUp ? 'Creating...' : 'Signing in...') : (_isSignUp ? 'Sign Up' : 'Login')),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading ? null : () => setState(() { _isSignUp = !_isSignUp; }),
                    child: Text(_isSignUp ? 'Have an account? Login' : 'Need an account? Sign Up'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _loading ? null : () => Navigator.of(context).maybePop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
