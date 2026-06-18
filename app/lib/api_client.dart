import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'constants.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiException($statusCode): $body';
}

class ApiClient {
  ApiClient({http.Client? client})
      : _client = client ?? http.Client(),
        baseUrl = apiBaseUrl;

  final String baseUrl;
  final http.Client _client;
  String? _token;

  void updateToken(String? token) {
    _token = token;
  }

  Uri _uri(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBase$normalizedPath');
  }

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> _handleJsonResponse(http.Response resp) async {
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.body.isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw ApiException(resp.statusCode, 'Expected JSON object');
    }
    throw ApiException(resp.statusCode, resp.body);
  }

  Future<List<dynamic>> _handleJsonListResponse(http.Response resp) async {
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.body.isEmpty) return const <dynamic>[];
      final decoded = jsonDecode(resp.body);
      if (decoded is List<dynamic>) {
        return decoded;
      }
      throw ApiException(resp.statusCode, 'Expected JSON array');
    }
    throw ApiException(resp.statusCode, resp.body);
  }

  // Auth

  Future<LoginResponse> loginWithGoogleIdToken(String idToken) async {
    final resp = await _client.post(
      _uri('/auth/google'),
      headers: _headers(),
      body: jsonEncode(<String, dynamic>{'idToken': idToken}),
    );
    final json = await _handleJsonResponse(resp);
    return LoginResponse.fromJson(json);
  }

  // Child profile

  Future<ChildProfile?> getChild() async {
    final resp = await _client.get(_uri('/child'), headers: _headers());
    if (resp.statusCode == 404) {
      return null;
    }
    final json = await _handleJsonResponse(resp);
    return ChildProfile.fromJson(json);
  }

  Future<ChildProfile> upsertChild({required int age, required String theme}) async {
    final resp = await _client.put(
      _uri('/child'),
      headers: _headers(),
      body: jsonEncode(<String, dynamic>{
        'age': age,
        'theme': theme,
      }),
    );
    final json = await _handleJsonResponse(resp);
    return ChildProfile.fromJson(json);
  }

  // Word lists

  Future<List<WordListSummary>> listWordLists() async {
    final resp = await _client.get(_uri('/word-lists'), headers: _headers());
    final list = await _handleJsonListResponse(resp);
    return list
        .map((item) => WordListSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<WordListDetail> getWordList(String id) async {
    final resp = await _client.get(_uri('/word-lists/$id'), headers: _headers());
    final json = await _handleJsonResponse(resp);
    return WordListDetail.fromJson(json);
  }

  Future<WordListDetail> generateWordList({
    required String prompt,
    int size = 10,
    String? name,
  }) async {
    final resp = await _client.post(
      _uri('/word-lists/generate'),
      headers: _headers(),
      body: jsonEncode(<String, dynamic>{
        'prompt': prompt,
        'size': size,
        if (name != null && name.isNotEmpty) 'name': name,
      }),
    );
    final json = await _handleJsonResponse(resp);
    final listJson = json['list'] as Map<String, dynamic>;
    final wordsJson = (json['words'] as List<dynamic>? ?? <dynamic>[]);

    final base = WordListSummary.fromJson(listJson);
    final words = wordsJson
        .map((w) => WordInList.fromJson(w as Map<String, dynamic>))
        .toList();

    return WordListDetail(
      id: base.id,
      name: base.name,
      source: base.source,
      prompt: base.prompt,
      createdAt: base.createdAt,
      updatedAt: null,
      words: words,
    );
  }

  // Quiz

  Future<QuizSession> createQuizSession({
    required String wordListId,
    required String mode, // 'listen_type' | 'read_say'
    int size = 10,
  }) async {
    final resp = await _client.post(
      _uri('/quiz-sessions'),
      headers: _headers(),
      body: jsonEncode(<String, dynamic>{
        'wordListId': wordListId,
        'mode': mode,
        'size': size,
      }),
    );
    final json = await _handleJsonResponse(resp);
    return QuizSession.fromJson(json);
  }

  Future<QuizAttemptResult> submitQuizAttempt({
    required String sessionId,
    required String wordId,
    String? typedAnswer,
    String? speechRecognized,
    int? score,
  }) async {
    final body = <String, dynamic>{
      'wordId': wordId,
      if (typedAnswer != null) 'typedAnswer': typedAnswer,
      if (speechRecognized != null) 'speechRecognized': speechRecognized,
      if (score != null) 'score': score,
    };

    final resp = await _client.post(
      _uri('/quiz-sessions/$sessionId/attempts'),
      headers: _headers(),
      body: jsonEncode(body),
    );

    final json = await _handleJsonResponse(resp);
    return QuizAttemptResult.fromJson(json);
  }
}
