import '../identity.dart';
import 'id3_models.dart';

enum CommResolutionStatus { pair, unique, conflict, noCandidate, blocked }

final class IgnoredComment {
  const IgnoredComment(this.frame, this.reason);
  final CommFrame frame;
  final String reason;
}

/// Une preuve pour le futur matching, jamais une association inter-fichiers.
final class CommResolution {
  CommResolution({
    required this.status,
    required this.originalName,
    required List<CommFrame> supportingFrames,
    required List<IgnoredComment> ignored,
    required Map<String, List<CommFrame>> candidates,
    required this.reason,
  }) : supportingFrames = List.unmodifiable(supportingFrames),
       ignored = List.unmodifiable(ignored),
       candidates = Map.unmodifiable(
         candidates.map((k, v) => MapEntry(k, List<CommFrame>.unmodifiable(v))),
       );
  final CommResolutionStatus status;
  final String? originalName;
  final List<CommFrame> supportingFrames;
  final List<IgnoredComment> ignored;
  final Map<String, List<CommFrame>> candidates;
  final String reason;
  String? get evidenceRule => switch (status) {
    CommResolutionStatus.pair => 'comm_pair_v1',
    CommResolutionStatus.unique => 'comm_unique_v1',
    _ => null,
  };
  bool get allowsFilenameFallback => status == CommResolutionStatus.noCandidate;
}

final class CommResolver {
  const CommResolver();

  CommResolution resolve(Id3ReadResult tag) {
    final groups = <String, List<CommFrame>>{};
    final ignored = <IgnoredComment>[];
    CommResolution result(
      CommResolutionStatus status,
      String? name,
      String reason,
    ) => CommResolution(
      status: status,
      originalName: name,
      supportingFrames: name == null ? [] : groups[name]!,
      ignored: ignored,
      candidates: groups,
      reason: reason,
    );
    if (!tag.isTrustworthy) {
      return result(
        CommResolutionStatus.blocked,
        null,
        'Tag incomplet, invalide ou non pris en charge.',
      );
    }
    final indices = <int>{};
    for (final c in tag.comments) {
      if (c.index < 0 || !indices.add(c.index)) {
        return result(
          CommResolutionStatus.blocked,
          null,
          'Indice de trame répété ou invalide : ne pas compter deux fois la même trame.',
        );
      }
      final name = canonicalOriginalName(c.text);
      if (name == null) {
        ignored.add(
          IgnoredComment(c, 'Commentaire sans nom historique MP3 exploitable.'),
        );
      } else {
        (groups[name] ??= []).add(c);
      }
    }
    final pairs = groups.entries.where((e) => e.value.length >= 2).toList();
    if (pairs.length > 1)
      return result(
        CommResolutionStatus.conflict,
        null,
        'Plusieurs identifiants ont une paire concordante.',
      );
    if (pairs.length == 1) {
      final name = pairs.single.key;
      for (final e in groups.entries.where((e) => e.key != name)) {
        ignored.addAll(
          e.value.map(
            (c) => IgnoredComment(
              c,
              'Identifiant isolé écarté au profit de la paire concordante.',
            ),
          ),
        );
      }
      return result(
        CommResolutionStatus.pair,
        name,
        'Un seul identifiant soutenu par au moins deux trames distinctes.',
      );
    }
    if (groups.length == 1)
      return result(
        CommResolutionStatus.unique,
        groups.keys.single,
        'Identifiant unique sans contradiction.',
      );
    if (groups.isEmpty)
      return result(
        CommResolutionStatus.noCandidate,
        null,
        'Aucun commentaire MP3 exploitable.',
      );
    return result(
      CommResolutionStatus.conflict,
      null,
      'Identifiants isolés contradictoires, sans paire concordante.',
    );
  }
}
