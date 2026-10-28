import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final class AudioSnapshot {
  const AudioSnapshot(
    this.position,
    this.duration,
    this.playing, {
    this.ended = false,
  });
  final int position, duration;
  final bool playing, ended;
}

abstract interface class AudioPort {
  Future<void> open(String reference);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(int milliseconds);
  Future<void> volume(double value);
  Future<AudioSnapshot> snapshot();
  Future<void> dispose();
}

final class NativeAudioPort implements AudioPort {
  const NativeAudioPort();
  static const channel = MethodChannel('index/audio');
  @override
  Future<void> open(String reference) {
    final uri = Uri.parse(reference);
    if (uri.scheme != 'file' && uri.scheme != 'content')
      throw ArgumentError('Référence audio locale requise.');
    return channel.invokeMethod<void>(
      'open',
      uri.scheme == 'file'
          ? uri.toFilePath(windows: Platform.isWindows)
          : reference,
    );
  }

  @override
  Future<void> play() => channel.invokeMethod<void>('play');
  @override
  Future<void> pause() => channel.invokeMethod<void>('pause');
  @override
  Future<void> seek(int milliseconds) => channel
      .invokeMethod<void>('seek', milliseconds)
      .timeout(const Duration(seconds: 15));
  @override
  Future<void> volume(double value) =>
      channel.invokeMethod<void>('volume', value.clamp(0, 1));
  @override
  Future<AudioSnapshot> snapshot() async {
    final r = await channel.invokeMapMethod<String, dynamic>('snapshot');
    return AudioSnapshot(
      r!['position'] as int,
      r['duration'] as int,
      r['playing'] == true,
      ended: r['ended'] == true,
    );
  }

  @override
  Future<void> dispose() => channel.invokeMethod<void>('release');
}

/// Garde anti-seek : dix secondes réellement jouées en zone de fin.
final class ListeningGuard {
  int? _last;
  int nearEndMs = 0;
  bool progressed = false, completed = false;
  void discontinuity(int position) {
    _last = position;
    nearEndMs = 0;
  }

  void observe(AudioSnapshot state) {
    final delta = _last == null ? 0 : state.position - _last!;
    _last = state.position;
    if (!state.playing && !state.ended) {
      nearEndMs = 0;
      return;
    }
    if (delta <= 0 || delta > 2000) {
      if (delta.abs() > 2000) nearEndMs = 0;
      return;
    }
    progressed = true;
    final near =
        state.duration > 0 &&
        (state.position >= state.duration * .95 ||
            state.duration - state.position <= 60000);
    nearEndMs = near ? nearEndMs + delta : 0;
    if (nearEndMs >= 10000) completed = true;
  }
}

typedef Checkpoint = void Function(
  String id,
  AudioSnapshot state,
  ListeningGuard guard,
  String status,
);

final class Playback extends ChangeNotifier {
  Playback(this.port, this.save, {this.autoPoll = true});
  final AudioPort port;
  final Checkpoint save;
  final bool autoPoll;
  Future<void> Function()? onEnded;
  bool _endedHandled = false;
  String? episodeId, reference;
  AudioSnapshot state = const AudioSnapshot(0, 0, false);
  ListeningGuard guard = ListeningGuard();
  double level = .8;
  String error = '';
  bool busy = false, _polling = false, _closed = false;
  int _savedAt = 0;
  Timer? _timer;
  Future<void>? _pending;

  Future<void> _command(Future<void> Function() action) async {
    if (_closed || busy) return;
    busy = true;
    error = '';
    notifyListeners();
    final task = action();
    _pending = task;
    try {
      await task;
    } catch (e) {
      error = 'Lecture interrompue : $e';
      try {
        await port.pause();
      } catch (_) {}
      state = AudioSnapshot(state.position, state.duration, false);
    } finally {
      busy = false;
      _pending = null;
      if (!_closed) notifyListeners();
    }
  }

  Future<void> start(String id, String ref, int resume) {
    final recovering = error.isNotEmpty;
    return _command(() async {
      await _waitPoll();
      if (episodeId != null) {
        await _pauseForCheckpoint(recovering);
        flush('paused');
      }
      episodeId = null;
      reference = null;
      state = const AudioSnapshot(0, 0, false);
      await port.open(ref).timeout(const Duration(seconds: 30));
      episodeId = id;
      reference = ref;
      guard = ListeningGuard();
      _endedHandled = false;
      var initial = await port.snapshot();
      final position = resume.clamp(
        0,
        initial.duration > 0 ? initial.duration : 2147483647,
      );
      await port.seek(position);
      await port.volume(level);
      state = AudioSnapshot(position, initial.duration, false);
      guard.discontinuity(position);
      _savedAt = position;
      flush('paused');
      await port.play();
      state = AudioSnapshot(position, initial.duration, true);
      if (autoPoll)
        _timer ??= Timer.periodic(
          const Duration(milliseconds: 250),
          (_) => unawaited(poll()),
        );
    });
  }

  Future<void> _waitPoll() async {
    while (_polling) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  Future<void> _pauseForCheckpoint(bool recovering) async {
    try {
      await port.pause();
    } catch (_) {
      if (!recovering) rethrow;
    }
    // Après une erreur du décodeur, ne pas redemander un snapshot au moteur
    // défaillant. Sauvegarder le dernier état connu ; un échec SQLite reste bloquant.
    if (!recovering) await _capture();
    state = AudioSnapshot(state.position, state.duration, false);
  }

  Future<void> _capture() async {
    state = await port.snapshot();
    guard.observe(state);
  }

  void flush(String status) {
    if (episodeId == null) return;
    save(episodeId!, state, guard, status);
    _savedAt = state.position;
  }

  Future<void> poll() async {
    if (_closed || busy || _polling || episodeId == null) return;
    _polling = true;
    try {
      final progressed = guard.progressed, completed = guard.completed;
      final wasPlaying = state.playing;
      await _capture();
      if ((state.position - _savedAt).abs() >= 5000 ||
          state.ended ||
          (wasPlaying && !state.playing)) {
        flush(state.playing ? 'playing' : 'paused');
      } else if (guard.progressed != progressed ||
          guard.completed != completed) {
        save(episodeId!, state, guard, state.playing ? 'playing' : 'paused');
      }
      if (state.ended) {
        _timer?.cancel();
        _timer = null;
      }
    } catch (e) {
      error = 'Suivi ou lecture impossible : $e';
      try {
        await port.pause();
      } catch (_) {}
      state = AudioSnapshot(state.position, state.duration, false);
    } finally {
      _polling = false;
      if (!_closed) notifyListeners();
    }
    if (!_closed && error.isEmpty && state.ended && !_endedHandled) {
      _endedHandled = true;
      await onEnded?.call();
    }
  }

  /// Arrêt demandé par l’utilisateur, distinct de la pause de sauvegarde.
  Future<void> rewind() => _command(() async {
    if (episodeId == null) return;
    await _waitPoll();
    await port.pause();
    await port.seek(0);
    _timer?.cancel();
    _timer = null;
    state = AudioSnapshot(0, state.duration, false);
    guard = ListeningGuard()..discontinuity(0);
    _endedHandled = false;
    flush('stopped');
  });

  Future<void> toggle() => _command(() async {
    if (episodeId == null) return;
    await _waitPoll();
    if (state.playing) {
      await port.pause();
      await _capture();
      flush('paused');
    } else {
      guard.discontinuity(state.position);
      await port.play();
      state = AudioSnapshot(state.position, state.duration, true);
      if (autoPoll)
        _timer ??= Timer.periodic(
          const Duration(milliseconds: 250),
          (_) => unawaited(poll()),
        );
    }
  });
  Future<void> stop() {
    final recovering = error.isNotEmpty;
    return _command(() async {
      if (episodeId == null) return;
      await _waitPoll();
      await _pauseForCheckpoint(recovering);
      flush('stopped');
      state = AudioSnapshot(state.position, state.duration, false);
      guard.discontinuity(state.position);
    });
  }

  Future<void> seek(int position) => _command(() async {
    if (episodeId == null) return;
    await _waitPoll();
    final playing = state.playing;
    final target = position.clamp(
      0,
      state.duration > 0 ? state.duration : 2147483647,
    );
    await port.seek(target);
    if (playing) await port.play();
    state = AudioSnapshot(target, state.duration, playing);
    guard.discontinuity(target);
    _endedHandled = false;
    flush(playing ? 'playing' : 'paused');
  });
  Future<void> setVolume(double value) => _command(() async {
    level = value.clamp(0, 1);
    if (episodeId != null) await port.volume(level);
  });
  Future<void> unload() async {
    await suspend();
    if (episodeId != null) await port.dispose();
    _timer?.cancel();
    _timer = null;
    episodeId = null;
    reference = null;
    state = const AudioSnapshot(0, 0, false);
    notifyListeners();
  }

  Future<void> suspend() async {
    if (_pending != null) await _pending;
    await stop();
    if (error.isNotEmpty) throw StateError(error);
  }

  Future<void> release() async {
    if (_closed) return;
    await suspend();
    _timer?.cancel();
    if (episodeId != null) await port.dispose();
    _closed = true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

String playbackTime(int value) {
  final seconds = max(0, value ~/ 1000);
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
