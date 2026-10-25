import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final path = args.single;
  if (!await File(path).exists()) {
    throw StateError('Le fichier de verrou attendu doit déjà exister.');
  }
  RandomAccessFile? file;
  var stage = 'open';
  try {
    // Windows peut refuser l'ouverture même, avant l'appel explicite à lock().
    file = await File(path).open(mode: FileMode.append);
    stage = 'lock';
    await file.lock(FileLock.exclusive);
    await file.unlock();
    stdout.writeln(jsonEncode({'status': 'acquired'}));
    exitCode = 0;
  } on FileSystemException catch (error) {
    stdout.writeln(
      jsonEncode({
        'status': 'blocked',
        'stage': stage,
        'error_code': error.osError?.errorCode,
        'message': error.message,
      }),
    );
    exitCode = 3;
  } finally {
    await file?.close();
  }
}
