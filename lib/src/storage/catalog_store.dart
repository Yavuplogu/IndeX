import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import '../catalog/models.dart';
import '../catalog/planner.dart';
import '../io/catalog_sources.dart';
import '../matching/matching_engine.dart';
import 'migrations.dart';

final class ImportCancelled implements Exception {
  const ImportCancelled();
}

final class ImportOutcome {
  const ImportOutcome(this.runId, this.inserted, this.updated, this.unchanged);
  final int runId;
  final int inserted;
  final int updated;
  final int unchanged;
  Map<String, int> toJson() => {
    'run_id': runId,
    'inserted': inserted,
    'updated': updated,
    'unchanged': unchanged,
  };
}

final class CatalogStore {
  CatalogStore._(this.database);
  factory CatalogStore.open(String path) =>
      CatalogStore.fromDatabase(sqlite3.open(path));
  factory CatalogStore.inMemory() =>
      CatalogStore.fromDatabase(sqlite3.openInMemory());

  /// Prend possession de la connexion et la ferme également si la migration échoue.
  factory CatalogStore.fromDatabase(Database db) {
    try {
      migrate(db);
      return CatalogStore._(db);
    } catch (_) {
      db.close();
      rethrow;
    }
  }
  final Database database;
  void close() => database.close();

  ImportOutcome importPlan(
    CatalogPlan plan, {
    DateTime? now,
    String? catalogVersion,
    DateTime? catalogGeneratedAt,
    bool Function()? isCancelled,
    void Function(int processed)? afterEpisode,
  }) {
    final stamp = (now ?? DateTime.now()).toUtc().toIso8601String();
    database.execute(
      'INSERT INTO import_runs(started_at,status,source_digest) VALUES(?,?,?)',
      [stamp, 'running', plan.sourceDigest],
    );
    final run = database.lastInsertRowId;
    var inserted = 0, updated = 0, unchanged = 0, processed = 0;
    try {
      if (!plan.canApply)
        throw const FormatException(
          'Journal inutilisable ; import refusé avant toute modification du catalogue.',
        );
      database.execute('BEGIN IMMEDIATE');
      try {
        final snapshots = database.select(
          "SELECT COALESCE(snapshot_run_id,id) AS snapshot FROM import_runs WHERE source_digest=? AND status='completed' ORDER BY id DESC LIMIT 1",
          [plan.sourceDigest],
        );
        final snapshot = snapshots.isEmpty
            ? run
            : snapshots.single['snapshot'] as int;
        if (catalogVersion != null) {
          final previous = database.select(
            'SELECT source_digest FROM catalog_versions WHERE version=?',
            [catalogVersion],
          );
          if (previous.isNotEmpty &&
              previous.single['source_digest'] != plan.sourceDigest)
            throw StateError(
              'Une version de catalogue publiée ne peut pas changer de contenu.',
            );
        }
        for (final episode in plan.episodes) {
          if (isCancelled?.call() == true) throw const ImportCancelled();
          final existing = database.select(
            'SELECT fingerprint,origin FROM episodes WHERE id=?',
            [episode.id],
          );
          if (existing.isNotEmpty &&
              existing.single['origin'] == 'user' &&
              catalogVersion != null) {
            _issue(
              run,
              CatalogIssue(
                'user_override_preserved',
                'Fiche utilisateur préservée face au catalogue de référence.',
                originalName: episode.originalName,
              ),
            );
            unchanged++;
          } else if (existing.isNotEmpty &&
              existing.single['fingerprint'] == episode.fingerprint) {
            unchanged++;
          } else {
            _writeEpisode(
              episode,
              stamp,
              catalogVersion == null ? 'user' : 'reference',
              existing.isEmpty,
            );
            if (existing.isEmpty)
              inserted++;
            else
              updated++;
          }
          afterEpisode?.call(++processed);
        }
        if (isCancelled?.call() == true) throw const ImportCancelled();
        for (final record
            in snapshots.isEmpty ? plan.records : const <SourceRecord>[]) {
          database.execute(
            'INSERT INTO source_records(run_id,kind,source_key,disposition,original_name,raw_bytes,fields_json) VALUES(?,?,?,?,?,?,?)',
            [
              run,
              record.kind,
              record.key,
              record.disposition,
              record.originalName,
              record.bytes,
              record.fields == null ? null : jsonEncode(record.fields),
            ],
          );
        }
        for (final issue in plan.issues) {
          _issue(run, issue);
        }
        if (catalogVersion != null)
          database.execute(
            'INSERT OR IGNORE INTO catalog_versions VALUES(?,?,?,?)',
            [
              catalogVersion,
              plan.sourceDigest,
              (catalogGeneratedAt ?? now ?? DateTime.now())
                  .toUtc()
                  .toIso8601String(),
              schemaVersion,
            ],
          );
        final result = ImportOutcome(run, inserted, updated, unchanged);
        database.execute(
          'UPDATE import_runs SET status=?,completed_at=?,summary_json=?,snapshot_run_id=? WHERE id=?',
          [
            'completed',
            stamp,
            jsonEncode({...plan.summary(), ...result.toJson()}),
            snapshot,
            run,
          ],
        );
        database.execute('COMMIT');
        return result;
      } catch (_) {
        database.execute('ROLLBACK');
        rethrow;
      }
    } catch (e) {
      database.execute(
        'UPDATE import_runs SET status=?,completed_at=?,error=? WHERE id=?',
        [
          e is ImportCancelled ? 'cancelled' : 'failed',
          stamp,
          e.toString(),
          run,
        ],
      );
      // Les diagnostics d'un journal rejeté restent consultables, sans toucher aux fiches.
      for (final issue in plan.issues) {
        _issue(run, issue);
      }
      rethrow;
    }
  }

  /// Charge/migre les données de référence d'un seed sans dépendre de CSV/TXT externes.
  /// Les tables de suivi et les chemins locaux de la cible ne sont jamais remplacés.
  ImportOutcome importReference(String path, {DateTime? now}) {
    final file = File(path);
    if (file.lengthSync() > 64 * 1024 * 1024)
      throw const FormatException('Catalogue de référence excessif.');
    final targetPath =
        database
                .select('PRAGMA database_list')
                .singleWhere((r) => r['name'] == 'main')['file']
            as String;
    if (targetPath.isNotEmpty &&
        File(targetPath).resolveSymbolicLinksSync() ==
            file.resolveSymbolicLinksSync()) {
      throw ArgumentError(
        'Le seed de référence et la base de travail doivent être distincts.',
      );
    }
    final source = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      source.execute('PRAGMA trusted_schema=OFF');
      if (source.select('PRAGMA application_id').single.values.single !=
              applicationId ||
          !{
            2,
            3,
            4,
            schemaVersion,
          }.contains(source.select('PRAGMA user_version').single.values.single))
        throw const FormatException('Catalogue de référence non reconnu.');
      if (source.select('PRAGMA integrity_check').single.values.single !=
              'ok' ||
          source.select('PRAGMA foreign_key_check').isNotEmpty)
        throw const FormatException('Catalogue de référence corrompu.');
      if ((source.select('PRAGMA user_version').single.values.single as int) >=
              4 &&
          source.select('SELECT 1 FROM local_settings LIMIT 1').isNotEmpty) {
        throw const FormatException(
          'Un seed ne doit pas contenir de réglages personnels.',
        );
      }
      if (source.select('SELECT * FROM catalog_versions').length != 1 ||
          source.select('SELECT 1 FROM local_audio_links LIMIT 1').isNotEmpty ||
          source
              .select('SELECT 1 FROM user_episode_state LIMIT 1')
              .isNotEmpty) {
        throw const FormatException(
          'Un seed documentaire sans données personnelles est requis.',
        );
      }
      final version = source.select('SELECT * FROM catalog_versions').single;
      if (version['version'] is! String ||
          version['source_digest'] is! String ||
          version['generated_at'] is! String) {
        throw const FormatException('Métadonnées de catalogue invalides.');
      }
      final runs = source.select(
        "SELECT COALESCE(snapshot_run_id,id) AS id FROM import_runs WHERE status='completed' AND source_digest=? ORDER BY id DESC LIMIT 1",
        [version['source_digest']],
      );
      if (runs.isEmpty)
        throw const FormatException('Provenance du catalogue absente.');
      final run = runs.single['id'];
      final budget = source.select(
        "SELECT count(*) n,COALESCE(sum(length(raw_bytes)),0) bytes FROM source_records WHERE run_id=? AND kind IN('txt','journal')",
        [run],
      ).single;
      if ((budget['n'] as int) > 10001 ||
          (budget['bytes'] as int) > 48 * 1024 * 1024)
        throw const FormatException('Sources du catalogue excessives.');
      final inputs = <TxtInput>[];
      List<int>? journal;
      for (final row in source.select(
        "SELECT * FROM source_records WHERE run_id=? AND kind IN('txt','journal') ORDER BY id",
        [run],
      )) {
        final bytes = row['raw_bytes'];
        if (bytes is! Uint8List)
          throw const FormatException('Source manquante dans le seed.');
        if (row['kind'] == 'txt') {
          final key = row['source_key'];
          if (key is! String ||
              key.isEmpty ||
              key.length > 2048 ||
              key.startsWith('/') ||
              RegExp(r'^[A-Za-z]:').hasMatch(key) ||
              key.split('/').contains('..')) {
            throw const FormatException(
              'Provenance TXT invalide dans le seed.',
            );
          }
          final rawMetadata = row['fields_json'];
          if (rawMetadata != null &&
              (rawMetadata is! String || rawMetadata.length > 65536))
            throw const FormatException(
              'Métadonnées de source excessives ou invalides.',
            );
          final metadata = rawMetadata == null
              ? null
              : jsonDecode(rawMetadata as String);
          if (metadata != null &&
              (metadata is! Map<String, dynamic> ||
                  (metadata['read_error'] != null &&
                      metadata['read_error'] is! String))) {
            throw const FormatException('Métadonnées de source invalides.');
          }
          inputs.add(
            TxtInput(key, bytes, readError: metadata?['read_error'] as String?),
          );
        } else {
          if (journal != null)
            throw const FormatException('Plusieurs journaux dans le seed.');
          journal = bytes;
        }
      }
      final plan = CatalogPlanner().plan(inputs, journalBytes: journal);
      if (!plan.canApply || plan.sourceDigest != version['source_digest'])
        throw const FormatException(
          'Empreinte des sources du catalogue incohérente.',
        );
      final generatedAt = DateTime.tryParse(version['generated_at'] as String);
      if (generatedAt == null || !generatedAt.isUtc)
        throw const FormatException('Date du catalogue invalide.');
      return importPlan(
        plan,
        now: now,
        catalogVersion: version['version'] as String,
        catalogGeneratedAt: generatedAt,
      );
    } finally {
      source.close();
    }
  }

  void _issue(int run, CatalogIssue i) => database.execute(
    'INSERT INTO import_issues(run_id,code,severity,source,original_name,message) VALUES(?,?,?,?,?,?)',
    [run, i.code, i.severity.name, i.source, i.originalName, i.message],
  );

  void _writeEpisode(
    CatalogEpisode e,
    String stamp,
    String origin,
    bool isNew,
  ) {
    final d = e.document;
    final date = d.broadcastDate?.toIso8601String().substring(0, 10);
    final values = <Object?>[
      e.originalName,
      d.originalNameRaw!,
      d.title!,
      date,
      d.description ?? '',
      d.sourceText ?? '',
      d.musicText ?? '',
      d.pageUrl,
      d.mp3Url,
      e.sourcePath,
      Uint8List.fromList(e.sourceBytes),
      d.rawText,
      e.systemName,
      e.journalStatus,
      e.journalFields == null ? null : jsonEncode(e.journalFields),
      e.fingerprint,
      e.needsReview ? 1 : 0,
      origin,
      stamp,
      e.id,
    ];
    if (isNew) {
      database.execute(
        'INSERT INTO episodes(original_name,original_raw,title,broadcast_date,description,sources_text,music_text,page_url,mp3_url,source_path,source_bytes,raw_text,system_name,journal_status,journal_json,fingerprint,needs_review,origin,updated_at,id) VALUES(${List.filled(20, '?').join(',')})',
        values,
      );
    } else {
      database.execute(
        'UPDATE episodes SET original_name=?,original_raw=?,title=?,broadcast_date=?,description=?,sources_text=?,music_text=?,page_url=?,mp3_url=?,source_path=?,source_bytes=?,raw_text=?,system_name=COALESCE(?,system_name),journal_status=COALESCE(?,journal_status),journal_json=COALESCE(?,journal_json),fingerprint=?,needs_review=?,origin=?,updated_at=? WHERE id=?',
        values,
      );
    }
    void alias(String kind, String value) {
      if (value.isNotEmpty)
        database.execute(
          'INSERT OR IGNORE INTO episode_aliases VALUES(?,?,?)',
          [e.id, kind, value],
        );
    }

    alias('original_filename', e.originalName);
    alias('txt_filename', e.sourcePath.split('/').last);
    if (e.systemName != null) alias('catalog_filename', e.systemName!);
    database.execute('DELETE FROM literary_sources WHERE episode_id=?', [e.id]);
    for (var i = 0; i < d.sources.length; i++) {
      final s = d.sources[i];
      database.execute('INSERT INTO literary_sources VALUES(?,?,?,?,?,?)', [
        e.id,
        i,
        s.rawText,
        s.title,
        s.author,
        s.publisher,
      ]);
    }
    database.execute('DELETE FROM music_tracks WHERE episode_id=?', [e.id]);
    for (var i = 0; i < d.music.length; i++) {
      final m = d.music[i];
      database.execute('INSERT INTO music_tracks VALUES(?,?,?,?,?,?,?)', [
        e.id,
        i,
        m.rawText,
        m.artist,
        m.title,
        m.album,
        m.label,
      ]);
    }
  }

  List<MatchEpisode> matchEpisodes() => [
    for (final row in database.select(
      'SELECT id,title,journal_status,journal_json FROM episodes WHERE journal_json IS NOT NULL ORDER BY id',
    ))
      // The current journal is authoritative; historical aliases are audit only.
      for (final fields in [
        jsonDecode(row['journal_json'] as String) as Map<String, dynamic>,
      ])
        MatchEpisode(
          id: row['id'] as String,
          originalName: fields["FICHIER MP3 D'ORIGINE"] as String,
          title: row['title'] as String,
          journalStatus: row['journal_status'] as String?,
          systemNames: [
            if ((fields['TITRE SYSTEME'] as String?)?.isNotEmpty == true)
              fields['TITRE SYSTEME'] as String,
          ],
        ),
  ];

  /// Réévalue les liens automatiques ; préserve choix manuels et suivi.
  /// Une réaffectation automatique est auditée, sans supprimer l'état d'écoute.
  List<CatalogIssue> applyAudioScan(AudioScan scan, {DateTime? now}) {
    final excluded = unlinkedAudioReferences;
    final links = database.select('SELECT * FROM local_audio_links');
    final manualByRef = {
      for (final row in links)
        if (row['manual'] == 1) row['audio_ref'] as String: row,
    };
    final manualByEpisode = {
      for (final row in links)
        if (row['manual'] == 1) row['episode_id'] as String: row,
    };
    final automatic = const MatchingEngine().match(
      matchEpisodes(),
      scan.audios
          .where(
            (a) =>
                !manualByRef.containsKey(a.reference) &&
                !excluded.contains(a.reference),
          )
          .toList(),
    );
    final byRef = {for (final d in automatic) d.audio.reference: d};
    final issues = [...scan.issues];
    final decisions = <MatchDecision>[
      for (final audio in scan.audios)
        if (manualByRef.containsKey(audio.reference))
          MatchDecision(
            audio: audio,
            status: MatchStatus.confirmed,
            episodeId: manualByRef[audio.reference]!['episode_id'] as String,
            method: 'manual',
            reason: 'Association manuelle confirmée par l’utilisateur, conservée. Contenu audio non vérifié.',
          )
        else if (excluded.contains(audio.reference))
          MatchDecision(
            audio: audio,
            status: MatchStatus.unknown,
            episodeId: null,
            method: 'manual_unlinked',
            reason: 'Association retirée par l’utilisateur ; choisissez Associer… pour la rétablir.',
          )
        else if (byRef[audio.reference]!.status == MatchStatus.confirmed &&
            manualByEpisode.containsKey(byRef[audio.reference]!.episodeId))
          MatchDecision(
            audio: audio,
            status: MatchStatus.conflict,
            episodeId: byRef[audio.reference]!.episodeId,
            method: byRef[audio.reference]!.method,
            reason: 'Cet épisode possède déjà un choix manuel ; aucun remplacement automatique.',
          )
        else if (!scan.complete &&
            byRef[audio.reference]!.status == MatchStatus.confirmed)
          MatchDecision(
            audio: audio,
            status: MatchStatus.blocked,
            episodeId: byRef[audio.reference]!.episodeId,
            method: byRef[audio.reference]!.method,
            reason: 'Scan incomplet : concordance par nom trouvée, association automatique non validée.',
          )
        else
          byRef[audio.reference]!,
    ];
    final stamp = (now ?? DateTime.now()).toUtc().toIso8601String();
    database.execute('BEGIN IMMEDIATE');
    try {
      if (scan.complete) {
        final seen = scan.audios.map((a) => a.reference).toSet();
        for (final row in database.select(
          'SELECT episode_id,audio_ref,manual FROM local_audio_links',
        )) {
          final ref = row['audio_ref'] as String;
          final inScope =
              ref.startsWith(scan.scope) &&
              (scan.scope.startsWith('content://') ||
                  scan.recursive ||
                  !ref.substring(scan.scope.length).contains('/'));
          if (inScope) {
            if (row['manual'] == 1) {
              database.execute(
                'UPDATE local_audio_links SET available=? WHERE episode_id=?',
                [seen.contains(ref) ? 1 : 0, row['episode_id']],
              );
            } else {
              // Presence alone no longer validates an association made by COMM.
              database.execute(
                "UPDATE local_audio_links SET available=0,matching_status='unknown',local_verification_status='NON_VERIFIEE' WHERE episode_id=?",
                [row['episode_id']],
              );
            }
          }
        }
      }
      for (final d in decisions) {
        if (d.status != MatchStatus.confirmed) {
          if (scan.complete)
            database.execute(
              'UPDATE local_audio_links SET available=0,matching_status=?,local_verification_status=? WHERE audio_ref=? AND manual=0',
              [d.status.name, 'NON_VERIFIEE', d.audio.reference],
            );
          issues.add(
            CatalogIssue(
              d.status == MatchStatus.blocked
                  ? 'audio_scan_incomplete'
                  : d.status == MatchStatus.unknown
                  ? 'audio_unknown_filename'
                  : 'audio_association_conflict',
              d.reason,
              source: d.audio.reference,
            ),
          );
          if (d.episodeId != null && manualByEpisode.containsKey(d.episodeId)) {
            issues.add(
              CatalogIssue(
                'manual_link_preserved',
                'Choix manuel conservé.',
                source: d.audio.reference,
              ),
            );
          }
          continue;
        }
        if (d.method == 'manual') continue;
        final owner = database.select(
          'SELECT episode_id,manual FROM local_audio_links WHERE audio_ref=?',
          [d.audio.reference],
        );
        if (owner.isNotEmpty && owner.single['episode_id'] != d.episodeId) {
          // A complete scan may correct an old automatic owner. Manual owners
          // have already been removed from automatic matching and stay protected.
          database.execute(
            'DELETE FROM local_audio_links WHERE episode_id=? AND manual=0',
            [owner.single['episode_id']],
          );
          issues.add(
            CatalogIssue(
              'audio_link_reassigned',
              'Ancienne association automatique réévaluée selon le nom du journal ; suivi de l’ancien épisode conservé.',
              source: d.audio.reference,
            ),
          );
        }
        _link(
          d.episodeId!,
          d.audio.reference,
          d.audio.currentName,
          d.method!,
          'NON_VERIFIEE',
          jsonEncode(d.toJson()),
          false,
          stamp,
        );
      }
      database.execute(
        'INSERT INTO audio_scan_runs(scope,completed,scanned_at,summary_json) VALUES(?,?,?,?)',
        [
          scan.scope,
          scan.complete ? 1 : 0,
          stamp,
          jsonEncode({
            'audio_count': scan.audios.length,
            'decisions': {
              for (final s in MatchStatus.values)
                s.name: decisions.where((d) => d.status == s).length,
            },
            'issues': issues.map((i) => i.toJson()).toList(),
          }),
        ],
      );
      final id = database.lastInsertRowId;
      for (final d in decisions) {
        database.execute('INSERT INTO audio_scan_items VALUES(?,?,?)', [
          id,
          d.audio.reference,
          jsonEncode(d.toJson()),
        ]);
      }
      database.execute('COMMIT');
      return List.unmodifiable(issues);
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  static const _unlinkedKey = 'audio_unlinked_refs_v1';
  Set<String> get unlinkedAudioReferences {
    final rows = database.select(
      'SELECT value FROM local_settings WHERE key=?',
      [_unlinkedKey],
    );
    if (rows.isEmpty) return {};
    return (jsonDecode(rows.single['value'] as String) as List)
        .cast<String>()
        .toSet();
  }

  void _saveUnlinked(Set<String> refs) {
    database.execute(
      'INSERT INTO local_settings(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
      [_unlinkedKey, jsonEncode(refs.toList()..sort())],
    );
  }

  /// Retrait explicite du lien et du suivi personnel de cet épisode, sans toucher au fichier.
  void unlinkAudio(String reference) {
    database.execute('BEGIN IMMEDIATE');
    try {
      final rows = database.select(
        'SELECT episode_id FROM local_audio_links WHERE audio_ref=?',
        [reference],
      );
      if (rows.isEmpty) throw StateError('Cette association n’existe plus.');
      _saveUnlinked(unlinkedAudioReferences..add(reference));
      database.execute('DELETE FROM user_episode_state WHERE episode_id=?', [
        rows.single['episode_id'],
      ]);
      database.execute('DELETE FROM local_audio_links WHERE audio_ref=?', [
        reference,
      ]);
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  void recordManualLink(
    String episodeId,
    String reference,
    String currentName, {
    DateTime? now,
  }) {
    // À appeler seulement après une association explicitement choisie par l'utilisateur.
    database.execute('BEGIN IMMEDIATE');
    try {
      final owner = database.select(
        'SELECT episode_id FROM local_audio_links WHERE audio_ref=?',
        [reference],
      );
      if (owner.isNotEmpty && owner.single['episode_id'] != episodeId)
        throw StateError('Ce MP3 est déjà lié à un autre épisode.');
      _saveUnlinked(unlinkedAudioReferences..remove(reference));
      _link(
        episodeId,
        reference,
        currentName,
        'manual',
        'NON_VERIFIEE',
        '{"rule":"manual"}',
        true,
        (now ?? DateTime.now()).toUtc().toIso8601String(),
      );
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  void _link(
    String id,
    String ref,
    String name,
    String method,
    String verification,
    String evidence,
    bool manual,
    String stamp,
  ) {
    database.execute(
      '''INSERT INTO local_audio_links(episode_id,audio_ref,current_name,method,matching_status,local_verification_status,evidence_json,manual,available,updated_at)
      VALUES(?,?,?,?,?,?,?,?,1,?) ON CONFLICT(episode_id) DO UPDATE SET audio_ref=excluded.audio_ref,current_name=excluded.current_name,method=excluded.method,
      matching_status=excluded.matching_status,local_verification_status=excluded.local_verification_status,evidence_json=excluded.evidence_json,
      manual=excluded.manual,available=1,updated_at=excluded.updated_at''',
      [
        id,
        ref,
        name,
        method,
        'confirmed',
        verification,
        evidence,
        manual ? 1 : 0,
        stamp,
      ],
    );
  }
}
