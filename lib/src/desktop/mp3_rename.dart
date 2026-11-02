import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../io/catalog_sources.dart';
import '../io/local_audio_paths.dart';
import '../matching/matching_engine.dart';
import '../storage/catalog_store.dart';

/// Le système de fichiers doit refuser une cible existante, même concurrente.
typedef RenameFile = Future<void> Function(File source, File target);

final class RenameEntry {
  const RenameEntry._(
    this.before,
    this.after,
    this.episodeId,
    this.name,
    this.status,
    this.reason,
    this.bytes,
    this.modified,
    this.digest,
  );
  final String before, after, episodeId, name, status, reason, modified, digest;
  final int bytes;
  bool get planned => status == 'planned';
}

final class RenamePlan {
  RenamePlan._(this.scope, this.recursive, List<RenameEntry> entries)
    : entries = List.unmodifiable(entries);
  final String scope;
  final bool recursive;
  final List<RenameEntry> entries;
  int get planned => entries.where((e) => e.planned).length;
}

String _stamp() => DateTime.now().toUtc().toIso8601String();
Future<String> _digest(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

bool _safeName(String value) =>
    value.length <= 240 &&
    RegExp(
      r'^[^\\/:*?"<>|\x00-\x1f]+\.mp3$',
      caseSensitive: false,
    ).hasMatch(value) &&
    !RegExp(
      r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:[ .]|$)',
      caseSensitive: false,
    ).hasMatch(value);

/// Plan en lecture seule ; journal durable AVANT chaque opération native.
/// Aucun File.rename Dart en production : il peut remplacer une cible.
final class Mp3Renamer {
  Mp3Renamer(this.store);
  final CatalogStore store;
  final _paths = LocalAudioPaths();
  Object _referenceKey(String reference) =>
      Uri.tryParse(reference)?.scheme == 'content'
      ? documentReferenceKey(reference)
      : _paths.referenceKey(reference);

  bool _excluded(String reference) {
    final key = _referenceKey(reference);
    return store.unlinkedAudioReferences.any((r) => _referenceKey(r) == key);
  }

  bool get unresolved => store.database
      .select(
        "SELECT 1 FROM rename_items WHERE status IN ('planned','moving','blocked') LIMIT 1",
      )
      .isNotEmpty;

  Future<RenamePlan> preview(
    Directory root, {
    required bool recursive,
    String? inUse,
    void Function(int done, int total)? onProgress,
  }) async {
    _paths.clear();
    if (unresolved)
      throw StateError(
        'Un renommage interrompu doit être réconcilié avant une nouvelle opération.',
      );
    final directory = Directory(await root.resolveSymbolicLinks());
    final scan = await scanAudioDirectory(directory, recursive: recursive);
    if (!scan.complete)
      throw StateError(
        'Analyse incomplète : aucun renommage proposé. Vérifiez les droits et le dossier.',
      );
    final episodes = store.matchEpisodes();
    final byId = {for (final e in episodes) e.id: e};
    final decisions = const MatchingEngine().match(episodes, scan.audios);
    final entries = <RenameEntry>[];
    var done = 0;
    for (final d in decisions) {
      final source = File.fromUri(Uri.parse(d.audio.reference));
      final episode = byId[d.episodeId];
      var status = 'planned', reason = '';
      final name = episode?.systemNames.firstOrNull ?? '';
      final target = File('${source.parent.path}/$name');
      if (d.status != MatchStatus.confirmed || episode == null) {
        status = d.status == MatchStatus.conflict ? 'conflict' : 'ignored';
        reason = d.reason;
      } else if (_excluded(d.audio.reference)) {
        status = 'ignored';
        reason = 'Association retirée par l’utilisateur.';
      } else if (d.method != 'original_filename') {
        status = 'unchanged';
        reason = 'Déjà au nom système.';
      } else if (!_safeName(name) || target.path.length > 240) {
        status = 'ignored';
        reason =
            'Nom système absent, invalide ou chemin trop long pour Windows.';
      } else if (MatchingEngine.filenameKey(name) ==
          MatchingEngine.filenameKey(d.audio.currentName)) {
        status = 'unchanged';
        reason = 'Déjà conforme.';
      } else {
        final link = store.database.select(
          'SELECT audio_ref FROM local_audio_links WHERE episode_id=?',
          [episode.id],
        );
        if (link.isNotEmpty &&
            _referenceKey(link.single['audio_ref'] as String) !=
                _referenceKey(d.audio.reference)) {
          status = 'ignored';
          reason = 'Une autre association est conservée pour cet épisode.';
        } else if (inUse != null &&
            await _sameFile(source, File.fromUri(Uri.parse(inUse)))) {
          status = 'ignored';
          reason = 'Fichier utilisé par le lecteur : arrêtez et libérez la piste avant de refaire l’aperçu.';
        } else if (await _collision(target)) {
          status = 'conflict';
          reason =
              'Une cible de même nom existe déjà (casse et Unicode inclus).';
        }
      }
      var bytes = 0, modified = '', digest = '';
      if (status == 'planned') {
        try {
          final stat = await source.stat();
          if (stat.type != FileSystemEntityType.file ||
              await FileSystemEntity.isLink(source.path))
            throw StateError('Fichier non régulier.');
          bytes = stat.size;
          modified = stat.modified.toUtc().toIso8601String();
          digest = await _digest(source);
          if (!await _unchanged(source, bytes, modified))
            throw StateError('Fichier changé pendant la vérification.');
        } catch (error) {
          status = 'ignored';
          reason = 'Lecture/vérification impossible : $error';
        }
      }
      entries.add(
        RenameEntry._(
          d.audio.reference,
          target.uri.toString(),
          episode?.id ?? '',
          name,
          status,
          reason,
          bytes,
          modified,
          digest,
        ),
      );
      onProgress?.call(++done, decisions.length);
    }
    // Deux cibles identiques restent conflictuelles même avant leur création.
    final counts = <String, int>{};
    for (final e in entries.where((e) => e.planned)) {
      counts.update(
        MatchingEngine.filenameKey(File.fromUri(Uri.parse(e.after)).path),
        (v) => v + 1,
        ifAbsent: () => 1,
      );
    }
    return RenamePlan._(directory.uri.toString(), recursive, [
      for (final e in entries)
        if (e.planned &&
            counts[MatchingEngine.filenameKey(
                  File.fromUri(Uri.parse(e.after)).path,
                )]! >
                1)
          RenameEntry._(
            e.before,
            e.after,
            e.episodeId,
            e.name,
            'conflict',
            'Plusieurs fichiers visent la même cible.',
            e.bytes,
            e.modified,
            e.digest,
          )
        else
          e,
    ]);
  }

  Future<int> execute(
    RenamePlan plan, {
    required RenameFile move,
    String? Function()? inUse,
    void Function(int done, int total)? onProgress,
  }) async {
    _paths.clear();
    if (unresolved) throw StateError('Réconciliation requise.');
    final freshScan = await scanAudioDirectory(
      Directory.fromUri(Uri.parse(plan.scope)),
      recursive: plan.recursive,
    );
    if (!freshScan.complete)
      throw StateError('Analyse devenue incomplète : refaire l’aperçu.');
    final freshDecisions = {
      for (final d in const MatchingEngine().match(
        store.matchEpisodes(),
        freshScan.audios,
      ))
        d.audio.reference: d,
    };
    final db = store.database;
    // Tous les éléments confirmés sont persistés avant le premier accès en écriture aux MP3.
    db.execute('BEGIN IMMEDIATE');
    late int run;
    try {
      db.execute(
        "INSERT INTO rename_runs(scope,recursive,started_at,status) VALUES(?,?,?,'running')",
        [plan.scope, plan.recursive ? 1 : 0, _stamp()],
      );
      run = db.lastInsertRowId;
      for (final e in plan.entries.where((e) => e.planned)) {
        db.execute(
          "INSERT INTO rename_items(run_id,episode_id,before_ref,after_ref,target_name,bytes,modified,digest,status,updated_at) VALUES(?,?,?,?,?,?,?,?,'planned',?)",
          [
            run,
            e.episodeId,
            e.before,
            e.after,
            e.name,
            e.bytes,
            e.modified,
            e.digest,
            _stamp(),
          ],
        );
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
    var done = 0;
    for (final row in db.select(
      'SELECT * FROM rename_items WHERE run_id=? ORDER BY id',
      [run],
    )) {
      final source = File.fromUri(Uri.parse(row['before_ref'] as String));
      final target = File.fromUri(Uri.parse(row['after_ref'] as String));
      final id = row['id'] as int;
      var attempted = false;
      try {
        final decision = freshDecisions[row['before_ref']];
        if (decision?.status != MatchStatus.confirmed ||
            decision?.episodeId != row['episode_id'] ||
            decision?.method != 'original_filename')
          throw StateError(
            'Association devenue ambiguë ou fichier absent : refaire l’aperçu.',
          );
        final current = inUse?.call();
        if (current != null &&
            await _sameFile(source, File.fromUri(Uri.parse(current))))
          throw StateError('Fichier utilisé par le lecteur.');
        final episode = store
            .matchEpisodes()
            .where((e) => e.id == row['episode_id'])
            .firstOrNull;
        if (episode == null ||
            !episode.systemNames.contains(row['target_name']) ||
            MatchingEngine.filenameKey(source.uri.pathSegments.last) !=
                MatchingEngine.filenameKey(episode.originalName))
          throw StateError('Le catalogue a changé : refaire l’aperçu.');
        _checkLink(row);
        if (_excluded(source.uri.toString()))
          throw StateError('Association retirée depuis l’aperçu.');
        if (!await _unchanged(
              source,
              row['bytes'] as int,
              row['modified'] as String,
            ) ||
            await _digest(source) != row['digest'])
          throw StateError('Le fichier a changé depuis l’aperçu.');
        if (await _collision(target))
          throw StateError('Cible occupée depuis l’aperçu. Aucun écrasement.');
        if (!await FileSystemEntity.identical(
          source.parent.path,
          target.parent.path,
        ))
          throw StateError('Renommage limité au même dossier.');
        final active = inUse?.call();
        if (active != null &&
            await _sameFile(source, File.fromUri(Uri.parse(active))))
          throw StateError('Fichier utilisé par le lecteur.');
        _status(id, 'moving', null);
        attempted = true;
        await move(source, target);
        // Vérification avant de modifier les liens, y compris en cas de callback défaillant.
        if (await FileSystemEntity.type(source.path, followLinks: false) !=
                FileSystemEntityType.notFound ||
            !await _validTarget(target, row['digest'] as String))
          throw StateError('Résultat natif à réconcilier.');
        _finish(row);
      } catch (error) {
        _status(id, attempted ? 'moving' : 'failed', error.toString());
        // Après un résultat natif incertain, ne pas continuer à déplacer d’autres fichiers.
        if (attempted) break;
      }
      onProgress?.call(++done, plan.planned);
    }
    _finishRuns();
    return run;
  }

  /// Au démarrage : ne renomme rien ; constate les fichiers puis répare SQLite.
  Future<void> recover() async {
    _paths.clear();
    for (final row in store.database.select(
      "SELECT * FROM rename_items WHERE status IN ('planned','moving','blocked') ORDER BY id",
    )) {
      if (Uri.parse(row['before_ref'] as String).scheme == 'content') continue;
      final id = row['id'] as int;
      if (row['status'] == 'planned') {
        _status(
          id,
          'skipped',
          'Opération interrompue avant tentative ; refaire l’aperçu.',
        );
        continue;
      }
      try {
        final before = File.fromUri(Uri.parse(row['before_ref'] as String));
        final after = File.fromUri(Uri.parse(row['after_ref'] as String));
        final oldType = await FileSystemEntity.type(
          before.path,
          followLinks: false,
        );
        final newType = await FileSystemEntity.type(
          after.path,
          followLinks: false,
        );
        if (oldType == FileSystemEntityType.notFound &&
            await _validTarget(after, row['digest'] as String)) {
          _finish(row);
        } else if (oldType == FileSystemEntityType.file &&
            newType == FileSystemEntityType.notFound &&
            await _digest(before) == row['digest']) {
          _status(
            id,
            'failed',
            'Renommage non effectué avant interruption ; fichier d’origine conservé.',
          );
        } else {
          _status(
            id,
            'blocked',
            'Réconciliation ambiguë : dossier inaccessible, fichier changé, absent ou deux noms présents. Aucun fichier modifié.',
          );
        }
      } catch (error) {
        _status(id, 'blocked', 'Réconciliation impossible : $error');
      }
    }
    _finishRuns();
  }

  void _checkLink(Map<String, Object?> row) {
    final before = _referenceKey(row['before_ref'] as String);
    final after = _referenceKey(row['after_ref'] as String);
    for (final link in store.database.select(
      'SELECT episode_id,audio_ref FROM local_audio_links',
    )) {
      final reference = _referenceKey(link['audio_ref'] as String);
      if ((link['episode_id'] == row['episode_id'] && reference != before) ||
          (link['episode_id'] != row['episode_id'] &&
              (reference == before || reference == after))) {
        throw StateError(
          'Association modifiée ou cible déjà associée : intervention nécessaire.',
        );
      }
    }
  }

  void _finish(Map<String, Object?> row) {
    final db = store.database;
    db.execute('BEGIN IMMEDIATE');
    try {
      _checkLink(row);
      db.execute(
        '''INSERT INTO local_audio_links(episode_id,audio_ref,current_name,method,matching_status,local_verification_status,evidence_json,manual,available,updated_at)
        VALUES(?,?,?,'catalog_filename','confirmed','NON_VERIFIEE',?,0,1,?)
        ON CONFLICT(episode_id) DO UPDATE SET audio_ref=excluded.audio_ref,current_name=excluded.current_name,method=CASE WHEN local_audio_links.manual=1 THEN local_audio_links.method ELSE 'catalog_filename' END,available=1,updated_at=excluded.updated_at''',
        [
          row['episode_id'],
          row['after_ref'],
          row['target_name'],
          jsonEncode({
            'rename_run': row['run_id'],
            'before': row['before_ref'],
            'after': row['after_ref'],
          }),
          _stamp(),
        ],
      );
      // Les diagnostics courants suivent le chemin, sans changer l’identité documentaire.
      for (final item in db.select(
        'SELECT rowid,audio_ref,decision_json FROM audio_scan_items',
      )) {
        if (_referenceKey(item['audio_ref'] as String) !=
            _referenceKey(row['before_ref'] as String))
          continue;
        final decision =
            jsonDecode(item['decision_json'] as String) as Map<String, dynamic>;
        decision['audio_reference'] = row['after_ref'];
        decision['current_name'] = row['target_name'];
        if (decision['matching_method'] != 'manual') {
          decision['matching_method'] = 'catalog_filename';
          decision['reason'] =
              'Association conservée après renommage confirmé.';
        }
        db.execute(
          'UPDATE audio_scan_items SET audio_ref=?,decision_json=? WHERE rowid=?',
          [row['after_ref'], jsonEncode(decision), item['rowid']],
        );
      }
      _status(row['id'] as int, 'succeeded', null);
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _status(int id, String status, String? error) => store.database.execute(
    'UPDATE rename_items SET status=?,error=?,updated_at=? WHERE id=?',
    [status, error, _stamp(), id],
  );
  void _finishRuns() {
    store.database.execute(
      "UPDATE rename_runs SET status='completed',completed_at=? WHERE status='running' AND NOT EXISTS(SELECT 1 FROM rename_items i WHERE i.run_id=rename_runs.id AND i.status IN ('planned','moving','blocked'))",
      [_stamp()],
    );
  }

  List<Map<String, Object?>> report(int run) => [
    for (final row in store.database.select(
      'SELECT * FROM rename_items WHERE run_id=? ORDER BY id',
      [run],
    ))
      Map<String, Object?>.from(row),
  ];
}

/// Contrat SAF opaque ; aucun URI content:// n’est converti en chemin de disque.
typedef DocumentOperation = Future<Object?> Function(
  String method,
  Map<String, Object?> arguments,
);

/// Même journal et mêmes identités que Windows, avec capacités du fournisseur.
final class DocumentMp3Renamer {
  DocumentMp3Renamer(this.store, this.call) : _journal = Mp3Renamer(store);
  final CatalogStore store;
  final DocumentOperation call;
  final Mp3Renamer _journal;
  bool get unresolved => _journal.unresolved;
  List<Map<String, Object?>> report(int run) => _journal.report(run);
  Future<Map<String, Object?>> _map(
    String method,
    Map<String, Object?> args,
  ) async => Map<String, Object?>.from(await call(method, args) as Map);

  Future<RenamePlan> preview(
    String tree, {
    required bool recursive,
    String? inUse,
    void Function(int done, int total)? onProgress,
  }) async {
    if (unresolved) throw StateError('Réconciliation du renommage requise.');
    if (Uri.parse(tree).scheme != 'content')
      throw ArgumentError('Dossier SAF requis.');
    final scan = await _map('scan', {'tree': tree, 'recursive': recursive});
    if (scan['complete'] != true)
      throw StateError('Analyse SAF incomplète : aucun renommage.');
    final decisions = const MatchingEngine().match(store.matchEpisodes(), [
      for (final raw in scan['files'] as List)
        AudioCandidate(
          reference: (raw as Map)['reference'] as String,
          currentName: raw['name'] as String,
        ),
    ]);
    final episodes = {for (final e in store.matchEpisodes()) e.id: e};
    final entries = <RenameEntry>[];
    for (final d in decisions) {
      final episode = episodes[d.episodeId];
      final name = episode?.systemNames.firstOrNull ?? '';
      var status = 'planned', reason = '', after = d.audio.reference;
      var info = <String, Object?>{};
      if (d.status != MatchStatus.confirmed || episode == null) {
        status = d.status == MatchStatus.conflict ? 'conflict' : 'ignored';
        reason = d.reason;
      } else if (_journal._excluded(d.audio.reference)) {
        status = 'ignored';
        reason = 'Association retirée par l’utilisateur.';
      } else if (d.method != 'original_filename' ||
          MatchingEngine.filenameKey(name) ==
              MatchingEngine.filenameKey(d.audio.currentName)) {
        status = 'unchanged';
        reason = 'Déjà au nom système.';
      } else if (!_safeName(name)) {
        status = 'ignored';
        reason = 'Nom système invalide.';
      } else if (inUse != null &&
          documentReferenceKey(inUse) ==
              documentReferenceKey(d.audio.reference)) {
        status = 'ignored';
        reason = 'Libérez le fichier du lecteur avant de refaire l’aperçu.';
      } else {
        try {
          info = await _map('renameInfo', {
            'reference': d.audio.reference,
            'name': name,
          });
          if (info['supported'] != true) {
            status = 'ignored';
            reason =
                info['reason'] as String? ??
                'Fournisseur sans garantie de renommage sûr.';
          } else if (info['collision'] == true) {
            status = 'conflict';
            reason = 'Cible déjà présente. Aucun écrasement.';
          } else {
            after = info['after'] as String;
            final row = {
              'episode_id': episode.id,
              'before_ref': d.audio.reference,
              'after_ref': after,
            };
            _journal._checkLink(row);
          }
        } catch (e) {
          status = 'ignored';
          reason = 'Vérification impossible : $e';
        }
      }
      entries.add(
        RenameEntry._(
          d.audio.reference,
          after,
          episode?.id ?? '',
          name,
          status,
          reason,
          info['bytes'] as int? ?? 0,
          info['modified'] as String? ?? '',
          info['digest'] as String? ?? '',
        ),
      );
      onProgress?.call(entries.length, decisions.length);
    }
    final counts = <String, int>{};
    for (final e in entries.where((e) => e.planned))
      counts.update(e.after, (v) => v + 1, ifAbsent: () => 1);
    return RenamePlan._(tree, recursive, [
      for (final e in entries)
        if (e.planned && counts[e.after]! > 1)
          RenameEntry._(
            e.before,
            e.after,
            e.episodeId,
            e.name,
            'conflict',
            'Plusieurs fichiers visent la même cible.',
            e.bytes,
            e.modified,
            e.digest,
          )
        else
          e,
    ]);
  }

  Future<int> execute(
    RenamePlan plan, {
    String? Function()? inUse,
    void Function(int done, int total)? onProgress,
  }) async {
    final fresh = await preview(
      plan.scope,
      recursive: plan.recursive,
      inUse: inUse?.call(),
    );
    final checked = {for (final e in fresh.entries) e.before: e};
    final db = store.database;
    db.execute('BEGIN IMMEDIATE');
    late int run;
    try {
      db.execute(
        "INSERT INTO rename_runs(scope,recursive,started_at,status) VALUES(?,?,?,'running')",
        [plan.scope, plan.recursive ? 1 : 0, _stamp()],
      );
      run = db.lastInsertRowId;
      for (final e in plan.entries.where((e) => e.planned)) {
        db.execute(
          "INSERT INTO rename_items(run_id,episode_id,before_ref,after_ref,target_name,bytes,modified,digest,status,updated_at) VALUES(?,?,?,?,?,?,?,?,'planned',?)",
          [
            run,
            e.episodeId,
            e.before,
            e.after,
            e.name,
            e.bytes,
            e.modified,
            e.digest,
            _stamp(),
          ],
        );
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
    var done = 0;
    for (final raw in db.select(
      'SELECT * FROM rename_items WHERE run_id=? ORDER BY id',
      [run],
    )) {
      final row = Map<String, Object?>.from(raw), id = raw['id'] as int;
      var attempted = false;
      try {
        final e = checked[row['before_ref']];
        if (e == null ||
            !e.planned ||
            e.episodeId != row['episode_id'] ||
            e.after != row['after_ref'] ||
            e.digest != row['digest'] ||
            e.modified != row['modified'] ||
            e.bytes != row['bytes'])
          throw StateError(
            'Source, catalogue ou collision modifiés : refaire l’aperçu.',
          );
        _journal._checkLink(row);
        final active = inUse?.call();
        if (_journal._excluded(e.before) ||
            (active != null &&
                documentReferenceKey(active) == documentReferenceKey(e.before)))
          throw StateError('Association retirée ou fichier en lecture.');
        _journal._status(id, 'moving', null);
        attempted = true;
        final result = await call('renameDocument', {
          'reference': e.before,
          'name': e.name,
          'digest': e.digest,
          'bytes': e.bytes,
          'modified': e.modified,
        });
        if (result != e.after)
          throw StateError(
            'Référence retournée inattendue : réconciliation nécessaire.',
          );
        final after = await call('fingerprint', {'reference': e.after});
        final before = await call('fingerprint', {'reference': e.before});
        if (before != null || after is! Map || after['digest'] != e.digest)
          throw StateError('Résultat à réconcilier.');
        _journal._finish(row);
      } catch (e) {
        _journal._status(id, attempted ? 'moving' : 'failed', e.toString());
        if (attempted) break;
      }
      onProgress?.call(++done, plan.planned);
    }
    _journal._finishRuns();
    return run;
  }

  Future<void> recover() async {
    for (final raw in store.database.select(
      "SELECT * FROM rename_items WHERE status IN ('planned','moving','blocked') ORDER BY id",
    )) {
      final row = Map<String, Object?>.from(raw), id = raw['id'] as int;
      if (Uri.parse(row['before_ref'] as String).scheme != 'content') continue;
      if (row['status'] == 'planned') {
        _journal._status(
          id,
          'skipped',
          'Interrompu avant tentative ; refaire l’aperçu.',
        );
        continue;
      }
      try {
        _journal._checkLink(row);
        if (_journal._excluded(row['before_ref'] as String) ||
            _journal._excluded(row['after_ref'] as String))
          throw StateError(
            'Association retirée depuis l’opération : intervention explicite requise.',
          );
        var before = await call('fingerprint', {
          'reference': row['before_ref'],
        });
        final after = await call('fingerprint', {
          'reference': row['after_ref'],
        });
        if (before is Map &&
            after is Map &&
            before['identity'] != null &&
            before['identity'] == after['identity'] &&
            after['digest'] == row['digest']) {
          // Le fournisseur IndeX achève seulement un lien dur déjà journalisé,
          // avec même inode et même empreinte ; aucune copie ni cible remplacée.
          await call('renameDocument', {
            'reference': row['before_ref'],
            'name': row['target_name'],
            'digest': row['digest'],
            'bytes': row['bytes'],
            'modified': row['modified'],
          });
          before = await call('fingerprint', {'reference': row['before_ref']});
        }
        if (before == null &&
            after is Map &&
            after['digest'] == row['digest']) {
          _journal._finish(row);
        } else if (before is Map &&
            before['digest'] == row['digest'] &&
            after == null) {
          _journal._status(
            id,
            'failed',
            'Nom d’origine conservé ; refaire l’aperçu.',
          );
        } else {
          _journal._status(
            id,
            'blocked',
            'Réconciliation ambiguë ou accès indisponible. Aucun fichier modifié.',
          );
        }
      } catch (e) {
        _journal._status(id, 'blocked', 'Réconciliation impossible : $e');
      }
    }
    _journal._finishRuns();
  }
}

Future<bool> _sameFile(File a, File b) async {
  try {
    return await FileSystemEntity.identical(a.path, b.path);
  } on FileSystemException {
    return a.absolute.path == b.absolute.path;
  }
}

Future<bool> _unchanged(File file, int bytes, String modified) async =>
    await FileSystemEntity.type(file.path, followLinks: false) ==
        FileSystemEntityType.file &&
    (await file.stat()).size == bytes &&
    (await file.stat()).modified.toUtc().toIso8601String() == modified;
Future<bool> _validTarget(File file, String digest) async =>
    await FileSystemEntity.type(file.path, followLinks: false) ==
        FileSystemEntityType.file &&
    await _digest(file) == digest;
Future<bool> _collision(File target) async {
  final key = MatchingEngine.filenameKey(target.uri.pathSegments.last);
  await for (final entry in target.parent.list(followLinks: false)) {
    if (MatchingEngine.filenameKey(
          entry.uri.pathSegments.where((s) => s.isNotEmpty).last,
        ) ==
        key)
      return true;
  }
  return false;
}
