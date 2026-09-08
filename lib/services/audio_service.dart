import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Which background loop is playing — general everywhere, or the game's own
/// while a Word Builder screen is on top (CLAUDE.md-adjacent: play should
/// sound like a different place from practice, the way its tile already
/// looks like one).
enum BackgroundTrack { general, game }

/// Background music, short sound effects and Tamil letter pronunciation.
///
/// Every asset here is a placeholder synthesized by `tools/gen_audio.py` —
/// plain sine tones on a pentatonic scale, so nothing can land dissonant or
/// jarring for a 4-8 year old, and nothing borrowed or licensed. Real
/// recordings can replace any file under `assets/audio/` later with zero
/// code change, the same fallback architecture CLAUDE.md section 9 already
/// planned for letter sounds.
///
/// Every call takes its own `enabled` flag rather than reading settings
/// itself — the service holds no [WidgetRef], so whoever calls it (already
/// watching [settingsStoreProvider]) decides. Every call is also wrapped
/// against failure: a missing or unplayable asset must never crash a
/// tracing session over something as small as sound.
class AudioService {
  final AudioPlayer _music = AudioPlayer()..setReleaseMode(ReleaseMode.loop);
  final AudioPlayer _sfx = AudioPlayer();
  final FlutterTts _tts = FlutterTts();

  BackgroundTrack? _currentTrack;
  bool _ttsConfigured = false;

  AudioService() {
    // Every AudioPlayer requests exclusive Android audio focus (AUDIOFOCUS_GAIN)
    // by default, which pauses whatever else is playing — including our own
    // looping _music player, on a *different* AudioPlayer instance. A click or
    // the celebration "ding" would silently pause the background music and
    // nothing ever resumed it. mixWithOthers tells the OS this is a short,
    // secondary sound that should never take focus away from anything.
    unawaited(
      _sfx.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      ),
    );
  }

  static const _tracks = {
    BackgroundTrack.general: 'audio/music/general_loop.wav',
    BackgroundTrack.game: 'audio/music/game_loop.wav',
  };

  /// Starts [track] if it is not already playing, or stops the music if
  /// [enabled] is false. Safe to call on every build — a no-op once the
  /// right track is already looping.
  Future<void> ensureBackgroundMusic(BackgroundTrack track, {required bool enabled}) async {
    if (!enabled) {
      await stopBackgroundMusic();
      return;
    }
    if (_currentTrack == track) return;
    _currentTrack = track;
    try {
      await _music.stop();
      await _music.setVolume(0.35);
      await _music.play(AssetSource(_tracks[track]!));
    } catch (_) {
      // No asset yet, or the platform has no audio output — play continues
      // silently rather than not at all.
    }
  }

  Future<void> stopBackgroundMusic() async {
    if (_currentTrack == null) return;
    _currentTrack = null;
    try {
      await _music.stop();
    } catch (_) {}
  }

  /// Silences the music without forgetting which track was playing, so the
  /// app can back off cleanly when it is backgrounded — pressing the system
  /// back button (or the home button) leaves the process alive for a while
  /// with nothing telling the native player to stop, and it would otherwise
  /// keep looping after the child has left the app entirely.
  Future<void> pauseBackgroundMusic() async {
    try {
      await _music.pause();
    } catch (_) {}
  }

  /// Undoes [pauseBackgroundMusic] when the app comes back to the
  /// foreground. A no-op if nothing was playing to begin with.
  Future<void> resumeBackgroundMusic() async {
    if (_currentTrack == null) return;
    try {
      await _music.resume();
    } catch (_) {}
  }

  Future<void> playClick({required bool enabled}) async {
    if (!enabled) return;
    try {
      await _sfx.play(AssetSource('audio/sfx/click.wav'), volume: 0.6);
    } catch (_) {}
  }

  Future<void> playCelebration({required bool enabled}) async {
    if (!enabled) return;
    try {
      await _sfx.play(AssetSource('audio/sfx/celebration.wav'), volume: 0.8);
    } catch (_) {}
  }

  /// Speaks Tamil text — used for letter pronunciation (uyir only for now).
  /// TTS rather than a recording: no artist has voiced these yet, and this
  /// is exactly the fallback CLAUDE.md section 9 names for that gap.
  Future<void> speak(String text, {required bool enabled}) async {
    if (!enabled || text.isEmpty) return;
    try {
      if (!_ttsConfigured) {
        await _tts.setLanguage('ta-IN');
        await _tts.setSpeechRate(0.42);
        await _tts.setVolume(1.0);
        _ttsConfigured = true;
      }
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // No Tamil voice on this device — the tracing screen still works
      // without it, same as any other missing audio here.
    }
  }

  /// Cuts off mid-sentence pronunciation — used alongside
  /// [pauseBackgroundMusic] when the app is backgrounded, so a letter or
  /// word does not keep being read out to an empty screen.
  Future<void> stopSpeech() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  void dispose() {
    _music.dispose();
    _sfx.dispose();
    _tts.stop();
  }
}

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(service.dispose);
  return service;
});
