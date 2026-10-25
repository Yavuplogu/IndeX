import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

import '../io/catalog_sources.dart';
import '../matching/matching_engine.dart';
import '../search/search_engine.dart';
import '../search/sqlite_search_engine.dart';
import '../storage/catalog_store.dart';
import 'episode.dart';

String _token() => List.generate(
  12,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

final class PortableSession {
  PortableSession._(
    this.portableDirectory,
    this.dataDirectory,
    this.store,
    this._lock,
  );
  static final _held = <String>{};
  final Directory portableDirectory, dataDirectory;
  final CatalogStore store;
  final RandomAccessFile _lock;
  Future<Map<String, Object?>>? _scan;
  bool _closed = false;
  String get databasePath => '${dataDirectory.path}/index-utilisateur.sqlite';

  static Directory? configuredDirectory(Directory portableDirectory) {
    final file = File('${portableDirectory.path}/index-portable.json');
    if (!file.existsSync()) return null;
    if (file.lengthSync() > 8192)
      throw const FormatException('Configuration portable excessive.');
    final value = jsonDecode(file.readAsStringSync());
    if (value is! Map<String, dynamic> ||
        value['version'] != 1 ||
        value['data_directory'] is! String) {
      throw const FormatException('Configuration portable non reconnue.');
    }
    final path = value['data_directory'] as String;
    if (!Directory(path).isAbsolute || path.trim().isEmpty)
      throw const FormatException('Chemin de données invalide.');
    return Directory(path);
  }

  static Future<PortableSession> open({
    required Directory portableDirectory,
    required Directory dataDirectory,
    required Uint8List referenceBytes,
    required String referenceSha256,
    bool requireExisting = false,
  }) async {
    if (referenceBytes.length > 64 * 1024 * 1024 ||
        sha256.convert(referenceBytes).toString() != referenceSha256) {
      throw const FormatException('Empreinte du catalogue intégré invalide.');
    }
    if (!dataDirectory.existsSync())
      throw const FileSystemException('Dossier utilisateur introuvable.');
    final data = Directory(dataDirectory.resolveSymbolicLinksSync());
    final database = File('${data.path}/index-utilisateur.sqlite');
    if (requireExisting && !database.existsSync())
      throw const FileSystemException(
        'Base utilisateur attendue introuvable ; aucune base vide créée.',
      );
    final lock = await _acquire(data);
    CatalogStore? store;
    Directory? temp;
    try {
      await _probe(data);
      await _probe(portableDirectory);
      temp = await data.createTemp('.index-reference-');
      final reference = File('${temp.path}/catalogue.sqlite');
      await reference.writeAsBytes(referenceBytes, flush: true);
      final dbPath = database.path, referencePath = reference.path;
      await Isolate.run(() {
        final target = CatalogStore.open(dbPath);
        try {
          target.importReference(referencePath);
          SqliteSearchEngine(target.database).checkIndex();
        } finally {
          target.close();
        }
      });
      store = CatalogStore.open(database.path);
      await _writePointer(portableDirectory, data);
      return PortableSession._(portableDirectory, data, store, lock);
    } catch (_) {
      store?.close();
      await lock.unlock();
      await lock.close();
      _held.remove(data.path);
      rethrow;
    } finally {
      if (temp != null) await temp.delete(recursive: true);
    }
  }

  static Future<RandomAccessFile> _acquire(Directory directory) async {
    if (!_held.add(directory.path))
      throw StateError('Ce dossier est déjà ouvert dans cette application.');
    RandomAccessFile? lock;
    try {
      lock = await File('${directory.path}/.index.lock')
          .open(mode: FileMode.append);
      await lock.lock(FileLock.exclusive);
      return lock;
    } catch (_) {
      await lock?.close();
      _held.remove(directory.path);
      rethrow;
    }
  }

  static Future<void> _probe(Directory directory) async {
    final probe = File('${directory.path}/.index-write-${_token()}');
    try {
      await probe.create(exclusive: true);
      await probe.writeAsString('test', flush: true);
    } finally {
      if (await probe.exists()) await probe.delete();
    }
  }

  static Future<void> _writePointer(Directory portable, Directory data) async {
    final pending = File('${portable.path}/.index-portable-${_token()}.tmp');
    try {
      await pending.create(exclusive: true);
      await pending.writeAsString(
        '${jsonEncode({'version': 1, 'data_directory': data.path})}\n',
        flush: true,
      );
      await pending.rename('${portable.path}/index-portable.json');
    } finally {
      if (await pending.exists()) await pending.delete();
    }
  }

  String? setting(String key) {
    final rows = store.database.select(
      'SELECT value FROM local_settings WHERE key=?',
      [key],
    );
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  void setSetting(String key, String value) {
    if (_closed) throw StateError('Session fermée.');
    store.database.execute(
      'INSERT INTO local_settings(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
      [key, value],
    );
  }

  List<DesktopEpisode> episodes({
    String query = '',
    Set<SearchField> fields = const {
      SearchField.title,
      SearchField.description,
      SearchField.sources,
      SearchField.music,
    },
  }) {
    final hits = <String, SearchHit>{};
    if (query.trim().isNotEmpty) {
      for (var offset = 0; offset < 10000; offset += 100) {
        final page = SqliteSearchEngine(store.database).search(
          query,
          options: SearchOptions(
            fields: fields,
            limit: 100,
            offset: offset,
            prefix: true,
          ),
        );
        for (final hit in page) {
          hits[hit.episodeId] = hit;
        }
        if (page.length < 100) break;
      }
    }
    final root = setting('mp3_directory');
    final scope = root == null || root.isEmpty
        ? null
        : Directory(root).absolute.uri.toString();
    final sources = <String, List<Map<String, Object?>>>{},
        music = <String, List<Map<String, Object?>>>{};
    for (final row in store.database.select(
      'SELECT * FROM literary_sources ORDER BY episode_id,sequence',
    )) {
      sources
          .putIfAbsent(row['episode_id'] as String, () => [])
          .add(Map<String, Object?>.from(row));
    }
    for (final row in store.database.select(
      'SELECT * FROM music_tracks ORDER BY episode_id,sequence',
    )) {
      music
          .putIfAbsent(row['episode_id'] as String, () => [])
          .add(Map<String, Object?>.from(row));
    }
    final rows = store.database.select(
      '''SELECT e.*,u.position_ms,u.listening_status,u.is_favorite,
      l.audio_ref,l.available,l.manual FROM episodes e LEFT JOIN user_episode_state u ON u.episode_id=e.id
      LEFT JOIN local_audio_links l ON l.episode_id=e.id ORDER BY e.broadcast_date DESC,e.id''',
    );
    final result = [
      for (final row in rows)
        if (query.trim().isEmpty || hits.containsKey(row['id']))
          DesktopEpisode(
            id: row['id'] as String,
            originalName: row['original_name'] as String,
            title: row['title'] as String,
            date: row['broadcast_date'] as String?,
            description: row['description'] as String,
            sourcesText: row['sources_text'] as String,
            musicText: row['music_text'] as String,
            sources: sources[row['id']] ?? [],
            music: music[row['id']] ?? [],
            status: row['listening_status'] as String? ?? 'NON_ECOUTE',
            favorite: row['is_favorite'] == 1,
            audioRef: row['audio_ref'] as String?,
            audioAvailable:
                scope != null &&
                row['available'] == 1 &&
                (row['manual'] == 1 ||
                    (row['audio_ref'] as String).startsWith(scope)),
            positionMs: row['position_ms'] as int? ?? 0,
            excerpt: hits[row['id']]?.excerpt ?? '',
            markedExcerpt: hits[row['id']]?.markedExcerpt ?? '',
            matchedFields: hits[row['id']]?.matchedFields ?? const {},
            markedFields: hits[row['id']]?.markedFields ?? const {},
          ),
    ];
    if (query.trim().isNotEmpty) {
      final ranks = {for (final (i, id) in hits.keys.indexed) id: i};
      result.sort((a, b) => ranks[a.id]!.compareTo(ranks[b.id]!));
    }
    return result;
  }

  void favorite(String id, bool value) => _state(id, favorite: value);
  void listened(String id, bool value, {bool resetConfirmed = false}) {
    if (!value && !resetConfirmed)
      throw ArgumentError('Confirmation de remise à zéro requise.');
    _state(id, listened: value);
  }

  void _state(String id, {bool? favorite, bool? listened}) {
    if (_closed) throw StateError('Session fermée.');
    store.database.execute('BEGIN IMMEDIATE');
    try {
      store.database.execute(
        'INSERT OR IGNORE INTO user_episode_state(episode_id) VALUES(?)',
        [id],
      );
      if (favorite != null)
        store.database.execute(
          'UPDATE user_episode_state SET is_favorite=?,updated_at=? WHERE episode_id=?',
          [favorite ? 1 : 0, DateTime.now().toUtc().toIso8601String(), id],
        );
      if (listened != null)
        store.database.execute(
          'UPDATE user_episode_state SET listening_status=?,position_ms=CASE WHEN ?=0 THEN 0 ELSE position_ms END,updated_at=? WHERE episode_id=?',
          [
            listened ? 'ECOUTE' : 'NON_ECOUTE',
            listened ? 1 : 0,
            DateTime.now().toUtc().toIso8601String(),
            id,
          ],
        );
      store.database.execute('COMMIT');
    } catch (_) {
      store.database.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<Map<String, Object?>> scan(String path, {bool recursive = false}) {
    if (_scan != null) throw StateError('Un scan est déjà en cours.');
    setSetting('mp3_directory', Directory(path).absolute.path);
    setSetting('recursive', recursive.toString());
    final dbPath = databasePath;
    final task = _startScanWorker(dbPath, path, recursive);
    _scan = task;
    return task.whenComplete(() {
      _scan = null;
    });
  }

  Future<void> _snapshot(File destination) async {
    final target = sqlite3.open(destination.path);
    try {
      await store.database.backup(target, nPage: -1).drain<void>();
      if (target.select('PRAGMA integrity_check').single.values.single !=
              'ok' ||
          target.select('PRAGMA foreign_key_check').isNotEmpty)
        throw StateError('Sauvegarde invalide.');
      SqliteSearchEngine(target).checkIndex();
    } finally {
      target.close();
    }
  }

  Future<File> backup() async {
    if (_scan != null) await _scan;
    final directory = await Directory('${dataDirectory.path}/sauvegardes')
        .create();
    final pending = File('${directory.path}/.backup-${_token()}.sqlite');
    final latest = File('${directory.path}/IndeX_derniere_sauvegarde.sqlite');
    try {
      await _snapshot(pending);
      if (await latest.exists()) {
        final previous = await latest.copy(
          '${directory.path}/.previous-${_token()}.sqlite',
        );
        await previous.rename(
          '${directory.path}/IndeX_sauvegarde_precedente.sqlite',
        );
      }
      await pending.rename(latest.path);
      return latest;
    } finally {
      if (await pending.exists()) await pending.delete();
    }
  }

  /// Copie contrôlée, ancien dossier conservé. La destination doit être dédiée et vide.
  Future<PortableSession> relocate(Directory destination) async {
    if (_scan != null) await _scan;
    final target = Directory(await destination.resolveSymbolicLinks());
    if (target.uri.toString().startsWith(dataDirectory.uri.toString())) {
      throw ArgumentError(
        'La destination doit être extérieure au dossier actuel.',
      );
    }
    if (await target.list().isEmpty == false)
      throw StateError('Choisir un dossier vide pour la copie.');
    final lock = await _acquire(target);
    CatalogStore? next;
    try {
      await _probe(target);
      await backup();
      final database = File('${target.path}/index-utilisateur.sqlite');
      await _snapshot(database);
      for (final name in ['sauvegardes', 'exports']) {
        final origin = Directory('${dataDirectory.path}/$name');
        if (!await origin.exists()) continue;
        await Directory('${target.path}/$name').create();
        await for (final item in origin.list(
          recursive: true,
          followLinks: false,
        )) {
          final relative = item.uri.pathSegments
              .skip(
                origin.absolute.uri.pathSegments
                    .where((s) => s.isNotEmpty)
                    .length,
              )
              .join('/');
          if (item is Link)
            throw StateError(
              'Lien symbolique interdit dans les données à déplacer.',
            );
          if (item is Directory)
            await Directory('${target.path}/$name/$relative')
                .create(recursive: true);
          if (item is File) {
            final copy = File('${target.path}/$name/$relative');
            await copy.parent.create(recursive: true);
            await item.copy(copy.path);
          }
        }
      }
      next = CatalogStore.open(database.path);
      await _writePointer(portableDirectory, target);
      final result = PortableSession._(portableDirectory, target, next, lock);
      await dispose();
      return result;
    } catch (_) {
      next?.close();
      await lock.unlock();
      await lock.close();
      _held.remove(target.path);
      rethrow;
    }
  }

  Future<void> closeSafely() async {
    await backup();
    await dispose();
  }

  Future<void> dispose() async {
    if (_closed) return;
    if (_scan != null) await _scan;
    store.close();
    await _lock.unlock();
    await _lock.close();
    _held.remove(dataDirectory.path);
    _closed = true;
  }
}

Future<Map<String, Object?>> _startScanWorker(
  String dbPath,
  String path,
  bool recursive,
) => Isolate.run(() async {
  final scan = await scanAudioDirectory(Directory(path), recursive: recursive);
  final target = CatalogStore.open(dbPath);
  try {
    final decisions = const MatchingEngine().match(
      target.matchEpisodes(),
      scan.audios,
    );
    final issues = target.applyAudioScan(scan);
    return <String, Object?>{
      'complete': scan.complete,
      'count': scan.audios.length,
      'issues': issues.map((i) => i.toJson()).toList(),
      'decisions': decisions.map((d) => d.toJson()).toList(),
    };
  } finally {
    target.close();
  }
});
