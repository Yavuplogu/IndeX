import 'package:index_core/index_core.dart';

import 'catalog_fixtures.dart';

AudioCandidate audio(String reference, {String name = firstOriginal}) =>
    AudioCandidate(reference: reference, currentName: name);

MatchEpisode episode({
  String id = firstId,
  String original = firstOriginal,
  String title = 'Un titre',
  String? status = 'CONFIRMEE',
}) => MatchEpisode(
  id: id,
  originalName: original,
  title: title,
  systemNames: ['2013-04-27 Un titre.mp3'],
  journalStatus: status,
);
