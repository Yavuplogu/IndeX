import 'package:index_core/src/desktop/portable_paths.dart';
import 'package:test/test.dart';

void main() {
  test('Régression Windows RUNNER~1/runneradmin : URI, casse, séparateurs et frontière', () {
    const roots = [
      r'C:\Users\runneradmin\AppData\Local\Temp\IndeX',
      r'C:\Users\RUNNER~1\AppData\Local\Temp\IndeX',
    ];
    const destination = r'D:\Données\IndeX déplacé';
    String rebase(String value) =>
        rebasePortableReference(value, roots, destination, windows: true);
    final sourceFile = Uri.file(
      '${roots.last}\\MP3 été #\\mr_x.mp3',
      windows: true,
    );
    final expected = Uri.file(
      '$destination\\MP3 été #\\mr_x.mp3',
      windows: true,
    );
    expect(rebase(sourceFile.toString()), expected.toString());
    expect(
      rebase(r'c:\users\runner~1\AppData\Local\Temp\IndeX\MP3'),
      '$destination\\MP3',
    );
    expect(
      rebase('C:/Users/RUNNER~1/AppData/Local/Temp/IndeX/MP3'),
      '$destination\\MP3',
    );
    expect(rebase(roots.first.toUpperCase()), destination);
    expect(
      rebase('${roots.last}2\\extérieur.mp3'),
      '${roots.last}2\\extérieur.mp3',
    );
    expect(rebase(r'E:\Musique\extérieur.mp3'), r'E:\Musique\extérieur.mp3');
    final special = Uri.file(
      '${roots.last}\\100% + #.mp3',
      windows: true,
    ).toString();
    expect(
      rebase(special),
      Uri.file('$destination\\100% + #.mp3', windows: true).toString(),
    );
    expect(rebase('content://storage/MP3'), 'content://storage/MP3');
  });
}
