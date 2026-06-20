import 'package:just_audio/just_audio.dart';

/// Simple background music service that loops through a fixed playlist.
class BackgroundMusicService {
  BackgroundMusicService._();

  static final BackgroundMusicService instance =
      BackgroundMusicService._();

  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;

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
    await _player.setVolume(0.3);
    await _player.play();

    _initialized = true;
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
