import 'dart:async';

import 'package:flutter/material.dart';

import '../monster_mascot.dart';
import 'child_profile_screen.dart';
import 'quiz_stats_screen.dart';
import 'word_lists_screen.dart';

class FreeModeScreen extends StatefulWidget {
  const FreeModeScreen({super.key});

  @override
  State<FreeModeScreen> createState() => _FreeModeScreenState();
}

class _FreeModeScreenState extends State<FreeModeScreen> {
  // Placeholder until LiveKit audio levels drive this.
  double _talkLevel = 0;
  Timer? _talkTimer;

  @override
  void dispose() {
    _talkTimer?.cancel();
    super.dispose();
  }

  void _toggleTalkDemo() {
    if (_talkTimer != null) {
      _talkTimer?.cancel();
      _talkTimer = null;
      setState(() => _talkLevel = 0);
      return;
    }

    // Simple deterministic flap so the avatar looks alive in this screen.
    var on = false;
    _talkTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      on = !on;
      setState(() => _talkLevel = on ? 1 : 0.2);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WordFriend'),
        actions: [
          IconButton(
            tooltip: 'Word lists',
            icon: const Icon(Icons.library_books),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WordListsScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Stats',
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const QuizStatsScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Child profile',
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChildProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: MonsterMascot(
                size: 180,
                pose: MonsterPose.idle,
                talkLevel: _talkLevel,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _starterChip('Help me spell a word'),
                  _starterChip('Word family game'),
                  _starterChip('Why is this spelled like that?'),
                  _starterChip('Teach me a pattern'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _emptyChatPlaceholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _toggleTalkDemo,
                      icon: Icon(_talkTimer == null ? Icons.play_arrow : Icons.stop),
                      label: Text(_talkTimer == null
                          ? 'Avatar talk demo'
                          : 'Stop demo'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _starterChip(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () {
        // Intentional no-op for now: this screen is a new home shell.
        // When LiveKit is wired, this will send a structured "starter" event
        // to the agent to kick off the conversation.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Starter: $text')),
        );
      },
    );
  }

  Widget _emptyChatPlaceholder() {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Free mode chat will live here.\n\nNext: LiveKit connect + open mic + transcript + spelling helper drawer.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
