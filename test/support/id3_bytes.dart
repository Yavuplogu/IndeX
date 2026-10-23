import 'dart:convert';
import 'dart:typed_data';

import 'package:index_core/index_core.dart';

List<int> syncSafe(int n) => [
  n >> 21 & 127,
  n >> 14 & 127,
  n >> 7 & 127,
  n & 127,
];
List<int> u32(int n) => [n >> 24 & 255, n >> 16 & 255, n >> 8 & 255, n & 255];

List<int> textBytes(
  String text,
  int encoding, {
  bool little = true,
  bool bom = true,
}) {
  if (encoding == 0) return latin1.encode(text);
  if (encoding == 3) return utf8.encode(text);
  final isLittle = encoding == 1 && little;
  return [
    if (encoding == 1 && bom) ...[
      if (isLittle) ...[255, 254] else ...[254, 255],
    ],
    for (final c in text.codeUnits) ...[
      if (isLittle) ...[c & 255, c >> 8] else ...[c >> 8, c & 255],
    ],
  ];
}

List<int> comment(
  String text, {
  String description = '',
  String language = 'eng',
  int encoding = 0,
  bool little = true,
}) => [
  encoding,
  ...ascii.encode(language),
  ...textBytes(description, encoding, little: little),
  ...[
    if (encoding == 1 || encoding == 2) ...[0, 0] else 0,
  ],
  ...textBytes(text, encoding, little: little),
];

List<int> frame(
  String id,
  List<int> payload, {
  int version = 3,
  int flags = 0,
}) => [
  ...ascii.encode(id),
  ...versionSize(payload.length, version),
  0,
  flags,
  ...payload,
];
List<int> versionSize(int n, int version) =>
    version == 4 ? syncSafe(n) : u32(n);

List<int> tag(
  List<List<int>> frames, {
  int version = 3,
  int flags = 0,
  List<int> extended = const [],
  int padding = 0,
}) {
  final data = [
    ...extended,
    ...frames.expand((f) => f),
    ...List.filled(padding, 0),
  ];
  final header = [73, 68, 51, version, 0, flags, ...syncSafe(data.length)];
  return [
    ...header,
    ...data,
    if (version == 4 && flags & 16 != 0) ...[51, 68, 73, ...header.sublist(3)],
  ];
}

List<int> unsync(List<int> bytes) => [
  for (var i = 0; i < bytes.length; i++) ...[
    bytes[i],
    if (bytes[i] == 255 &&
        (i + 1 == bytes.length || bytes[i + 1] == 0 || bytes[i + 1] >= 224))
      0,
  ],
];

final class MemorySource implements TagByteSource {
  MemorySource(this.bytes);
  final List<int> bytes;
  final requests = <int>[];
  @override
  Future<Uint8List> readPrefix(int count) async {
    requests.add(count);
    return Uint8List.fromList(bytes.take(count).toList());
  }
}
