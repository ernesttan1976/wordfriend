import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../monster_mascot.dart';
import '../session_state.dart';
import '../voice/voice_chat_controller.dart';
import 'child_profile_screen.dart';
import 'quiz_stats_screen.dart';
import 'word_lists_screen.dart';

class FreeModeScreen extends StatefulWidget {
  const FreeModeScreen({super.key});

  @override
  State<FreeModeScreen> createState() => _FreeModeScreenState();
}

class _FreeModeScreenState extends State<FreeModeScreen> {
  double _talkLevel = 0;
  Timer? _talkTimer;

  VoiceChatController? _voice;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _talkTimer?.cancel();
    _voice?.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_voice != null) return;

    final session = context.read<SessionState>();
    final child = session.childProfile;
    if (child == null) return;

    _voice = VoiceChatController(api: session.api, child: child)
      ..addListener(_onVoiceChanged);
  }

  void _onVoiceChanged() {
    if (!mounted) return;

    final v = _voice;
    if (v == null) return;

    // Drive a simple mouth-flap from agent speaking state.
    if (v.status == VoiceAgentStatus.speaking) {
      _talkTimer ??= Timer.periodic(const Duration(milliseconds: 120), (_) {
        if (!mounted) return;
        setState(() {
          _talkLevel = _talkLevel > 0.6 ? 0.2 : 1.0;
        });
      });
    } else {
      _talkTimer?.cancel();
      _talkTimer = null;
      if (_talkLevel != 0) {
        setState(() => _talkLevel = 0);
      }
    }

    // Keep the chat pinned to bottom when new messages arrive.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final voice = _voice;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WordFriend'),
        actions: [
          if (voice != null)
            IconButton(
              tooltip: voice.connected ? 'Disconnect tutor' : 'Connect tutor',
              icon: Icon(voice.connected ? Icons.headset_off : Icons.headset),
              onPressed: () async {
                try {
                  if (voice.connected) {
                    await voice.disconnect();
                  } else {
                    await voice.connectFreeMode();
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Tutor connect failed: $e')),
                  );
                }
              },
            ),
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
            const SizedBox(height: 6),
            if (voice != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _statusDot(voice.status),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusLabel(voice.status, voice.connected),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (voice.connected)
                      IconButton(
                        tooltip: voice.micEnabled ? 'Mute mic' : 'Unmute mic',
                        icon: Icon(
                          voice.micEnabled ? Icons.mic : Icons.mic_off,
                        ),
                        onPressed: () async {
                          try {
                            await voice.setMicEnabled(!voice.micEnabled);
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Mic error: $e')),
                            );
                          }
                        },
                      ),
                  ],
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
                child: _chatBody(),
              ),
            ),
            _composer(),
          ],
        ),
      ),
    );
  }

  Widget _starterChip(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () {
        final v = _voice;
        if (v == null || !v.connected) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connect the tutor first')),
          );
          return;
        }
        void _ = v.sendStarter(text);
      },
    );
  }

  Widget _chatBody() {
    final v = _voice;
    if (v == null) {
      return const Center(child: Text('Loading...'));
    }

    if (!v.connected) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Connect your tutor to start free chat.\n\nYou can talk with the mic, or type a message.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        if (v.lastHeard.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Heard: ${v.lastHeard}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: v.messages.length,
            itemBuilder: (context, i) {
              final m = v.messages[i];
              final isAgent = m.speaker == 'agent';
              return Align(
                alignment: isAgent ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isAgent
                        ? Colors.black.withOpacity(0.06)
                        : Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(m.text),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _composer() {
    final v = _voice;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendText(),
              decoration: InputDecoration(
                hintText: v?.connected == true
                    ? 'Type a message'
                    : 'Connect tutor to chat',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: (v?.connected ?? false) ? _sendText : null,
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _sendText() {
    final v = _voice;
    if (v == null || !v.connected) return;

    final text = _textController.text;
    _textController.clear();
    void _ = v.sendChildText(text);
  }

  Widget _statusDot(VoiceAgentStatus s) {
    Color c;
    switch (s) {
      case VoiceAgentStatus.disconnected:
        c = Colors.black26;
        break;
      case VoiceAgentStatus.connecting:
        c = Colors.orange;
        break;
      case VoiceAgentStatus.listening:
        c = Colors.green;
        break;
      case VoiceAgentStatus.thinking:
        c = Colors.blue;
        break;
      case VoiceAgentStatus.speaking:
        c = Colors.purple;
        break;
    }

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
  }

  String _statusLabel(VoiceAgentStatus s, bool connected) {
    if (!connected) return 'Tutor disconnected';
    switch (s) {
      case VoiceAgentStatus.disconnected:
        return 'Tutor disconnected';
      case VoiceAgentStatus.connecting:
        return 'Connecting...';
      case VoiceAgentStatus.listening:
        return 'Listening';
      case VoiceAgentStatus.thinking:
        return 'Thinking';
      case VoiceAgentStatus.speaking:
        return 'Speaking';
    }
  }
}
