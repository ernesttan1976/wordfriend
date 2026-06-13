import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/child_profile_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/word_lists_screen.dart';
import 'session_state.dart';

void main() {
  runApp(const WordFriendApp());
}

class WordFriendApp extends StatelessWidget {
  const WordFriendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SessionState(),
      child: MaterialApp(
        title: 'WordFriend',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();

    if (session.token == null) {
      return const SignInScreen();
    }

    if (session.child == null) {
      return const ChildProfileScreen();
    }

    return const WordListsScreen();
  }
}
