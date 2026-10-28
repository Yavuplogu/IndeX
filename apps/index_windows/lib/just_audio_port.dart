import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'audio_player.dart';

/// Windows : WinRT MediaPlayer par just_audio_windows, enregistré par Flutter.
/// Création paresseuse : la consultation sans MP3 ne démarre aucun moteur audio.
final class JustAudioPort implements AudioPort {
  AudioPlayer? _player;
  StreamSubscription<PlayerException>? _errors;
  Object? _failure;

  AudioPlayer get _opened {
    final player = _player;
    if (player == null) throw StateError('Aucun audio ouvert.');
    return player;
  }

  @override
  Future<void> open(String reference) async {
    final uri = Uri.parse(reference);
    if (uri.scheme != 'file' || uri.hasQuery || uri.hasFragment) {
      throw ArgumentError('Référence de fichier audio local requise.');
    }
    await dispose();
    final player = AudioPlayer(
      handleInterruptions: false,
      handleAudioSessionActivation: false,
    );
    _player = player;
    _failure = null;
    _errors = player.errorStream.listen((error) {
      if (identical(_player, player)) _failure = error;
    });
    try {
      await player.setAudioSource(AudioSource.uri(uri));
      _checkError();
    } catch (_) {
      await dispose();
      rethrow;
    }
  }

  void _checkError() {
    final failure = _failure;
    if (failure != null) throw StateError('Lecteur Windows : $failure');
  }

  @override
  Future<void> play() async {
    _checkError();
    final player = _opened;
    // play() reste en attente jusqu'à pause/fin : ne pas bloquer Playback.busy.
    // Les erreurs tardives sont conservées et relevées au prochain snapshot.
    unawaited(
      player.play().catchError((Object error) {
        if (identical(_player, player)) _failure = error;
      }),
    );
  }

  @override
  Future<void> pause() async {
    await _opened.pause();
  }

  @override
  Future<void> seek(int milliseconds) async {
    _checkError();
    if (milliseconds < 0) throw ArgumentError('Position négative.');
    // just_audio conserve la lecture active pendant le déplacement.
    await _opened
        .seek(Duration(milliseconds: milliseconds))
        .timeout(const Duration(seconds: 15));
    _checkError();
  }

  @override
  Future<void> volume(double value) => _opened.setVolume(value.clamp(0, 1));

  @override
  Future<AudioSnapshot> snapshot() async {
    _checkError();
    final player = _opened;
    final ended = player.processingState == ProcessingState.completed;
    return AudioSnapshot(
      player.position.inMilliseconds,
      player.duration?.inMilliseconds ?? 0,
      player.playing &&
          !ended &&
          player.processingState == ProcessingState.ready,
      ended: ended,
    );
  }

  @override
  Future<void> dispose() async {
    final player = _player;
    _player = null;
    await _errors?.cancel();
    _errors = null;
    _failure = null;
    await player?.dispose();
  }
}
