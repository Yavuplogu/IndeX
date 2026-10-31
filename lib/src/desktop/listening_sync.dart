import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../identity.dart';
import '../storage/catalog_store.dart';
import '../storage/sync_schema.dart';

const syncMaxBytes = 5 * 1024 * 1024;
const _maxCounter = 1000000000;
const _fields = ['favorite', 'status', 'position'];
const _defaults = <String, Object>{
  'favorite': false,
  'status': {'listening_status': 'NON_ECOUTE', 'completed_at': null},
  'position': {'position_ms': 0, 'duration_ms': null, 'last_played_at': null},
};
String _token(String prefix) =>
    '$prefix${List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
String _stamp() => DateTime.now().toUtc().toIso8601String();
Object? _ordered(Object? value) => value is Map
    ? {
        for (final key in (value.keys.cast<String>().toList()..sort()))
          key: _ordered(value[key]),
      }
    : value is List
    ? value.map(_ordered).toList()
    : value;
String _json(Object? value) => jsonEncode(_ordered(value));
Never _invalid(String message) =>
    throw FormatException('Suivi JSON invalide : $message');
Map<String, dynamic> _map(Object? value, Set<String>? keys) {
  if (value is! Map<String, dynamic>) _invalid('objet attendu.');
  if (keys != null &&
      (value.length != keys.length || !value.keys.every(keys.contains)))
    _invalid('champs manquants ou inconnus.');
  return value;
}

void _date(Object? value, {bool nullable = true}) {
  if (value == null && nullable) return;
  if (value is! String ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$')
          .hasMatch(value))
    _invalid('date UTC attendue.');
  final parsed = DateTime.tryParse(value);
  if (parsed == null ||
      parsed.toIso8601String().substring(0, 19) != value.substring(0, 19))
    _invalid('date impossible.');
}

void _id(Object? value, String prefix) {
  if (value is! String || !RegExp('^${prefix}_[0-9a-f]{32}\$').hasMatch(value))
    _invalid('identifiant $prefix invalide.');
}

void _value(String field, Object? value) {
  if (field == 'favorite') {
    if (value is! bool) _invalid('favori booléen attendu.');
  } else if (field == 'status') {
    final map = _map(value, {'listening_status', 'completed_at'});
    if (!['NON_ECOUTE', 'EN_COURS', 'ECOUTE'].contains(map['listening_status']))
      _invalid('statut inconnu.');
    _date(map['completed_at']);
    if (map['listening_status'] != 'ECOUTE' && map['completed_at'] != null)
      _invalid('date de fin sans état Écouté.');
  } else {
    final map = _map(value, {'position_ms', 'duration_ms', 'last_played_at'});
    final position = map['position_ms'], duration = map['duration_ms'];
    if (position is! int ||
        position < 0 ||
        position > 604800000 ||
        (duration != null &&
            (duration is! int ||
                duration <= 0 ||
                duration > 604800000 ||
                position > duration)))
      _invalid('position ou durée hors limites.');
    _date(map['last_played_at']);
  }
}

final class SyncField {
  SyncField._(Object? value, Map<String, int> clock)
    : valueJson = _json(value),
      clock = Map.unmodifiable(clock);
  final String valueJson;
  final Map<String, int> clock;
  Object? get value => jsonDecode(valueJson);
  Map<String, Object?> toJson() => {'value': value, 'clock': clock};
}

final class SyncEpisode {
  SyncEpisode._(this.id, Map<String, SyncField> fields)
    : fields = Map.unmodifiable(fields);
  final String id;
  final Map<String, SyncField> fields;
}

final class SyncDocument {
  SyncDocument._(
    this.exportId,
    this.sourceDevice,
    this.exportedAt,
    this.catalogVersion,
    List<SyncEpisode> episodes,
    this.digest,
  ) : episodes = List.unmodifiable(episodes);
  final String exportId, sourceDevice, exportedAt, catalogVersion, digest;
  final List<SyncEpisode> episodes;

  factory SyncDocument.decode(List<int> bytes) {
    if (bytes.length > syncMaxBytes) _invalid('fichier supérieur à 5 Mio.');
    final text = utf8.decode(bytes);
    // Borner la profondeur avant jsonDecode, y compris pour les objets inconnus.
    var depth = 0, quoted = false, escaped = false;
    for (final code in text.codeUnits) {
      if (quoted) {
        if (escaped) {
          escaped = false;
        } else if (code == 92) {
          escaped = true;
        } else if (code == 34) {
          quoted = false;
        }
      } else if (code == 34) {
        quoted = true;
      } else if (code == 123 || code == 91) {
        if (++depth > 12) _invalid('structure trop profonde.');
      } else if (code == 125 || code == 93) {
        depth--;
      }
    }
    final root = _map(jsonDecode(text), {
      'format',
      'schema_version',
      'export_id',
      'exported_at',
      'source_device_id',
      'catalog_version',
      'episodes',
    });
    if (root['format'] != 'index-listening-sync' ||
        root['schema_version'] is! int ||
        root['schema_version'] != 1)
      _invalid('format ou version non pris en charge.');
    _id(root['export_id'], 'e');
    _id(root['source_device_id'], 'd');
    _date(root['exported_at'], nullable: false);
    if (root['catalog_version'] is! String ||
        (root['catalog_version'] as String).length > 200)
      _invalid('version de catalogue invalide.');
    final list = root['episodes'];
    if (list is! List || list.length > 10000)
      _invalid('liste excessive ou absente.');
    final ids = <String>{}, episodes = <SyncEpisode>[];
    for (final raw in list) {
      final entry = _map(raw, {'episode_id', 'fields'});
      final id = entry['episode_id'];
      if (id is! String ||
          !id.startsWith('mrx:') ||
          id.length > 259 ||
          canonicalOriginalName(id.substring(4)) != id.substring(4) ||
          !ids.add(id))
        _invalid('épisode invalide ou répété.');
      final fields = _map(entry['fields'], _fields.toSet());
      final parsed = <String, SyncField>{};
      for (final field in _fields) {
        final state = _map(fields[field], {'value', 'clock'});
        _value(field, state['value']);
        final clock = _map(state['clock'], null);
        if (clock.length > 32) _invalid('trop d’appareils dans une version.');
        final versions = <String, int>{};
        for (final device in clock.keys) {
          _id(device, 'd');
          final revision = clock[device];
          if (revision is! int || revision < 1 || revision > _maxCounter)
            _invalid('version de changement invalide.');
          versions[device] = revision;
        }
        if (versions.isEmpty &&
            _json(state['value']) != _json(_defaults[field]))
          _invalid('changement sans version.');
        parsed[field] = SyncField._(state['value'], versions);
      }
      episodes.add(SyncEpisode._(id, parsed));
    }
    return SyncDocument._(
      root['export_id'] as String,
      root['source_device_id'] as String,
      root['exported_at'] as String,
      root['catalog_version'] as String,
      episodes,
      sha256.convert(utf8.encode(_json(root))).toString(),
    );
  }
}

enum SyncChoice { local, file }

enum SyncChangeKind { incoming, retained, identical, merged, conflict }

final class SyncChange {
  const SyncChange._(
    this.episodeId,
    this.field,
    this.local,
    this.incoming,
    this.kind,
  );
  final String episodeId, field;
  final SyncField local, incoming;
  final SyncChangeKind kind;
  String get key => '$episodeId|$field';
}

final class SyncImportPlan {
  SyncImportPlan._(
    this.document,
    this.revision,
    this.device,
    List<SyncChange> changes,
    List<String> unknown,
    this.newEpisodes,
    this.alreadyImported,
  ) : changes = List.unmodifiable(changes),
      unknown = List.unmodifiable(unknown);
  final SyncDocument document;
  final int revision, newEpisodes;
  final String device;
  final List<SyncChange> changes;
  final List<String> unknown;
  final bool alreadyImported;
  List<SyncChange> get conflicts =>
      changes.where((e) => e.kind == SyncChangeKind.conflict).toList();
  int get modifications => changes
      .where(
        (e) =>
            e.kind == SyncChangeKind.incoming ||
            e.kind == SyncChangeKind.merged,
      )
      .length;
}

typedef SyncPublisher = Future<void> Function(File partial, File target);

final class ListeningSync {
  ListeningSync(this.store, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  final CatalogStore store;
  String get deviceId {
    final existing = store.database.select(
      'SELECT device_id FROM sync_device WHERE slot=1',
    );
    if (existing.isNotEmpty) return existing.single['device_id'] as String;
    store.database.execute(
      "INSERT OR IGNORE INTO sync_device(slot,device_id) VALUES(1,?)",
      [_token('d_')],
    );
    return store.database
            .select('SELECT device_id FROM sync_device WHERE slot=1')
            .single['device_id']
        as String;
  }

  int get _revision =>
      store.database
              .select('SELECT revision FROM sync_device WHERE slot=1')
              .single['revision']
          as int;

  /// Une action explicite de reset reste causale même si sa valeur était déjà zéro.
  /// Appeler dans la transaction de l’action utilisateur.
  void markExplicit(String id, Iterable<String> fields) {
    final device = deviceId;
    for (final field in fields) {
      final expression = syncFieldExpressions[field]!.replaceAll('%r.', '');
      final value = jsonDecode(
        store.database.select(
              'SELECT $expression AS value FROM user_episode_state WHERE episode_id=?',
              [id],
            ).single['value']
            as String,
      );
      final current = _read(id, field);
      final clock = {
        ...current.clock,
        device: (current.clock[device] ?? 0) + 1,
      };
      _write(id, field, SyncField._(value, clock));
      store.database.execute(
        'UPDATE sync_device SET revision=revision+1 WHERE slot=1',
      );
    }
  }

  SyncField _read(String id, String field) {
    final rows = store.database.select(
      'SELECT value_json,clock_json FROM sync_fields WHERE episode_id=? AND field=?',
      [id, field],
    );
    return rows.isEmpty
        ? SyncField._(_defaults[field], {})
        : SyncField._(
            jsonDecode(rows.single['value_json'] as String),
            Map<String, int>.from(
              jsonDecode(rows.single['clock_json'] as String) as Map,
            ),
          );
  }

  void _write(String id, String field, SyncField state) =>
      store.database.execute(
        'INSERT INTO sync_fields VALUES(?,?,?,?) ON CONFLICT(episode_id,field) DO UPDATE SET value_json=excluded.value_json,clock_json=excluded.clock_json',
        [id, field, state.valueJson, _json(state.clock)],
      );

  T _snapshot<T>(T Function() read) {
    final db = store.database;
    db.execute('BEGIN');
    try {
      final result = read();
      db.execute('COMMIT');
      return result;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  SyncDocument exportDocument() {
    final device = deviceId;
    return _snapshot(() => _exportDocument(device));
  }

  SyncDocument _exportDocument(String device) {
    final ids = store.database.select(
      'SELECT DISTINCT episode_id FROM sync_fields ORDER BY episode_id',
    );
    final root = {
      'format': 'index-listening-sync',
      'schema_version': 1,
      'export_id': _token('e_'),
      'exported_at': _now().toUtc().toIso8601String(),
      'source_device_id': device,
      'catalog_version':
          store.database
              .select(
                'SELECT version FROM catalog_versions ORDER BY generated_at DESC LIMIT 1',
              )
              .firstOrNull?['version'] ??
          '',
      'episodes': [
        for (final row in ids)
          {
            'episode_id': row['episode_id'],
            'fields': {
              for (final field in _fields)
                field: _read(row['episode_id'] as String, field).toJson(),
            },
          },
      ],
    };
    return SyncDocument.decode(utf8.encode(_json(root)));
  }

  List<int> encode(SyncDocument document) => utf8.encode(
    const JsonEncoder.withIndent('  ').convert({
      'format': 'index-listening-sync',
      'schema_version': 1,
      'export_id': document.exportId,
      'exported_at': document.exportedAt,
      'source_device_id': document.sourceDevice,
      'catalog_version': document.catalogVersion,
      'episodes': [
        for (final e in document.episodes)
          {
            'episode_id': e.id,
            'fields': {for (final f in _fields) f: e.fields[f]!.toJson()},
          },
      ],
    }),
  );

  Future<File> exportFile(
    Directory data, {
    required SyncPublisher publish,
  }) async {
    final document = exportDocument();
    final bytes = encode(document);
    if (bytes.length > syncMaxBytes) _invalid('export supérieur à 5 Mio.');
    final directory = await Directory('${data.path}/exports')
        .create(recursive: true);
    final time = DateTime.parse(document.exportedAt).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${time.year.toString().padLeft(4, '0')}${two(time.month)}${two(time.day)}_${two(time.hour)}${two(time.minute)}${two(time.second)}';
    final target = File('${directory.path}/IndeX_suivi_$stamp.json');
    if (await FileSystemEntity.type(target.path, followLinks: false) !=
        FileSystemEntityType.notFound)
      throw StateError(
        'Un export a déjà été créé à cette seconde. Réessayez dans une seconde ; le fichier existant est conservé.',
      );
    final staging = await directory.createTemp('.index-export-');
    try {
      final partial = File('${staging.path}/payload.part');
      await partial.writeAsBytes(bytes, flush: true);
      await publish(partial, target);
      return target;
    } finally {
      try {
        if (await staging.exists()) await staging.delete(recursive: true);
      } on FileSystemException {
        /* Résidu privé, jamais importé automatiquement. */
      }
    }
  }

  static Future<SyncDocument> readFile(File file) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.openRead()) {
      if (bytes.length + chunk.length > syncMaxBytes)
        _invalid('fichier supérieur à 5 Mio.');
      bytes.add(chunk);
    }
    return SyncDocument.decode(bytes.takeBytes());
  }

  SyncImportPlan preview(SyncDocument document) {
    final device = deviceId;
    return _snapshot(() => _preview(document, device));
  }

  SyncImportPlan _preview(SyncDocument document, String device) {
    final previous = store.database.select(
      'SELECT digest FROM sync_imports WHERE export_id=?',
      [document.exportId],
    );
    if (previous.isNotEmpty) {
      if (previous.single['digest'] != document.digest)
        _invalid('identifiant d’export réutilisé avec un contenu différent.');
      return SyncImportPlan._(document, _revision, device, [], [], 0, true);
    }
    final known = store.database
        .select('SELECT id FROM episodes')
        .map((r) => r['id'])
        .toSet();
    final changes = <SyncChange>[], unknown = <String>[];
    var created = 0;
    for (final e in document.episodes) {
      if (!known.contains(e.id)) {
        unknown.add(e.id);
        continue;
      }
      if (store.database.select(
        'SELECT 1 FROM sync_fields WHERE episode_id=? LIMIT 1',
        [e.id],
      ).isEmpty)
        created++;
      for (final field in _fields) {
        final local = _read(e.id, field), incoming = e.fields[field]!;
        final devices = {...local.clock.keys, ...incoming.clock.keys};
        if (devices.length > 32)
          _invalid('fusion de plus de 32 appareils non prise en charge.');
        var greater = false, less = false;
        for (final d in devices) {
          final a = local.clock[d] ?? 0, b = incoming.clock[d] ?? 0;
          greater |= a > b;
          less |= a < b;
        }
        final equal = local.valueJson == incoming.valueJson;
        if (!greater && !less && !equal)
          _invalid(
            'même version avec valeurs différentes : profils clonés ou fichier altéré.',
          );
        final kind = greater && less
            ? (equal ? SyncChangeKind.merged : SyncChangeKind.conflict)
            : less
            ? SyncChangeKind.incoming
            : greater
            ? SyncChangeKind.retained
            : SyncChangeKind.identical;
        changes.add(SyncChange._(e.id, field, local, incoming, kind));
      }
    }
    return SyncImportPlan._(
      document,
      _revision,
      device,
      changes,
      unknown,
      created,
      false,
    );
  }

  Future<void> apply(
    SyncImportPlan plan,
    Map<String, SyncChoice> choices, {
    required Future<void> Function() backup,
  }) async {
    if (plan.device != deviceId || plan.revision != _revision)
      throw StateError(
        'Le suivi a changé depuis l’aperçu. Recommencez l’import.',
      );
    if (plan.alreadyImported) return;
    final requiredKeys = plan.conflicts.map((c) => c.key).toSet();
    if (choices.length != requiredKeys.length ||
        !choices.keys.every(requiredKeys.contains))
      throw StateError('Choisissez une résolution pour chaque conflit.');
    // Calculer/valider toutes les résolutions avant le point de restauration.
    final selected = <SyncChange, SyncField>{};
    for (final c in plan.changes) {
      if (c.kind == SyncChangeKind.retained ||
          c.kind == SyncChangeKind.identical)
        continue;
      final clock = <String, int>{};
      for (final d in {...c.local.clock.keys, ...c.incoming.clock.keys}) {
        clock[d] = max(c.local.clock[d] ?? 0, c.incoming.clock[d] ?? 0);
      }
      if (c.kind == SyncChangeKind.conflict)
        clock[plan.device] = (clock[plan.device] ?? 0) + 1;
      if (clock.length > 32)
        _invalid('fusion de plus de 32 appareils non prise en charge.');
      if (clock.values.any((v) => v > _maxCounter))
        _invalid('compteur de version épuisé.');
      final value =
          c.kind == SyncChangeKind.conflict &&
              choices[c.key] == SyncChoice.local
          ? c.local.value
          : c.incoming.value;
      selected[c] = SyncField._(value, clock);
    }
    await backup();
    final db = store.database;
    db.execute('BEGIN IMMEDIATE');
    try {
      if (plan.revision != _revision)
        throw StateError(
          'Le suivi a changé pendant la sauvegarde. Recommencez l’import.',
        );
      db.execute('UPDATE sync_device SET suppress=1 WHERE slot=1');
      final changed = <String>{};
      for (final entry in selected.entries) {
        _write(entry.key.episodeId, entry.key.field, entry.value);
        if (entry.key.local.valueJson != entry.value.valueJson)
          changed.add(entry.key.episodeId);
      }
      for (final id in changed) {
        final favorite = _read(id, 'favorite').value as bool;
        final status = _read(id, 'status').value as Map;
        final position = _read(id, 'position').value as Map;
        db.execute(
          'INSERT OR IGNORE INTO user_episode_state(episode_id) VALUES(?)',
          [id],
        );
        db.execute(
          '''UPDATE user_episode_state SET is_favorite=?,listening_status=?,completed_at=?,position_ms=?,duration_ms=?,last_played_at=?,playback_status='stopped',updated_at=? WHERE episode_id=?''',
          [
            favorite ? 1 : 0,
            status['listening_status'],
            status['completed_at'],
            position['position_ms'],
            position['duration_ms'],
            position['last_played_at'],
            _stamp(),
            id,
          ],
        );
      }
      db.execute('INSERT INTO sync_imports VALUES(?,?,?,?,?)', [
        plan.document.exportId,
        plan.document.digest,
        plan.document.sourceDevice,
        _stamp(),
        _json({
          'episodes_changed': changed.length,
          'conflicts': choices.map((k, v) => MapEntry(k, v.name)),
          'unknown': plan.unknown,
        }),
      ]);
      db.execute(
        'UPDATE sync_device SET suppress=0,revision=revision+1 WHERE slot=1',
      );
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }
}
