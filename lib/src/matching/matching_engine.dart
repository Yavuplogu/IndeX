import 'package:unorm_dart/unorm_dart.dart' as unicode;

import '../id3/comm_resolver.dart';
import '../id3/id3_models.dart';
import '../identity.dart';

enum MatchStatus { confirmed, provisional, conflict, unknown, blocked }

final class MatchEpisode {
  MatchEpisode({
    required this.id,
    required this.originalName,
    required this.title,
    List<String> systemNames = const [],
    this.journalStatus,
  }) : systemNames = List.unmodifiable(systemNames);
  final String id;
  final String originalName;
  final String title;
  final List<String> systemNames;
  final String? journalStatus;
}

final class AudioCandidate {
  const AudioCandidate({
    required this.reference,
    required this.currentName,
    required this.tag,
  });

  /// Chemin/URI opaque local, jamais une identité d'épisode.
  final String reference;
  final String currentName;
  final Id3ReadResult tag;
}

final class MatchDecision {
  const MatchDecision({
    required this.audio,
    required this.status,
    required this.episodeId,
    required this.method,
    required this.reason,
    required this.proof,
  });
  final AudioCandidate audio;
  final MatchStatus status;
  final String? episodeId;
  final String? method;
  final String reason;
  final CommResolution proof;
  bool get id3Verified =>
      proof.status == CommResolutionStatus.pair ||
      proof.status == CommResolutionStatus.unique;
  Map<String, Object?> toJson() => {
    'audio_reference': audio.reference,
    'current_name': audio.currentName,
    'episode_id': episodeId,
    'status': status.name,
    'matching_method': method,
    'reason': reason,
    'local_verification_status': id3Verified
        ? 'CONFIRMEE'
        : audio.tag.isTrustworthy
        ? 'ABSENTE'
        : 'ILLISIBLE',
    'evidence_rule': proof.evidenceRule,
    'supporting_frames': proof.supportingFrames.map((f) => f.index).toList(),
    'comments': [
      for (final c in audio.tag.comments)
        {
          'index': c.index,
          'language': c.language,
          'description': c.description,
          'text': c.text,
        },
    ],
    'ignored_comments': [
      for (final i in proof.ignored)
        {'index': i.frame.index, 'reason': i.reason},
    ],
    'id3_issues': [
      for (final i in audio.tag.issues) {'code': i.code, 'message': i.message},
    ],
  };
}

final class MatchingEngine {
  const MatchingEngine();

  List<MatchDecision> match(
    List<MatchEpisode> episodes,
    List<AudioCandidate> audios,
  ) {
    final decisions = <MatchDecision>[];
    final refs = <String, int>{};
    for (final a in audios) {
      refs.update(a.reference, (v) => v + 1, ifAbsent: () => 1);
    }
    for (final a in audios) {
      final proof = const CommResolver().resolve(a.tag);
      MatchDecision result(
        MatchStatus status, {
        String? id,
        String? method,
        required String reason,
      }) => MatchDecision(
        audio: a,
        status: status,
        episodeId: id,
        method: method,
        reason: reason,
        proof: proof,
      );
      if (refs[a.reference] != 1) {
        decisions.add(
          result(
            MatchStatus.conflict,
            reason: 'Référence audio répétée dans le scan.',
          ),
        );
        continue;
      }
      if (proof.status == CommResolutionStatus.blocked) {
        decisions.add(result(MatchStatus.blocked, reason: proof.reason));
        continue;
      }
      if (proof.status == CommResolutionStatus.conflict) {
        decisions.add(result(MatchStatus.conflict, reason: proof.reason));
        continue;
      }
      List<MatchEpisode> candidates;
      String method;
      if (proof.originalName != null) {
        method = 'id3_comment';
        candidates = episodes
            .where(
              (e) =>
                  canonicalOriginalName(e.originalName) == proof.originalName,
            )
            .toList();
      } else {
        final name = canonicalOriginalName(a.currentName);
        method = 'original_filename';
        candidates = episodes
            .where(
              (e) =>
                  name != null && canonicalOriginalName(e.originalName) == name,
            )
            .toList();
        if (candidates.isEmpty) {
          method = 'catalog_filename';
          candidates = episodes
              .where(
                (e) => e.systemNames.any(
                  (n) =>
                      unicode.nfc(n).toLowerCase() ==
                      unicode.nfc(a.currentName).toLowerCase(),
                ),
              )
              .toList();
        }
        if (candidates.isEmpty) {
          method = 'normalized_title';
          final title = normalizeTitle(a.currentName, isFile: true);
          candidates = episodes
              .where(
                (e) => title.isNotEmpty && normalizeTitle(e.title) == title,
              )
              .toList();
        }
      }
      if (candidates.isEmpty) {
        decisions.add(
          result(
            MatchStatus.unknown,
            method: method,
            reason: proof.originalName != null
                ? 'Identifiant ID3 inconnu ; aucun repli par titre.'
                : 'Audio inconnu.',
          ),
        );
        continue;
      }
      if (candidates.length != 1) {
        decisions.add(
          result(
            MatchStatus.conflict,
            method: method,
            reason: 'Plusieurs fiches correspondent à cette preuve.',
          ),
        );
        continue;
      }
      final target = candidates.single;
      final provisional =
          method == 'normalized_title' ||
          (method != 'id3_comment' &&
              {'CONFLIT', 'NON_VERIFIEE'}.contains(target.journalStatus));
      decisions.add(
        result(
          provisional ? MatchStatus.provisional : MatchStatus.confirmed,
          id: target.id,
          method: method,
          reason: provisional
              ? 'Association provisoire à valider ; aucun statut ID3 inventé.'
              : 'Correspondance unique selon $method.',
        ),
      );
    }
    final byEpisode = <String, List<int>>{};
    for (var i = 0; i < decisions.length; i++) {
      final d = decisions[i];
      if (d.episodeId != null) (byEpisode[d.episodeId!] ??= []).add(i);
    }
    for (final group in byEpisode.values.where((g) => g.length > 1)) {
      for (final i in group) {
        final d = decisions[i];
        decisions[i] = MatchDecision(
          audio: d.audio,
          status: MatchStatus.conflict,
          episodeId: d.episodeId,
          method: d.method,
          reason: 'Plusieurs MP3 correspondent au même épisode ; aucun choix automatique.',
          proof: d.proof,
        );
      }
    }
    return List.unmodifiable(decisions);
  }

  static String normalizeTitle(String text, {bool isFile = false}) {
    var value = unicode.nfc(text).toLowerCase();
    if (isFile) {
      value = value.replaceFirst(RegExp(r'\.mp3$'), '');
      value = value.replaceFirst(RegExp(r'^\d{4}-\d{2}-\d{2}[ -]+'), '');
    }
    return value
        .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
