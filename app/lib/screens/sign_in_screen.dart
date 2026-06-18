import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../session_state.dart';

/// Set via `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`.
///
/// For Android, this should be the OAuth "Web application" client ID.
const String googleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue: '',
);

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _submitting = false;

  Future<void> _signInWithGoogle() async {
    if (googleServerClientId.isEmpty) {
      // Keep this error actionable; without serverClientId, idToken will be null on Android.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Missing GOOGLE_SERVER_CLIENT_ID. Run with --dart-define=GOOGLE_SERVER_CLIENT_ID=... (use the Web client id).',
          ),
        ),
      );
      return;
    }

    final session = context.read<SessionState>();
    setState(() {
      _submitting = true;
    });

    try {
      final googleSignIn = GoogleSignIn(
        // Request OpenID Connect so we can get an ID token.
        scopes: const <String>['email', 'openid', 'profile'],
        serverClientId: googleServerClientId,
      );

      final account = await googleSignIn.signIn();
      if (account == null) {
        // User cancelled.
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError(
          'Google did not return an idToken. Ensure GOOGLE_SERVER_CLIENT_ID is set to the Web client id, and the Android OAuth client is configured with your debug SHA-1.',
        );
      }

      await session.signInWithIdToken(idToken);
      await session.loadChildProfile();
    } catch (e) {
      // `SessionState` will store API errors; this covers local/plugin errors too.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in to WordFriend'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Sign in with Google to continue.'),
            const SizedBox(height: 16),
            if (session.error != null)
              Text(
                session.error!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submitting ? null : _signInWithGoogle,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign in with Google'),
            ),
          ],
        ),
      ),
    );
  }
}
