import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxp2p/chunk.dart';

void main() {
  group('Chunk', () {
    test('create method increments id and creates chunk', () {
      final initialIdx = Chunk.idx;
      final chunk = Chunk.create(seq: 0, end: true, data: Uint8List.fromList([1, 2, 3]));
      expect(chunk.id, initialIdx);
      expect(Chunk.idx, initialIdx + 1);
      expect(chunk.seq, 0);
      expect(chunk.end, true);
      expect(chunk.data, Uint8List.fromList([1, 2, 3]));
    });

    test('serialize and fromBytes roundtrip', () {
      final originalChunk = Chunk.create(seq: 5, end: false, data: Uint8List.fromList([10, 20, 30]));
      final serializedBytes = originalChunk.serialize();
      final deserializedChunk = Chunk.fromBytes(serializedBytes);

      expect(deserializedChunk.id, originalChunk.id);
      expect(deserializedChunk.seq, originalChunk.seq);
      expect(deserializedChunk.end, originalChunk.end);
      expect(deserializedChunk.data, originalChunk.data);
    });

    test('fromBytes with different data types', () {
      final originalChunk = Chunk.create(seq: 200, end: true, data: Uint8List.fromList([255, 0, 128]));
      final serializedBytes = originalChunk.serialize();
      final deserializedChunk = Chunk.fromBytes(serializedBytes);

      expect(deserializedChunk.id, originalChunk.id);
      expect(deserializedChunk.seq, originalChunk.seq);
      expect(deserializedChunk.end, originalChunk.end);
      expect(deserializedChunk.data, originalChunk.data);
    });
  });
}