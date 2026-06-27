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
  WordListDetail? _currentDetail;

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
    final detail = await api.getWordList(widget.listId);
    _currentDetail = detail;
    return detail;
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

  Future<void> _deleteWord(WordInList word) async {
    final api = context.read<SessionState>().api;
    await api.deleteWordFromList(listId: widget.listId, wordId: word.id);
    setState(() {
      _currentDetail = _currentDetail?.copyWith(
        words: _currentDetail!.words.where((w) => w.id != word.id).toList(),
      );
    });
  }

  Future<void> _editWord(WordInList word) async {
    final spellingController = TextEditingController(text: word.spelling);
    final phonicsController = TextEditingController(text: word.phonicsPattern ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => SketchDialog(
        title: const Text('Edit word'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: spellingController,
              decoration: const InputDecoration(labelText: 'Spelling'),
            ),
            TextField(
              controller: phonicsController,
              decoration: const InputDecoration(labelText: 'Phonics pattern'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final api = context.read<SessionState>().api;
    final updated = await api.updateWordInList(
      listId: widget.listId,
      wordId: word.id,
      spelling: spellingController.text.trim(),
      phonicsPattern: phonicsController.text.trim().isEmpty
          ? null
          : phonicsController.text.trim(),
    );

    setState(() {
      _currentDetail = _currentDetail?.copyWith(
        words: _currentDetail!.words
            .map((w) => w.id == updated.id ? updated : w)
            .toList(),
      );
    });
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
          final detail = _currentDetail ?? snapshot.data;
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
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            await _editWord(word);
                          } else if (value == 'delete') {
                            await _deleteWord(word);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Reuse edit dialog for adding
          final newWord = WordInList(
            id: '',
            spelling: '',
            phonicsPattern: null,
          );
          await _editWord(newWord);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
