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

enum CatalogSort {
  relevance,
  dateNew,
  dateOld,
  titleAZ,
  titleZA,
  audioFirst,
  audioLast,
}

enum AudioFolderState { unconfigured, ready, unavailable, incomplete }

final class AppModel extends ChangeNotifier {
  AppModel({required this.portableDirectory, this.seedLoader = bundledSeed});
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
  Set<SearchField> fields = Set.of(SearchField.values);
  List<DesktopEpisode> catalog = [], visible = [];
  DesktopEpisode? selected;
  Map<String, Object?>? report;
  Future<void>? _work;
  bool _disposed = false;
  void changed() {
    if (!_disposed) notifyListeners();
  }

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
    requireExisting = File('${portableDirectory.path}/index-portable.json')
        .existsSync();
    final known = PortableSession.configuredDirectory(portableDirectory);
    if (known == null) return;
    requireExisting = true;
    dataPath = known.path;
    await _open(known, true);
    if (mp3Path.isNotEmpty) await _scan(mp3Path);
    needsSetup = mp3Path.isEmpty;
  });
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
        if (session == null) await _open(Directory(data), requireExisting);
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

  Future<void> _scan(String path) async {
    message = 'Association par noms d’origine et système du journal…';
    changed();
    mp3Path = Directory(path).absolute.path;
    report = await session!.scan(
      mp3Path,
      recursive: session!.setting('recursive') == 'true',
    );
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
        buffer.writeln('   Source : ${issue['source']}');
      if (issue['code'] != null) buffer.writeln('   Code : ${issue['code']}');
      buffer.writeln();
    }
    buffer.writeln('Rapport complet et preuves des associations :');
    buffer.writeln(const JsonEncoder.withIndent('  ').convert(report));
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
