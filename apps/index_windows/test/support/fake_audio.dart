import 'package:index_windows/audio_player.dart';

final class FakeAudio implements AudioPort {
  AudioSnapshot value = const AudioSnapshot(0, 120000, false);
  String? ref;
  bool fail = false;
  int snapshotCalls = 0;
  @override
  Future<void> open(String reference) async {
    if (fail) throw StateError('absent');
    ref = reference;
    value = const AudioSnapshot(0, 120000, false);
  }

  @override
  Future<void> play() async {
    value = AudioSnapshot(value.position, value.duration, true);
  }

  @override
  Future<void> pause() async {
    value = AudioSnapshot(value.position, value.duration, false);
  }

  @override
  Future<void> seek(int position) async {
    value = AudioSnapshot(position, value.duration, value.playing);
  }

  @override
  Future<void> volume(double value) async {}
  @override
  Future<AudioSnapshot> snapshot() async {
    snapshotCalls++;
    return value;
  }

  @override
  Future<void> dispose() async {
    ref = null;
  }
}
