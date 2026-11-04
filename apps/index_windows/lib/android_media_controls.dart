import 'dart:async';

import 'package:flutter/services.dart';

import 'audio_player.dart';

/// Commandes système vers les mêmes règles que les boutons de l'application.
/// La session native extrapole sa progression : aucune métadonnée envoyée à 4 Hz.
final class AndroidMediaControls {
  AndroidMediaControls({
    required this.playback,
    required this.onCommand,
    required this.nowPlaying,
    required this.onError,
  }) {
    NativeAudioPort.channel.setMethodCallHandler(_handle);
    playback.addListener(refresh);
  }
  final Playback playback;
  final Future<void> Function(String action, int? position) onCommand;
  final Map<String, Object?>? Function() nowPlaying;
  final void Function(Object error) onError;
  Future<void> _pending = Future.value();
  String? _signature;
  bool _disposed = false;

  Future<Object?> _handle(MethodCall call) async {
    if (call.method != 'control') throw MissingPluginException(call.method);
    if (_disposed) throw StateError('Commandes média fermées.');
    final args = Map<String, Object?>.from(call.arguments as Map);
    final action = args['action'] as String;
    const supported = {
      'play',
      'pause',
      'stop',
      'previous',
      'next',
      'forward',
      'rewind',
      'seek',
      'tick',
      'backendLost',
      'focusPause',
      'focusResume',
    };
    if (!supported.contains(action))
      throw ArgumentError('Commande média inconnue.');
    final position = (args['value'] as num?)?.toInt();
    if (action == 'seek' &&
        (position == null || position < 0 || position > 2147483647)) {
      throw ArgumentError('Position média invalide.');
    }
    if ((action == 'focusPause' || action == 'focusResume') &&
        (position == null || position <= 0)) {
      throw ArgumentError('Jeton de reprise invalide.');
    }
    final task = _pending.then((_) async {
      if (_disposed) throw StateError('Commandes média fermées.');
      await playback.waitUntilIdle();
      if (_disposed) throw StateError('Commandes média fermées.');
      await onCommand(action, position);
      if (playback.error.isNotEmpty) throw StateError(playback.error);
    });
    _pending = task.catchError((Object error) {
      if (!_disposed) onError(error);
    });
    await task;
    return null;
  }

  void refresh() {
    if (_disposed) return;
    final metadata = nowPlaying();
    if (metadata == null) {
      _signature = null;
      return;
    }
    final signature =
        '${playback.sourceRevision}|${metadata['id']}|${metadata['title']}|${metadata['date']}|${playback.state.duration}';
    if (_signature == signature) return;
    _signature = signature;
    unawaited(
      NativeAudioPort.channel
          .invokeMethod<void>('metadata', metadata)
          .catchError((Object error) {
            if (!_disposed) onError(error);
          }),
    );
  }

  void dispose() {
    _disposed = true;
    playback.removeListener(refresh);
    NativeAudioPort.channel.setMethodCallHandler(null);
  }
}
