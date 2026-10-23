import 'dart:io';
import 'dart:typed_data';

import '../id3/id3_models.dart';

/// Ouvre uniquement en FileMode.read et referme même en cas d'échec.
final class FileTagSource implements TagByteSource {
  const FileTagSource(this.file);
  final File file;

  @override
  Future<Uint8List> readPrefix(int count) async {
    if (count < 0) throw ArgumentError.value(count, 'count');
    final reader = await file.open(mode: FileMode.read);
    try {
      final result = BytesBuilder(copy: false);
      while (result.length < count) {
        final remaining = count - result.length;
        final chunk = await reader.read(remaining > 65536 ? 65536 : remaining);
        if (chunk.isEmpty) break;
        result.add(chunk);
      }
      return result.takeBytes();
    } finally {
      await reader.close();
    }
  }
}
