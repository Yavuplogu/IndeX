import 'dart:async';
import 'dart:io';

import 'package:index_core/index_desktop.dart';
import 'package:test/test.dart';

List<int> audioBytes() {
  final bytes = List<int>.filled(417 * 2, 0);
  for (final at in [0, 417]) bytes.setRange(at, at + 4, [255, 251, 144, 0]);
  return bytes;
}

void main() {
  late Directory folder;
  late HttpServer server;
  late Uri source;
  var requests = 0;
  Future<void> Function(HttpRequest) handler = (_) async {};
  setUp(() async {
    folder = Directory.systemTemp.createTempSync('index-download-');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    source = Uri.parse('http://127.0.0.1:${server.port}/audio.mp3');
    requests = 0;
    server.listen((request) {
      requests++;
      unawaited(handler(request).catchError((Object _) {}));
    });
    handler = (request) async {
      request.response.headers.contentType = ContentType('audio', 'mpeg');
      request.response.contentLength = audioBytes().length;
      request.response.add(audioBytes());
      await request.response.close();
    };
  });
  tearDown(() async {
    await server.close(force: true);
    folder.deleteSync(recursive: true);
  });
  Future<void> publish(File part, File target) async {
    if (await target.exists()) throw StateError('Cible déjà présente.');
    await part.rename(target.path);
  }

  Mp3Download job({
    DownloadPublisher? publisher,
    int maxBytes = 100000,
    void Function(int, int?)? progress,
  }) => Mp3Download(
    source: source,
    folder: folder,
    name: 'mr_x_1997_01_04.mp3',
    publish: publisher ?? publish,
    onProgress: progress,
    timeout: const Duration(seconds: 2),
    maxBytes: maxBytes,
  );

  test(
    'Requête explicite, redirection, progression et fichier final intégral',
    () async {
      final received = <int>[];
      var publishing = false;
      final download = job(
        progress: (bytes, total) {
          received.add(bytes);
          expect(total, audioBytes().length);
        },
        publisher: (part, target) async {
          publishing = true;
          expect(await part.readAsBytes(), audioBytes());
          await publish(part, target);
        },
      );
      expect(requests, 0);
      final target = await download.run();
      expect(publishing, isTrue);
      expect(await target.readAsBytes(), audioBytes());
      expect(received.first, 0);
      expect(received.last, audioBytes().length);
      expect(folder.listSync(), hasLength(1));
      // Un lien de redirection suit le même budget et ne publie aucun intermédiaire.
      target.deleteSync();
      handler = (request) async {
        if (request.uri.path != '/final') {
          request.response.statusCode = 302;
          request.response.headers.set(HttpHeaders.locationHeader, '/final');
        } else {
          request.response.headers.contentType = ContentType('audio', 'mpeg');
          request.response.add(audioBytes());
        }
        await request.response.close();
      };
      expect(await (await job().run()).readAsBytes(), audioBytes());
    },
  );

  for (final failure in [
    'html',
    '404',
    'truncated',
    'oversized',
    'redirect-loop',
  ]) {
    test('Échec $failure : aucun MP3 ni fichier partiel associé', () async {
      handler = (request) async {
        request.response.headers.contentType = ContentType('audio', 'mpeg');
        if (failure == 'html') {
          request.response.headers.contentType = ContentType.html;
          request.response.write('<html>Erreur serveur</html>');
        } else if (failure == '404') {
          request.response.statusCode = 404;
        } else if (failure == 'truncated') {
          request.response.add(audioBytes().sublist(0, 200));
        } else if (failure == 'redirect-loop') {
          request.response.statusCode = 302;
          request.response.headers.set(
            HttpHeaders.locationHeader,
            '/audio.mp3',
          );
        } else {
          request.response.contentLength = audioBytes().length;
          request.response.add(audioBytes());
        }
        await request.response.close();
      };
      await expectLater(
        job(maxBytes: failure == 'oversized' ? 100 : 100000).run(),
        throwsA(isA<Exception>()),
      );
      expect(folder.listSync(), isEmpty);
    });
  }

  test(
    'Cible préexistante ou apparue pendant la réception : jamais écrasée',
    () async {
      final target = File('${folder.path}/mr_x_1997_01_04.mp3')
        ..writeAsStringSync('conservé');
      await expectLater(job().run(), throwsA(isA<FileSystemException>()));
      expect(requests, 0);
      target.deleteSync();
      await expectLater(
        job(
          publisher: (part, target) async {
            target.writeAsStringSync('concurrent');
            await publish(part, target);
          },
        ).run(),
        throwsStateError,
      );
      expect(target.readAsStringSync(), 'concurrent');
      expect(folder.listSync(), hasLength(1));
    },
  );

  test(
    'Annulation d’un transfert suspendu : nettoyage et aucun fichier final',
    () async {
      final first = Completer<void>();
      handler = (request) async {
        request.response.bufferOutput = false;
        request.response.headers.contentType = ContentType('audio', 'mpeg');
        request.response.add(audioBytes());
        await request.response.flush();
        // Pas de fin de réponse : le client doit pouvoir annuler sans attendre.
      };
      final download = job(
        progress: (bytes, _) {
          if (bytes > 0 && !first.isCompleted) first.complete();
        },
      );
      final work = download.run();
      final failure = expectLater(work, throwsA(isA<DownloadCancelled>()));
      await first.future;
      download.cancel();
      await failure.timeout(const Duration(seconds: 3));
      expect(folder.listSync(), isEmpty);
    },
  );

  test(
    'URL et nom non locaux : schémas, traversée et identifiants refusés',
    () async {
      expect(mp3DownloadUri('file:///test.mp3'), isNull);
      expect(mp3DownloadUri('https://user:secret@example.test/a.mp3'), isNull);
      expect(mp3DownloadUri('http://example.test/a.mp3'), isNotNull);
      final download = Mp3Download(
        source: source,
        folder: folder,
        name: '../escape.mp3',
        publish: publish,
      );
      await expectLater(download.run(), throwsArgumentError);
      expect(requests, 0);
    },
  );

  test(
    'Validation en lecture seule des quatorze fixtures MP3 existantes',
    () async {
      final files = Directory('MP3_Files')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.mp3'));
      expect(files, hasLength(14));
      for (final file in files) await validateDownloadedMp3(file);
    },
  );
}
