import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:index_windows/audio_player.dart';

import 'support/fake_audio.dart';

void main() {
  testWidgets(
    'Interruption temporaire : pause sauvegardée, reprise au même endroit et polling réactivé',
    (tester) async {
      final audio = InterruptibleAudio();
      final saved = <(String, int, String)>[];
      final p = Playback(
        audio,
        (id, state, guard, status) => saved.add((id, state.position, status)),
      );
      try {
        await p.start('a', 'ref-a', 0);
        audio.audio.value = const AudioSnapshot(1000, 120000, true);
        await tester.pump(const Duration(milliseconds: 250));
        audio.loss(1);
        await p.pauseForInterruption(1);
        expect(p.state.playing, isFalse);
        expect(saved.last, ('a', 1000, 'paused'));
        final calls = audio.audio.snapshotCalls;
        await tester.pump(const Duration(seconds: 2));
        expect(audio.audio.snapshotCalls, calls);
        audio.regained = true;
        await p.resumeAfterInterruption(1);
        expect(p.state.playing, isTrue);
        expect(saved.last, ('a', 1000, 'playing'));
        final savedCount = saved.length;
        await p.resumeAfterInterruption(1);
        expect(
          saved.length,
          savedCount,
          reason:
              'Une restitution de focus dupliquée ne relance pas une écoute.',
        );
        audio.audio.value = const AudioSnapshot(2000, 120000, true);
        await tester.pump(const Duration(milliseconds: 250));
        expect(p.state.position, 2000);
        expect(p.guard.progressed, isTrue);
      } finally {
        await p.release();
        p.dispose();
      }
    },
  );

  test('Pause/arrêt/source changée : les anciennes reprises ne modifient ni écoute ni position', () async {
    final audio = InterruptibleAudio();
    final p = Playback(audio, (_, __, ___, ____) {}, autoPoll: false);
    try {
      await p.start('a', 'a', 12000);
      audio.loss(1);
      await p.pauseForInterruption(1);
      await p.pause(); // Choix manuel, même si le son était déjà suspendu.
      audio.regained = true;
      await p.resumeAfterInterruption(1);
      expect(p.state.playing, isFalse);
      expect(p.state.position, 12000);
      await p.toggle();
      audio.loss(2);
      await p.pauseForInterruption(2);
      await p.rewind();
      audio.regained = true;
      await p.resumeAfterInterruption(2);
      expect(p.state.playing, isFalse);
      expect(p.state.position, 0);
      await p.toggle();
      audio.loss(3);
      await p.start('b', 'b', 7000);
      await p.pauseForInterruption(3);
      audio.regained = true;
      await p.resumeAfterInterruption(3);
      expect(p.episodeId, 'b');
      expect(p.state.playing, isTrue);
      expect(p.state.position, 7000);
    } finally {
      await p.release();
      p.dispose();
    }
  });

  test('Contrat natif : les jetons sont transmis et un refus est une absence de reprise', () async {
    final calls = <MethodCall>[];
    var accepted = true;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(NativeAudioPort.channel, (call) async {
      calls.add(call);
      return accepted;
    });
    try {
      const port = NativeAudioPort();
      expect(await port.pauseForInterruption(21), isTrue);
      accepted = false;
      expect(await port.resumeAfterInterruption(21), isFalse);
      expect(calls.map((c) => (c.method, c.arguments)), [
        ('pauseTransient', 21),
        ('resumeAfterInterruption', 21),
      ]);
    } finally {
      messenger.setMockMethodCallHandler(NativeAudioPort.channel, null);
    }
  });
}

final class InterruptibleAudio implements AudioPort, InterruptionAudioPort {
  final audio = FakeAudio();
  int? token;
  bool regained = false;
  void loss(int value) {
    token = value;
    regained = false;
    audio.value = AudioSnapshot(
      audio.value.position,
      audio.value.duration,
      false,
    );
  }

  void cancel() {
    token = null;
    regained = false;
  }

  @override
  Future<void> open(String ref) async {
    cancel();
    await audio.open(ref);
  }

  @override
  Future<void> play() async {
    cancel();
    await audio.play();
  }

  @override
  Future<void> pause() async {
    cancel();
    await audio.pause();
  }

  @override
  Future<void> seek(int value) async {
    cancel();
    await audio.seek(value);
  }

  @override
  Future<void> volume(double value) => audio.volume(value);
  @override
  Future<AudioSnapshot> snapshot() => audio.snapshot();
  @override
  Future<void> dispose() => audio.dispose();
  @override
  Future<bool> pauseForInterruption(int value) async {
    if (token != value) return false;
    await audio.pause();
    return true;
  }

  @override
  Future<bool> resumeAfterInterruption(int value) async {
    if (token != value || !regained) return false;
    cancel();
    await audio.play();
    return true;
  }
}
