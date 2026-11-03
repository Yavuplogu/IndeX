import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:index_windows/app.dart';
import 'package:index_windows/app_model.dart';
import 'package:index_windows/audio_player.dart';

import 'support/app_harness.dart';
import 'support/fake_audio.dart';

void main() {
  testWidgets(
    'Android : arrière-plan sauvegarde sans pause ; Retour conserve la lecture et le profil',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = Directory.systemTemp.createTempSync('index-background-');
      final audio = FakeAudio();
      final model = AppModel(
        portableDirectory: root,
        android: true,
        audioPort: audio,
        pollAudio: false,
      );
      final window = FakeWindow();
      try {
        await tester.runAsync(
          () => model.configure('${root.path}/user', '', true),
        );
        await tester.pumpWidget(IndeXApp(model: model, window: window));
        await tester.pumpAndSettle();
        final id = model.catalog.first.id;
        await model.playback.start(id, 'content://test/audio', 0);
        audio.value = const AudioSnapshot(1000, 120000, true);
        await model.playback.poll();
        audio.value = const AudioSnapshot(6000, 120000, true);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pumpAndSettle();
        expect(model.playback.state.playing, isTrue);
        expect(audio.value.playing, isTrue);
        expect(model.session!.listeningState(id)!['position_ms'], 6000);
        expect(
          model.session!.listeningState(id)!['listening_status'],
          'EN_COURS',
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(window.minimized, 1);
        expect(window.destroyed, 0);
        expect(model.session, isNotNull);
        expect(model.playback.state.playing, isTrue);
        await model.playback.pause();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(window.minimized, 2);
        expect(model.session!.listeningState(id)!['position_ms'], 6000);
        await tester.pumpWidget(const SizedBox());
      } finally {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.runAsync(model.release);
        model.dispose();
        root.deleteSync(recursive: true);
      }
    },
  );
}
