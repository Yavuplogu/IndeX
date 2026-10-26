import 'dart:io';

import '../catalog/models.dart';
import '../matching/matching_engine.dart';
import 'file_tag_source.dart';

/// Parcours des TXT sans suivre de liens symboliques, avec lecture bornée.
Future<List<TxtInput>> loadTxtDirectory(
  Directory directory, {
  int maxBytesPerFile = 2 * 1024 * 1024,
}) async {
  final result = <TxtInput>[];
  final rootSegments = directory.absolute.uri
      .normalizePath()
      .pathSegments
      .where((s) => s.isNotEmpty)
      .length;
  await for (final entity in directory.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File || !entity.path.toLowerCase().endsWith('.txt'))
      continue;
    // Uri.path conserve l'échappement %20 ; pathSegments fournit les noms décodés.
    final relative = entity.absolute.uri
        .normalizePath()
        .pathSegments
        .skip(rootSegments)
        .join('/');
    try {
      final bytes = await FileTagSource(entity).readPrefix(maxBytesPerFile + 1);
      result.add(TxtInput(relative, bytes));
    } on FileSystemException catch (e) {
      result.add(TxtInput(relative, [], readError: e.message));
    }
  }
  result.sort((a, b) => a.path.compareTo(b.path));
  return result;
}

final class AudioScan {
  AudioScan({
    required this.scope,
    required this.complete,
    required this.recursive,
    required List<AudioCandidate> audios,
    required List<CatalogIssue> issues,
  }) : audios = List.unmodifiable(audios),
       issues = List.unmodifiable(issues);
  final String scope;
  final bool complete;
  final bool recursive;
  final List<AudioCandidate> audios;
  final List<CatalogIssue> issues;
}

Future<AudioScan> scanAudioDirectory(
  Directory directory, {
  bool recursive = false,
}) async {
  final audios = <AudioCandidate>[];
  final issues = <CatalogIssue>[];
  var complete = true;
  final scope = directory.absolute.uri.toString();
  try {
    await for (final entity in directory.list(
      recursive: recursive,
      followLinks: false,
    )) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.mp3'))
        continue;
      final ref = entity.absolute.uri;
      audios.add(
        AudioCandidate(
          reference: ref.toString(),
          currentName: ref.pathSegments.last,
        ),
      );
    }
  } on FileSystemException catch (e) {
    complete = false;
    issues.add(
      CatalogIssue(
        'audio_scope_unavailable',
        'Scan incomplet : ${e.message}',
        source: scope,
      ),
    );
  }
  audios.sort((a, b) => a.reference.compareTo(b.reference));
  return AudioScan(
    scope: scope,
    complete: complete,
    recursive: recursive,
    audios: audios,
    issues: issues,
  );
}
