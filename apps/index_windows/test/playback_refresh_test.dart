import 'dart:io';

import 'package:flutter/material.dart';
import 'package:index_windows/app.dart';

import 'support/app_harness.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:index_core/index_core.dart';
import 'package:index_windows/app_model.dart';
import 'package:index_windows/audio_player.dart';
import 'package:index_windows/playback_builder.dart';

import 'support/fake_audio.dart';

void main() {
  testWidgets(
    'Fiche conservée : pourcentage exact après pause et changement de piste',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = Directory.systemTemp.createTempSync('index-live-detail-');
      final audio = FakeAudio();
      final model = AppModel(
        portableDirectory: root,
        audioPort: audio,
        pollAudio: false,
      );
      try {
        await tester.runAsync(
          () => model.configure(
            '${root.path}/user',
            Directory('../../MP3_Files').absolute.path,
            false,
          ),
        );
        final queue = model.visible.where((e) => e.audioAvailable).toList();
        model.select(queue.first);
        await tester.pumpWidget(IndeXApp(model: model, window: FakeWindow()));
        await tester.pumpAndSettle();
        await model.playEpisode(queue.first);
        audio.value = const AudioSnapshot(1000, 120000, true);
        await model.playback.poll();
        await tester.pumpAndSettle();
        audio.value = const AudioSnapshot(6000, 120000, true);
        await model.playback.poll();
        await tester.pumpAndSettle();
        expect(find.text('En cours (5 %)'), findsOneWidget);
        await model.playback.toggle();
        await tester.pumpAndSettle();
        expect(find.text('En cours (5 %)'), findsOneWidget);
        await model.playEpisode(queue[1]);
        await tester.pumpAndSettle();
        expect(model.selected!.id, queue.first.id);
        expect(find.text('En cours (5 %)'), findsOneWidget);
        expect(
          model.session!.listeningState(queue.first.id)!['position_ms'],
          6000,
        );
        await tester.pumpWidget(const SizedBox());
      } finally {
        await tester.runAsync(model.release);
        model.dispose();
        root.deleteSync(recursive: true);
      }
    },
  );

  testWidgets(
    'Ticks : seul le lecteur et la ligne concernée reconstruisent leur contenu',
    (tester) async {
      final audio = FakeAudio();
      final p = Playback(audio, (_, __, ___, ____) {}, autoPoll: false);
      var documentBuilds = 0,
          activeBuilds = 0,
          otherBuilds = 0,
          playerBuilds = 0;
      await p.start('a', 'a', 0);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (_) {
              documentBuilds++;
              return Column(
                children: [
                  PlaybackBuilder(
                    playback: p,
                    episodeId: 'a',
                    builder: (_) {
                      activeBuilds++;
                      return const SizedBox();
                    },
                  ),
                  PlaybackBuilder(
                    playback: p,
                    episodeId: 'b',
                    builder: (_) {
                      otherBuilds++;
                      return const SizedBox();
                    },
                  ),
                  PlaybackBuilder(
                    playback: p,
                    builder: (_) {
                      playerBuilds++;
                      return const SizedBox();
                    },
                  ),
                ],
              );
            },
          ),
        ),
      );
      try {
        for (final position in [250, 500, 750]) {
          audio.value = AudioSnapshot(position, 120000, true);
          await p.poll();
          await tester.pump();
        }
        expect(documentBuilds, 1);
        expect(activeBuilds, 4);
        expect(otherBuilds, 1);
        expect(playerBuilds, 4);
        await p.start('b', 'b', 0);
        await tester.pump();
        final oldBuilds = activeBuilds;
        final newBuilds = otherBuilds;
        audio.value = const AudioSnapshot(1000, 120000, true);
        await p.poll();
        await tester.pump();
        expect(activeBuilds, oldBuilds);
        expect(otherBuilds, newBuilds + 1);
        await tester.pumpWidget(const SizedBox());
      } finally {
        await p.release();
        p.dispose();
      }
    },
  );

  test('Checkpoint : suivi durable sans relecture documentaire ; filtres et fin immédiatement actualisés', () async {
    final root = Directory.systemTemp.createTempSync('index-playback-refresh-');
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
      model.session!.setSetting('auto_next', 'false');
      final episode = model.visible.firstWhere((e) => e.audioAvailable);
      model.select(episode);
      model.favorite(episode);
      await model.playEpisode(model.selected!);
      audio.value = const AudioSnapshot(1000, 120000, true);
      await model.playback.poll();
      expect(model.selected!.status, 'EN_COURS');
      model.query = episode.title;
      model.fields = {SearchField.title};
      model.status = 'EN_COURS';
      model.reload();
      final before = model.selected!;
      expect(model.visible.any((e) => e.id == episode.id), isTrue);
      var notifications = 0;
      model.addListener(() => notifications++);
      for (final position in [2000, 3000, 4000, 5000, 6000]) {
        audio.value = AudioSnapshot(position, 120000, true);
        await model.playback.poll();
      }
      expect(notifications, 0);
      expect(model.selected!.positionMs, 5000);
      expect(model.session!.listeningState(episode.id)!['position_ms'], 5000);
      expect(identical(model.selected!.sources, before.sources), isTrue);
      expect(identical(model.selected!.music, before.music), isTrue);
      expect(model.selected!.markedFields, before.markedFields);
      expect(model.selected!.favorite, isTrue);
      expect(
        model.visible.firstWhere((e) => e.id == episode.id).positionMs,
        5000,
      );
      await model.playback.toggle();
      expect(model.session!.listeningState(episode.id)!['position_ms'], 6000);
      expect(notifications, 0);
      await model.playback.toggle();
      await model.playback.seekFromPlayer(120000);
      audio.value = const AudioSnapshot(120000, 120000, false, ended: true);
      await model.playback.poll();
      expect(
        model.catalog.firstWhere((e) => e.id == episode.id).status,
        'ECOUTE',
      );
      expect(model.visible.any((e) => e.id == episode.id), isFalse);
      expect(notifications, greaterThan(0));
    } finally {
      await model.release();
      model.dispose();
      root.deleteSync(recursive: true);
    }
  });
}
