import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../providers/auth_provider.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  Color _selectedColor = Colors.tealAccent;
  bool _saving = false;

  final _palette = <Color>[
    Colors.tealAccent,
    Colors.teal,
    Colors.orange,
    Colors.deepOrangeAccent,
    Colors.pinkAccent,
    Colors.purple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlueAccent,
    Colors.green,
    Colors.lime,
    Colors.amber,
  ];

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileProvider>();
    if (!profile.isLoaded) {
      profile.load().then((_) => _prefill());
    } else {
      _prefill();
    }
  }

  void _prefill() {
    final auth = context.read<AuthProvider>();
    final profile = context.read<ProfileProvider>();
    if (!profile.isCompleted) {
      if (profile.name == 'Calum Taylor' && auth.email != null) {
        final local = auth.email!.split('@').first;
        _nameCtrl.text = _humanize(local);
      } else {
        _nameCtrl.text = profile.name;
      }
      _bioCtrl.text = profile.bio == 'Home cook & flavour explorer' ? '' : profile.bio;
      _selectedColor = profile.avatarColor;
      setState((){});
    } else {
      // Already complete -> navigate away
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  String _humanize(String s) {
    return s.replaceAll(RegExp(r'[._-]+'), ' ').split(' ').where((p)=>p.isNotEmpty).map((p)=> p[0].toUpperCase()+p.substring(1)).join(' ');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = context.read<ProfileProvider>();
    setState(() { _saving = true; });
    await profile.completeSetup(
      name: _nameCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
      avatarColor: _selectedColor,
    );
    if (!mounted) return;
    setState(() { _saving = false; });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile set up')));
    Navigator.pop(context); // return to previous (e.g., login screen) which can then close
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Setup'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.person_outline, size: 72),
                  const SizedBox(height: 12),
                  Text('Finish setting up your profile', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('Add a friendly display name, a short bio and pick a colour.'),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Display name'),
                    validator: (v) {
                      if (v==null || v.trim().isEmpty) return 'Enter a name';
                      if (v.trim().length < 2) return 'Too short';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bioCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Bio (optional)'),
                  ),
                  const SizedBox(height: 24),
                  Text('Avatar colour', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final c in _palette)
                        GestureDetector(
                          onTap: () => setState(() => _selectedColor = c),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _selectedColor == c ? Colors.black87 : Colors.white,
                                width: _selectedColor == c ? 2 : 1,
                              ),
                              boxShadow: [
                                if (_selectedColor == c)
                                  const BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0,2),
                                  ),
                              ],
                            ),
                            child: _selectedColor == c ? const Icon(Icons.check, color: Colors.black87) : null,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
                    label: Text(_saving ? 'Saving...' : 'Save & Continue'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _saving ? null : () { Navigator.pop(context); },
                    child: const Text('Skip for now'),
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
