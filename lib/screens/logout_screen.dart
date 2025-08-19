import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LogoutScreen extends StatelessWidget {
  const LogoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Logout')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.logout, size: 72),
                const SizedBox(height: 16),
                Text('Sign out', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('This is a placeholder logout screen. No remote session handling yet.'),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () {
                    auth.logout();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged out (placeholder)')));
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Logout'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
