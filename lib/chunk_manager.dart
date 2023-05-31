import 'dart:typed_data';

import 'package:maxp2p/chunk.dart';
import 'package:mutex/mutex.dart';

class PacketChunks {
  final Mutex mutex;
  final Map<int, Chunk> data;
  int? totalChunks;

  PacketChunks()
      : mutex = Mutex(),
        data = <int, Chunk>{};

  void addChunk(Chunk chunk) {
    data[chunk.seq] = chunk;
    if (chunk.end) {
      totalChunks = chunk.seq + 1;
    }
  }

  int total() {
    if (totalChunks == null) {
      throw 'unknown total number of chunks';
    }
    return totalChunks!;
  }

  bool isComplete() {
    if (totalChunks == null) {
      return false;
    }
    return data.length == totalChunks;
  }
}

class ChunkManager {
  final Mutex mutex;
  final Map<int, PacketChunks> partialPackets;
  Future<void> Function(Uint8List) onPacket;

  ChunkManager({required this.onPacket})
      : mutex = Mutex(),
        partialPackets = <int, PacketChunks>{};

  Future<void> addChunk(Chunk chunk) async {
    final packetChunks = await mutex.protect(() async {
      if (!partialPackets.containsKey(chunk.id)) {
        partialPackets[chunk.id] = PacketChunks();
      }
      final packetChunks = partialPackets[chunk.id]!;
      return packetChunks;
    });

    final isComplete = await packetChunks.mutex.protect(() async {
      packetChunks.addChunk(chunk);
      return packetChunks.isComplete();
    });

    if (isComplete) {
      await mutex.protect(() async {
        partialPackets.remove(chunk.id);
      });
      final byteBuilder = BytesBuilder(copy: false);
      for (var idx = 0; idx < packetChunks.total(); idx++) {
        byteBuilder.add(packetChunks.data[idx]!.data);
      }
      await onPacket(byteBuilder.takeBytes());
    }
  }

  Future<void> onMessage(Uint8List bytes) async {
    final chunk = Chunk.fromBytes(bytes);
    await addChunk(chunk);
  }
}
