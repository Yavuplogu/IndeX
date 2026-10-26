import 'package:unorm_dart/unorm_dart.dart' as unicode;

// provisional is historical; blocked now denotes an incomplete filesystem scan.
enum MatchStatus { confirmed, provisional, conflict, unknown, blocked }

final class MatchEpisode {
  MatchEpisode({
    required this.id,
    required this.originalName,
    required this.title,
    List<String> systemNames = const [],
    this.journalStatus,
  }) : systemNames = List.unmodifiable(systemNames);
  final String id, originalName, title;
  final List<String> systemNames;
  // Historical journal metadata, never used to decide a filename association.
  final String? journalStatus;
}

final class AudioCandidate {
  const AudioCandidate({required this.reference, required this.currentName});

  /// Chemin/URI opaque local, jamais une identité d'épisode.
  final String reference;
  final String currentName;
}

final class MatchDecision {
  const MatchDecision({
    required this.audio,
    required this.status,
    required this.episodeId,
    required this.method,
    required this.reason,
  });
  final AudioCandidate audio;
  final MatchStatus status;
  final String? episodeId, method;
  final String reason;
  Map<String, Object?> toJson() => {
    'audio_reference': audio.reference,
    'current_name': audio.currentName,
    'episode_id': episodeId,
    'status': status.name,
    'matching_method': method,
    'reason': reason,
    'local_verification_status': 'NON_VERIFIEE',
    'evidence_rule': method == 'manual' ? 'manual' : 'journal_filename_v1',
    'filename_comparison': 'unicode_nfc_case_insensitive_exact',
    'audio_content_verified': false,
  };
}

/// Journal names only: original filename, then current system filename.
/// NFC/case normalization never removes accents, punctuation or spaces.
final class MatchingEngine {
  const MatchingEngine();
  static String filenameKey(String value) => unicode.nfc(value).toLowerCase();

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
      final name = filenameKey(a.currentName);
      var method = 'original_filename';
      var candidates = episodes
          .where((e) => filenameKey(e.originalName) == name)
          .toList();
      // Ambiguity at the first level is terminal, never resolved by a fallback.
      if (candidates.isEmpty) {
        method = 'catalog_filename';
        candidates = episodes
            .where((e) => e.systemNames.any((n) => filenameKey(n) == name))
            .toList();
      }
      if (candidates.isEmpty) {
        decisions.add(
          result(
            MatchStatus.unknown,
            reason: 'Aucun nom d’origine ni nom système exact dans le journal.',
          ),
        );
      } else if (candidates.length != 1) {
        decisions.add(
          result(
            MatchStatus.conflict,
            method: method,
            reason: 'Nom ambigu dans le journal : plusieurs épisodes correspondent.',
          ),
        );
      } else {
        decisions.add(
          result(
            MatchStatus.confirmed,
            id: candidates.single.id,
            method: method,
            reason: method == 'original_filename'
                ? 'Associé par nom exact et unique : FICHIER MP3 D’ORIGINE. Contenu audio non vérifié.'
                : 'Associé par nom exact et unique : TITRE SYSTEME. Contenu audio non vérifié.',
          ),
        );
      }
    }
    final byEpisode = <String, List<int>>{};
    for (final (i, d) in decisions.indexed) {
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
        );
      }
    }
    return List.unmodifiable(decisions);
  }
}
