import 'dart:async';
import 'dart:io';

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
    final port = JustAudioPort(fileProbe: (_) async {});
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
      final port = JustAudioPort(fileProbe: (_) async {});
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

  test('Ouverture bloquée : timeout annule le moteur, journalise et permet une autre piste', () async {
    platform.loading = true;
    final journal = <Map<String, Object?>>[];
    final port = JustAudioPort(
      fileProbe: (_) async {},
      openTimeout: const Duration(milliseconds: 50),
      disposeTimeout: const Duration(seconds: 1),
      onDiagnostic: journal.add,
    );
    final playback = Playback(port, (_, _, _, _) {}, autoPoll: false);
    await playback
        .start('bad', 'file:///C:/Zimbabwe.mp3', 0)
        .timeout(const Duration(seconds: 2));
    expect(playback.busy, isFalse);
    expect(playback.episodeId, isNull);
    expect(playback.error, contains('Windows n’a pas confirmé'));
    expect(platform.players, isEmpty);
    expect(
      journal.any(
        (e) => e['event'] == 'open_failed' && e['file'] == 'Zimbabwe.mp3',
      ),
      isTrue,
    );
    platform.loading = false;
    await playback.start('good', 'file:///C:/Foccart.mp3', 0);
    expect(playback.error, isEmpty);
    expect(playback.state.playing, isTrue);
    await playback.release();
    playback.dispose();
  });

  test('Erreur native pendant loading : remontée immédiate sans attendre le timeout', () async {
    platform.loading = true;
    platform.openError = true;
    final port = JustAudioPort(
      fileProbe: (_) async {},
      openTimeout: const Duration(seconds: 2),
    );
    await expectLater(
      port.open('file:///C:/Haiti.mp3').timeout(const Duration(seconds: 1)),
      throwsA(isA<PlayerException>().having((e) => e.code, 'code', 1001)),
    );
    expect(platform.players, isEmpty);
    await port.dispose();
  });

  test(
    'Chemin local absent : erreur explicite avant tout moteur Windows',
    () async {
      final root = Directory.systemTemp.createTempSync(
        'index-audio-file-access-',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final port = JustAudioPort(fileProbe: verifyLocalAudioFile);
      final missing = File('${root.path}/Rhodésie (1 sur 2).mp3');
      await expectLater(
        port.open(missing.uri.toString()),
        throwsA(isA<FileSystemException>()),
      );
      expect(platform.last, isNull);
      await port.dispose();
    },
  );

  test(
    'Fichier Unicode lisible transmis sans changer ses octets ou sa référence',
    () async {
      final root = Directory.systemTemp.createTempSync(
        'index-audio-exact-path-',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final file = File('${root.path}/Haïti (2 sur 2) %20 + #.mp3')
        ..writeAsBytesSync([1, 2, 3]);
      final events = <Map<String, Object?>>[];
      final port = JustAudioPort(
        fileProbe: verifyLocalAudioFile,
        onDiagnostic: events.add,
      );
      await port.open(file.uri.toString());
      expect(platform.last!.uri, file.uri.toString());
      expect(file.readAsBytesSync(), [1, 2, 3]);
      expect(events.any((event) => event['event'] == 'file_access_ok'), isTrue);
      await port.dispose();
    },
  );

  test('Source distante refusée, échec de chargement récupérable et play rejeté capturé', () async {
    final port = JustAudioPort(fileProbe: (_) async {});
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
  bool failLoad = false, loading = false, openError = false;
  final players = <String, TestPlayer>{};
  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    final player = TestPlayer(request.id, failLoad, loading, openError);
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
  TestPlayer(super.id, this.failLoad, this.loading, this.openError);
  final bool failLoad, loading, openError;
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
    if (loading) {
      emit(state: ProcessingStateMessage.loading);
      if (openError)
        Timer.run(() {
          if (!events.isClosed)
            emit(state: ProcessingStateMessage.loading, error: 1001);
        });
      return LoadResponse(duration: null);
    }
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
