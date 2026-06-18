import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

import '../api_client.dart';
import '../models.dart';
import '../session_state.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.session});

  final QuizSession session;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _index = 0;
  final TextEditingController _answerController = TextEditingController();
  bool _submitting = false;
  int _correctCount = 0;
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _speaking = false;

  QuizWord get _currentWord => widget.session.words[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakCurrentWord();
    });
  }

  Future<void> _speakCurrentWord() async {
    if (_speaking || _submitting) return;

    final sessionState = context.read<SessionState>();
    final child = sessionState.childProfile;
    if (child == null) return;

    setState(() {
      _speaking = true;
    });

    try {
      await _audioPlayer.stop();
      await _flutterTts.stop();

      if (child.ttsEngine == 'native') {
        await _flutterTts.speak(_currentWord.spelling);
      } else {
        final bytes = await sessionState.api.postBytes(
          '/tts',
          body: {
            'text': _currentWord.spelling,
            'voice': child.ttsVoice,
          },
        );

        // BytesSource expects Uint8List, convert List<int> to Uint8List
        final uri = Uri.dataFromBytes(
          Uint8List.fromList(bytes),
          mimeType: 'audio/mpeg',
        );
        await _audioPlayer.setAudioSource(AudioSource.uri(uri));
        await _audioPlayer.play();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Speech failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _speaking = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) return;

    final api = context.read<SessionState>().api;
    setState(() {
      _submitting = true;
    });

    try {
      final result = await api.submitQuizAttempt(
        sessionId: widget.session.id,
        wordId: _currentWord.id,
        typedAnswer: answer,
      );

      if (!mounted) return;
      if (result.isCorrect) {
        _correctCount += 1;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isCorrect ? 'Correct!' : 'Try again: ${_currentWord.spelling}',
          ),
        ),
      );

      _answerController.clear();

      if (_index + 1 < widget.session.words.length) {
        setState(() {
          _index += 1;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _speakCurrentWord();
        });
      } else {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Quiz complete'),
            content: Text(
              'You got $_correctCount out of ${widget.session.words.length} correct.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit answer: HTTP ${e.statusCode}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit answer: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    _flutterTts.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listen & type quiz'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: ( (_index + 1) / widget.session.words.length),
            ),
            const SizedBox(height: 16),
            Text(
              'Word ${_index + 1} of ${widget.session.words.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            const Text('Listen carefully. Type what you hear.'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _speaking ? null : _speakCurrentWord,
              icon: const Icon(Icons.volume_up),
              label: const Text('Replay word'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _answerController,
              decoration: const InputDecoration(
                labelText: 'Your spelling',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submitting ? null : _submit(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
