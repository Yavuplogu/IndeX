import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:index_windows/android_media_controls.dart';
import 'package:index_windows/app_model.dart';
import 'package:index_windows/audio_player.dart';

import 'support/fake_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const codec = StandardMethodCodec();
  Future<void> send(String action, [int? value]) async {
    final result = Completer<ByteData?>();
    await messenger.handlePlatformMessage(
      'index/audio',
      codec.encodeMethodCall(
        MethodCall('control', {'action': action, 'value': value}),
      ),
      result.complete,
    );
    codec.decodeEnvelope((await result.future)!);
  }

  test('Commandes système : suivi partagé, pause idempotente, arrêt, fin et suivant non écouté', () async {
    final root = Directory.systemTemp.createTempSync('index-system-media-');
    final audio = FakeAudio();
    final files = <Map<String, String>>[];
    final model = AppModel(
      portableDirectory: root,
      android: true,
      audioPort: audio,
      pollAudio: false,
      documentOperation: (method, args) async {
        if (method == 'scan')
          return {'complete': true, 'files': files, 'errors': <String>[]};
        throw StateError(method);
      },
    );
    final metadata = <Map<dynamic, dynamic>>[];
    final errors = <Object>[];
    messenger.setMockMethodCallHandler(NativeAudioPort.channel, (call) async {
      if (call.method == 'metadata') metadata.add(call.arguments as Map);
      return null;
    });
    AndroidMediaControls? controls;
    try {
      // Fournisseur SAF simulé ; aucun MP3 n'est écrit ou téléchargé.
      await model.configure('${root.path}/user', '', true);
      for (final episode in model.catalog.take(3)) {
        files.add({
          'name': episode.originalName,
          'reference':
              'content://provider/tree/MP3/document/MP3%2F${episode.id}.mp3',
        });
      }
      await model.scan('content://provider/tree/MP3');
      expect(model.error, isEmpty);
      final queue = model.visible.where((e) => e.audioAvailable).toList();
      expect(queue.length, greaterThan(2));
      final first = queue.first;
      model.select(first);
      model.favorite(first);
      controls = AndroidMediaControls(
        playback: model.playback,
        onCommand: model.systemAudioCommand,
        nowPlaying: () {
          final e = model.playingEpisode;
          return e == null
              ? null
              : {'id': e.id, 'title': e.title, 'date': e.date};
        },
        onError: errors.add,
      );
      await model.playEpisode(first);
      audio.value = const AudioSnapshot(5000, 120000, true);
      await send('tick');
      expect(model.session!.listeningState(first.id)!['position_ms'], 5000);
      final metadataCount = metadata.length;
      audio.value = const AudioSnapshot(6000, 120000, true);
      await send('tick');
      expect(
        metadata.length,
        metadataCount,
        reason: 'Les ticks ne republient pas les métadonnées.',
      );
      await send('pause');
      await send('pause');
      expect(model.playback.state.playing, isFalse);
      expect(model.session!.listeningState(first.id)!['position_ms'], 6000);
      await send('play');
      await send('focusPause', 7);
      expect(model.playback.state.playing, isFalse);
      await send('focusResume', 7);
      expect(model.playback.state.position, 6000);
      expect(
        model.catalog.firstWhere((e) => e.id == first.id).favorite,
        isTrue,
      );
      await send('play');
      expect(model.playback.state.playing, isTrue);
      await send('forward');
      expect(model.playback.state.position, 16000);
      await send('rewind');
      expect(model.playback.state.position, 6000);
      await send('stop');
      expect(
        model.catalog.firstWhere((e) => e.id == first.id).status,
        'NON_ECOUTE',
      );
      expect(model.playback.state.position, 0);
      await send('play');
      model.session!.listened(queue[1].id, true);
      model.reload();
      await send('seek', 120000);
      audio.value = const AudioSnapshot(120000, 120000, false, ended: true);
      await send('tick');
      expect(
        model.catalog.firstWhere((e) => e.id == first.id).status,
        'ECOUTE',
      );
      expect(model.playback.episodeId, queue[2].id);
      await send('previous');
      expect(model.playback.episodeId, queue[1].id);
      await send('next');
      expect(model.playback.episodeId, queue[2].id);
      expect(
        model.selected!.id,
        first.id,
        reason: 'Les commandes système ne changent pas la fiche.',
      );
      final beforeReplay = metadata.length;
      await model.playEpisode(model.playingEpisode!);
      expect(
        metadata.length,
        greaterThan(beforeReplay),
        reason: 'Réouverture du même épisode : métadonnées republiées.',
      );
      expect(errors, isEmpty);
      await expectLater(send('seek', -1), throwsA(isA<PlatformException>()));
      await expectLater(
        send('focusResume', -1),
        throwsA(isA<PlatformException>()),
      );
      await expectLater(send('unknown'), throwsA(isA<PlatformException>()));
      await send('pause');
      audio.value = const AudioSnapshot(7000, 120000, false);
      await send('tick');
      await send('backendLost');
      expect(model.playback.episodeId, isNull);
      expect(model.session!.listeningState(queue[2].id)!['position_ms'], 7000);
      await send('play');
      expect(model.playback.state.position, 7000);
      expect(model.playback.state.playing, isTrue);
    } finally {
      controls?.dispose();
      messenger.setMockMethodCallHandler(NativeAudioPort.channel, null);
      await model.release();
      model.dispose();
      root.deleteSync(recursive: true);
    }
  });

  test('Acquittement natif après checkpoint durable seulement', () async {
    final audio = FakeAudio();
    var durable = -1, acknowledgements = 0;
    var diskFull = false;
    messenger.setMockMethodCallHandler(NativeAudioPort.channel, (call) async {
      switch (call.method) {
        case 'open':
          await audio.open(call.arguments as String);
        case 'play':
          await audio.play();
        case 'pause':
          await audio.pause();
        case 'seek':
          await audio.seek(call.arguments as int);
        case 'volume':
          break;
        case 'release':
          await audio.dispose();
        case 'snapshot':
          return {
            'position': audio.value.position,
            'duration': audio.value.duration,
            'playing': audio.value.playing,
            'ended': audio.value.ended,
          };
        case 'checkpointed':
          expect(durable, audio.value.position);
          acknowledgements++;
      }
      return null;
    });
    final p = Playback(const NativeAudioPort(), (_, state, __, ___) {
      if (diskFull) throw StateError('disque plein');
      durable = state.position;
    }, autoPoll: false);
    try {
      await p.start('a', 'content://test/audio', 0);
      audio.value = const AudioSnapshot(5000, 120000, true);
      await p.poll();
      await p.pause();
      expect(durable, 5000);
      final before = acknowledgements;
      diskFull = true;
      audio.value = const AudioSnapshot(10000, 120000, true);
      await p.poll();
      expect(p.error, contains('disque plein'));
      expect(acknowledgements, before);
      expect(audio.value.playing, isFalse);
    } finally {
      diskFull = false;
      await p.release();
      p.dispose();
      messenger.setMockMethodCallHandler(NativeAudioPort.channel, null);
    }
  });

  test(
    'La commande système attend un poll en vol avant son acquittement',
    () async {
      final audio = DelayedSnapshotAudio();
      final p = Playback(audio, (_, __, ___, ____) {}, autoPoll: false);
      var dispatched = false;
      final controls = AndroidMediaControls(
        playback: p,
        nowPlaying: () => null,
        onError: (_) {},
        onCommand: (_, __) async {
          dispatched = true;
          await p.poll();
        },
      );
      try {
        await p.start('id', 'ref', 0);
        final gate = Completer<AudioSnapshot>();
        audio.pendingSnapshot = gate;
        final poll = p.poll();
        final command = send('tick');
        await Future<void>.delayed(Duration.zero);
        expect(dispatched, isFalse);
        audio.audio.value = const AudioSnapshot(5000, 120000, true);
        gate.complete(audio.audio.value);
        await poll;
        await command;
        expect(dispatched, isTrue);
      } finally {
        controls.dispose();
        await p.release();
        p.dispose();
      }
    },
  );

  test(
    'Commandes système sérialisées et attendent une ouverture déjà engagée',
    () async {
      final audio = DelayedAudio();
      final p = Playback(audio, (_, __, ___, ____) {}, autoPoll: false);
      final controls = AndroidMediaControls(
        playback: p,
        nowPlaying: () => null,
        onError: (_) {},
        onCommand: (action, position) async {
          if (action == 'pause')
            await p.pause();
          else
            await p.toggle();
        },
      );
      try {
        final opening = p.start('id', 'ref', 0);
        await Future<void>.delayed(Duration.zero);
        final pause = send('pause');
        audio.ready.complete();
        await opening;
        await pause;
        expect(p.state.playing, isFalse);
        expect(p.busy, isFalse);
      } finally {
        controls.dispose();
        await p.release();
        p.dispose();
      }
    },
  );
}

final class DelayedAudio implements AudioPort {
  final ready = Completer<void>();
  final audio = FakeAudio();
  @override
  Future<void> open(String ref) async {
    await ready.future;
    await audio.open(ref);
  }

  @override
  Future<void> play() => audio.play();
  @override
  Future<void> pause() => audio.pause();
  @override
  Future<void> seek(int position) => audio.seek(position);
  @override
  Future<void> volume(double value) => audio.volume(value);
  @override
  Future<AudioSnapshot> snapshot() => audio.snapshot();
  @override
  Future<void> dispose() => audio.dispose();
}

final class DelayedSnapshotAudio implements AudioPort {
  Completer<AudioSnapshot>? pendingSnapshot;
  final audio = FakeAudio();
  @override
  Future<void> open(String ref) => audio.open(ref);
  @override
  Future<void> play() => audio.play();
  @override
  Future<void> pause() => audio.pause();
  @override
  Future<void> seek(int position) => audio.seek(position);
  @override
  Future<void> volume(double value) => audio.volume(value);
  @override
  Future<AudioSnapshot> snapshot() {
    final pending = pendingSnapshot;
    pendingSnapshot = null;
    return pending == null ? audio.snapshot() : pending.future;
  }

  @override
  Future<void> dispose() => audio.dispose();
}
