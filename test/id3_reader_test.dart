import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:index_core/index_core.dart';
import 'package:index_core/index_io.dart';
import 'package:test/test.dart';

import 'support/id3_bytes.dart';

void main() {
  final reader = Id3Reader();
  for (final version in [3, 4]) {
    for (final encoding in version == 3 ? [0, 1] : [0, 1, 2, 3]) {
      for (final little in encoding == 1 ? [true, false] : [true]) {
        test('COMM v2.$version encodage $encoding ${little ? "LE" : "BE"}', () {
          final text = encoding == 0 ? 'Été, ÿ' : 'Été, écoute 🎧';
          final payload = comment(
            text,
            description: 'Description',
            encoding: encoding,
            little: little,
            language: 'fra',
          );
          final bytes = tag(
            [frame('COMM', payload, version: version)],
            version: version,
            padding: 4,
          );
          final result = reader.parse(bytes);
          expect(
            result.status,
            Id3Status.readable,
            reason: result.issues.toString(),
          );
          expect(result.comments.single.text, text);
          expect(result.comments.single.description, 'Description');
          expect(result.comments.single.language, 'fra');
          expect(result.comments.single.encoding, encoding);
          expect(result.comments.single.rawPayload, payload);
        });
      }
    }
  }
  test(
    'Toutes les COMM répétées sont conservées, même avec les mêmes clés',
    () {
      final result = reader.parse(
        tag([
          frame('TIT2', [0, 65]),
          frame('COMM', comment('mr_x_2013_04_27.mp3')),
          frame('COMM', comment('mr_x_2013_04_27.mp3')),
          frame('COMM', comment('Autre texte', description: 'ID3v1 Comment')),
        ]),
      );
      expect(result.status, Id3Status.readable);
      expect(result.comments, hasLength(3));
      expect(result.comments.map((c) => c.index), [1, 2, 3]);
      expect(
        const CommResolver().resolve(result).status,
        CommResolutionStatus.pair,
      );
    },
  );
  test(
    'A/A/B : le résultat du lecteur alimente effectivement la résolution',
    () {
      final result = reader.parse(
        tag([
          for (final id in [
            'mr_x_2013_04_27.mp3',
            'mr_x_2013_04_27.mp3',
            'mr_x_2013_11_23.mp3',
          ])
            frame('COMM', comment(id)),
        ]),
      );
      final resolution = const CommResolver().resolve(result);
      expect(resolution.originalName, 'mr_x_2013_04_27.mp3');
      expect(resolution.ignored.single.frame.text, 'mr_x_2013_11_23.mp3');
    },
  );
  test('Désynchronisation globale ID3v2.3', () {
    final body = unsync(frame('COMM', comment('ÿà et ÿ\u0000')));
    final result = reader.parse([
      73,
      68,
      51,
      3,
      0,
      128,
      ...syncSafe(body.length),
      ...body,
    ]);
    expect(result.status, Id3Status.readable);
    // Le dernier NUL est le terminateur facultatif du texte.
    expect(result.comments.single.text, 'ÿà et ÿ');
  });
  for (final tagFlag in [0, 128]) {
    test(
      'Désynchronisation v2.4 par trame et flag global $tagFlag sans double retrait',
      () {
        final payload = comment('ÿ\u0000à');
        final result = reader.parse(
          tag(
            [frame('COMM', unsync(payload), version: 4, flags: 2)],
            version: 4,
            flags: tagFlag,
          ),
        );
        expect(result.status, Id3Status.readable);
        expect(result.comments.single.text, 'ÿ\u0000à');
      },
    );
  }
  for (final version in [3, 4]) {
    test('En-tête étendu sans CRC v2.$version', () {
      final ext = version == 3
          ? [...u32(6), 0, 0, 0, 0, 0, 0]
          : [...syncSafe(6), 1, 0];
      final result = reader.parse(
        tag(
          [frame('COMM', comment('audio.mp3'), version: version)],
          version: version,
          flags: 64,
          extended: ext,
        ),
      );
      expect(result.status, Id3Status.readable);
      expect(result.comments.single.text, 'audio.mp3');
    });
    test('Groupement de trame v2.$version', () {
      final result = reader.parse(
        tag([
          frame(
            'COMM',
            [7, ...comment('audio.mp3')],
            version: version,
            flags: version == 3 ? 32 : 64,
          ),
        ], version: version),
      );
      expect(result.status, Id3Status.readable);
      expect(result.comments.single.text, 'audio.mp3');
    });
  }
  test('Footer v2.4 cohérent et incohérent', () {
    final bytes = tag(
      [frame('COMM', comment('audio.mp3'), version: 4)],
      version: 4,
      flags: 16,
    );
    expect(reader.parse(bytes).status, Id3Status.readable);
    bytes[bytes.length - 1] ^= 1;
    expect(reader.parse(bytes).issues.single.code, 'id3_invalid_footer');
  });
  test('DLI v2.4 vérifié', () {
    final payload = comment('audio.mp3');
    final valid = reader.parse(
      tag([
        frame(
          'COMM',
          [...syncSafe(payload.length), ...payload],
          version: 4,
          flags: 1,
        ),
      ], version: 4),
    );
    expect(valid.status, Id3Status.readable);
    final invalid = reader.parse(
      tag([
        frame('COMM', [...syncSafe(2), ...payload], version: 4, flags: 1),
      ], version: 4),
    );
    expect(invalid.issues.single.code, 'id3_invalid_dli');
  });
  test('Tailles v2.3 big-endian et v2.4 syncsafe distinctes', () {
    for (final version in [3, 4]) {
      final text = 'a' * 300;
      final result = reader.parse(
        tag([frame('COMM', comment(text), version: version)], version: version),
      );
      expect(result.status, Id3Status.readable);
      expect(result.comments.single.text, text);
    }
  });
  test('Version ID3v2.2 explicitement non prise en charge, sans repli', () {
    final result = reader.parse([73, 68, 51, 2, 0, 0, 0, 0, 0, 0]);
    expect(result.status, Id3Status.unsupported);
    expect(
      const CommResolver().resolve(result).allowsFilenameFallback,
      isFalse,
    );
  });
  test('Absence de tag distincte des tags tronqués', () {
    expect(reader.parse([255, 251, 0]).status, Id3Status.absent);
    expect(
      reader.parse([73, 68, 51]).issues.single.code,
      'id3_truncated_header',
    );
    final truncated = tag([frame('COMM', comment('audio.mp3'))])..removeLast();
    expect(reader.parse(truncated).issues.single.code, 'id3_truncated_tag');
  });
  test('Fin corrompue après paire valide : résultat partiel bloqué', () {
    final result = reader.parse(
      tag([
        frame('COMM', comment('audio.mp3')),
        frame('COMM', comment('audio.mp3')),
        [65, 66],
      ]),
    );
    expect(result.comments, hasLength(2));
    expect(result.status, Id3Status.invalid);
    expect(
      const CommResolver().resolve(result).status,
      CommResolutionStatus.blocked,
    );
  });
  test('Entiers syncsafe et tailles de trame malformés', () {
    final badHeader = tag([])..[6] = 128;
    expect(reader.parse(badHeader).issues.single.code, 'id3_invalid_syncsafe');
    final badFrame = frame('COMM', comment('a'))..[7] = 255;
    expect(
      reader.parse(tag([badFrame])).issues.single.code,
      'id3_invalid_frame_size',
    );
    expect(
      reader.parse(tag([frame('COMM', [])])).issues.single.code,
      'id3_invalid_frame_size',
    );
  });
  test('Padding corrompu et identifiants invalides', () {
    expect(
      reader
          .parse(
            tag([
              [0, 0, 65],
            ]),
          )
          .issues
          .single
          .code,
      'id3_invalid_padding',
    );
    expect(
      reader
          .parse(
            tag([
              frame('com!', [0]),
            ]),
          )
          .issues
          .single
          .code,
      'id3_invalid_frame_id',
    );
  });
  test('Encodage, langue, terminateur, UTF-8/16 malformés', () {
    final cases = <(List<int>, int, String)>[
      ([5, 101, 110, 103, 0], 4, 'id3_unsupported_encoding'),
      (comment('texte', encoding: 3), 3, 'id3_unsupported_encoding'),
      ([0, 255, 255, 255, 0], 3, 'id3_invalid_language'),
      ([0, 101, 110, 103, 65], 3, 'id3_missing_terminator'),
      ([3, 101, 110, 103, 0, 255], 4, 'id3_invalid_text'),
      ([1, 101, 110, 103, 255, 254, 0, 0, 65], 3, 'id3_invalid_text'),
      ([1, 101, 110, 103, 0, 0, 65, 0], 3, 'id3_invalid_text'),
      (
        [1, 101, 110, 103, 255, 254, 0, 0, 255, 254, 0, 216],
        3,
        'id3_invalid_text',
      ),
    ];
    for (final (payload, version, code) in cases) {
      final result = reader.parse(
        tag([frame('COMM', payload, version: version)], version: version),
      );
      expect(result.status, Id3Status.invalid);
      expect(result.issues.single.code, code);
    }
  });
  test('Commentaires compressés/chiffrés et extensions CRC non traités bloquent la preuve', () {
    for (final version in [3, 4]) {
      final result = reader.parse(
        tag([
          frame(
            'COMM',
            comment('audio.mp3'),
            version: version,
            flags: version == 3 ? 128 : 8,
          ),
        ], version: version),
      );
      expect(result.issues.single.code, 'id3_unsupported_comment_flags');
    }
    final result = reader.parse(
      tag(
        [],
        flags: 64,
        extended: [...u32(10), 128, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      ),
    );
    expect(result.issues.single.code, 'id3_extended_flags_unsupported');
  });
  test('Bornes tag, commentaire et nombre de trames', () {
    final bytes = tag([frame('COMM', comment('longue chaîne'))]);
    expect(
      Id3Reader(maxTagBytes: 10).parse(bytes).issues.single.code,
      'id3_tag_too_large',
    );
    expect(
      Id3Reader(maxCommentBytes: 4).parse(bytes).issues.single.code,
      'id3_comment_too_large',
    );
    expect(
      Id3Reader(maxFrames: 1)
          .parse(
            tag([
              frame('TIT2', [0]),
              frame('COMM', comment('a')),
            ]),
          )
          .issues
          .single
          .code,
      'id3_too_many_frames',
    );
  });
  test('Lecture limitée au tag, jamais au gros contenu audio', () async {
    final prefix = tag([frame('COMM', comment('audio.mp3'))]);
    final source = MemorySource([...prefix, ...List.filled(1024 * 1024, 42)]);
    final result = await reader.read(source);
    expect(result.status, Id3Status.readable);
    expect(source.requests, [10, prefix.length]);
    final oversized = MemorySource([73, 68, 51, 3, 0, 0, ...syncSafe(100000)]);
    expect(
      (await Id3Reader(maxTagBytes: 100).read(oversized)).issues.single.code,
      'id3_tag_too_large',
    );
    expect(oversized.requests, [10]);
  });
  test(
    'Adaptateur fichier inexistant : erreur explicite sans exception non gérée',
    () async {
      final dir = await Directory.systemTemp.createTemp('index-missing-');
      addTearDown(() => dir.delete(recursive: true));
      final result = await reader.read(
        FileTagSource(File('${dir.path}/absent.mp3')),
      );
      expect(result.issues.single.code, 'id3_source_error');
      expect(result.isTrustworthy, isFalse);
    },
  );
  test(
    'Petites entrées arbitraires et tags malformés : aucun crash de parseur',
    () {
      final random = Random(1701);
      for (var i = 0; i < 400; i++) {
        final payload = List.generate(
          random.nextInt(300),
          (_) => random.nextInt(256),
        );
        final bytes = i.isEven
            ? payload
            : [
                73,
                68,
                51,
                i % 4 == 1 ? 3 : 4,
                0,
                0,
                ...syncSafe(payload.length),
                ...payload,
              ];
        final result = reader.parse(bytes);
        expect(result, isA<Id3ReadResult>());
      }
    },
  );
  test('Une source qui change entre deux lectures est refusée', () async {
    final source = ChangingSource();
    expect(
      (await reader.read(source)).issues.single.code,
      'id3_source_changed',
    );
  });
}

final class ChangingSource implements TagByteSource {
  var calls = 0;
  @override
  Future<Uint8List> readPrefix(int count) async {
    final bytes = tag([frame('COMM', comment('audio.mp3'))]);
    if (++calls == 2) bytes[5] = 128;
    return Uint8List.fromList(bytes.take(count).toList());
  }
}
