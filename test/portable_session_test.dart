import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:index_core/index_desktop.dart';
import 'package:index_core/index_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Directory root, portable, data;
  late Uint8List seed;
  late String hash;
  final opened = <PortableSession>[];
  setUpAll(() async {
    seed = await File('assets/catalogue.sqlite').readAsBytes();
    hash = sha256.convert(seed).toString();
  });
  setUp(() async {
    root = await Directory.systemTemp.createTemp('index-portable-');
    portable = await Directory('${root.path}/application').create();
    data = await Directory('${root.path}/données utilisateur').create();
  });
  tearDown(() async {
    for (final session in opened.reversed) {
      await session.dispose();
    }
    opened.clear();
    await root.delete(recursive: true);
  });
  Future<PortableSession> start({
    Directory? folder,
    bool existing = false,
  }) async {
    final s = await PortableSession.open(
      portableDirectory: portable,
      dataDirectory: folder ?? data,
      referenceBytes: seed,
      referenceSha256: hash,
      requireExisting: existing,
    );
    opened.add(s);
    return s;
  }

  test('Catalogue sans sources externes, pointeur portable et suivi durable dès modification', () async {
    final s = await start();
    final entries = s.episodes();
    expect(entries, hasLength(716));
    expect(entries.every((e) => !e.audioAvailable), isTrue);
    final id = entries.first.id;
    s.favorite(id, true);
    s.listened(id, true);
    s.setSetting('theme', 'dark');
    expect(() => s.listened(id, false), throwsArgumentError);
    await s.closeSafely();
    final pointer = jsonDecode(
      await File('${portable.path}/index-portable.json').readAsString(),
    ) as Map;
    expect(pointer.keys.toSet(), {'version', 'data_directory'});
    expect(
      FileSystemEntity.identicalSync(
        PortableSession.configuredDirectory(portable)!.path,
        data.path,
      ),
      isTrue,
    );
    final after = await start(existing: true);
    final entry = after.episodes().firstWhere((e) => e.id == id);
    expect(entry.favorite, isTrue);
    expect(entry.status, 'ECOUTE');
    expect(after.setting('theme'), 'dark');
    after.listened(id, false, resetConfirmed: true);
    expect(after.episodes().firstWhere((e) => e.id == id).positionMs, 0);
    expect(
      after
          .episodes(query: 'auteur', fields: {SearchField.title})
          .every((e) => e.title.toLowerCase().contains('auteur')),
      isTrue,
    );
  });
  test(
    'Backup cohérent du WAL, deux générations et récupération des favoris',
    () async {
      final s = await start();
      final id = s.episodes().first.id;
      s.favorite(id, true);
      final latest = await s.backup();
      s.favorite(id, false);
      await s.backup();
      for (final pair in [
        (latest, false),
        (
          File('${data.path}/sauvegardes/IndeX_sauvegarde_precedente.sqlite'),
          true,
        ),
      ]) {
        final db = sqlite3.open(pair.$1.path, mode: OpenMode.readOnly);
        expect(db.select('PRAGMA integrity_check').single.values.single, 'ok');
        expect(
          db.select(
            'SELECT is_favorite FROM user_episode_state WHERE episode_id=?',
            [id],
          ).single['is_favorite'],
          pair.$2 ? 1 : 0,
        );
        db.close();
      }
    },
  );
  test(
    'Échec de sauvegarde bloque la fermeture et permet de réessayer',
    () async {
      final s = await start();
      final id = s.episodes().first.id;
      final blocker = await File('${data.path}/sauvegardes')
          .writeAsString('bloqué');
      await expectLater(s.closeSafely(), throwsA(isA<FileSystemException>()));
      s.favorite(id, true);
      expect(s.episodes().firstWhere((e) => e.id == id).favorite, isTrue);
      await blocker.delete();
      await s.closeSafely();
    },
  );
  test(
    'Base attendue absente : pas de création ni écrasement du pointeur',
    () async {
      await expectLater(
        start(existing: true),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        await File('${data.path}/index-utilisateur.sqlite').exists(),
        isFalse,
      );
      expect(
        await File('${portable.path}/index-portable.json').exists(),
        isFalse,
      );
    },
  );
  test('Empreinte invalide et configuration étrangère refusées', () async {
    await expectLater(
      PortableSession.open(
        portableDirectory: portable,
        dataDirectory: data,
        referenceBytes: seed,
        referenceSha256: 'invalide',
      ),
      throwsFormatException,
    );
    await File('${portable.path}/index-portable.json')
        .writeAsString('{"version":99}');
    expect(
      () => PortableSession.configuredDirectory(portable),
      throwsFormatException,
    );
  });
  test('Deux sessions dans le même dossier sont refusées', () async {
    final s = await start();
    await expectLater(start(), throwsStateError);
    expect(s.episodes(), hasLength(716));
  });
  test('Le verrou refuse aussi un second processus', () async {
    final session = await start();
    // Cette sonde SDK-only ne doit pas relancer les hooks natifs du package :
    // sous Windows ils tenteraient de remplacer sqlite3.dll déjà chargée ici.
    final probeDirectory = await Directory('${root.path}/sonde').create();
    final helper = await File('test/support/try_portable_lock.dart')
        .copy('${probeDirectory.path}/try_portable_lock.dart');
    final result = await Process.run(Platform.resolvedExecutable, [
      helper.absolute.path,
      '${data.path}/.index.lock',
    ], workingDirectory: probeDirectory.path);
    expect(
      result.exitCode,
      3,
      reason:
          'Un second processus ne doit pas ouvrir les données en écriture.\nstdout: ${result.stdout}\nstderr: ${result.stderr}',
    );
    final lines = (result.stdout as String)
        .split('\n')
        .where((line) => line.trim().startsWith('{'));
    expect(lines, isNotEmpty);
    expect(
      (jsonDecode(lines.last) as Map<String, dynamic>)['status'],
      'blocked',
    );
    // Contrôle positif : la même sonde doit réussir dès que le verrou est libéré.
    await session.dispose();
    final released = await Process.run(Platform.resolvedExecutable, [
      helper.absolute.path,
      '${data.path}/.index.lock',
    ], workingDirectory: probeDirectory.path);
    expect(
      released.exitCode,
      0,
      reason: 'Après libération : ${released.stdout}\n${released.stderr}',
    );
    expect(
      (jsonDecode((released.stdout as String).trim())
          as Map<String, dynamic>)['status'],
      'acquired',
    );
  });

  test('Scan par noms du journal, association manuelle et changement de dossier sans suppression', () async {
    final s = await start();
    final report = await s.scan(Directory('MP3_Files').absolute.path);
    expect(report['complete'], isTrue);
    expect(report['count'], 6);
    expect(s.episodes().where((e) => e.audioAvailable), hasLength(6));
    s.favorite(s.episodes().first.id, true);
    final empty = await Directory('${root.path}/vide').create();
    await s.scan(empty.path);
    expect(s.episodes().where((e) => e.audioAvailable), isEmpty);
    expect(
      s.store.database.select('SELECT * FROM local_audio_links'),
      hasLength(6),
    );
    final missing = await s.scan('${root.path}/absent');
    expect(missing['complete'], isFalse);
    expect(s.episodes().any((e) => e.favorite), isTrue);
  });
  test('Déplacement contrôlé copie base, sauvegardes et exports, ancien dossier conservé', () async {
    final s = await start();
    final id = s.episodes().first.id;
    s.favorite(id, true);
    final exports = await Directory('${data.path}/exports/sous dossier')
        .create(recursive: true);
    await File('${exports.path}/suivi.json').writeAsString('{"exemple":true}');
    final target = await Directory('${root.path}/nouveau').create();
    final next = await s.relocate(target);
    opened.add(next);
    expect(next.episodes().firstWhere((e) => e.id == id).favorite, isTrue);
    expect(
      await File('${target.path}/exports/sous dossier/suivi.json')
          .readAsString(),
      '{"exemple":true}',
    );
    expect(
      await File('${data.path}/index-utilisateur.sqlite').exists(),
      isTrue,
    );
    expect(
      FileSystemEntity.identicalSync(
        PortableSession.configuredDirectory(portable)!.path,
        target.path,
      ),
      isTrue,
    );
    final occupied = await Directory('${root.path}/occupe').create();
    await File('${occupied.path}/garder').writeAsString('ok');
    await expectLater(next.relocate(occupied), throwsStateError);
    expect(await File('${occupied.path}/garder').readAsString(), 'ok');
  });
}
