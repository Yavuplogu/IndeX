import 'package:flutter_test/flutter_test.dart';
import 'package:index_windows/audio_player.dart';

import 'support/fake_audio.dart';

void main() {
  test('Fin : seek seul sans validation, dix secondes continues, durée inconnue et pause', () {
    final guard = ListeningGuard();
    guard.discontinuity(115000);
    guard.observe(const AudioSnapshot(115000, 120000, true));
    guard.observe(const AudioSnapshot(120000, 120000, false, ended: true));
    expect(guard.completed, isFalse);
    guard.discontinuity(100000);
    for (var i = 1; i <= 10; i++) {
      guard.observe(AudioSnapshot(100000 + i * 1000, 120000, true));
    }
    expect(guard.completed, isTrue);
    final unknown = ListeningGuard()..discontinuity(0);
    for (var i = 1; i <= 20; i++) {
      unknown.observe(AudioSnapshot(i * 1000, 0, true));
    }
    expect(unknown.progressed, isTrue);
    expect(unknown.completed, isFalse);
    final paused = ListeningGuard()..discontinuity(100000);
    for (var i = 1; i <= 7; i++) {
      paused.observe(AudioSnapshot(100000 + i * 1000, 120000, true));
    }
    paused.observe(const AudioSnapshot(107000, 120000, false));
    paused.discontinuity(107000);
    for (var i = 1; i <= 7; i++) {
      paused.observe(AudioSnapshot(107000 + i * 1000, 120000, true));
    }
    expect(paused.completed, isFalse);
  });
  test('Checkpoints à 5 s, pause et seek ; nouvelle piste, borne de reprise et échec récupérable', () async {
    final native = FakeAudio();
    final saved = <(String, int, bool, String)>[];
    final p = Playback(
      native,
      (id, state, guard, status) =>
          saved.add((id, state.position, guard.completed, status)),
      autoPoll: false,
    );
    await p.start('a', 'local-a', 3000);
    expect(p.state.position, 3000);
    for (var i = 4; i <= 8; i++) {
      native.value = AudioSnapshot(i * 1000, 120000, true);
      await p.poll();
    }
    expect(saved.last.$2, 8000);
    expect(saved.last.$4, 'playing');
    await p.seek(118000);
    expect(saved.last.$3, isFalse);
    await p.stop();
    expect(saved.last.$4, 'stopped');
    expect(saved.last.$2, 118000);
    native.fail = true;
    await p.start('b', 'bad', 0);
    expect(p.error, isNotEmpty);
    expect(p.episodeId, isNull);
    native.fail = false;
    await p.start('b', 'local-b', 999999);
    expect(p.episodeId, 'b');
    expect(p.state.position, 120000);
    await p.unload();
    expect(p.episodeId, isNull);
    await p.release();
    p.dispose();
  });
  test('Erreur d’écriture : pause, erreur visible et fermeture bloquée tant que le stockage échoue', () async {
    final native = FakeAudio();
    var diskFull = false;
    final p = Playback(native, (id, state, guard, status) {
      if (diskFull) throw StateError('disque plein');
    }, autoPoll: false);
    await p.start('a', 'local', 0);
    diskFull = true;
    native.value = const AudioSnapshot(5000, 120000, true);
    await p.poll();
    expect(p.error, contains('disque plein'));
    expect(native.value.playing, isFalse);
    await expectLater(p.suspend(), throwsStateError);
    diskFull = false;
    await p.release();
    p.dispose();
  });
}
