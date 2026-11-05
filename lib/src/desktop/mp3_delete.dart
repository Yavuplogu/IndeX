import 'dart:convert';

import '../storage/catalog_store.dart';
import '../io/local_audio_paths.dart';

/// Les adaptateurs doivent vérifier le périmètre et refuser tout remplacement.
typedef InspectAudioDeletion = Future<Map<String, Object?>> Function(
  String scope,
  String reference,
);
typedef RemoveAudioFile = Future<void> Function(
  String scope,
  String reference,
  String signature,
);

final class AudioDeletionEntry {
  AudioDeletionEntry(
    this.episodeId,
    this.title,
    this.date,
    this.reference,
    this.name,
    this.signature,
    this.identity,
    this._status,
    this._reason,
  );
  final String episodeId, title, reference, name, signature, identity;
  final String? date;
  String _status, _reason;
  String get status => _status;
  String get reason => _reason;
  Map<String, Object?> toJson() => {
    'episode_id': episodeId,
    'title': title,
    'date': date,
    'reference': reference,
    'name': name,
    'status': status,
    'reason': reason,
  };
}

final class AudioDeletionPlan {
  AudioDeletionPlan._(this.scope, this._store, this.entries);
  final String scope;
  final CatalogStore _store;
  final List<AudioDeletionEntry> entries;
  bool _used = false;
  bool get used => _used;
  int get planned => entries.where((e) => e.status == 'planned').length;
}

/// Journal local durable avant chaque suppression, aucun reset du suivi.
final class HeardAudioDeletion {
  HeardAudioDeletion(this.store, {required this.inspect, required this.remove});
  final CatalogStore store;
  final InspectAudioDeletion inspect;
  final RemoveAudioFile remove;
  final _paths = LocalAudioPaths();
  static const journalKey = 'heard_audio_deletion_v1';

  List<Map<String, Object?>> _links() => [
    for (final r in store.database.select(
      '''SELECT l.*,e.title,e.broadcast_date,
      COALESCE(u.listening_status,'NON_ECOUTE') AS listening_status
      FROM local_audio_links l JOIN episodes e ON e.id=l.episode_id
      LEFT JOIN user_episode_state u ON u.episode_id=l.episode_id''',
    ))
      Map<String, Object?>.from(r),
  ];

  Object _key(String ref) => ref.startsWith('content:')
      ? documentReferenceKey(ref)
      : _paths.referenceKey(ref);

  Future<String?> _active(String scope, String? reference) async {
    if (reference == null) return null;
    try {
      final value = await inspect(scope, reference);
      final identity = value['identity'] as String?;
      if (value['exists'] != true || identity == null || identity.isEmpty) {
        throw StateError('Piste chargée impossible à identifier.');
      }
      return identity;
    } catch (_) {
      throw StateError(
        'Libérez la piste chargée avant de préparer cette suppression.',
      );
    }
  }

  Future<AudioDeletionPlan> preview(String scope, {String? inUse}) async {
    _paths.clear();
    if (scope.isEmpty)
      throw StateError('Choisissez un dossier MP3 dans Fichiers.');
    final rows = _links();
    final active = await _active(scope, inUse);
    final metadata = <String, Map<String, Object?>>{};
    final errors = <String, String>{};
    // Inclure aussi les liens non écoutés pour détecter les alias d’un même fichier.
    for (final r in rows) {
      final ref = r['audio_ref'] as String;
      try {
        metadata[ref] = await inspect(scope, ref);
      } catch (e) {
        errors[ref] = e.toString();
      }
    }
    final entries = <AudioDeletionEntry>[];
    for (final r in rows.where((r) => r['listening_status'] == 'ECOUTE')) {
      final ref = r['audio_ref'] as String;
      final info = metadata[ref];
      final identity = info?['identity'] as String? ?? '';
      final aliases = rows
          .where(
            (x) =>
                _key(x['audio_ref'] as String) == _key(ref) ||
                (identity.isNotEmpty &&
                    metadata[x['audio_ref']]?['identity'] == identity),
          )
          .length;
      var status = 'planned';
      var reason = 'Suppression définitive du MP3 ; suivi et favori conservés.';
      if (r['available'] != 1 || info?['exists'] == false) {
        status = 'missing';
        reason =
            'MP3 absent ou disponibilité non confirmée : aucun effacement.';
      } else if (info == null) {
        status = 'failed';
        reason = errors[ref] ?? 'Vérification impossible.';
      } else if (r['matching_status'] != 'confirmed' ||
          info['eligible'] != true ||
          identity.isEmpty ||
          (info['signature'] as String? ?? '').isEmpty ||
          aliases != 1 ||
          active == identity ||
          (inUse != null && _key(inUse) == _key(ref))) {
        status = 'excluded';
        reason = aliases != 1
            ? 'Même fichier lié à plusieurs épisodes.'
            : active == identity || (inUse != null && _key(inUse) == _key(ref))
            ? 'Fichier chargé dans le lecteur.'
            : info['reason'] as String? ?? 'Association non confirmée ou fichier hors du dossier choisi.';
      }
      if (status == 'excluded' && reason.isEmpty) {
        reason = 'Association non confirmée ou fichier non vérifiable.';
      }
      entries.add(
        AudioDeletionEntry(
          r['episode_id'] as String,
          r['title'] as String,
          r['broadcast_date'] as String?,
          ref,
          info?['name'] as String? ?? r['current_name'] as String,
          info?['signature'] as String? ?? '',
          identity,
          status,
          reason,
        ),
      );
    }
    return AudioDeletionPlan._(scope, store, List.unmodifiable(entries));
  }

  void _journal(AudioDeletionPlan plan) => store.database.execute(
    'INSERT INTO local_settings(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
    [
      journalKey,
      jsonEncode({
        'at': DateTime.now().toUtc().toIso8601String(),
        'scope': plan.scope,
        'entries': plan.entries.map((e) => e.toJson()).toList(),
      }),
    ],
  );

  Future<void> execute(
    AudioDeletionPlan plan, {
    required String currentScope,
    required String? Function() inUse,
    void Function()? onProgress,
  }) async {
    _paths.clear();
    if (!identical(plan._store, store) ||
        plan.used ||
        plan.scope != currentScope) {
      throw StateError('Aperçu périmé. Actualisez avant de confirmer.');
    }
    plan._used = true;
    _journal(plan);
    // Une passe préalable, puis les nouveaux liens seulement : pas de N² appels SAF.
    final identities = <String, Object?>{};
    for (final row in _links()) {
      final ref = row['audio_ref'] as String;
      try {
        identities[ref] = (await inspect(plan.scope, ref))['identity'];
      } catch (_) {
        identities[ref] = null;
      }
    }
    for (final e in plan.entries.where((e) => e.status == 'planned').toList()) {
      var prepared = false;
      try {
        final info = await inspect(plan.scope, e.reference);
        final active = await _active(plan.scope, inUse());
        final rows = _links();
        final current = rows
            .where((r) => r['episode_id'] == e.episodeId)
            .firstOrNull;
        if (current == null ||
            current['audio_ref'] != e.reference ||
            current['listening_status'] != 'ECOUTE' ||
            current['matching_status'] != 'confirmed' ||
            current['available'] != 1 ||
            info['eligible'] != true ||
            info['signature'] != e.signature ||
            active == e.identity ||
            (inUse() != null && _key(inUse()!) == _key(e.reference))) {
          throw StateError(
            'État, association, fichier ou lecteur modifié depuis l’aperçu.',
          );
        }
        // Recontrôler les alias, y compris un nouveau lien créé après l’aperçu.
        for (final r in rows.where((r) => r['episode_id'] != e.episodeId)) {
          final ref = r['audio_ref'] as String;
          if (_key(ref) == _key(e.reference))
            throw StateError('Association devenue ambiguë.');
          if (!identities.containsKey(ref)) {
            try {
              identities[ref] = (await inspect(plan.scope, ref))['identity'];
            } catch (_) {
              identities[ref] = null;
            }
          }
          if (identities[ref] == e.identity)
            throw StateError('Même fichier lié à plusieurs épisodes.');
        }
        final fresh = _links()
            .where((r) => r['episode_id'] == e.episodeId)
            .firstOrNull;
        final loaded = inUse();
        final loadedIdentity = await _active(plan.scope, loaded);
        final latest = _links()
            .where((r) => r['episode_id'] == e.episodeId)
            .firstOrNull;
        if (fresh == null ||
            latest == null ||
            latest['audio_ref'] != e.reference ||
            latest['listening_status'] != 'ECOUTE' ||
            latest['available'] != 1 ||
            latest['matching_status'] != 'confirmed' ||
            inUse() != loaded ||
            loadedIdentity == e.identity) {
          throw StateError(
            'Suivi, association ou lecteur modifié : suppression refusée.',
          );
        }
        // Écrire l’intention AVANT l’appel destructif. Un crash n’efface aucun suivi.
        e._status = 'deleting';
        e._reason = 'Opération interrompue possible : vérifier dans Fichiers.';
        store.database.execute('BEGIN IMMEDIATE');
        try {
          store.database.execute(
            'UPDATE local_audio_links SET available=0 WHERE episode_id=? AND audio_ref=?',
            [e.episodeId, e.reference],
          );
          _journal(plan);
          store.database.execute('COMMIT');
        } catch (_) {
          store.database.execute('ROLLBACK');
          rethrow;
        }
        prepared = true;
        await remove(plan.scope, e.reference, e.signature);
        e._status = 'deleted';
        e._reason = 'MP3 supprimé ; suivi et favori conservés.';
      } catch (error) {
        e._status = 'failed';
        e._reason = error.toString();
        if (prepared) {
          // Ne rétablir que la disponibilité d’un fichier dont la présence est certaine.
          try {
            final existing = await inspect(plan.scope, e.reference);
            if (existing['exists'] == true &&
                existing['signature'] == e.signature) {
              store.database.execute(
                'UPDATE local_audio_links SET available=1 WHERE episode_id=? AND audio_ref=?',
                [e.episodeId, e.reference],
              );
            }
          } catch (_) {
            /* garder indisponible, scan manuel pour réconcilier */
          }
        }
      }
      _journal(plan);
      onProgress?.call();
    }
  }
}
