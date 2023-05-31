import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxp2p/chunk.dart';

void main() {
  group('Packer', () {
    test('Chunk', () async {
      final input = utf8.encode("Hello World");
      final chunk =
          Chunk(id: 0, seq: 0, end: true, data: Uint8List.fromList(input));

      final bytes = chunk.serialize();
      expect(bytes, chunkExpected);
    });
  });
}

final chunkExpected = <int>[
  132,
  162,
  105,
  100,
  207,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  163,
  115,
  101,
  113,
  207,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  163,
  101,
  110,
  100,
  195,
  164,
  100,
  97,
  116,
  97,
  196,
  11,
  72,
  101,
  108,
  108,
  111,
  32,
  87,
  111,
  114,
  108,
  100
];
