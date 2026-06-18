import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'models.dart';

class SessionState extends ChangeNotifier {
  SessionState({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  UserInfo? _user;
  ChildProfile? _child;
  String? _token;
  bool _loading = false;
  String? _error;

  UserInfo? get user => _user;
  ChildProfile? get child => _child;
  ChildProfile? get childProfile => _child;
  String? get token => _token;
  bool get loading => _loading;
  String? get error => _error;

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  Future<void> signInWithIdToken(String idToken) async {
    _setError(null);
    _setLoading(true);
    try {
      final login = await api.loginWithGoogleIdToken(idToken);
      _token = login.token;
      _user = login.user;
      api.updateToken(_token);
    } on ApiException catch (e) {
      _setError('Login failed: HTTP ${e.statusCode}');
      rethrow;
    } catch (e) {
      _setError('Login failed: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadChildProfile() async {
    if (_token == null) return;
    _setError(null);
    _setLoading(true);
    try {
      final profile = await api.getChild();
      _child = profile;
      notifyListeners();
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        // No child yet; this is fine.
        _child = null;
        notifyListeners();
        return;
      }
      _setError('Failed to load child profile: HTTP ${e.statusCode}');
      rethrow;
    } catch (e) {
      _setError('Failed to load child profile: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> saveChildProfile({required int age, required String theme}) async {
    if (_token == null) {
      throw StateError('Not authenticated');
    }
    _setError(null);
    _setLoading(true);
    try {
      final saved = await api.upsertChild(age: age, theme: theme);
      _child = saved;
      notifyListeners();
    } on ApiException catch (e) {
      _setError('Failed to save child profile: HTTP ${e.statusCode}');
      rethrow;
    } catch (e) {
      _setError('Failed to save child profile: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void signOut() {
    _user = null;
    _child = null;
    _token = null;
    api.updateToken(null);
    notifyListeners();
  }

  Future<void> updateTtsSettings({
    required String engine,
    String? voice,
  }) async {
    if (_token == null) throw StateError('Not authenticated');

    _setError(null);
    _setLoading(true);

    try {
      final updated =
          await api.updateChildTtsSettings(engine: engine, voice: voice);
      _child = updated;
      notifyListeners();
    } on ApiException catch (e) {
      _setError('Failed to update TTS settings: HTTP ${e.statusCode}');
      rethrow;
    } catch (e) {
      _setError('Failed to update TTS settings: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
}
