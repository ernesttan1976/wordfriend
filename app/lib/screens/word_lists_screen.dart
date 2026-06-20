import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../models.dart';
import '../session_state.dart';
import 'child_profile_screen.dart';
import 'word_list_detail_screen.dart';
import 'quiz_stats_screen.dart';
import 'quiz_screen.dart';
import '../monster_mascot.dart';
import 'mascot_test_screen.dart';

class WordListsScreen extends StatefulWidget {
  const WordListsScreen({super.key});

  @override
  State<WordListsScreen> createState() => _WordListsScreenState();
}

class _WordListsScreenState extends State<WordListsScreen> {
  late Future<List<WordListSummary>> _listsFuture;

  @override
  void initState() {
    super.initState();
    _listsFuture = _loadLists();
  }

  Future<List<WordListSummary>> _loadLists() async {
    final api = context.read<SessionState>().api;
    return api.listWordLists();
  }

  Future<void> _refresh() async {
    setState(() {
      _listsFuture = _loadLists();
    });
  }

  Future<void> _deleteList(WordListSummary list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete list'),
        content: Text('Delete "${list.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final api = context.read<SessionState>().api;
    await api.deleteWordList(list.id);
    await _refresh();
  }

  Future<void> _renameList(WordListSummary list) async {
    final controller = TextEditingController(text: list.name);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename list'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'List name'),
          autofocus: true,
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

    if (confirmed != true) return;

    final newName = controller.text.trim();
    if (newName.isEmpty || newName == list.name) return;

    final api = context.read<SessionState>().api;
    try {
      await api.updateWordListName(id: list.id, name: newName);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to rename list: $e')),
      );
    }
  }

  Future<void> _quickQuiz(List<WordListSummary> lists) async {
    if (lists.isEmpty) return;

    final selected = <String>{};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select lists for quiz'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: lists
                  .map(
                    (l) => StatefulBuilder(
                      builder: (context, setStateDialog) {
                        final isChecked = selected.contains(l.id);
                        return CheckboxListTile(
                          value: isChecked,
                          title: Text(l.name),
                          onChanged: (val) {
                            setStateDialog(() {
                              if (val == true) {
                                selected.add(l.id);
                              } else {
                                selected.remove(l.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Start quiz'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || selected.isEmpty) return;

    final api = context.read<SessionState>().api;

    try {
      final words = await api.randomWordsFromLists(
        listIds: selected.toList(),
        size: 10,
      );

      final wordIds = words.map((w) => w.id).toList();

      final session = await api.createQuizSessionFromWords(
        mode: 'listen_type',
        wordIds: wordIds,
      );

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuizScreen(session: session),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start quiz: $e')),
      );
    }
  }

  Future<void> _showGenerateDialog() async {
    final promptController = TextEditingController();
    final sizeController = TextEditingController(text: '10');
    final nameController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Generate word list (AI)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: promptController,
                  decoration: const InputDecoration(
                    labelText: 'Prompt (e.g. "Space words with long a")',
                  ),
                ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name (optional)',
                  ),
                ),
                TextField(
                  controller: sizeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Number of words (5-50)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Generate'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final prompt = promptController.text.trim();
    if (prompt.isEmpty) return;
    final size = int.tryParse(sizeController.text.trim()) ?? 10;
    final name = nameController.text.trim().isEmpty ? null : nameController.text.trim();

    final api = context.read<SessionState>().api;
    try {
      // Show a modal loading dialog while the AI generates the list.
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          const words = ['Thinking...', 'Guessing...', 'Analyzing...', 'Finding...'];

          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                StreamBuilder<int>(
                  stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
                  builder: (context, snapshot) {
                    final index = snapshot.data ?? 0;
                    final text = words[index % words.length];
                    return Text(
                      text,
                      textAlign: TextAlign.center,
                    );
                  },
                ),
              ],
            ),
          );
        },
      );

      final detail = await api.generateWordList(
        prompt: prompt,
        size: size,
        name: name,
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WordListDetailScreen(listId: detail.id, initialDetail: detail),
        ),
      );
      await _refresh();
    } on ApiException catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate list: HTTP ${e.statusCode}')),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate list: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
        title: const Text('Word lists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Quick quiz (10)',
            onPressed: () async {
              final lists = await _listsFuture;
              await _quickQuiz(lists);
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Quiz stats',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const QuizStatsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.child_care),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChildProfileScreen()),
              );
              await _refresh();
            },
          ),
          IconButton(
            icon: const Icon(Icons.pets),
            tooltip: 'Mascot test',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MascotTestScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => session.signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<WordListSummary>>(
          future: _listsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Failed to load lists: ${snapshot.error}'),
                  ),
                ],
              );
            }
            final lists = snapshot.data ?? <WordListSummary>[];
            if (lists.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No word lists yet. Generate one with the + button.'),
                  ),
                ],
              );
            }
            return ListView.builder(
              itemCount: lists.length,
              itemBuilder: (context, index) {
                final list = lists[index];
                final subtitleParts = <String>[];
                // Show first 3 actual words from the list
                if (list.previewWords != null && list.previewWords!.isNotEmpty) {
                  subtitleParts.add(list.previewWords!.take(3).join(', '));
                }
                if (list.wordCount != null) {
                  subtitleParts.add('${list.wordCount} words');
                }
                subtitleParts.add(list.source == 'ai' ? 'AI' : 'Manual');
                return ListTile(
                  title: Text(list.name),
                  subtitle: Text(subtitleParts.join(' · ')),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => WordListDetailScreen(listId: list.id),
                      ),
                    );
                  },
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'rename') {
                        await _renameList(list);
                      } else if (value == 'delete') {
                        await _deleteList(list);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'rename',
                        child: Text('Rename'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showGenerateDialog,
            child: const Icon(Icons.add),
          ),
        ),
        Positioned(
          bottom: 90,
          right: 16,
          child: MonsterMascot(
            size: 120,
            pose: MonsterPose.idle,
          ),
        ),
      ],
    );
  }
}
