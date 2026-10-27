import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:index_windows/app.dart';
import 'package:index_windows/app_model.dart';
import 'package:index_windows/audio_player.dart';

import 'support/fake_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Arrêt et statut manuel : remise à zéro durable, favori préservé ; modes persistants et fin unique', () async {
    final root = Directory.systemTemp.createTempSync('index-modes-');
    final audio = FakeAudio();
    final model = AppModel(
      portableDirectory: root,
      audioPort: audio,
      pollAudio: false,
    );
    await model.configure(
      '${root.path}/user',
      Directory('../../MP3_Files').absolute.path,
      false,
    );
    final queue = model.visible.where((e) => e.audioAvailable).toList();
    expect(queue.length, greaterThan(1));
    final episode = queue.first;
    expect(model.autoNext, isTrue);
    expect(model.shuffle, isFalse);
    model.favorite(episode);
    await model.playEpisode(episode);
    for (var i = 1; i <= 5; i++) {
      audio.value = AudioSnapshot(i * 1000, 120000, true);
      await model.playback.poll();
    }
    expect(model.progress(model.playingEpisode!), closeTo(5 / 120, .001));
    expect(model.playingEpisode!.status, 'EN_COURS');
    await model.stopAudio();
    expect(model.playback.state.position, 0);
    expect(model.playback.state.playing, isFalse);
    expect(model.playingEpisode!.status, 'NON_ECOUTE');
    expect(model.playingEpisode!.favorite, isTrue);
    expect(
      model.session!.listeningState(episode.id)!['playback_status'],
      'stopped',
    );
    expect(model.progress(model.playingEpisode!), 0);
    await model.playToggle();
    audio.value = const AudioSnapshot(1000, 120000, true);
    await model.playback.poll();
    await model.listened(model.playingEpisode!);
    expect(model.playingEpisode!.status, 'ECOUTE');
    expect(model.playback.state.position, 0);
    expect(model.playback.state.playing, isFalse);
    await model.playback.poll();
    expect(model.playingEpisode!.status, 'ECOUTE');
    // Réinitialiser puis atteindre la fin : enchaînement dans l'ordre visible.
    await model.listened(model.playingEpisode!, reset: true);
    await model.playToggle();
    audio.value = const AudioSnapshot(120000, 120000, false, ended: true);
    await model.playback.poll();
    expect(model.playingEpisode!.id, queue[1].id);
    expect(model.playback.state.playing, isTrue);
    model.toggleAutoNext();
    audio.value = const AudioSnapshot(120000, 120000, false, ended: true);
    await model.playback.poll();
    final stoppedId = model.playingEpisode!.id;
    await model.playback.poll();
    expect(model.playingEpisode!.id, stoppedId);
    expect(model.playback.state.playing, isFalse);
    // Le mode aléatoire lance immédiatement et prime sur autoNext désactivé.
    await model.toggleShuffle();
    expect(model.shuffle, isTrue);
    expect(model.playingEpisode!.id, isNot(stoppedId));
    final randomId = model.playingEpisode!.id;
    audio.value = const AudioSnapshot(120000, 120000, false, ended: true);
    await model.playback.poll();
    expect(model.playingEpisode!.id, isNot(randomId));
    await model.toggleShuffle();
    expect(model.shuffle, isFalse);
    final id = model.playingEpisode!.id;
    await model.release();
    model.dispose();
    final reopened = AppModel(
      portableDirectory: root,
      audioPort: FakeAudio(),
      pollAudio: false,
    );
    await reopened.boot();
    expect(reopened.autoNext, isFalse);
    expect(reopened.shuffle, isFalse);
    expect(reopened.catalog.firstWhere((e) => e.id == id).durationMs, 120000);
    await reopened.release();
    reopened.dispose();
    root.deleteSync(recursive: true);
  });

  testWidgets(
    'Seek : cible maintenue pendant la réponse native et horodatage au survol',
    (tester) async {
      final audio = DelayedSeek();
      final p = Playback(audio, (_, _, _, _) {}, autoPoll: false);
      await p.start('a', 'file:///a.mp3', 10000);
      audio.gate = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: PlayerSeekBar(playback: p, enabled: true),
              ),
            ),
          ),
        ),
      );
      final slider = find.byKey(const ValueKey('player-progress'));
      final middle = tester.getCenter(slider);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: middle);
      await tester.pump();
      await mouse.moveTo(middle + const Offset(1, 0));
      await tester.pump();
      expect(find.text('1:00'), findsOneWidget);
      await tester.tapAt(middle);
      await tester.pump();
      final preview = tester.widget<Slider>(slider).value;
      expect(preview, closeTo(60000, 1000));
      expect(p.state.position, 10000);
      audio.gate!.complete();
      await tester.pump();
      await tester.pump();
      expect(p.state.position, closeTo(60000, 1000));
      expect(tester.widget<Slider>(slider).value, preview);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
      await p.release();
      p.dispose();
    },
  );
}

class DelayedSeek implements AudioPort {
  final delegate = FakeAudio();
  Completer<void>? gate;
  @override
  Future<void> open(String reference) => delegate.open(reference);
  @override
  Future<void> play() => delegate.play();
  @override
  Future<void> pause() => delegate.pause();
  @override
  Future<void> seek(int milliseconds) async {
    await gate?.future;
    await delegate.seek(milliseconds);
  }

  @override
  Future<void> volume(double value) => delegate.volume(value);
  @override
  Future<AudioSnapshot> snapshot() => delegate.snapshot();
  @override
  Future<void> dispose() => delegate.dispose();
}
