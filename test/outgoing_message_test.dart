import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxp2p/outgoing_message.dart';

void main() {
  group('OutgoingMessage', () {
    test('OutgoingMessage can be created with bytes and a callback', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      Future<void> callback(String error) async {}

      final message = OutgoingMessage(bytes, callback);

      expect(message.bytes, equals(bytes));
      expect(message.callback, equals(callback));
    });

    
  });
}
