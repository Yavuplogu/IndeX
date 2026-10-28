import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';

import 'audio_player.dart';

Future<void> verifyLocalAudioFile(Uri uri) async {
  final file = File.fromUri(uri);
  if (!await file.exists()) {
    throw FileSystemException(
      'Le MP3 associé est introuvable ou inaccessible. Relancez l’analyse du dossier.',
      file.path,
    );
  }
  // Vérifier les droits sans lire ni copier le contenu du MP3.
  final handle = await file.open(mode: FileMode.read);
  await handle.close();
}

/// Windows : WinRT MediaPlayer par just_audio_windows, enregistré par Flutter.
final class JustAudioPort implements AudioPort {
  JustAudioPort({
    this.openTimeout = const Duration(seconds: 20),
    this.disposeTimeout = const Duration(seconds: 3),
    this.onDiagnostic,
    this.fileProbe = verifyLocalAudioFile,
  });
  final Duration openTimeout, disposeTimeout;
  final Future<void> Function(Uri) fileProbe;
  final void Function(Map<String, Object?> event)? onDiagnostic;
  AudioPlayer? _player;
  StreamSubscription<PlayerException>? _errors;
  StreamSubscription<PlayerState>? _states;
  Object? _failure;

  void _log(
    String event, {
    String? source,
    Object? error,
    PlayerState? state,
    Uri? reference,
  }) {
    try {
      onDiagnostic?.call({
        'at': DateTime.now().toUtc().toIso8601String(),
        'event': event,
        if (source != null) 'file': source,
        if (reference != null) 'path': File.fromUri(reference).path,
        if (error != null) 'error': error.toString(),
        if (state != null) 'state': state.processingState.name,
        if (state != null) 'playing': state.playing,
        if (state != null) 'duration_ms': _player?.duration?.inMilliseconds,
        if (state != null) 'position_ms': _player?.position.inMilliseconds,
      });
    } catch (_) {
      // Un journal indisponible ne remplace pas le suivi SQLite et ne bloque pas l'audio.
    }
  }

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
    final source = uri.pathSegments.last;
    _log('open', source: source, reference: uri);
    final watch = Stopwatch()..start();
    try {
      await fileProbe(uri).timeout(openTimeout);
      _log('file_access_ok', source: source);
    } catch (error) {
      _log('file_access_failed', source: source, error: error);
      rethrow;
    }
    final player = AudioPlayer(
      handleInterruptions: false,
      handleAudioSessionActivation: false,
    );
    final failed = Completer<Object>();
    _player = player;
    _failure = null;
    void recordFailure(Object error) {
      if (!identical(_player, player)) return;
      _failure = error;
      _log('native_error', source: source, error: error);
      if (!failed.isCompleted) failed.complete(error);
    }

    _errors = player.errorStream.listen(recordFailure, onError: recordFailure);
    _states = player.playerStateStream.listen((state) {
      if (identical(_player, player))
        _log('state', source: source, state: state);
    });
    try {
      // Une erreur native doit débloquer l'ouverture même si le backend reste loading.
      await Future.any<void>([
        () async {
          await player.setAudioSource(AudioSource.uri(uri));
          // Un événement idle précoce ne signifie pas que le fichier est prêt.
          await player.processingStateStream.firstWhere(
            (state) =>
                state == ProcessingState.ready ||
                state == ProcessingState.completed,
          );
        }(),
        failed.future.then<void>((error) => throw error),
      ]).timeout(
        openTimeout - watch.elapsed > Duration.zero
            ? openTimeout - watch.elapsed
            : Duration.zero,
        onTimeout: () {
          throw TimeoutException(
            'Windows n’a pas confirmé l’ouverture du MP3.',
            openTimeout,
          );
        },
      );
      _checkError();
      _log('opened', source: source);
    } catch (error) {
      _log('open_failed', source: source, error: error);
      // Future.timeout ne détruit pas sa source : annuler réellement le lecteur.
      try {
        await dispose();
      } catch (cleanup) {
        _log('cleanup_failed', source: source, error: cleanup);
      }
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
    // Le Future reste en attente jusqu'à pause/fin : ne pas bloquer les commandes.
    unawaited(
      player.play().catchError((Object error) {
        if (identical(_player, player)) {
          _failure = error;
          _log('play_failed', error: error);
        }
      }),
    );
  }

  @override
  Future<void> pause() => _opened.pause();

  @override
  Future<void> seek(int milliseconds) async {
    _checkError();
    if (milliseconds < 0) throw ArgumentError('Position négative.');
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
    final cleanup = <Future<void>>[
      if (_errors != null) _errors!.cancel(),
      if (_states != null) _states!.cancel(),
      if (player != null) player.dispose(),
    ];
    _errors = null;
    _states = null;
    _failure = null;
    await Future.wait<void>(cleanup).timeout(disposeTimeout);
  }
}
