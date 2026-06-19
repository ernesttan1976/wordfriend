import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../session_state.dart';
import '../constants.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _submitting = false;
  late final GoogleSignIn _googleSignIn;
  bool _hasGoogleSession = false;

  @override
  void initState() {
    super.initState();
    _googleSignIn = GoogleSignIn(
      scopes: const <String>['email', 'openid', 'profile'],
      serverClientId: googleServerClientId,
    );
    _checkExistingGoogleSession();
  }

  Future<void> _checkExistingGoogleSession() async {
    final account = await _googleSignIn.signInSilently();
    if (!mounted) return;
    setState(() {
      _hasGoogleSession = account != null;
    });
  }

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
      final account = await _googleSignIn.signIn();
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
      setState(() {
        _hasGoogleSession = true;
      });
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

  Future<void> _signOutGoogle() async {
    await _googleSignIn.signOut();
    if (!mounted) return;
    setState(() {
      _hasGoogleSession = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Word Friend',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Image.asset(
                        'assets/monster.png',
                        height: 280,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (session.error != null)
                      Text(
                        session.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    if (session.error != null) const SizedBox(height: 16),
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
                    if (_hasGoogleSession) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _signOutGoogle,
                        child: const Text('Sign out of Google'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
