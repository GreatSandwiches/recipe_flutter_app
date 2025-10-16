import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    if (!settings.isLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          const _SectionHeader(label: 'Appearance'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: Text(
              settings.darkMode ? 'Dark theme enabled' : 'Light theme enabled',
            ),
            value: settings.darkMode,
            onChanged: (v) async {
              await settings.setDarkMode(v);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Theme changed to ${v ? 'Dark' : 'Light'}'),
                  ),
                );
              }
            },
          ),
          const Divider(height: 0),
          const _SectionHeader(label: 'Preferences'),
          ListTile(
            title: const Text('Measurement Units'),
            subtitle: Text(
              settings.units == 'metric'
                  ? 'Metric (g, ml, °C)'
                  : 'US Customary (oz, cups, °F)',
            ),
            trailing: DropdownButton<String>(
              value: settings.units,
              onChanged: (val) async {
                if (val != null) {
                  await settings.setUnits(val);
                }
              },
              items: const [
                DropdownMenuItem(value: 'metric', child: Text('Metric')),
                DropdownMenuItem(value: 'us', child: Text('US Customary')),
              ],
            ),
          ),
          const Divider(height: 0),
          SwitchListTile(
            title: const Text('Notifications'),
            subtitle: Text(settings.notifications ? 'Enabled' : 'Disabled'),
            value: settings.notifications,
            onChanged: (v) async {
              await settings.setNotifications(v);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Notifications ${v ? 'enabled' : 'disabled'}',
                    ),
                  ),
                );
              }
            },
          ),
          const Divider(height: 0),
          const _SectionHeader(label: 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App Version'),
            subtitle: Text(settings.appVersion ?? 'Unknown'),
          ),
          ListTile(
            leading: const Icon(Icons.policy_outlined),
            title: const Text('Privacy Policy'),
            onTap: () {
              showDialog(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Privacy Policy'),
                  content: const Text(
                    'Placeholder privacy policy. Replace with actual content.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Licenses'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Recipe App',
              applicationVersion: settings.appVersion,
            ),
          ),
          const _SectionHeader(label: 'Danger Zone'),
          ListTile(
            leading: const Icon(Icons.restore, color: Colors.redAccent),
            title: const Text('Reset Settings'),
            subtitle: const Text('Restore default preferences'),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Reset Settings'),
                  content: const Text(
                    'This will restore defaults for theme, notifications and units.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await settings.setDarkMode(false);
                await settings.setNotifications(true);
                await settings.setUnits('metric');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings reset to defaults')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 1.1,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
