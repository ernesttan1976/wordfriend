import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../session_state.dart';
import '../background_music_service.dart';

class ChildProfileScreen extends StatefulWidget {
  const ChildProfileScreen({super.key});

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  final TextEditingController _ageController = TextEditingController();
  String _theme = 'pony';
  bool _saving = false;
  String _ttsEngine = 'native';
  String? _ttsVoice;
  List<String> _voices = [];
  bool _loadingVoices = false;
  double _musicVolume = 0.1;
  double _ttsVolume = 1.0;

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionState>();
    final child = session.child;
    if (child != null) {
      _ageController.text = child.age.toString();
      _theme = child.theme;
      _ttsEngine = child.ttsEngine;
      _ttsVoice = child.ttsVoice;
    }

    _loadVoices();
    _loadLocalVolumes();
  }

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalVolumes() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _musicVolume = prefs.getDouble('music_volume') ?? 1.0;
      _ttsVolume = prefs.getDouble('tts_volume') ?? 1.0;
    });
  }

  Future<void> _saveLocalVolume(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
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

  Future<void> _loadVoices() async {
    final session = context.read<SessionState>();
    setState(() {
      _loadingVoices = true;
    });

    try {
      final voices = await session.api.getTtsVoices();
      if (mounted) {
        setState(() {
          _voices = voices;
        });
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _loadingVoices = false;
      });
    }
  }

  Future<void> _saveTts() async {
    final session = context.read<SessionState>();

    try {
      await session.updateTtsSettings(
        engine: _ttsEngine,
        voice: _ttsEngine == 'openai' ? _ttsVoice : null,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech settings saved')),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Child profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 50),
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
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Audio Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            const Text('Music Volume'),
            Slider(
              value: _musicVolume,
              min: 0,
              max: 1,
              divisions: 10,
              label: (_musicVolume * 100).round().toString(),
              onChanged: (value) {
                setState(() {
                  _musicVolume = value;
                });
                BackgroundMusicService.instance.updateVolume(value);
              },
            ),
            const SizedBox(height: 8),
            const Text('TTS Volume'),
            Slider(
              value: _ttsVolume,
              min: 0,
              max: 1,
              divisions: 10,
              label: (_ttsVolume * 100).round().toString(),
              onChanged: (value) {
                setState(() {
                  _ttsVolume = value;
                });
                _saveLocalVolume('tts_volume', value);
              },
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Speech Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            RadioListTile<String>(
              value: 'native',
              groupValue: _ttsEngine,
              title: const Text('Use device voice'),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _ttsEngine = value;
                });
              },
            ),
            RadioListTile<String>(
              value: 'openai',
              groupValue: _ttsEngine,
              title: const Text('Use OpenAI voice'),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _ttsEngine = value;
                });
              },
            ),
            if (_ttsEngine == 'openai') ...[
              const SizedBox(height: 8),
              _loadingVoices
                  ? const CircularProgressIndicator()
                  : Builder(
                      builder: (context) {
                        // Ensure unique items and only use value if it exists exactly once
                        final uniqueVoices = _voices.toSet().toList();
                        final effectiveValue = (_ttsVoice != null &&
                                uniqueVoices.where((v) => v == _ttsVoice).length == 1)
                            ? _ttsVoice
                            : null;

                        return DropdownButtonFormField<String>(
                          value: effectiveValue,
                          items: uniqueVoices
                              .map(
                                (v) => DropdownMenuItem<String>(
                                  value: v,
                                  child: Text(v),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _ttsVoice = value;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Voice',
                            border: OutlineInputBorder(),
                          ),
                        );
                      },
                    ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _ttsEngine == 'openai' && _ttsVoice == null
                    ? null
                    : _saveTts,
                child: const Text('Save Speech Settings'),
              ),
            ],
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
