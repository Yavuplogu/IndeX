enum Severity { warning, error }

/// Code stable pour les tests/rapports, message français pour l'utilisateur.
final class Diagnostic {
  const Diagnostic(this.code, this.message, {this.severity = Severity.error});
  final String code;
  final String message;
  final Severity severity;

  @override
  String toString() => '$code: $message';
}
