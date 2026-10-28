import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:just_audio/just_audio.dart' show PlayerException;
import 'package:index_windows/audio_player.dart';
import 'package:index_windows/just_audio_port.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late JustAudioPlatform original;
  late TestAudioPlatform platform;
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          (_) async => null,
        );
    original = JustAudioPlatform.instance;
    platform = TestAudioPlatform();
    JustAudioPlatform.instance = platform;
  });
  tearDown(() {
    JustAudioPlatform.instance = original;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          null,
        );
  });

  test('WinRT adapter : lecture non bloquante, seek actif sans redémarrage et fin explicite', () async {
    final port = JustAudioPort();
    final playback = Playback(port, (_, _, _, _) {}, autoPoll: false);
    await playback
        .start('a', 'file:///C:/Mes%20MP3/%C3%89pisode.mp3', 4000)
        .timeout(const Duration(seconds: 2));
    expect(playback.error, isEmpty);
    await Future<void>.delayed(Duration.zero);
    final native = platform.last!;
    expect(native.uri, 'file:///C:/Mes%20MP3/%C3%89pisode.mp3');
    expect(native.pendingPlay!.isCompleted, isFalse);
    expect(playback.busy, isFalse);
    await playback.seek(65000);
    expect(native.playCalls, 1);
    expect(playback.state.position, 65000);
    expect(playback.state.playing, isTrue);
    native.emit(
      position: const Duration(seconds: 120),
      state: ProcessingStateMessage.completed,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final end = await port.snapshot();
    expect(end.ended, isTrue);
    expect(end.playing, isFalse);
    await playback.release();
    playback.dispose();
  });

  test(
    'Erreurs asynchrones remontées, pause et réouverture après libération',
    () async {
      final port = JustAudioPort();
      final playback = Playback(port, (_, _, _, _) {}, autoPoll: false);
      await playback.start('a', 'file:///C:/a.mp3', 0);
      platform.last!.emit(error: 500);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await playback.poll();
      expect(playback.error, contains('500'));
      expect(playback.state.playing, isFalse);
      // Un nouveau fichier recrée le moteur et efface l'erreur précédente.
      await playback.start('b', 'file:///C:/b.mp3', 0);
      expect(playback.error, isEmpty);
      expect(playback.episodeId, 'b');
      expect(playback.state.playing, isTrue);
      platform.last!.emit(error: 501);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await playback.poll();
      expect(playback.error, contains('501'));
      await playback.release();
      expect(platform.players, isEmpty);
      playback.dispose();
    },
  );

  test('Source distante refusée, échec de chargement récupérable et play rejeté capturé', () async {
    final port = JustAudioPort();
    await expectLater(
      port.open('https://example.invalid/a.mp3'),
      throwsArgumentError,
    );
    expect(platform.last, isNull);
    platform.failLoad = true;
    await expectLater(
      port.open('file:///C:/absent.mp3'),
      throwsA(isA<PlayerException>()),
    );
    platform.failLoad = false;
    await port.open('file:///C:/ok.mp3');
    await port.play();
    await Future<void>.delayed(Duration.zero);
    platform.last!.pendingPlay!.completeError(
      StateError('sortie audio indisponible'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await expectLater(
      port.snapshot(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('sortie audio indisponible'),
        ),
      ),
    );
    await port.dispose();
    await port.open('file:///C:/encore.mp3');
    expect((await port.snapshot()).duration, 120000);
    await port.dispose();
  });
}

class TestAudioPlatform extends JustAudioPlatform {
  TestPlayer? last;
  bool failLoad = false;
  final players = <String, TestPlayer>{};
  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    final player = TestPlayer(request.id, failLoad);
    players[request.id] = last = player;
    return player;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async {
    await players.remove(request.id)?.dispose(DisposeRequest());
    return DisposePlayerResponse();
  }
}

class TestPlayer extends AudioPlayerPlatform {
  TestPlayer(super.id, this.failLoad);
  final bool failLoad;
  final events = StreamController<PlaybackEventMessage>.broadcast();
  Duration position = Duration.zero;
  Completer<PlayResponse>? pendingPlay;
  int playCalls = 0;
  String? uri;
  void emit({
    Duration? position,
    ProcessingStateMessage state = ProcessingStateMessage.ready,
    int? error,
  }) {
    if (position != null) this.position = position;
    events.add(
      PlaybackEventMessage(
        processingState: state,
        updateTime: DateTime.now(),
        updatePosition: this.position,
        bufferedPosition: const Duration(seconds: 120),
        duration: const Duration(seconds: 120),
        icyMetadata: null,
        currentIndex: 0,
        androidAudioSessionId: null,
        errorCode: error,
        errorMessage: error == null ? null : 'Erreur de décodage',
      ),
    );
  }

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => events.stream;
  @override
  Future<LoadResponse> load(LoadRequest request) async {
    if (failLoad) throw PlatformException(code: '404', message: 'absent');
    final list = request.audioSourceMessage as ConcatenatingAudioSourceMessage;
    uri = (list.children.first as UriAudioSourceMessage).uri;
    emit(position: request.initialPosition ?? Duration.zero);
    return LoadResponse(duration: const Duration(seconds: 120));
  }

  @override
  Future<PlayResponse> play(PlayRequest request) {
    playCalls++;
    pendingPlay = Completer<PlayResponse>();
    return pendingPlay!.future;
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    if (pendingPlay?.isCompleted == false)
      pendingPlay!.complete(PlayResponse());
    return PauseResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    emit(position: request.position);
    return SeekResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();
  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse();
  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse();
  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
    SetSkipSilenceRequest request,
  ) async => SetSkipSilenceResponse();
  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();
  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async => SetShuffleModeResponse();
  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
    SetShuffleOrderRequest request,
  ) async => SetShuffleOrderResponse();
  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    if (pendingPlay?.isCompleted == false)
      pendingPlay!.complete(PlayResponse());
    await events.close();
    return DisposeResponse();
  }
}
