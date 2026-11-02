import 'dart:io';

/// Identité documentaire opaque Android : fournisseur + documentId, jamais un path.
/// Deux grants SAF vers le même document peuvent avoir des préfixes tree différents.
Object documentReferenceKey(String reference) {
  final uri = Uri.tryParse(reference);
  if (uri?.scheme == 'content') {
    final segments = uri!.pathSegments;
    final at = segments.length == 2 && segments[0] == 'document'
        ? 0
        : segments.length == 4 &&
              segments[0] == 'tree' &&
              segments[2] == 'document'
        ? 2
        : -1;
    if (at >= 0) return (uri.authority, segments[at + 1]);
  }
  return reference;
}

/// Clés temporaires de comparaison, sans réécriture des références persistées.
/// Le parent reste résoluble lorsque la feuille vient d’être renommée.
final class LocalAudioPaths {
  final _directories = <String, String>{};
  void clear() => _directories.clear();

  String _directoryPath(Directory directory) => _directories.putIfAbsent(
    directory.absolute.path,
    () {
      try {
        return directory.resolveSymbolicLinksSync();
      } on FileSystemException {
        // Un dossier inaccessible reste opaque, sans deviner son ancien alias.
        return directory.absolute.path;
      }
    },
  );

  String _case(String path) => Platform.isWindows ? path.toLowerCase() : path;

  String referenceKey(String reference) {
    final uri = Uri.tryParse(reference);
    if (uri?.scheme != 'file') return reference;
    final file = File.fromUri(uri!);
    final parent = _directoryPath(file.parent);
    final path = File('$parent/${file.uri.pathSegments.last}').path;
    // Comparer la casse des caractères décodés, pas celle de leurs %xx.
    return File(_case(path)).uri.toString();
  }

  bool contains(String scope, String reference) {
    final uri = Uri.tryParse(scope);
    // Les références SAF restent opaques ; conserver le périmètre du fournisseur.
    if (uri?.scheme != 'file') return reference.startsWith(scope);
    if (Uri.tryParse(reference)?.scheme != 'file') return false;
    final prefix = Directory(_case(_directoryPath(Directory.fromUri(uri!)))).uri
        .toString();
    final key = referenceKey(reference);
    return key.startsWith(prefix);
  }
}
