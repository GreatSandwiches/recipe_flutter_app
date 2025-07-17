import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Column(
        children: [

          // Settings Title
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Center(
              child: Text(
                'Settings',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),

          // Dark Mode Toggle
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: false,
            onChanged: (bool value) {

            },
          ),

          // Notifications Toggle
          SwitchListTile(
            title: const Text('Notifications'),
            value: true,
            onChanged: (bool value) {

            },
          ),

          // Language Selection

          // About Section

          // Contact Us Section??



        ],
      ),
    );
  }
}
