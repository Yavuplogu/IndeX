import 'package:index_core/index_core.dart';

import 'catalog_fixtures.dart';
import 'id3_bytes.dart';

AudioCandidate audio(
  String reference, {
  String name = 'Quelconque.mp3',
  List<String>? comments,
}) => AudioCandidate(
  reference: reference,
  currentName: name,
  tag: comments == null
      ? Id3ReadResult(
          status: Id3Status.absent,
          majorVersion: null,
          comments: [],
          issues: [],
        )
      : Id3Reader().parse(
          tag([for (final text in comments) frame('COMM', comment(text))]),
        ),
);

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
