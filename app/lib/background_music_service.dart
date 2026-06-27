import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple background music service that loops through a fixed playlist.
class BackgroundMusicService {
  BackgroundMusicService._();

  static final BackgroundMusicService instance =
      BackgroundMusicService._();

  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;
  double _currentVolume = 0.3;
  double _preTtsVolume = 0.3;

  Future<void> initAndPlay() async {
    if (_initialized) return;

    final playlist = ConcatenatingAudioSource(children: [
      AudioSource.asset(
        'assets/soundtracks/cotton-toys-soundroll-main-version-16753-01-17.mp3',
      ),
      AudioSource.asset(
        'assets/soundtracks/pixeltown-color-parade-main-version-41716-01-53.mp3',
      ),
      AudioSource.asset(
        'assets/soundtracks/tumbling-danijel-zambo-main-version-42313-01-05.mp3',
      ),
    ]);

    await _player.setAudioSource(playlist);
    await _player.setLoopMode(LoopMode.all);

    // Load persisted volume (default 0.3 if not set)
    final prefs = await SharedPreferences.getInstance();
    _currentVolume = prefs.getDouble('music_volume') ?? 0.3;
    _preTtsVolume = _currentVolume;

    await _player.setVolume(_currentVolume);
    await _player.play();

    _initialized = true;
  }

  Future<void> dispose() async {
    await _player.dispose();
  }

  Future<void> pause() async {
    if (_initialized) {
      await _player.pause();
    }
  }

  Future<void> resume() async {
    if (_initialized) {
      await _player.play();
    }
  }

  /// Set background music volume directly (0.0 - 1.0).
  Future<void> updateVolume(double value) async {
    _currentVolume = value.clamp(0.0, 1.0);
    _preTtsVolume = _currentVolume;

    if (_initialized) {
      await _player.setVolume(_currentVolume);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('music_volume', _currentVolume);
  }

  /// Fade out and mute background music for TTS playback.
  Future<void> duckForTts({Duration duration = const Duration(milliseconds: 400)}) async {
    if (!_initialized) return;

    _preTtsVolume = _currentVolume;
    await _fadeVolume(to: 0.0, duration: duration);
  }

  /// Fade music back in after TTS playback.
  Future<void> restoreAfterTts({Duration duration = const Duration(milliseconds: 600)}) async {
    if (!_initialized) return;

    await _fadeVolume(to: _preTtsVolume, duration: duration);
  }

  Future<void> _fadeVolume({required double to, required Duration duration}) async {
    const steps = 10;
    final from = _currentVolume;
    final stepDuration = duration ~/ steps;

    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final value = from + (to - from) * t;
      _currentVolume = value.clamp(0.0, 1.0);
      await _player.setVolume(_currentVolume);
      await Future.delayed(stepDuration);
    }
  }
}
