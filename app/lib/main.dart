import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/child_profile_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/word_lists_screen.dart';
import 'session_state.dart';
import 'background_music_service.dart';
import 'design/sketch_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WordFriendApp());

  // Start background music without blocking app startup.
  // Any errors are caught so they don't crash the app.
  BackgroundMusicService.instance.initAndPlay().catchError((_) {});
}

class WordFriendApp extends StatelessWidget {
  const WordFriendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SessionState(),
      child: MaterialApp(
        title: 'WordFriend',
        theme: SketchTheme.pony(),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      context.read<SessionState>().restoreSession();
    }
  }

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
