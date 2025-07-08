import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxp2p/packer.dart';

void main() {
  group('Packer', () {
    test('packNull', () {
      final p = Packer();
      p.packNull();
      expect(p.takeBytes(), Uint8List.fromList([0xc0]));
    });

    test('packBool true', () {
      final p = Packer();
      p.packBool(true);
      expect(p.takeBytes(), Uint8List.fromList([0xc3]));
    });

    test('packBool false', () {
      final p = Packer();
      p.packBool(false);
      expect(p.takeBytes(), Uint8List.fromList([0xc2]));
    });

    test('packBool null', () {
      final p = Packer();
      p.packBool(null);
      expect(p.takeBytes(), Uint8List.fromList([0xc0]));
    });

    test('packDouble', () {
      final p = Packer();
      p.packDouble(123.45);
      expect(p.takeBytes(), Uint8List.fromList([0xcb, 64, 94, 220, 204, 204, 204, 204, 205]));
    });

    test('packDouble null', () {
      final p = Packer();
      p.packDouble(null);
      expect(p.takeBytes(), Uint8List.fromList([0xc0]));
    });

    test('packString short', () {
      final p = Packer();
      p.packString("hello");
      expect(p.takeBytes(), Uint8List.fromList([0xa5, 104, 101, 108, 108, 111]));
    });

    test('packString long', () {
      final p = Packer();
      final longString = "a" * 40;
      p.packString(longString);
      expect(p.takeBytes(), Uint8List.fromList([0xd9, 40, ...utf8.encode(longString)]));
    });

    test('packString null', () {
      final p = Packer();
      p.packString(null);
      expect(p.takeBytes(), Uint8List.fromList([0xc0]));
    });

    test('packStringEmptyIsNull empty', () {
      final p = Packer();
      p.packStringEmptyIsNull("");
      expect(p.takeBytes(), Uint8List.fromList([0xc0]));
    });

    test('packStringEmptyIsNull non-empty', () {
      final p = Packer();
      p.packStringEmptyIsNull("test");
      expect(p.takeBytes(), Uint8List.fromList([0xa4, 116, 101, 115, 116]));
    });

    test('packBinary', () {
      final p = Packer();
      p.packBinary(Uint8List.fromList([1, 2, 3]));
      expect(p.takeBytes(), Uint8List.fromList([0xc4, 3, 1, 2, 3]));
    });

    test('packBinary null', () {
      final p = Packer();
      p.packBinary(null);
      expect(p.takeBytes(), Uint8List.fromList([0xc0]));
    });

    test('packListLength', () {
      final p = Packer();
      p.packListLength(2);
      expect(p.takeBytes(), Uint8List.fromList([0x92]));
    });

    test('packListLength null', () {
      final p = Packer();
      p.packListLength(null);
      expect(p.takeBytes(), Uint8List.fromList([0xc0]));
    });

    test('packMapLength', () {
      final p = Packer();
      p.packMapLength(1);
      expect(p.takeBytes(), Uint8List.fromList([0x81]));
    });

    test('packMapLength null', () {
      final p = Packer();
      p.packMapLength(null);
      expect(p.takeBytes(), Uint8List.fromList([0xc0]));
    });

    test('packInt 1 byte', () {
      final p = Packer();
      p.packInt(10, 1);
      expect(p.takeBytes(), Uint8List.fromList([0xcc, 10]));
    });

    test('packInt 2 bytes', () {
      final p = Packer();
      p.packInt(256, 2);
      expect(p.takeBytes(), Uint8List.fromList([0xcd, 1, 0]));
    });

    test('packInt 4 bytes', () {
      final p = Packer();
      p.packInt(65536, 4);
      expect(p.takeBytes(), Uint8List.fromList([0xce, 0, 1, 0, 0]));
    });

    test('packInt 8 bytes', () {
      final p = Packer();
      p.packInt(4294967296, 8);
      expect(p.takeBytes(), Uint8List.fromList([0xcf, 0, 0, 0, 1, 0, 0, 0, 0]));
    });

    test('packInt null', () {
      final p = Packer();
      p.packInt(null, 1);
      expect(p.takeBytes(), Uint8List.fromList([0xcc]));
    });

    test('packInt signed', () {
      final p = Packer();
      p.packInt(-10, 1, true);
      expect(p.takeBytes(), Uint8List.fromList([0xd0, 246]));
    });

    test('packInt signed 2 bytes', () {
      final p = Packer();
      p.packInt(-256, 2, true);
      expect(p.takeBytes(), Uint8List.fromList([0xd1, 255, 0]));
    });

    test('packInt signed 4 bytes', () {
      final p = Packer();
      p.packInt(-65536, 4, true);
      expect(p.takeBytes(), Uint8List.fromList([0xd2, 255, 255, 0, 0]));
    });

    test('packInt signed 8 bytes', () {
      final p = Packer();
      p.packInt(-4294967296, 8, true);
      expect(p.takeBytes(), Uint8List.fromList([0xd3, 255, 255, 255, 255, 0, 0, 0, 0]));
    });

    test('pack multiple items', () {
      final p = Packer();
      p.packString("key1");
      p.packInt(123, 1);
      p.packString("key2");
      p.packBool(true);
      expect(p.takeBytes(), Uint8List.fromList([0xa4, 107, 101, 121, 49, 0xcc, 123, 0xa4, 107, 101, 121, 50, 0xc3]));
    });

    test('buffer grows', () {
      final p = Packer(10); // Small initial buffer
      p.packString("a" * 100); // Force buffer to grow
      expect(p.takeBytes().length, greaterThan(10));
    });
  });
}