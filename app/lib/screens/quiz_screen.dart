import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  QuizWord get _currentWord => widget.session.words[_index];

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
            const Text(
              'Imagine the app has just spoken the word.\n'
              'Type what you heard.',
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
