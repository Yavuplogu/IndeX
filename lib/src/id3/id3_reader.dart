import 'dart:convert';
import 'dart:typed_data';

import '../diagnostic.dart';
import 'id3_models.dart';

/// ID3v2.3/v2.4 en lecture seule ; jamais de chargement du contenu audio entier.
final class Id3Reader {
  Id3Reader({
    this.maxTagBytes = 16 * 1024 * 1024,
    this.maxCommentBytes = 256 * 1024,
    this.maxFrames = 4096,
  }) {
    if (maxTagBytes < 10 || maxCommentBytes < 4 || maxFrames < 1) {
      throw ArgumentError('Limites ID3 invalides.');
    }
  }
  final int maxTagBytes;
  final int maxCommentBytes;
  final int maxFrames;

  Future<Id3ReadResult> read(TagByteSource source) async {
    try {
      final header = await source.readPrefix(10);
      if (header.length > 10) throw const FormatException('Source non bornée.');
      if (!_hasMagic(header) ||
          header.length < 10 ||
          ![3, 4].contains(header[3])) {
        return parse(header);
      }
      final size = _syncSafe(header, 6);
      final length =
          10 + size + (header[3] == 4 && header[5] & 0x10 != 0 ? 10 : 0);
      if (length > maxTagBytes)
        return _failure('id3_tag_too_large', 'Tag ID3 trop volumineux.');
      final bytes = await source.readPrefix(length);
      if (bytes.length > length)
        throw const FormatException('Source non bornée.');
      // Un fichier modifié entre les deux lectures ne doit pas fournir une preuve.
      if (bytes.length >= 10 && !_equal(header, bytes.sublist(0, 10))) {
        return _failure(
          'id3_source_changed',
          'Le tag a changé pendant sa lecture.',
        );
      }
      return parse(bytes);
    } on _TagProblem catch (e) {
      return _failure(e.code, e.message);
    } on Exception catch (e) {
      return _failure('id3_source_error', 'Lecture ID3 impossible : $e');
    }
  }

  Id3ReadResult parse(List<int> bytes) {
    final comments = <CommFrame>[];
    int? version;
    try {
      if (!_hasMagic(bytes))
        return Id3ReadResult(
          status: Id3Status.absent,
          majorVersion: null,
          comments: [],
          issues: [],
        );
      if (bytes.length < 10)
        throw const _TagProblem('id3_truncated_header', 'En-tête ID3 tronqué.');
      version = bytes[3];
      if (![3, 4].contains(version) || bytes[4] != 0) {
        return Id3ReadResult(
          status: Id3Status.unsupported,
          majorVersion: version,
          comments: [],
          issues: const [
            Diagnostic(
              'id3_unsupported_version',
              'Version/révision ID3 non prise en charge ; preuve inutilisable.',
            ),
          ],
        );
      }
      final flags = bytes[5];
      if (flags & (version == 3 ? 0x1f : 0x0f) != 0) {
        throw const _TagProblem(
          'id3_reserved_tag_flags',
          'Drapeaux de tag ID3 réservés.',
        );
      }
      final size = _syncSafe(bytes, 6);
      final footer = version == 4 && flags & 0x10 != 0;
      final total = 10 + size + (footer ? 10 : 0);
      if (total > maxTagBytes)
        throw const _TagProblem(
          'id3_tag_too_large',
          'Tag ID3 trop volumineux.',
        );
      if (bytes.length < total)
        throw const _TagProblem('id3_truncated_tag', 'Tag ID3 tronqué.');
      if (footer &&
          (!_equal(bytes.sublist(10 + size, 13 + size), [0x33, 0x44, 0x49]) ||
              !_equal(bytes.sublist(13 + size, total), bytes.sublist(3, 10)))) {
        throw const _TagProblem(
          'id3_invalid_footer',
          'Pied de tag ID3v2.4 incohérent.',
        );
      }
      var body = bytes.sublist(10, 10 + size);
      if (version == 3 && flags & 0x80 != 0) body = _deunsync(body);
      var offset = 0;
      if (flags & 0x40 != 0) offset = _extendedHeader(body, version);
      var index = 0;
      while (offset < body.length) {
        if (body[offset] == 0) {
          if (body.sublist(offset).any((b) => b != 0)) {
            throw const _TagProblem(
              'id3_invalid_padding',
              'Données non nulles après le début du padding.',
            );
          }
          break;
        }
        if (body.length - offset < 10)
          throw const _TagProblem(
            'id3_truncated_frame',
            'En-tête de trame ID3 tronqué.',
          );
        if (index >= maxFrames)
          throw const _TagProblem('id3_too_many_frames', 'Trop de trames ID3.');
        final id = String.fromCharCodes(body.sublist(offset, offset + 4));
        if (!RegExp(r'^[A-Z0-9]{4}$').hasMatch(id)) {
          throw const _TagProblem(
            'id3_invalid_frame_id',
            'Identifiant de trame ID3 invalide.',
          );
        }
        final length = version == 4
            ? _syncSafe(body, offset + 4)
            : _u32(body, offset + 4);
        if (length == 0 || length > body.length - offset - 10) {
          throw const _TagProblem(
            'id3_invalid_frame_size',
            'Taille de trame ID3 invalide ou tronquée.',
          );
        }
        final statusFlags = body[offset + 8];
        final formatFlags = body[offset + 9];
        if (statusFlags & (version == 3 ? 0x1f : 0x8f) != 0 ||
            formatFlags & (version == 3 ? 0x1f : 0xb0) != 0) {
          throw const _TagProblem(
            'id3_reserved_frame_flags',
            'Drapeaux de trame réservés.',
          );
        }
        if (id == 'COMM') {
          if (length > maxCommentBytes)
            throw const _TagProblem(
              'id3_comment_too_large',
              'Commentaire ID3 trop volumineux.',
            );
          var payload = body.sublist(offset + 10, offset + 10 + length);
          if (formatFlags & (version == 3 ? 0xc0 : 0x0c) != 0) {
            throw const _TagProblem(
              'id3_unsupported_comment_flags',
              'Commentaire compressé ou chiffré non pris en charge.',
            );
          }
          if (version == 4 && (flags & 0x80 != 0 || formatFlags & 0x02 != 0)) {
            payload = _deunsync(payload);
          }
          if (formatFlags & (version == 3 ? 0x20 : 0x40) != 0) {
            if (payload.isEmpty)
              throw const _TagProblem(
                'id3_invalid_group',
                'Identifiant de groupe absent.',
              );
            payload = payload.sublist(1);
          }
          if (version == 4 && formatFlags & 0x01 != 0) {
            if (payload.length < 4)
              throw const _TagProblem(
                'id3_invalid_dli',
                'Indicateur de longueur tronqué.',
              );
            final declared = _syncSafe(payload, 0);
            payload = payload.sublist(4);
            if (declared != payload.length)
              throw const _TagProblem(
                'id3_invalid_dli',
                'Indicateur de longueur incohérent.',
              );
          }
          comments.add(_comment(payload, index, version));
        }
        offset += 10 + length;
        index++;
      }
      return Id3ReadResult(
        status: Id3Status.readable,
        majorVersion: version,
        comments: comments,
        issues: [],
      );
    } on _TagProblem catch (e) {
      return Id3ReadResult(
        status: Id3Status.invalid,
        majorVersion: version,
        comments: comments,
        issues: [Diagnostic(e.code, e.message)],
      );
    } on FormatException catch (e) {
      return Id3ReadResult(
        status: Id3Status.invalid,
        majorVersion: version,
        comments: comments,
        issues: [
          Diagnostic('id3_invalid_text', 'Texte ID3 invalide : ${e.message}'),
        ],
      );
    }
  }

  static Id3ReadResult _failure(String code, String message) => Id3ReadResult(
    status: Id3Status.invalid,
    majorVersion: null,
    comments: [],
    issues: [Diagnostic(code, message)],
  );

  static int _extendedHeader(List<int> body, int version) {
    if (body.length < 4)
      throw const _TagProblem(
        'id3_invalid_extended_header',
        'En-tête étendu tronqué.',
      );
    final size = version == 3 ? _u32(body, 0) + 4 : _syncSafe(body, 0);
    if (size > body.length || size < (version == 3 ? 10 : 6)) {
      throw const _TagProblem(
        'id3_invalid_extended_header',
        'Taille de l’en-tête étendu invalide.',
      );
    }
    // Ne pas valider silencieusement des CRC/restrictions que nous ne vérifions pas.
    if (version == 3
        ? (size != 10 || body[4] != 0 || body[5] != 0)
        : (size != 6 || body[4] != 1 || body[5] != 0)) {
      throw const _TagProblem(
        'id3_extended_flags_unsupported',
        'CRC/restrictions d’en-tête étendu non pris en charge.',
      );
    }
    return size;
  }

  static CommFrame _comment(List<int> payload, int index, int version) {
    if (payload.length < 5)
      throw const _TagProblem('id3_short_comment', 'Trame COMM trop courte.');
    final encoding = payload[0];
    if (encoding > (version == 3 ? 1 : 3)) {
      throw const _TagProblem(
        'id3_unsupported_encoding',
        'Encodage COMM non autorisé pour cette version ID3.',
      );
    }
    final language = String.fromCharCodes(payload.sublist(1, 4));
    if (!RegExp(r'^[A-Za-z]{3}$').hasMatch(language)) {
      throw const _TagProblem('id3_invalid_language', 'Langue COMM invalide.');
    }
    final content = payload.sublist(4);
    final wide = encoding == 1 || encoding == 2;
    var separator = -1;
    for (var i = 0; i < content.length - (wide ? 1 : 0); i += wide ? 2 : 1) {
      if (content[i] == 0 && (!wide || content[i + 1] == 0)) {
        separator = i;
        break;
      }
    }
    if (separator < 0)
      throw const _TagProblem(
        'id3_missing_terminator',
        'Description COMM sans terminateur.',
      );
    final descriptionBytes = content.sublist(0, separator);
    final textBytes = content.sublist(separator + (wide ? 2 : 1));
    late String description;
    late String text;
    if (wide) {
      final desc = _utf16(
        descriptionBytes,
        encoding == 2 ? Endian.big : null,
        allowEmpty: true,
      );
      description = desc.$1;
      text = _utf16(
        textBytes,
        desc.$2 ?? (encoding == 2 ? Endian.big : null),
        allowEmpty: true,
      ).$1;
    } else {
      description = encoding == 0
          ? latin1.decode(descriptionBytes)
          : utf8.decode(descriptionBytes, allowMalformed: false);
      text = encoding == 0
          ? latin1.decode(textBytes)
          : utf8.decode(textBytes, allowMalformed: false);
    }
    // Le terminateur de texte est facultatif. Les octets originaux restent disponibles.
    if (text.endsWith('\u0000')) text = text.substring(0, text.length - 1);
    return CommFrame(
      index: index,
      language: language,
      description: description,
      text: text,
      encoding: encoding,
      rawPayload: payload,
    );
  }

  static (String, Endian?) _utf16(
    List<int> bytes,
    Endian? fallback, {
    required bool allowEmpty,
  }) {
    if (bytes.isEmpty && allowEmpty) return ('', fallback);
    if (bytes.length.isOdd)
      throw const FormatException('UTF-16 de longueur impaire.');
    var endian = fallback;
    var start = 0;
    if (bytes.length >= 2) {
      if (bytes[0] == 0xff && bytes[1] == 0xfe) {
        endian = Endian.little;
        start = 2;
      }
      if (bytes[0] == 0xfe && bytes[1] == 0xff) {
        endian = Endian.big;
        start = 2;
      }
    }
    if (endian == null) throw const FormatException('BOM UTF-16 absent.');
    final units = <int>[];
    for (var i = start; i < bytes.length; i += 2) {
      units.add(
        endian == Endian.little
            ? bytes[i] | bytes[i + 1] << 8
            : bytes[i] << 8 | bytes[i + 1],
      );
    }
    for (var i = 0; i < units.length; i++) {
      final u = units[i];
      if (u >= 0xd800 && u <= 0xdbff) {
        if (++i >= units.length || units[i] < 0xdc00 || units[i] > 0xdfff) {
          throw const FormatException('Paire de substitution UTF-16 invalide.');
        }
      } else if (u >= 0xdc00 && u <= 0xdfff) {
        throw const FormatException('Substitution UTF-16 isolée.');
      }
    }
    return (String.fromCharCodes(units), endian);
  }

  static bool _hasMagic(List<int> bytes) =>
      bytes.length >= 3 &&
      bytes[0] == 0x49 &&
      bytes[1] == 0x44 &&
      bytes[2] == 0x33;
  static bool _equal(List<int> a, List<int> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => i).every((i) => a[i] == b[i]);
  static int _u32(List<int> b, int p) =>
      b[p] << 24 | b[p + 1] << 16 | b[p + 2] << 8 | b[p + 3];
  static int _syncSafe(List<int> b, int p) {
    if (b.sublist(p, p + 4).any((v) => v & 0x80 != 0))
      throw const _TagProblem(
        'id3_invalid_syncsafe',
        'Entier syncsafe ID3 invalide.',
      );
    return b[p] << 21 | b[p + 1] << 14 | b[p + 2] << 7 | b[p + 3];
  }

  static List<int> _deunsync(List<int> bytes) {
    final output = <int>[];
    for (var i = 0; i < bytes.length; i++) {
      output.add(bytes[i]);
      if (bytes[i] == 0xff && i + 1 < bytes.length && bytes[i + 1] == 0) i++;
    }
    return output;
  }
}

final class _TagProblem implements Exception {
  const _TagProblem(this.code, this.message);
  final String code;
  final String message;
}
