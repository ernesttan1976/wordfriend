import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import '../models.dart';
import '../session_state.dart';
import '../monster_mascot.dart';
import '../background_music_service.dart';
import '../widgets/quiz_keyboard.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.session});

  final QuizSession session;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final List<QuizWord> _words;
  int _index = 0;
  final TextEditingController _answerController = TextEditingController();
  bool _submitting = false;
  int _correctCount = 0;
  final List<String> _attempts = [];
  int _hintLevel = 0;
  List<String> _visibleHints = [];
  Timer? _hintCooldownTimer;
  int _hintCooldownSecondsRemaining = 0;
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _speaking = false;
  MonsterPose _pose = MonsterPose.quizScreen;
  bool _regenerating = false;

  QuizWord get _currentWord => _words[_index];

  void _resetForNextWord() {
    _attempts.clear();
    _hintLevel = 0;
    _visibleHints = [];
    _cancelHintCooldown();
    _answerController.clear();
    _pose = MonsterPose.quizScreen;
  }

  @override
  void initState() {
    super.initState();

    // Randomize the quiz sequence once per quiz run.
    _words = List<QuizWord>.of(widget.session.words)..shuffle(Random.secure());

    // Mute background music for the duration of the quiz.
    BackgroundMusicService.instance.duckForTts(
      duration: Duration.zero,
    );

    // TTS parameters are configured per word in _speakCurrentWord().

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakCurrentWord();
    });
  }

  void _cancelHintCooldown() {
    _hintCooldownTimer?.cancel();
    _hintCooldownTimer = null;
    _hintCooldownSecondsRemaining = 0;
  }

  @override
  void dispose() {
    // Restore background music when leaving the quiz.
    BackgroundMusicService.instance.restoreAfterTts(
      duration: Duration.zero,
    );
    _flutterTts.stop();
    _audioPlayer.dispose();
    _answerController.dispose();
    _cancelHintCooldown();
    super.dispose();
  }

  void _startHintCooldown({int seconds = 10}) {
    _hintCooldownTimer?.cancel();
    setState(() {
      _hintCooldownSecondsRemaining = seconds;
    });

    _hintCooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }

      if (_hintCooldownSecondsRemaining <= 1) {
        setState(() {
          _hintCooldownSecondsRemaining = 0;
        });
        t.cancel();
        _hintCooldownTimer = null;
        return;
      }

      setState(() {
        _hintCooldownSecondsRemaining -= 1;
      });
    });
  }

  void _appendLetter(String letter) {
    if (_submitting) return;

    final next = '${_answerController.text}$letter';
    _answerController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );

    // Rebuild so keyboard buttons (Back) reflect current text.
    if (mounted) setState(() {});
  }

  void _backspace() {
    if (_submitting) return;

    final text = _answerController.text;
    if (text.isEmpty) return;

    final next = text.substring(0, text.length - 1);
    _answerController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );

    // Rebuild so keyboard buttons (Back) reflect current text.
    if (mounted) setState(() {});
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
      // Pause background music while TTS plays
      await BackgroundMusicService.instance.pause();

      await _audioPlayer.stop();
      await _flutterTts.stop();

      if (child.ttsEngine == 'native') {
        // Apply TTS settings from profile (only if defined)
        final prefs = await SharedPreferences.getInstance();
        final configuredVolume = prefs.getDouble('tts_volume');
        final configuredRate = prefs.getDouble('tts_rate');
        final configuredPitch = prefs.getDouble('tts_pitch');

        if (configuredVolume != null) {
          await _flutterTts.setVolume(configuredVolume);
        }
        if (configuredRate != null) {
          await _flutterTts.setSpeechRate(configuredRate);
        }
        if (configuredPitch != null) {
          await _flutterTts.setPitch(configuredPitch);
        }

        // Keep iOS audio category stable for speech playback
        if (Platform.isIOS) {
          await _flutterTts.setIosAudioCategory(
            IosTextToSpeechAudioCategory.playback,
            [IosTextToSpeechAudioCategoryOptions.mixWithOthers],
          );
        }

        await _flutterTts.awaitSpeakCompletion(true);
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
        final file = File(
            '${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
        await file.writeAsBytes(bytes, flush: true);

        await _audioPlayer.setAudioSource(AudioSource.file(file.path));
        await _audioPlayer.play();

        // Wait until playback completes
        await _audioPlayer.processingStateStream
            .firstWhere((state) => state == ProcessingState.completed);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Speech failed: $e')),
        );
      }
    } finally {
      // Resume background music after TTS completes or fails
      await BackgroundMusicService.instance.resume();

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

      setState(() {
        _pose = correct ? MonsterPose.quizCorrect : MonsterPose.quizWrong;
      });

      if (correct || maxed) {
        Future.delayed(const Duration(milliseconds: 1200), () async {
          if (!mounted) return;

          if (_index + 1 < _words.length) {
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
                  'You got $_correctCount out of ${_words.length} correct.',
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
      // If wrong but not maxed, return to normal quiz pose after a short delay
      if (!correct && !maxed) {
        Future.delayed(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          setState(() {
            _pose = MonsterPose.quizScreen;
          });
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to submit answer: HTTP ${e.statusCode}')),
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
    if (_hintCooldownSecondsRemaining > 0) return;

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

      // After each successful hint, enforce a short delay before the next.
      if (mounted) _startHintCooldown(seconds: 10);
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

  Future<void> _showRegenerateDialog() async {
    if (_submitting || _speaking || _regenerating) return;

    final commentController = TextEditingController();
    bool regenHints = true;
    bool regenTts = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final canSubmit = commentController.text.trim().isNotEmpty &&
                (regenHints || regenTts);

            return AlertDialog(
              title: const Text('Regenerate'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                      'What went wrong? Add a short note so we can regenerate better.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Feedback comment',
                      hintText: 'e.g. no voice, hint is wrong, hints missing',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setLocalState(() {}),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: regenHints,
                    onChanged: (v) => setLocalState(() {
                      regenHints = v ?? false;
                    }),
                    title: const Text('Regenerate hints'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    value: regenTts,
                    onChanged: (v) => setLocalState(() {
                      regenTts = v ?? false;
                    }),
                    title: const Text('Regenerate voice (TTS)'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed:
                      canSubmit ? () => Navigator.of(context).pop(true) : null,
                  child: const Text('Regenerate'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final comment = commentController.text.trim();

    setState(() {
      _regenerating = true;
    });

    try {
      final api = context.read<SessionState>().api;
      await api.regenerateQuizWord(
        sessionId: widget.session.id,
        wordId: _currentWord.id,
        comment: comment,
        regenerateHints: regenHints,
        regenerateTts: regenTts,
      );

      if (!mounted) return;

      if (regenHints) {
        setState(() {
          _hintLevel = 0;
          _visibleHints = [];
          _cancelHintCooldown();
        });
      }

      if (regenTts) {
        await _speakCurrentWord();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Regenerated.')),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Regenerate failed: HTTP ${e.statusCode}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Regenerate failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _regenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    const keyboardHeight = 220.0; // fixed custom keyboard height
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listen & type quiz'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              keyboardHeight + bottomInset + 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: MonsterMascot(
                    size: 160,
                    pose: _pose,
                  ),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: ((_index + 1) / _words.length),
                ),
                const SizedBox(height: 16),
                Text(
                  'Word ${_index + 1} of ${_words.length}',
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
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: (_submitting || _speaking || _regenerating)
                      ? null
                      : _showRegenerateDialog,
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Regenerate'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _answerController,
                  decoration: const InputDecoration(
                    labelText: 'Your spelling',
                    border: OutlineInputBorder(),
                  ),
                  // Block OS keyboard, spellcheck, suggestions, and voice input.
                  readOnly: true,
                  showCursor: true,
                  enableInteractiveSelection: false,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  spellCheckConfiguration:
                      const SpellCheckConfiguration.disabled(),
                  contextMenuBuilder: (context, editableTextState) =>
                      const SizedBox.shrink(),
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
                    onPressed: (_hintCooldownSecondsRemaining > 0)
                        ? null
                        : _requestHint,
                    child: Text(
                      _hintCooldownSecondsRemaining > 0
                          ? 'Show hint (${_hintCooldownSecondsRemaining}s)'
                          : 'Show hint',
                    ),
                  ),
                for (int i = 0; i < _visibleHints.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('Hint ${i + 1}: ${_visibleHints[i]}'),
                  ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: QuizKeyboard(
              onLetter: _appendLetter,
              onBackspace: _backspace,
              onEnter: _submit,
              enableBackspace:
                  _answerController.text.isNotEmpty && !_submitting,
              enableEnter: !_submitting,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAudioSettings,
        child: const Icon(Icons.volume_up),
      ),
    );
  }

  Future<void> _openAudioSettings() async {
    final prefs = await SharedPreferences.getInstance();

    double musicVolume = prefs.getDouble('music_volume') ?? 0.5;
    double ttsVolume = prefs.getDouble('tts_volume') ?? 1.0;
    double ttsRate = prefs.getDouble('tts_rate') ?? 0.5;
    double ttsPitch = prefs.getDouble('tts_pitch') ?? 1.0;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Audio Settings'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Music Volume'),
                    ),
                    Slider(
                      value: musicVolume,
                      min: 0,
                      max: 1,
                      onChanged: (v) async {
                        setStateDialog(() => musicVolume = v);
                        await prefs.setDouble('music_volume', v);
                        await BackgroundMusicService.instance.updateVolume(v);
                      },
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('TTS Volume'),
                    ),
                    Slider(
                      value: ttsVolume,
                      min: 0,
                      max: 1,
                      onChanged: (v) async {
                        setStateDialog(() => ttsVolume = v);
                        await prefs.setDouble('tts_volume', v);
                        await _flutterTts.setVolume(v);
                      },
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Speech Rate'),
                    ),
                    Slider(
                      value: ttsRate,
                      min: 0.1,
                      max: 1.0,
                      onChanged: (v) async {
                        setStateDialog(() => ttsRate = v);
                        await prefs.setDouble('tts_rate', v);
                        await _flutterTts.setSpeechRate(v);
                      },
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Pitch'),
                    ),
                    Slider(
                      value: ttsPitch,
                      min: 0.5,
                      max: 2.0,
                      onChanged: (v) async {
                        setStateDialog(() => ttsPitch = v);
                        await prefs.setDouble('tts_pitch', v);
                        await _flutterTts.setPitch(v);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
