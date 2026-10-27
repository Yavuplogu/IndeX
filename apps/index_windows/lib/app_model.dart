import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:index_core/index_core.dart';
import 'package:index_core/index_desktop.dart';

final class SeedData {
  const SeedData(this.bytes, this.sha256);
  final Uint8List bytes;
  final String sha256;
}

Future<SeedData> bundledSeed() async {
  final data = await rootBundle.load('assets/catalogue.sqlite');
  final raw = jsonDecode(
    await rootBundle.loadString('assets/catalogue.sqlite.manifest.json'),
  ) as Map<String, dynamic>;
  return SeedData(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    raw['sqlite_sha256'] as String,
  );
}

/// Decode a file URI for presentation only; retain the original URI as identity.
String displayDiagnosticPath(String value) {
  final uri = Uri.tryParse(value);
  if (uri?.scheme == 'file') {
    try {
      return File.fromUri(uri!).path;
    } on ArgumentError {
      return value;
    }
  }
  return value;
}

Object? diagnosticForDisplay(Object? value) {
  if (value is String) return displayDiagnosticPath(value);
  if (value is List) return value.map(diagnosticForDisplay).toList();
  if (value is Map)
    return value.map((key, item) => MapEntry(key, diagnosticForDisplay(item)));
  return value;
}

enum CatalogSort {
  relevance,
  dateNew,
  dateOld,
  titleAZ,
  titleZA,
  audioFirst,
  audioLast,
}

enum AudioFileFilter { all, associated, unassociated }

enum AudioFolderState { unconfigured, ready, unavailable, incomplete }

/// Ouvre un dossier local sans interprétation de commande ni nouvelle dépendance.
Future<void> openNativeFolder(String path) async {
  await const MethodChannel('index/local_folders')
      .invokeMethod<void>('openDirectory', path.replaceAll('/', r'\'));
}

final class AppModel extends ChangeNotifier {
  AppModel({
    required this.portableDirectory,
    this.seedLoader = bundledSeed,
    this.folderOpener = openNativeFolder,
    Directory? defaultDataDirectory,
  }) : defaultDataDirectory =
           defaultDataDirectory ?? Directory('${portableDirectory.path}/user') {
    dataPath = this.defaultDataDirectory.absolute.path;
  }
  final Future<void> Function(String) folderOpener;
  final Directory defaultDataDirectory;
  bool opening = false;
  final Directory portableDirectory;
  final Future<SeedData> Function() seedLoader;
  PortableSession? session;
  bool busy = false,
      needsSetup = true,
      favoritesOnly = false,
      filesView = false,
      dark = false;
  bool requireExisting = false;
  String dataPath = '',
      mp3Path = '',
      query = '',
      status = 'Tous',
      message = '',
      error = '',
      queryError = '';
  AudioFolderState audioState = AudioFolderState.unconfigured;
  CatalogSort sort = CatalogSort.dateNew;
  AudioFileFilter audioFileFilter = AudioFileFilter.all;
  Set<SearchField> fields = Set.of(SearchField.values);
  List<DesktopEpisode> catalog = [], visible = [];
  DesktopEpisode? selected;
  Map<String, Object?>? report;
  Future<void>? _work;
  bool _disposed = false;
  void changed() {
    if (!_disposed) notifyListeners();
  }

  int get availableAudioCount => catalog.where((e) => e.audioAvailable).length;
  int get missingAudioCount => catalog.length - availableAudioCount;
  String get episodeCountLabel =>
      '${visible.length} / ${catalog.length} épisodes';
  Set<String> get manualAudioReferences => {
    for (final row in session!.store.database.select(
      'SELECT audio_ref FROM local_audio_links WHERE manual=1',
    ))
      row['audio_ref'] as String,
  };

  String get folderLabel => switch (audioState) {
    AudioFolderState.unconfigured => 'Aucun dossier MP3 paramétré',
    AudioFolderState.unavailable =>
      'Dossier MP3 inaccessible — liens et suivi conservés',
    AudioFolderState.incomplete => 'Scan incomplet — disponibilité à vérifier',
    AudioFolderState.ready => 'Dossier MP3 : $mp3Path',
  };
  bool get audioKnown => audioState == AudioFolderState.ready;
  String availability(DesktopEpisode e) => audioKnown
      ? (e.audioAvailable ? 'MP3 disponible' : 'MP3 absent')
      : audioState == AudioFolderState.unconfigured
      ? 'Dossier MP3 non paramétré'
      : 'Disponibilité à vérifier';

  Future<void> runWork(String label, Future<void> Function() action) async {
    if (busy) return;
    busy = true;
    message = label;
    error = '';
    changed();
    final task = action();
    _work = task;
    try {
      await task;
    } catch (e) {
      error = e.toString();
    } finally {
      busy = false;
      _work = null;
      changed();
    }
  }

  Future<void> boot() => runWork('Ouverture des données…', () async {
    opening = true;
    changed();
    try {
      requireExisting = File('${portableDirectory.path}/index-portable.json')
          .existsSync();
      final known = PortableSession.configuredDirectory(portableDirectory);
      if (known == null) {
        await defaultDataDirectory.create(recursive: true);
        return;
      }
      requireExisting = true;
      dataPath = known.path;
      await _open(known, true);
      // Le profil existe : ne jamais réafficher le formulaire pendant le scan.
      needsSetup = false;
      if (mp3Path.isNotEmpty && !skipStartupScan) await _scan(mp3Path);
    } finally {
      opening = false;
    }
  });

  Future<void> openMp3Folder() =>
      runWork('Ouverture du dossier MP3…', () async {
        if (mp3Path.isEmpty || !await Directory(mp3Path).exists()) {
          throw const FileSystemException(
            'Le dossier MP3 est introuvable ou inaccessible.',
          );
        }
        final path = Directory(mp3Path).absolute.uri.toFilePath();
        await folderOpener(path);
      });

  bool get skipStartupScan => session?.setting('skip_startup_scan') == 'true';
  bool get recursive => session?.setting('recursive') != 'false';
  void setSkipStartupScan(bool value) {
    session!.setSetting('skip_startup_scan', value.toString());
    changed();
  }

  void setRecursive(bool value) {
    session!.setSetting('recursive', value.toString());
    changed();
  }

  Future<void> _open(Directory directory, bool existing) async {
    final seed = await seedLoader();
    session = await PortableSession.open(
      portableDirectory: portableDirectory,
      dataDirectory: directory,
      referenceBytes: seed.bytes,
      referenceSha256: seed.sha256,
      requireExisting: existing,
    );
    dataPath = session!.dataDirectory.path;
    mp3Path = session!.setting('mp3_directory') ?? '';
    dark = session!.setting('theme') == 'dark';
    if (mp3Path.isEmpty)
      audioState = AudioFolderState.unconfigured;
    else
      audioState = await Directory(mp3Path).exists()
          ? AudioFolderState.ready
          : AudioFolderState.unavailable;
    _lastReport();
    _refreshAssociationReport();
    if (mp3Path.isNotEmpty && audioState == AudioFolderState.ready) {
      // Sans rescan, le dernier scan incomplet ne devient pas complet.
      audioState = report?['complete'] == true
          ? AudioFolderState.ready
          : AudioFolderState.incomplete;
    }
    reload();
  }

  Future<void> configure(String data, String mp3, bool later) =>
      runWork('Préparation du catalogue…', () async {
        if (data.trim().isEmpty)
          throw ArgumentError('Choisissez le dossier des données utilisateur.');
        if (!later && mp3.trim().isEmpty)
          throw ArgumentError(
            'Choisissez le dossier MP3 ou cochez « Préciser le dossier MP3 plus tard ».',
          );
        if (session == null) {
          final target = Directory(data);
          if (!requireExisting &&
              target.absolute.path == defaultDataDirectory.absolute.path) {
            await target.create(recursive: true);
          }
          await _open(target, requireExisting);
        }
        needsSetup = false;
        if (later) {
          session!.setSetting('mp3_directory', '');
          mp3Path = '';
          audioState = AudioFolderState.unconfigured;
          reload();
        } else
          await _scan(mp3);
      });
  void _lastReport() {
    final rows = session!.store.database.select(
      'SELECT id,completed,summary_json FROM audio_scan_runs ORDER BY id DESC LIMIT 1',
    );
    if (rows.isEmpty) return;
    final r = rows.single;
    final summary =
        jsonDecode(r['summary_json'] as String) as Map<String, dynamic>;
    report = {
      'complete': r['completed'] == 1,
      'count': summary['audio_count'],
      'issues': summary['issues'],
      'decisions': session!.store.database
          .select('SELECT decision_json FROM audio_scan_items WHERE run_id=?', [
            r['id'],
          ])
          .map((v) => jsonDecode(v['decision_json'] as String))
          .toList(),
    };
  }

  void _refreshAssociationReport() {
    if (report == null) return;
    final links = {
      for (final r in session!.store.database.select(
        'SELECT audio_ref,episode_id,manual FROM local_audio_links WHERE available=1 AND matching_status=?',
        ['confirmed'],
      ))
        r['audio_ref']: r,
    };
    final excluded = session!.store.unlinkedAudioReferences;
    report = {
      ...report!,
      'decisions': [
        for (final raw in (report!['decisions'] as List? ?? []))
          if (excluded.contains((raw as Map)['audio_reference']))
            {
              ...raw,
              'status': 'unknown',
              'episode_id': null,
              'matching_method': 'manual_unlinked',
              'evidence_rule': 'manual_unlinked',
              'reason': 'Association retirée par l’utilisateur ; choisissez Associer… pour la rétablir.',
            }
          else if (links.containsKey(raw['audio_reference']))
            {
              ...raw,
              'status': 'confirmed',
              'episode_id': links[raw['audio_reference']]!['episode_id'],
              if (links[raw['audio_reference']]!['manual'] == 1) ...{
                'matching_method': 'manual',
                'evidence_rule': 'manual',
                'reason': 'Association manuelle conservée.',
              },
            }
          else
            raw,
      ],
    };
  }

  Future<void> unlink(String reference) =>
      runWork('Retrait de l’association…', () async {
        session!.store.unlinkAudio(reference);
        _refreshAssociationReport();
        reload();
      });

  Future<void> _scan(String path) async {
    message = 'Association par noms d’origine et système du journal…';
    changed();
    mp3Path = Directory(path).absolute.path;
    report = await session!.scan(mp3Path, recursive: recursive);
    audioState = report!['complete'] == true
        ? AudioFolderState.ready
        : AudioFolderState.incomplete;
    if (!await Directory(mp3Path).exists())
      audioState = AudioFolderState.unavailable;
    reload();
    message = 'Scan terminé : ${report!['count']} fichier(s).';
  }

  Future<void> scan(String path) =>
      runWork('Analyse du dossier…', () => _scan(path));
  Future<void> folders(String mp3, bool recursive) =>
      runWork('Mise à jour des dossiers…', () async {
        session!.setSetting('recursive', recursive.toString());
        if (mp3.trim().isEmpty) {
          session!.setSetting('mp3_directory', '');
          mp3Path = '';
          audioState = AudioFolderState.unconfigured;
          reload();
        } else
          await _scan(mp3);
      });
  Future<void> relocate(Directory target) =>
      runWork('Copie et contrôle des données…', () async {
        session = await session!.relocate(target);
        dataPath = session!.dataDirectory.path;
        reload();
      });
  void reload() {
    if (session == null) return;
    catalog = session!.episodes();
    queryError = '';
    try {
      if (fields.isEmpty)
        throw ArgumentError('Sélectionnez au moins un champ de recherche.');
      visible = query.trim().characters.length < 3
          ? List.of(catalog)
          : session!.episodes(query: query, fields: fields);
    } catch (e) {
      visible = [];
      queryError = e.toString();
    }
    visible = visible
        .where(
          (e) =>
              (!favoritesOnly || e.favorite) &&
              (status == 'Tous' || e.status == status),
        )
        .toList();
    int compare(DesktopEpisode a, DesktopEpisode b) {
      final date = (b.date ?? '').compareTo(a.date ?? '');
      final value = switch (sort) {
        CatalogSort.dateNew => date,
        CatalogSort.dateOld => -date,
        CatalogSort.titleAZ => frenchTitleKey(
          a.title,
        ).compareTo(frenchTitleKey(b.title)),
        CatalogSort.titleZA => frenchTitleKey(
          b.title,
        ).compareTo(frenchTitleKey(a.title)),
        CatalogSort.audioFirst =>
          audioKnown
              ? (b.audioAvailable ? 1 : 0) - (a.audioAvailable ? 1 : 0)
              : 0,
        CatalogSort.audioLast =>
          audioKnown
              ? (a.audioAvailable ? 1 : 0) - (b.audioAvailable ? 1 : 0)
              : 0,
        CatalogSort.relevance => 0,
      };
      return value != 0
          ? value
          : (sort == CatalogSort.audioFirst || sort == CatalogSort.audioLast)
          ? date
          : a.id.compareTo(b.id);
    }

    if (sort != CatalogSort.relevance) visible.sort(compare);
    final previousId = selected?.id;
    final matches = visible.where((e) => e.id == previousId);
    selected = matches.isNotEmpty
        ? matches.first
        : visible.isNotEmpty
        ? visible.first
        : null;

    changed();
  }

  void search(String value) {
    if (query.isEmpty && value.isNotEmpty) sort = CatalogSort.relevance;
    if (value.isEmpty) sort = CatalogSort.dateNew;
    query = value;
    reload();
  }

  void selectRelative(int delta) {
    if (visible.isEmpty) return;
    final index = visible.indexWhere((e) => e.id == selected?.id);
    select(visible[(index + delta).clamp(0, visible.length - 1)]);
  }

  Future<File> exportScanDiagnostic() async {
    if (report == null || session == null) {
      throw StateError('Aucun diagnostic à exporter.');
    }
    final directory = Directory('$dataPath/exports');
    await directory.create(recursive: true);
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
      RegExp(r'[-:.]'),
      '',
    );
    final file = File('${directory.path}/IndeX_diagnostic_scan_$stamp.txt');
    final buffer = StringBuffer(
      'IndeX — diagnostic du scan\nDate UTC : $stamp\nDossier MP3 : $mp3Path\n\n',
    );
    buffer.writeln('MP3 analysés : ${report!['count'] ?? 0}');
    final issues = (report!['issues'] as List?) ?? [];
    buffer.writeln('Diagnostics : ${issues.length}\n');
    for (final (index, raw) in issues.indexed) {
      final issue = raw as Map;
      buffer.writeln('${index + 1}. ${issue['message'] ?? ''}');
      if (issue['source'] != null)
        buffer.writeln(
          '   Source : ${displayDiagnosticPath(issue['source'].toString())}',
        );
      if (issue['code'] != null) buffer.writeln('   Code : ${issue['code']}');
      buffer.writeln();
    }
    buffer.writeln('Rapport complet et preuves des associations :');
    buffer.writeln(
      const JsonEncoder.withIndent('  ').convert(diagnosticForDisplay(report)),
    );
    await file.writeAsString(buffer.toString(), flush: true);
    return file;
  }

  void select(DesktopEpisode e) {
    selected = e;
    changed();
  }

  void setTheme(bool value) {
    dark = value;
    session?.setSetting('theme', value ? 'dark' : 'light');
    changed();
  }

  void favorite(DesktopEpisode e) {
    session!.favorite(e.id, !e.favorite);
    reload();
  }

  void listened(DesktopEpisode e, {bool reset = false}) {
    session!.listened(e.id, e.status != 'ECOUTE', resetConfirmed: reset);
    reload();
  }

  Future<void> manual(String id, String reference, String name) =>
      runWork('Enregistrement du choix manuel…', () async {
        final uri = Uri.parse(reference);
        if (uri.scheme != 'file' || !await File.fromUri(uri).exists())
          throw StateError('Le MP3 sélectionné est introuvable.');
        session!.store.recordManualLink(id, reference, name);
        _refreshAssociationReport();
        reload();
      });
  bool isManual(String reference) => session!.store.database.select(
    'SELECT 1 FROM local_audio_links WHERE audio_ref=? AND manual=1',
    [reference],
  ).isNotEmpty;
  Future<void> closeSafely() async {
    if (_work != null) await _work;
    if (session != null) {
      await session!.closeSafely();
      session = null;
    }
  }

  Future<void> release() async {
    if (_work != null) await _work;
    await session?.dispose();
    session = null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
