/// Réécrit uniquement une racine connue, avec frontière de dossier. Les alias
/// Windows courts/longs sont mémorisés avant le déplacement, jamais devinés.
String rebasePortableReference(
  String value,
  List<String> oldRoots,
  String newRoot, {
  required bool windows,
}) {
  String comparable(String path) => windows ? path.toLowerCase() : path;
  final destination = windows ? newRoot.replaceAll('/', r'\') : newRoot;
  for (final oldRoot in oldRoots) {
    final source = windows ? oldRoot.replaceAll('/', r'\') : oldRoot;
    final uriPrefix = Uri.directory(source, windows: windows).toString();
    if (comparable(value).startsWith(comparable(uriPrefix))) {
      return '${Uri.directory(destination, windows: windows)}${value.substring(uriPrefix.length)}';
    }
    final path = windows ? value.replaceAll('/', r'\') : value;
    if (comparable(path) == comparable(source)) return destination;
    final prefix = '$source${windows ? r'\' : '/'}';
    if (comparable(path).startsWith(comparable(prefix))) {
      return '$destination${windows ? r'\' : '/'}${path.substring(prefix.length)}';
    }
  }
  return value;
}
