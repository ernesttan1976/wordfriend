import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../models.dart';
import '../session_state.dart';
import 'child_profile_screen.dart';
import 'word_list_detail_screen.dart';

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
      final detail = await api.generateWordList(prompt: prompt, size: size, name: name);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WordListDetailScreen(listId: detail.id, initialDetail: detail),
        ),
      );
      await _refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate list: HTTP ${e.statusCode}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate list: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Word lists'),
        actions: [
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
    );
  }
}
