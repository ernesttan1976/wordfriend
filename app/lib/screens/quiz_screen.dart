import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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
  final List<String> _attempts = [];
  int _hintLevel = 0;
  List<String> _visibleHints = [];
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _speaking = false;

  QuizWord get _currentWord => widget.session.words[_index];

  void _resetForNextWord() {
    _attempts.clear();
    _hintLevel = 0;
    _visibleHints = [];
    _answerController.clear();
  }

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

        // Write to temp file to avoid Android data URI issues
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
        await file.writeAsBytes(bytes, flush: true);

        await _audioPlayer.setAudioSource(AudioSource.file(file.path));
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
    if (_attempts.length >= 3) return;

    final answer = _answerController.text.trim();
    if (answer.isEmpty) return;

    final api = context.read<SessionState>().api;
    setState(() {
      _submitting = true;
      _attempts.add(answer);
    });

    try {
      final result = await api.submitQuizAttempt(
        sessionId: widget.session.id,
        wordId: _currentWord.id,
        typedAnswer: answer,
      );

      if (!mounted) return;
      final correct = result.isCorrect;
      if (correct) _correctCount++;

      final maxed = _attempts.length >= 3;

      if (correct || maxed) {
        Future.delayed(const Duration(milliseconds: 1200), () async {
          if (!mounted) return;

          if (_index + 1 < widget.session.words.length) {
            setState(() {
              _index += 1;
              _resetForNextWord();
            });
            _speakCurrentWord();
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
            if (mounted) Navigator.of(context).pop();
          }
        });
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
          _answerController.clear();
        });
      }
    }
  }

  Widget _buildDiff(String attempt, String correct) {
    final maxLen = correct.length;
    final chars = <Widget>[];

    for (int i = 0; i < maxLen; i++) {
      final correctChar = correct[i];
      final typedChar = i < attempt.length ? attempt[i] : '';
      final isCorrect = typedChar == correctChar;

      chars.add(Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isCorrect ? Colors.green[300] : Colors.pink[200],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          typedChar.isEmpty ? '_' : typedChar,
          style: const TextStyle(fontSize: 16),
        ),
      ));
    }

    return Wrap(children: chars);
  }

  void _requestHint() {
    if (_hintLevel >= 5) return;

    final api = context.read<SessionState>().api;
    final nextLevel = _hintLevel + 1;

    setState(() {
      _hintLevel = nextLevel;
    });

    api
        .getQuizHint(
          sessionId: widget.session.id,
          wordId: _currentWord.id,
          level: nextLevel,
        )
        .then((hints) {
      if (!mounted) return;
      setState(() {
        // Backend returns the full hints array; keep UI in sync
        _visibleHints = hints;
      });
    }).catchError((error) {
      if (!mounted) return;

      String message = 'Could not load hint.';
      if (error is ApiException) {
        // Surface backend error body to help diagnose issues
        message = 'Hint error: ${error.body}';
      }

      setState(() {
        _visibleHints.add(message);
      });
    });
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
            const SizedBox(height: 16),
            const Text('Attempts (max 3):'),
            const SizedBox(height: 8),
            for (final attempt in _attempts)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDiff(attempt, _currentWord.spelling),
                  const SizedBox(height: 6),
                ],
              ),
            const SizedBox(height: 12),
            if (_attempts.length < 3)
              TextButton(
                onPressed: _requestHint,
                child: const Text('Show hint'),
              ),
            for (int i = 0; i < _visibleHints.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('Hint ${i + 1}: ${_visibleHints[i]}'),
              ),
          ],
        ),
      ),
    );
  }
}
