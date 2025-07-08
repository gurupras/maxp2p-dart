import 'dart:async';
import 'dart:typed_data';

class OutgoingMessage {
  final Uint8List bytes;
  final Future<void> Function(String error) callback;

  OutgoingMessage(this.bytes, this.callback);
}
