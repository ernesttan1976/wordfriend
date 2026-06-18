import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../session_state.dart';

class QuizStatsScreen extends StatefulWidget {
  const QuizStatsScreen({super.key});

  @override
  State<QuizStatsScreen> createState() => _QuizStatsScreenState();
}

class _QuizStatsScreenState extends State<QuizStatsScreen> {
  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    final api = context.read<SessionState>().api;
    _statsFuture = api.getQuizStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz stats')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load stats: ${snapshot.error}'),
              ),
            );
          }

          final data = snapshot.data ?? {};
          final total = data['totalAttempts'] ?? 0;
          final correct = data['correct'] ?? 0;
          final incorrect = data['incorrect'] ?? 0;
          final accuracy = data['accuracy'] ?? 0;
          final last7 = data['last7DaysAttempts'] ?? 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatTile(label: 'Total attempts', value: '$total'),
              _StatTile(label: 'Correct', value: '$correct'),
              _StatTile(label: 'Incorrect', value: '$incorrect'),
              _StatTile(label: 'Accuracy', value: '${accuracy.toString()}%'),
              _StatTile(label: 'Last 7 days', value: '$last7'),
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
