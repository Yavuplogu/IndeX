import 'dart:async';
import 'dart:io';

/// Le stockage de plateforme publie le fichier complet sans remplacer une cible.
typedef DownloadPublisher = Future<void> Function(File partial, File target);

final class DownloadCancelled implements Exception {
  @override
  String toString() => 'Téléchargement annulé.';
}

Uri? mp3DownloadUri(String? value) {
  final uri = value == null ? null : Uri.tryParse(value.trim());
  return uri != null &&
          ['http', 'https'].contains(uri.scheme) &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty &&
          !uri.hasFragment
      ? uri
      : null;
}

final class Mp3Download {
  Mp3Download({
    required this.source,
    required this.folder,
    required this.name,
    required this.publish,
    this.onProgress,
    this.allowSource,
    this.onPublishing,
    this.timeout = const Duration(seconds: 20),
    this.maxBytes = 512 * 1024 * 1024,
  });
  final Uri source;
  final bool Function(Uri)? allowSource;
  final Directory folder;
  final String name;
  final DownloadPublisher publish;
  final void Function(int received, int? total)? onProgress;
  final void Function()? onPublishing;
  final Duration timeout;
  final int maxBytes;
  final _cancelled = Completer<void>();
  HttpClient? _client;
  bool _started = false, _publishing = false;

  void cancel() {
    if (_publishing || _cancelled.isCompleted) return;
    _cancelled.complete();
    _client?.close(force: true);
  }

  Future<T> _wait<T>(Future<T> work) => Future.any([
    work,
    _cancelled.future.then<T>((_) => throw DownloadCancelled()),
  ]);

  Future<File> run() async {
    if (_started) throw StateError('Ce téléchargement a déjà été lancé.');
    _started = true;
    if (mp3DownloadUri(source.toString()) == null)
      throw ArgumentError('URL MP3 HTTP/HTTPS invalide.');
    if (!RegExp(
          r'^[^\\/:*?"<>|\x00-\x1f]+\.mp3$',
          caseSensitive: false,
        ).hasMatch(name) ||
        name.length > 240 ||
        RegExp(
          r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])\.',
          caseSensitive: false,
        ).hasMatch(name)) {
      throw ArgumentError('Nom de fichier MP3 invalide.');
    }
    if (!await folder.exists())
      throw FileSystemException('Dossier MP3 introuvable.', folder.path);
    final destination = File('${folder.path}/$name');
    if (await FileSystemEntity.type(destination.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw FileSystemException(
        'Un fichier de ce nom existe déjà ; aucun écrasement.',
        destination.path,
      );
    }
    Directory? staging;
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..autoUncompress = false;
    _client = client;
    try {
      if (_cancelled.isCompleted) throw DownloadCancelled();
      staging = await folder.createTemp('.index-download-');
      final partial = File('${staging.path}/payload.part');
      var uri = source;
      late HttpClientResponse response;
      for (var redirects = 0; ; redirects++) {
        if (allowSource != null && !allowSource!(uri))
          throw const HttpException(
            'Domaine ou protocole de téléchargement refusé.',
          );
        final request = await _wait(client.getUrl(uri).timeout(timeout));
        request.followRedirects = false;
        request.headers.set(
          HttpHeaders.acceptHeader,
          'audio/mpeg, application/octet-stream',
        );
        request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
        response = await _wait(request.close().timeout(timeout));
        if (![301, 302, 303, 307, 308].contains(response.statusCode)) break;
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.listen((_) {}).cancel();
        final next = location == null
            ? null
            : mp3DownloadUri(uri.resolve(location).toString());
        if (redirects >= 5 ||
            next == null ||
            (uri.scheme == 'https' && next.scheme != 'https')) {
          throw const HttpException('Redirection du téléchargement refusée.');
        }
        uri = next;
      }
      if (response.statusCode != HttpStatus.ok)
        throw HttpException(
          'Le serveur a répondu HTTP ${response.statusCode}.',
        );
      final mime = response.headers.contentType?.mimeType ?? '';
      if (mime.startsWith('text/') ||
          mime.contains('json') ||
          mime.contains('xml')) {
        throw const FormatException(
          'Le serveur n’a pas fourni un fichier MP3.',
        );
      }
      final total = response.contentLength >= 0 ? response.contentLength : null;
      if (total != null && total > maxBytes)
        throw const FormatException('Fichier MP3 trop volumineux.');
      var received = 0;
      onProgress?.call(received, total);
      final output = await partial.open(mode: FileMode.writeOnly);
      final input = StreamIterator(response.timeout(timeout));
      try {
        while (await _wait(input.moveNext())) {
          final chunk = input.current;
          received += chunk.length;
          if (received > maxBytes)
            throw const FormatException('Fichier MP3 trop volumineux.');
          await output.writeFrom(chunk);
          onProgress?.call(received, total);
        }
        await output.flush();
      } finally {
        try {
          await input.cancel();
        } finally {
          await output.close();
        }
      }
      if (total != null && total != received)
        throw const FormatException('Téléchargement incomplet.');
      await validateDownloadedMp3(partial);
      if (_cancelled.isCompleted) throw DownloadCancelled();
      _publishing = true;
      onPublishing?.call();
      await publish(partial, destination);
      return destination;
    } catch (_) {
      if (_cancelled.isCompleted) throw DownloadCancelled();
      rethrow;
    } finally {
      client.close(force: true);
      _client = null;
      if (staging != null && await staging.exists()) {
        try {
          await staging.delete(recursive: true);
        } on FileSystemException {
          /* Un résidu .part n'est jamais associé. */
        }
      }
    }
  }
}

/// Contrôle de format, pas une certification du contenu documentaire ni un décodage complet.
Future<void> validateDownloadedMp3(File file) async {
  final input = await file.open();
  try {
    final length = await input.length();
    final head = await input.read(10);
    var offset = 0;
    if (head.length == 10 && head[0] == 73 && head[1] == 68 && head[2] == 51) {
      if (head.sublist(6, 10).any((b) => b > 127))
        throw const FormatException('En-tête MP3 invalide.');
      offset =
          10 + (head[6] << 21) + (head[7] << 14) + (head[8] << 7) + head[9];
      if (head[3] == 4 && head[5] & 16 != 0) offset += 10;
    }
    if (offset > length || offset > 16 * 1024 * 1024)
      throw const FormatException('En-tête MP3 invalide.');
    await input.setPosition(offset);
    final bytes = await input.read(65536);
    (int, int)? frame(int at) {
      if (at + 4 > bytes.length ||
          bytes[at] != 255 ||
          bytes[at + 1] & 224 != 224)
        return null;
      final version = (bytes[at + 1] >> 3) & 3;
      final layer = (bytes[at + 1] >> 1) & 3;
      final bit = bytes[at + 2] >> 4, sample = (bytes[at + 2] >> 2) & 3;
      if (version == 1 || layer != 1 || bit == 0 || bit == 15 || sample == 3)
        return null;
      final rate = (version == 3
          ? [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320]
          : [
              0,
              8,
              16,
              24,
              32,
              40,
              48,
              56,
              64,
              80,
              96,
              112,
              128,
              144,
              160,
            ])[bit];
      final hz =
          [44100, 48000, 32000][sample] ~/
          (version == 3
              ? 1
              : version == 2
              ? 2
              : 4);
      return (
        ((version == 3 ? 144000 : 72000) * rate ~/ hz) +
            ((bytes[at + 2] >> 1) & 1),
        (version << 2) | sample,
      );
    }

    for (var at = 0; at + 4 < bytes.length; at++) {
      final first = frame(at);
      if (first == null) continue;
      final second = frame(at + first.$1);
      if (second != null &&
          first.$2 == second.$2 &&
          at + first.$1 + second.$1 <= bytes.length)
        return;
    }
    throw const FormatException(
      'Le fichier reçu ne contient pas de trames audio MP3 valides.',
    );
  } finally {
    await input.close();
  }
}
