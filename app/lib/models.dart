class UserInfo {
  UserInfo({required this.id, this.email});

  final String id;
  final String? email;
}

class ChildProfile {
  ChildProfile({required this.id, required this.age, required this.theme});

  final String id;
  final int age;
  final String theme; // 'pony' | 'lego'

  factory ChildProfile.fromJson(Map<String, dynamic> json) {
    return ChildProfile(
      id: json['id'] as String,
      age: (json['age'] as num).toInt(),
      theme: json['theme'] as String,
    );
  }
}

class WordListSummary {
  WordListSummary({
    required this.id,
    required this.name,
    required this.source,
    this.prompt,
    this.wordCount,
    this.createdAt,
  });

  final String id;
  final String name;
  final String source; // 'manual' | 'ai'
  final String? prompt;
  final int? wordCount;
  final DateTime? createdAt;

  factory WordListSummary.fromJson(Map<String, dynamic> json) {
    return WordListSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      source: json['source'] as String,
      prompt: json['prompt'] as String?,
      wordCount: json['word_count'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

class WordInList {
  WordInList({
    required this.id,
    required this.spelling,
    this.phonicsPattern,
    this.position,
  });

  final String id;
  final String spelling;
  final String? phonicsPattern;
  final int? position;

  factory WordInList.fromJson(Map<String, dynamic> json) {
    return WordInList(
      id: json['id'] as String,
      spelling: json['spelling'] as String,
      phonicsPattern: json['phonics_pattern'] as String?,
      position: (json['position'] as int?),
    );
  }
}

class WordListDetail {
  WordListDetail({
    required this.id,
    required this.name,
    required this.source,
    this.prompt,
    this.createdAt,
    this.updatedAt,
    required this.words,
  });

  final String id;
  final String name;
  final String source;
  final String? prompt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<WordInList> words;

  factory WordListDetail.fromJson(Map<String, dynamic> json) {
    final wordsJson = (json['words'] as List<dynamic>? ?? []);
    return WordListDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      source: json['source'] as String,
      prompt: json['prompt'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      words:
          wordsJson.map((w) => WordInList.fromJson(w as Map<String, dynamic>)).toList(),
    );
  }
}

class QuizWord {
  QuizWord({required this.id, required this.spelling, this.phonicsPattern});

  final String id;
  final String spelling;
  final String? phonicsPattern;

  factory QuizWord.fromJson(Map<String, dynamic> json) {
    return QuizWord(
      id: json['id'] as String,
      spelling: json['spelling'] as String,
      phonicsPattern: json['phonics_pattern'] as String?,
    );
  }
}

class QuizSession {
  QuizSession({
    required this.id,
    required this.mode,
    required this.wordListId,
    this.startedAt,
    this.completedAt,
    required this.words,
  });

  final String id;
  final String mode; // 'listen_type' | 'read_say'
  final String wordListId;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<QuizWord> words;

  factory QuizSession.fromJson(Map<String, dynamic> json) {
    final wordsJson = (json['words'] as List<dynamic>? ?? []);
    return QuizSession(
      id: json['id'] as String,
      mode: json['mode'] as String,
      wordListId: json['wordListId'] as String,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'].toString())
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
      words:
          wordsJson.map((w) => QuizWord.fromJson(w as Map<String, dynamic>)).toList(),
    );
  }
}

class QuizAttemptResult {
  QuizAttemptResult({
    required this.wordId,
    required this.score,
    required this.isCorrect,
  });

  final String wordId;
  final int score;
  final bool isCorrect;

  factory QuizAttemptResult.fromJson(Map<String, dynamic> json) {
    return QuizAttemptResult(
      wordId: json['wordId'] as String,
      score: (json['score'] as num).toInt(),
      isCorrect: json['isCorrect'] as bool,
    );
  }
}

class LoginResponse {
  LoginResponse({required this.token, required this.user});

  final String token;
  final UserInfo user;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>;
    return LoginResponse(
      token: json['token'] as String,
      user: UserInfo(
        id: userJson['id'] as String,
        email: userJson['email'] as String?,
      ),
    );
  }
}
