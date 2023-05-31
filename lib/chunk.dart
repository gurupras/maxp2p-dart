import 'dart:typed_data';

import 'package:maxp2p/packer.dart' as maxp2p;
import 'package:maxp2p/serialize.dart';
import 'package:messagepack/messagepack.dart';

class Chunk implements Serialize {
  static int idx = 0;

  final int id, seq;
  final bool end;
  final Uint8List data;

  Chunk(
      {required this.id,
      required this.seq,
      required this.end,
      required this.data});

  static Chunk create(
      {required int seq, required bool end, required Uint8List data}) {
    return Chunk(id: idx++, seq: seq, end: end, data: data);
  }

  static Chunk fromBytes(Uint8List bytes) {
    final unpacker = Unpacker(bytes);
    final map = unpacker.unpackMap();
    final id = map['id'] as int;
    final seq = map['seq'] as int;
    final end = map['end'] as bool;
    final data = map['data'] as List<int>;
    return Chunk(id: id, seq: seq, end: end, data: Uint8List.fromList(data));
  }

  @override
  Uint8List serialize() {
    final p = maxp2p.Packer();
    serializeWithPacker(p);
    return p.takeBytes();
  }

  @override
  void serializeWithPacker(final maxp2p.Packer p) {
    p.packMapLength(4);
    p.packString("id");
    p.packInt(id, 8);
    p.packString("seq");
    p.packInt(seq, 8);

    p.packString("end");
    p.packBool(end);
    p.packString("data");
    p.packBinary(data);
  }
}
