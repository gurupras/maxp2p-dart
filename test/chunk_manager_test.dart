import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxp2p/chunk.dart';
import 'package:maxp2p/chunk_manager.dart';

void main() {
  group('PacketChunks', () {
    test('addChunk and isComplete with known totalChunks', () {
      final packetChunks = PacketChunks();
      packetChunks.totalChunks = 2;
      packetChunks.addChunk(Chunk(id: 0, seq: 0, end: false, data: Uint8List.fromList([1, 2])));
      expect(packetChunks.isComplete(), false);
      packetChunks.addChunk(Chunk(id: 0, seq: 1, end: true, data: Uint8List.fromList([3, 4])));
      expect(packetChunks.isComplete(), true);
      expect(packetChunks.total(), 2);
    });

    test('addChunk and isComplete with unknown totalChunks initially', () {
      final packetChunks = PacketChunks();
      packetChunks.addChunk(Chunk(id: 0, seq: 0, end: false, data: Uint8List.fromList([1, 2])));
      expect(packetChunks.isComplete(), false);
      packetChunks.addChunk(Chunk(id: 0, seq: 1, end: true, data: Uint8List.fromList([3, 4])));
      expect(packetChunks.isComplete(), true);
      expect(packetChunks.total(), 2);
    });

    test('total throws error if totalChunks is null', () {
      final packetChunks = PacketChunks();
      expect(() => packetChunks.total(), throwsA(isA<String>()));
    });
  });

  group('ChunkManager', () {
    test('addChunk reconstructs packet and calls onPacket', () async {
      Uint8List? receivedPacket;
      final chunkManager = ChunkManager(onPacket: (packet) {
        receivedPacket = packet;
        return Future.value();
      });

      final chunk1 = Chunk(id: 1, seq: 0, end: false, data: Uint8List.fromList([1, 2]));
      final chunk2 = Chunk(id: 1, seq: 1, end: false, data: Uint8List.fromList([3, 4]));
      final chunk3 = Chunk(id: 1, seq: 2, end: true, data: Uint8List.fromList([5, 6]));

      await chunkManager.addChunk(chunk1);
      expect(receivedPacket, null);
      await chunkManager.addChunk(chunk2);
      expect(receivedPacket, null);
      await chunkManager.addChunk(chunk3);

      expect(receivedPacket, Uint8List.fromList([1, 2, 3, 4, 5, 6]));
    });

    test('onMessage processes chunk and calls addChunk', () async {
      Uint8List? receivedPacket;
      final chunkManager = ChunkManager(onPacket: (packet) {
        receivedPacket = packet;
        return Future.value();
      });

      final chunkBytes1 = Chunk(id: 2, seq: 0, end: false, data: Uint8List.fromList([10, 11])).serialize();
      final chunkBytes2 = Chunk(id: 2, seq: 1, end: true, data: Uint8List.fromList([12, 13])).serialize();

      await chunkManager.onMessage(chunkBytes1);
      expect(receivedPacket, null);
      await chunkManager.onMessage(chunkBytes2);

      expect(receivedPacket, Uint8List.fromList([10, 11, 12, 13]));
    });

    test('addChunk handles out-of-order chunks', () async {
      Uint8List? receivedPacket;
      final chunkManager = ChunkManager(onPacket: (packet) {
        receivedPacket = packet;
        return Future.value();
      });

      final chunk1 = Chunk(id: 3, seq: 0, end: false, data: Uint8List.fromList([1, 2]));
      final chunk2 = Chunk(id: 3, seq: 1, end: false, data: Uint8List.fromList([3, 4]));
      final chunk3 = Chunk(id: 3, seq: 2, end: true, data: Uint8List.fromList([5, 6]));

      await chunkManager.addChunk(chunk2);
      expect(receivedPacket, null);
      await chunkManager.addChunk(chunk3);
      expect(receivedPacket, null);
      await chunkManager.addChunk(chunk1);

      expect(receivedPacket, Uint8List.fromList([1, 2, 3, 4, 5, 6]));
    });
  });
}