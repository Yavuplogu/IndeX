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

  test('Après renommage : MP3 disponible via dossier configuré aliasé, y compris après réouverture sans scan', () async {
    final s = await start();
    final mp3 = Directory('${root.path}/MP3')..createSync();
    final source = File('${mp3.path}/mr_x_1997_01_04.mp3')
      ..writeAsStringSync('audio conservé');
    final configured = Platform.isWindows
        ? mp3
        : Directory('${root.path}/MP3-alias');
    if (!Platform.isWindows) Link(configured.path).createSync(mp3.path);
    await s.scan(configured.path);
    final episode = s.episodes().firstWhere(
      (e) => e.originalName == source.uri.pathSegments.last,
    );
    expect(episode.audioAvailable, isTrue);
    final renamer = Mp3Renamer(s.store);
    final plan = await renamer.preview(configured, recursive: false);
    expect(plan.planned, 1);
    await renamer.execute(
      plan,
      move: (from, to) async {
        await from.rename(to.path);
      },
    );
    final after = s.episodes().firstWhere((e) => e.id == episode.id);
    expect(after.audioAvailable, isTrue);
    expect(s.setting('mp3_directory'), configured.absolute.path);
    final stored = after.audioRef;
    expect(
      FileSystemEntity.identicalSync(
        File.fromUri(Uri.parse(stored!)).path,
        File('${mp3.path}/${episode.systemName}').path,
      ),
      isTrue,
    );
    expect(s.episodes().firstWhere((e) => e.id == episode.id).audioRef, stored);
    await s.dispose();
    final reopened = await start(existing: true);
    expect(
      reopened.episodes().firstWhere((e) => e.id == episode.id).audioAvailable,
      isTrue,
    );
  });

  test(
    'Un ancien MP3 dans un dossier voisin reste hors du dossier configuré',
    () async {
      final s = await start();
      final selected = Directory('${root.path}/MP3')..createSync();
      final other = Directory('${root.path}/MP3-autre')..createSync();
      final source = File('${other.path}/mr_x_1997_01_04.mp3')
        ..writeAsStringSync('autre collection');
      await s.scan(other.path);
      final id = s
          .episodes()
          .firstWhere((e) => e.originalName == source.uri.pathSegments.last)
          .id;
      expect(s.episodes().firstWhere((e) => e.id == id).audioAvailable, isTrue);
      s.setSetting('mp3_directory', selected.path);
      expect(
        s.episodes().firstWhere((e) => e.id == id).audioAvailable,
        isFalse,
      );
      expect(
        s.store.database.select(
          'SELECT available FROM local_audio_links WHERE episode_id=?',
          [id],
        ).single['available'],
        1,
        reason: 'Le périmètre de consultation ne réécrit pas les métadonnées du dernier scan.',
      );
    },
  );

  test('Journal de renommage interrompu réconcilié après déplacement de la racine portable', () async {
    final session = await start();
    final mp3 = Directory('${root.path}/MP3')..createSync();
    final source = File('${mp3.path}/mr_x_1997_01_04.mp3')
      ..writeAsStringSync('contenu conservé');
    final episode = session.episodes().firstWhere(
      (e) => e.originalName == 'mr_x_1997_01_04.mp3',
    );
    session.store.recordManualLink(
      episode.id,
      source.uri.toString(),
      episode.originalName,
    );
    session.favorite(episode.id, true);
    session.checkpoint(
      episode.id,
      positionMs: 23000,
      durationMs: 120000,
      progressed: true,
      completed: false,
      playbackStatus: 'paused',
    );
    final renamer = Mp3Renamer(session.store);
    final plan = await renamer.preview(mp3, recursive: false);
    final run = await renamer.execute(
      plan,
      move: (from, to) async {
        await from.rename(to.path);
        throw StateError('interruption avant mise à jour du lien');
      },
    );
    await session.dispose();
    root = await root.rename('${root.path}-déplacé');
    portable = Directory('${root.path}/application');
    data = PortableSession.configuredDirectory(portable)!;
    final reopened = await start(existing: true);
    final state = reopened.episodes().firstWhere((e) => e.id == episode.id);
    final target = File('${root.path}/MP3/${episode.systemName}');
    expect(
      FileSystemEntity.identicalSync(
        File.fromUri(Uri.parse(state.audioRef!)).path,
        target.path,
      ),
      isTrue,
    );
    expect(state.favorite, isTrue);
    expect(state.positionMs, 23000);
    expect(
      Mp3Renamer(reopened.store).report(run).single['status'],
      'succeeded',
    );
    expect(Mp3Renamer(reopened.store).unresolved, isFalse);
  });

  test('Déplacement de toute la racine : suivi, liens manuels et exclusions conservés sans scan', () async {
    final s = await start();
    final entries = s.episodes();
    final mp3 = Directory('${root.path}/MP3 été #')..createSync();
    final auto = File('${mp3.path}/${entries[0].originalName}')
      ..writeAsBytesSync([]);
    final manual = File('${mp3.path}/choix manuel.mp3')..writeAsBytesSync([]);
    final removed = File('${mp3.path}/${entries[2].originalName}')
      ..writeAsBytesSync([]);
    await s.scan(mp3.path);
    s.store.recordManualLink(
      entries[1].id,
      manual.uri.toString(),
      'choix manuel.mp3',
    );
    s.store.unlinkAudio(removed.uri.toString());
    s.favorite(entries[0].id, true);
    s.checkpoint(
      entries[0].id,
      positionMs: 42000,
      durationMs: 120000,
      progressed: true,
      completed: false,
      playbackStatus: 'paused',
    );
    s.setSetting('skip_startup_scan', 'true');
    final oldRoot = root.path;
    expect(
      jsonDecode(s.setting('portable_root_aliases_v1')!),
      containsAll({oldRoot, root.resolveSymbolicLinksSync()}),
    );
    await s.closeSafely();
    root = Directory(
      root.renameSync('$oldRoot-déplacé').resolveSymbolicLinksSync(),
    );
    portable = Directory('${root.path}/application');
    data = Directory('${root.path}/données utilisateur');
    final configured = PortableSession.configuredDirectory(portable)!;
    expect(FileSystemEntity.identicalSync(configured.path, data.path), isTrue);
    final reopened = await start(existing: true);
    final linked = reopened.episodes().firstWhere((e) => e.id == entries[0].id);
    expect(
      linked.audioRef,
      File('${root.path}/MP3 été #/${auto.uri.pathSegments.last}').uri
          .toString(),
    );
    expect(linked.audioAvailable, isTrue);
    expect(linked.favorite, isTrue);
    expect(linked.positionMs, 42000);
    expect(linked.status, 'EN_COURS');
    expect(
      reopened.episodes().firstWhere((e) => e.id == entries[1].id).audioRef,
      File('${root.path}/MP3 été #/choix manuel.mp3').uri.toString(),
    );
    expect(
      reopened.store.unlinkedAudioReferences,
      contains(
        File('${root.path}/MP3 été #/${removed.uri.pathSegments.last}').uri
            .toString(),
      ),
    );
    expect(
      FileSystemEntity.identicalSync(
        reopened.setting('mp3_directory')!,
        '${root.path}/MP3 été #',
      ),
      isTrue,
    );
    expect(reopened.setting('skip_startup_scan'), 'true');
    expect(
      reopened.store.database.select(
        'SELECT manual FROM local_audio_links WHERE episode_id=?',
        [entries[1].id],
      ).single['manual'],
      1,
    );
    await reopened.scan('${root.path}/MP3 été #');
    expect(
      reopened.episodes().firstWhere((e) => e.id == entries[2].id).audioRef,
      isNull,
    );
    expect(
      reopened
          .episodes()
          .firstWhere((e) => e.id == entries[1].id)
          .audioAvailable,
      isTrue,
    );
  });

  test('Ancien pointeur absolu migré avant déplacement ; chemins relatifs sortants refusés', () async {
    final s = await start();
    await s.closeSafely();
    final pointer = File('${portable.path}/index-portable.json');
    pointer.writeAsStringSync(
      jsonEncode({'version': 1, 'data_directory': data.path}),
    );
    expect(PortableSession.configuredDirectory(portable)!.path, data.path);
    final reopened = await start(existing: true);
    final value = jsonDecode(pointer.readAsStringSync()) as Map;
    expect(value['version'], 2);
    expect(value['relative'], isTrue);
    expect(value['data_directory'], 'données utilisateur');
    await reopened.closeSafely();
    pointer.writeAsStringSync(
      jsonEncode({
        'version': 2,
        'relative': true,
        'data_directory': '../ailleurs',
      }),
    );
    expect(
      () => PortableSession.configuredDirectory(portable),
      throwsFormatException,
    );
    pointer.writeAsStringSync(
      jsonEncode({
        'version': 2,
        'relative': true,
        'data_directory': '/ailleurs',
      }),
    );
    expect(
      () => PortableSession.configuredDirectory(portable),
      throwsFormatException,
    );
  });

  test(
    'Données et MP3 extérieurs : chemins absolus inchangés après déplacement',
    () async {
      final external = Directory.systemTemp.createTempSync('index-externe-');
      addTearDown(() => external.deleteSync(recursive: true));
      final s = await start(folder: external);
      s.setSetting('mp3_directory', external.path);
      final entry = s.episodes().first;
      final file = File('${external.path}/manuel.mp3')..writeAsBytesSync([]);
      s.store.recordManualLink(entry.id, file.uri.toString(), 'manuel.mp3');
      s.favorite(entry.id, true);
      await s.closeSafely();
      root = Directory(
        root.renameSync('${root.path}-déplacé').resolveSymbolicLinksSync(),
      );
      portable = Directory('${root.path}/application');
      expect(
        PortableSession.configuredDirectory(portable)!.path,
        external.resolveSymbolicLinksSync(),
      );
      final reopened = await start(folder: external, existing: true);
      expect(reopened.setting('mp3_directory'), external.path);
      expect(
        reopened.episodes().firstWhere((e) => e.id == entry.id).audioRef,
        file.uri.toString(),
      );
      expect(
        reopened.episodes().firstWhere((e) => e.id == entry.id).favorite,
        isTrue,
      );
      await reopened.dispose();
    },
  );

  test('Conflit de références après déplacement : transaction annulée sans perte de suivi', () async {
    final s = await start();
    final entries = s.episodes();
    final oldRoot = root.path;
    final oldCanonicalRoot = root.resolveSymbolicLinksSync();
    final destination = '$oldCanonicalRoot-déplacé';
    final before = File('$oldRoot/manuel.mp3').uri.toString();
    final after = File('$destination/manuel.mp3').uri.toString();
    s.store.recordManualLink(entries[0].id, before, 'manuel.mp3');
    s.store.recordManualLink(entries[1].id, after, 'manuel.mp3');
    s.favorite(entries[0].id, true);
    await s.closeSafely();
    root = Directory(root.renameSync(destination).resolveSymbolicLinksSync());
    portable = Directory('${root.path}/application');
    data = Directory('${root.path}/données utilisateur');
    await expectLater(start(existing: true), throwsA(isA<SqliteException>()));
    final db = sqlite3.open('${data.path}/index-utilisateur.sqlite');
    try {
      expect(
        db
            .select('SELECT audio_ref FROM local_audio_links')
            .map((r) => r['audio_ref'])
            .toSet(),
        {before, after},
      );
      expect(
        db
            .select(
              "SELECT value FROM local_settings WHERE key='portable_root_v1'",
            )
            .single['value'],
        oldCanonicalRoot,
      );
      expect(
        db.select(
          'SELECT is_favorite FROM user_episode_state WHERE episode_id=?',
          [entries[0].id],
        ).single['is_favorite'],
        1,
      );
    } finally {
      db.close();
    }
  });

  test('Données relatives absentes : chemin explicite, aucun profil de remplacement', () async {
    final s = await start();
    await s.closeSafely();
    final missing = Directory('${root.resolveSymbolicLinksSync()}/absent');
    File('${portable.path}/index-portable.json').writeAsStringSync(
      jsonEncode({'version': 2, 'relative': true, 'data_directory': 'absent'}),
    );
    await expectLater(
      start(
        folder: PortableSession.configuredDirectory(portable),
        existing: true,
      ),
      throwsA(
        isA<FileSystemException>().having(
          (e) => e.path,
          'chemin',
          missing.path,
        ),
      ),
    );
    expect(missing.existsSync(), isFalse);
  });

  test('Migration utilisateur réelle v4 vers v6 conserve favori, statut et progression', () async {
    final copy = File('${data.path}/index-utilisateur.sqlite');
    await copy.writeAsBytes(seed);
    final old = sqlite3.open(copy.path);
    final id =
        old.select('SELECT id FROM episodes LIMIT 1').single['id'] as String;
    expect(old.select('PRAGMA user_version').single.values.single, 4);
    old.execute(
      'INSERT INTO user_episode_state(episode_id,position_ms,duration_ms,listening_status,is_favorite) VALUES(?,42000,120000,?,1)',
      [id, 'EN_COURS'],
    );
    old.close();
    final s = await start(existing: true);
    expect(
      s.store.database.select('PRAGMA user_version').single.values.single,
      6,
    );
    final state = s.listeningState(id)!;
    expect(state['position_ms'], 42000);
    expect(state['is_favorite'], 1);
    expect(state['listening_status'], 'EN_COURS');
    expect(state['playback_status'], 'stopped');
    s.checkpoint(
      id,
      positionMs: 45000,
      durationMs: 120000,
      progressed: true,
      completed: false,
      playbackStatus: 'paused',
    );
    expect(s.listeningState(id)!['is_favorite'], 1);
  });

  test('SAF : URI persistantes, scan incomplet sans perte, suppression détectée au scan complet', () async {
    final s = await start();
    final e = s.episodes().first;
    s.favorite(e.id, true);
    const tree = 'content://test.documents/tree/root';
    const ref = '$tree/document/root%2Fa.mp3';
    await s.scanDocuments(
      tree,
      [
        {'reference': ref, 'name': e.originalName},
      ],
      complete: true,
      recursive: false,
      errors: [],
    );
    expect(s.episodes().firstWhere((v) => v.id == e.id).audioAvailable, isTrue);
    await s.scanDocuments(
      tree,
      [],
      complete: false,
      recursive: false,
      errors: ['Permission retirée'],
    );
    expect(s.episodes().firstWhere((v) => v.id == e.id).audioAvailable, isTrue);
    await s.scanDocuments(
      tree,
      [],
      complete: true,
      recursive: false,
      errors: [],
    );
    expect(
      s.episodes().firstWhere((v) => v.id == e.id).audioAvailable,
      isFalse,
    );
    expect(s.episodes().firstWhere((v) => v.id == e.id).favorite, isTrue);
  });

  test(
    'Checkpoint durable, reprise, statut manuel et seed v4 vers v5 sans perte',
    () async {
      final s = await start();
      final id = s.episodes().first.id;
      s.favorite(id, true);
      s.checkpoint(
        id,
        positionMs: 9000,
        durationMs: 120000,
        progressed: true,
        completed: false,
        playbackStatus: 'playing',
      );
      expect(s.listeningState(id)!['listening_status'], 'EN_COURS');
      expect(s.listeningState(id)!['is_favorite'], 1);
      await s.dispose();
      final reopened = await start(existing: true);
      expect(reopened.listeningState(id)!['position_ms'], 9000);
      expect(reopened.listeningState(id)!['last_played_at'], isNotNull);
      reopened.checkpoint(
        id,
        positionMs: 119000,
        durationMs: 120000,
        progressed: true,
        completed: true,
        playbackStatus: 'paused',
      );
      expect(reopened.listeningState(id)!['completed_at'], isNotNull);
      reopened.checkpoint(
        id,
        positionMs: 1000,
        durationMs: 120000,
        progressed: true,
        completed: false,
        playbackStatus: 'playing',
      );
      expect(reopened.listeningState(id)!['listening_status'], 'ECOUTE');
      reopened.listened(id, false, resetConfirmed: true);
      expect(reopened.listeningState(id)!['completed_at'], isNull);
      expect(reopened.listeningState(id)!['position_ms'], 0);
      expect(reopened.listeningState(id)!['is_favorite'], 1);
    },
  );

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
    expect(pointer.keys.toSet(), {'version', 'data_directory', 'relative'});
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
