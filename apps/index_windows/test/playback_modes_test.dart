import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:index_windows/app.dart';
import 'package:index_windows/app_model.dart';
import 'package:index_windows/audio_player.dart';

import 'support/fake_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final autoNext in [true, false]) {
    for (final keyboard in [false, true]) {
      test(
        'Seek à trois secondes du terme : Écouté, auto-suivant=$autoNext, clavier=$keyboard',
        () async {
          final root = Directory.systemTemp.createTempSync('index-seek-end-');
          final audio = FakeAudio();
          final model = AppModel(
            portableDirectory: root,
            audioPort: audio,
            pollAudio: false,
          );
          try {
            await model.configure(
              '${root.path}/user',
              Directory('../../MP3_Files').absolute.path,
              false,
            );
            if (!autoNext) model.toggleAutoNext();
            final queue = model.visible.where((e) => e.audioAvailable).toList();
            final episode = queue.first;
            model.select(episode);
            await model.playEpisode(episode);
            await model.playback.seek(117000);
            if (keyboard) {
              audio.value = const AudioSnapshot(118000, 120000, true);
              await model.playback.poll();
              await model.playback.skip(10000);
              expect(model.selected!.status, 'EN_COURS');
              expect(model.playback.state.position, 120000);
              audio.value = const AudioSnapshot(
                120000,
                120000,
                false,
                ended: true,
              );
              await model.playback.poll();
            } else {
              for (var i = 118; i <= 120; i++) {
                audio.value = AudioSnapshot(
                  i * 1000,
                  120000,
                  i < 120,
                  ended: i == 120,
                );
                await model.playback.poll();
              }
            }
            expect(model.selected!.status, 'ECOUTE');
            expect(
              model.session!.listeningState(episode.id)!['listening_status'],
              'ECOUTE',
            );
            expect(
              model.session!.listeningState(episode.id)!['completed_at'],
              isNotNull,
            );
            expect(
              model.playingEpisode!.id,
              autoNext ? queue[1].id : episode.id,
            );
            expect(model.playback.state.playing, autoNext);
          } finally {
            await model.release();
            model.dispose();
            root.deleteSync(recursive: true);
          }
        },
      );
    }
  }
  test('Arrêt et statut manuel : remise à zéro durable, favori préservé ; modes persistants et fin unique', () async {
    final root = Directory.systemTemp.createTempSync('index-modes-');
    final audio = FakeAudio();
    final model = AppModel(
      portableDirectory: root,
      audioPort: audio,
      pollAudio: false,
      audioRandom: FirstChoiceRandom(),
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
    model.search('zzzzabsent123456789');
    expect(model.visible, isEmpty);
    model.select(model.playingEpisode!, keepOutsideList: true);
    audio.value = const AudioSnapshot(10000, 120000, true);
    await model.playback.poll(); // Un checkpoint rafraîchit le catalogue.
    expect(model.selected!.id, episode.id);
    expect(model.visible, isEmpty);
    expect(model.query, 'zzzzabsent123456789');
    model.search('');
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
    expect(model.playingEpisode!.id, queue[0].id);
    await model.nextAudio(-1);
    expect(
      model.playingEpisode!.id,
      queue[1].id,
    ); // Ni précédent séquentiel ni boucle.
    await model.nextAudio(1);
    expect(model.playingEpisode!.id, queue[0].id); // Ni suivant séquentiel.
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

  for (final autoNext in [true, false]) {
    for (final changeDetail in [false, true]) {
      test(
        'Réécoute terminée : auto-suivant=$autoNext, changement de fiche=$changeDetail',
        () async {
          final root = Directory.systemTemp.createTempSync('index-replay-');
          final audio = FakeAudio();
          final model = AppModel(
            portableDirectory: root,
            audioPort: audio,
            pollAudio: false,
          );
          try {
            await model.configure(
              '${root.path}/user',
              Directory('../../MP3_Files').absolute.path,
              false,
            );
            if (!autoNext) model.toggleAutoNext();
            final queue = model.visible.where((e) => e.audioAvailable).toList();
            final original = queue.first;
            model.select(original);
            model.favorite(original);
            await model.playEpisode(original);
            await model.playback.seek(100000);
            for (var i = 101; i <= 120; i++) {
              audio.value = AudioSnapshot(
                i * 1000,
                120000,
                i < 120,
                ended: i == 120,
              );
              await model.playback.poll();
            }
            expect(model.selected!.id, original.id);
            expect(model.selected!.status, 'ECOUTE');
            expect(
              model.playingEpisode!.id,
              autoNext ? queue[1].id : original.id,
            );
            if (changeDetail) {
              model.select(
                model.catalog.firstWhere((e) => e.id == queue[1].id),
              );
              model.select(
                model.catalog.firstWhere((e) => e.id == original.id),
              );
            }
            final detail = model.selected!;
            await model.playEpisode(detail);
            expect(model.playback.error, isEmpty);
            expect(model.playback.state.position, 0);
            expect(model.playback.state.playing, isTrue);
            expect(model.selected!.status, 'NON_ECOUTE');
            expect(model.progress(model.selected!), 0);
            expect(model.selected!.favorite, isTrue);
            expect(
              model.session!.listeningState(original.id)!['completed_at'],
              isNull,
            );
            for (var i = 1; i <= 6; i++) {
              audio.value = AudioSnapshot(i * 1000, 120000, true);
              await model.playback.poll();
            }
            expect(model.selected!.status, 'EN_COURS');
            expect(model.progress(model.selected!), closeTo(.05, .001));
            // Une ancienne fiche ne doit pas remplacer la position durable récente.
            final savedPosition = model.session!.listeningState(
              original.id,
            )!['position_ms'];
            await model.playEpisode(detail);
            expect(model.playback.state.position, savedPosition);
            expect(model.selected!.status, 'EN_COURS');
            if (!autoNext) {
              await model.playback.seek(100000);
              for (var i = 101; i <= 120; i++) {
                audio.value = AudioSnapshot(
                  i * 1000,
                  120000,
                  i < 120,
                  ended: i == 120,
                );
                await model.playback.poll();
              }
              expect(model.selected!.status, 'ECOUTE');
              await model.playToggle();
              expect(model.playback.state.position, 0);
              expect(model.playback.state.playing, isTrue);
              expect(model.selected!.status, 'NON_ECOUTE');
              expect(model.selected!.favorite, isTrue);
            }
          } finally {
            await model.release();
            model.dispose();
            root.deleteSync(recursive: true);
          }
        },
      );
    }
  }

  test(
    'Une ouverture audio échouée conserve le statut Écouté et le favori',
    () async {
      final root = Directory.systemTemp.createTempSync('index-replay-failed-');
      final audio = FakeAudio();
      final model = AppModel(
        portableDirectory: root,
        audioPort: audio,
        pollAudio: false,
      );
      try {
        await model.configure(
          '${root.path}/user',
          Directory('../../MP3_Files').absolute.path,
          false,
        );
        final episode = model.visible.firstWhere((e) => e.audioAvailable);
        model.select(episode);
        model.favorite(episode);
        await model.listened(episode);
        final completedAt = model.session!.listeningState(
          episode.id,
        )!['completed_at'];
        audio.fail = true;
        await model.playEpisode(model.selected!);
        expect(model.playback.error, isNotEmpty);
        expect(model.selected!.status, 'ECOUTE');
        expect(model.selected!.favorite, isTrue);
        expect(
          model.session!.listeningState(episode.id)!['completed_at'],
          completedAt,
        );
      } finally {
        await model.release();
        model.dispose();
        root.deleteSync(recursive: true);
      }
    },
  );

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
      await mouse.down(middle);
      await tester.pump();
      expect(
        find.text(playbackTime(tester.widget<Slider>(slider).value.round())),
        findsOneWidget,
      );
      await mouse.moveTo(middle + const Offset(45, 0));
      await tester.pump();
      final preview = tester.widget<Slider>(slider).value;
      expect(preview, greaterThan(60000));
      expect(find.text(playbackTime(preview.round())), findsOneWidget);
      // Même en quittant verticalement la barre, le temps reste visible tant que
      // le bouton est enfoncé et suit la cible du glissement.
      await mouse.moveTo(middle + const Offset(45, 80));
      await tester.pump();
      expect(find.text(playbackTime(preview.round())), findsOneWidget);
      await mouse.up();
      await tester.pump();
      expect(p.state.position, 10000);
      audio.gate!.complete();
      await tester.pump();
      await tester.pump();
      expect(p.state.position, closeTo(preview, 1));
      expect(tester.widget<Slider>(slider).value, closeTo(preview, 1));
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

class FirstChoiceRandom implements math.Random {
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}
