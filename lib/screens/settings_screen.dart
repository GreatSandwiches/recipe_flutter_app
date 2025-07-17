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

          // Dark Mode Toggle
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: false,
            onChanged: (bool value) {
              // Handle dark mode toggle


            },
          ),

          // Notifications Toggle
          SwitchListTile(
            title: const Text('Notifications'),
            value: true,
            onChanged: (bool value) {
              // Handle notifications toggle
              

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
