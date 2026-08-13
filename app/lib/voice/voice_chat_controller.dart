import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:path_provider/path_provider.dart';

import '../api_client.dart';
import '../background_music_service.dart';
import '../models.dart';

enum VoiceAgentStatus {
  disconnected,
  connecting,
  listening,
  thinking,
  speaking,
}

class ChatMessage {
  ChatMessage({required this.speaker, required this.text, DateTime? at})
      : at = at ?? DateTime.now();

  final String speaker; // 'child' | 'agent'
  final String text;
  final DateTime at;
}

class VoiceChatController extends ChangeNotifier {
  VoiceChatController({required ApiClient api, required ChildProfile child})
      : _api = api,
        _child = child;

  final ApiClient _api;
  final ChildProfile _child;

  final Room _room = Room();
  final AudioPlayer _ttsPlayer = AudioPlayer();
  EventsListener<RoomEvent>? _roomListener;
  CancelListenFunc? _cancelOnData;

  VoiceAgentStatus _status = VoiceAgentStatus.disconnected;
  bool _micEnabled = false;
  String _lastHeard = '';
  final List<ChatMessage> _messages = [];

  VoiceAgentStatus get status => _status;
  bool get connected => _status != VoiceAgentStatus.disconnected;
  bool get micEnabled => _micEnabled;
  String get lastHeard => _lastHeard;
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  Future<void> connectFreeMode({String? childName}) async {
    if (_status != VoiceAgentStatus.disconnected) return;

    _setStatus(VoiceAgentStatus.connecting);

    final lk = await _api.getLiveKitToken(identity: 'child_client');

    // Connect to the LiveKit room.
    await _room.connect(
      lk.wsUrl,
      lk.token,
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );

    // Subscribe to data messages (agent -> Flutter).
    _roomListener = _room.createListener();
    _cancelOnData = _roomListener!.on<DataReceivedEvent>((event) => _onData(event));

    // Default to open mic once connected.
    await setMicEnabled(true);

    // Provide minimal free-mode context.
    await sendJson({
      'type': 'free_context',
      'mode': 'free',
      if (childName != null) 'childName': childName,
    });

    _setStatus(VoiceAgentStatus.listening);
  }

  Future<void> sendLessonContext({
    required String quizSessionId,
    required String wordId,
    required String word,
    required List<String> attempts,
    required int hintLevel,
    required List<String> visibleHints,
  }) async {
    await sendJson({
      'type': 'lesson_context',
      'mode': 'quiz',
      'quizSessionId': quizSessionId,
      'wordId': wordId,
      'word': word,
      'attempts': attempts,
      'hintLevel': hintLevel,
      'visibleHints': visibleHints,
    });
  }

  Future<void> disconnect() async {
    if (_status == VoiceAgentStatus.disconnected) return;

    final cancelOnData = _cancelOnData;
    _cancelOnData = null;
    await cancelOnData?.call();
    await _roomListener?.dispose();
    _roomListener = null;

    await setMicEnabled(false);

    await _ttsPlayer.stop();
    await _room.disconnect();

    _lastHeard = '';
    _messages.clear();
    _setStatus(VoiceAgentStatus.disconnected);
  }

  Future<void> setMicEnabled(bool enabled) async {
    if (_micEnabled == enabled) return;

    // Let the SDK manage mic track lifecycle.
    await _room.localParticipant?.setMicrophoneEnabled(enabled);
    _micEnabled = enabled;
    notifyListeners();
  }

  Future<void> sendStarter(String text) async {
    await sendJson({'type': 'ui_event', 'event': 'starter', 'text': text});
  }

  Future<void> sendChildText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _messages.add(ChatMessage(speaker: 'child', text: trimmed));
    notifyListeners();

    await sendJson({'type': 'child_text', 'text': trimmed});
  }

  Future<void> sendJson(Map<String, dynamic> message) async {
    if (_status == VoiceAgentStatus.disconnected) return;
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(message)));
    await _room.localParticipant?.publishData(bytes, reliable: true);
  }

  void _onData(DataReceivedEvent event) {
    try {
      final raw = utf8.decode(event.data);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;

      final type = decoded['type'];
      if (type == 'transcript_partial' || type == 'transcript_final') {
        final text = (decoded['text'] as String?) ?? '';
        if (text.isNotEmpty) {
          _lastHeard = text;
          notifyListeners();
        }
        return;
      }

      if (type == 'agent_status') {
        final s = (decoded['status'] as String?) ?? '';
        _setStatus(_parseStatus(s));
        return;
      }

      if (type == 'agent_message') {
        final text = (decoded['text'] as String?) ?? '';
        if (text.isEmpty) return;
        _messages.add(ChatMessage(speaker: 'agent', text: text));
        notifyListeners();
        void _ = _speak(text);
        return;
      }
    } catch (_) {
      // Ignore malformed payloads.
    }
  }

  VoiceAgentStatus _parseStatus(String s) {
    switch (s) {
      case 'connecting':
        return VoiceAgentStatus.connecting;
      case 'listening':
        return VoiceAgentStatus.listening;
      case 'thinking':
        return VoiceAgentStatus.thinking;
      case 'speaking':
        return VoiceAgentStatus.speaking;
      default:
        return VoiceAgentStatus.listening;
    }
  }

  void _setStatus(VoiceAgentStatus next) {
    _status = next;
    notifyListeners();
  }

  Future<void> _speak(String text) async {
    try {
      // Duck background music while agent TTS plays.
      await BackgroundMusicService.instance.duckForTts(duration: Duration.zero);

      final bytes = await _api.postBytes(
        '/tts',
        body: {
          'text': text.length > 100 ? text.substring(0, 100) : text,
          // Prefer the child's configured OpenAI voice.
          'voice': _child.ttsVoice ?? 'alloy',
        },
      );

      // Write to temp file to avoid Android data URI issues.
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/agent_tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await file.writeAsBytes(bytes, flush: true);

      await _ttsPlayer.stop();
      await _ttsPlayer.setAudioSource(AudioSource.file(file.path));
      await _ttsPlayer.play();
    } catch (_) {
      // TTS failure should not break chat.
    } finally {
      await BackgroundMusicService.instance.restoreAfterTts(duration: Duration.zero);
    }
  }

  @override
  void dispose() {
    // ChangeNotifier.dispose is sync; best-effort cleanup.
    unawaited(disconnect());
    unawaited(_ttsPlayer.dispose());
    super.dispose();
  }
}
