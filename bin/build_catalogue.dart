import 'dart:convert';
import 'dart:io';

import 'package:index_core/index_io.dart';

Future<void> main(List<String> args) async {
  try {
    final options = <String, String>{};
    var replace = false;
    const allowed = {
      '--txt',
      '--journal',
      '--output',
      '--version',
      '--generated-at',
      '--report',
    };
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '--replace') {
        replace = true;
        continue;
      }
      if (!allowed.contains(arg) ||
          i + 1 >= args.length ||
          options.containsKey(arg))
        throw FormatException('Option inconnue, répétée ou incomplète : $arg');
      options[arg] = args[++i];
    }
    for (final key in ['--output', '--version', '--generated-at']) {
      if (!options.containsKey(key))
        throw FormatException('Option obligatoire : $key');
    }
    final stamp = DateTime.parse(options['--generated-at']!);
    if (!stamp.isUtc)
      throw const FormatException('Utiliser un horodatage UTC terminé par Z.');
    if (options['--report'] case final path?) {
      if (!path.toLowerCase().endsWith('.json'))
        throw const FormatException(
          'Le rapport doit être un fichier .json, jamais une source CSV/TXT/MP3.',
        );
    }
    final report = await buildCatalog(
      txtDirectory: Directory(options['--txt'] ?? 'TXT_Files'),
      journal: File(options['--journal'] ?? 'Journal_Files/journal.csv'),
      output: File(options['--output']!),
      version: options['--version']!,
      generatedAt: stamp,
      replace: replace,
    );
    if (options['--report'] case final path?) {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(report)}\n',
      );
    }
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert(report['summary']),
    );
  } on Exception catch (e) {
    stderr.writeln('Génération refusée : $e');
    exitCode = 1;
  }
}
