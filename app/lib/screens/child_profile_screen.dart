import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../session_state.dart';

class ChildProfileScreen extends StatefulWidget {
  const ChildProfileScreen({super.key});

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  final TextEditingController _ageController = TextEditingController();
  String _theme = 'pony';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionState>();
    final child = session.child;
    if (child != null) {
      _ageController.text = child.age.toString();
      _theme = child.theme;
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final session = context.read<SessionState>();
    final age = int.tryParse(_ageController.text.trim());
    if (age == null || age <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid age')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await session.saveChildProfile(age: age, theme: _theme);
    } catch (_) {
      // error is stored in session
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Child profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Tell us about your child.'),
            const SizedBox(height: 16),
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Age',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Theme'),
            Row(
              children: [
                Radio<String>(
                  value: 'pony',
                  groupValue: _theme,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _theme = value;
                    });
                  },
                ),
                const Text('Pony'),
                const SizedBox(width: 16),
                Radio<String>(
                  value: 'lego',
                  groupValue: _theme,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _theme = value;
                    });
                  },
                ),
                const Text('Lego'),
              ],
            ),
            const SizedBox(height: 16),
            if (session.error != null)
              Text(
                session.error!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
