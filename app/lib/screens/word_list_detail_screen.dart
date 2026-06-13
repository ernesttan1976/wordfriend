import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../models.dart';
import '../session_state.dart';
import 'quiz_screen.dart';

class WordListDetailScreen extends StatefulWidget {
  const WordListDetailScreen({
    super.key,
    required this.listId,
    this.initialDetail,
  });

  final String listId;
  final WordListDetail? initialDetail;

  @override
  State<WordListDetailScreen> createState() => _WordListDetailScreenState();
}

class _WordListDetailScreenState extends State<WordListDetailScreen> {
  late Future<WordListDetail> _detailFuture;

  @override
  void initState() {
    super.initState();
    if (widget.initialDetail != null) {
      _detailFuture = Future<WordListDetail>.value(widget.initialDetail!);
    } else {
      _detailFuture = _loadDetail();
    }
  }

  Future<WordListDetail> _loadDetail() async {
    final api = context.read<SessionState>().api;
    return api.getWordList(widget.listId);
  }

  Future<void> _startQuiz() async {
    final api = context.read<SessionState>().api;
    try {
      final session = await api.createQuizSession(
        wordListId: widget.listId,
        mode: 'listen_type',
        size: 10,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuizScreen(session: session),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start quiz: HTTP ${e.statusCode}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start quiz: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Word list'),
      ),
      body: FutureBuilder<WordListDetail>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load list: ${snapshot.error}'),
              ),
            );
          }
          final detail = snapshot.data;
          if (detail == null) {
            return const Center(child: Text('List not found'));
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            detail.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${detail.words.length} words · ${detail.source == 'ai' ? 'AI' : 'Manual'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _startQuiz,
                      child: const Text('Start quiz'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: detail.words.length,
                  itemBuilder: (context, index) {
                    final word = detail.words[index];
                    return ListTile(
                      leading: Text('${index + 1}'),
                      title: Text(word.spelling),
                      subtitle: word.phonicsPattern != null
                          ? Text(word.phonicsPattern!)
                          : null,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
