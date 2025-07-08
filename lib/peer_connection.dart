import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:maxp2p/chunk.dart';
import 'package:maxp2p/serialize.dart';
import 'package:mutex/mutex.dart';

import 'package:maxp2p/typedefs.dart';

const maxChunkSize = 16384 - (80); // Approximate size of metadata of Chunk

class PeerConnection {
  final RTCPeerConnection pc;
  final Mutex mutex;
  final int maxBufferedAmount;
  RTCDataChannel? dc;
  Callback<void>? onClose;
  Completer<void>?
      completer; // TODO: Ideally this should be a map<dc, completer>

  PeerConnection({required this.pc, this.maxBufferedAmount = 1 * 1024 * 1024})
      : mutex = Mutex();

  Future<int> send(Serialize s) async {
    final bytes = s.serialize();
    final numChunks = (bytes.length / maxChunkSize).ceil();
    int written = 0;
    for (var chunkIdx = 0; chunkIdx < numChunks; chunkIdx++) {
      final remaining = bytes.length - written;
      final chunkSize = min(remaining, maxChunkSize);

      final chunk = Chunk.create(
          seq: chunkIdx,
          end: chunkIdx == numChunks - 1,
          data: bytes.sublist(written, written + chunkSize));
      final chunkBytes = chunk.serialize();

      await mutex.protect(() async {
        await dc!.send(RTCDataChannelMessage.fromBinary(chunkBytes));
        final bufferedAmount = dc!.bufferedAmount!;
        // print(
        //     'Sent ${chunkBytes.length} bytes. buffered=$bufferedAmount max=$maxBufferedAmount');
        if (bufferedAmount > maxBufferedAmount) {
          completer = Completer();
          // print('DC flow-control triggered');
          await completer!.future;
          // print('DC available again');
          completer = null;
        }
      });
      written += chunkSize;
    }
    return written;
  }

  void addDC(RTCDataChannel dc, MessageCallback onMessage) {
    this.dc = dc;
    dc.bufferedAmountLowThreshold = 1 * 1024 * 1024 ~/ 2;

    dc.onBufferedAmountLow = (currentAmount) {
      if (completer != null) {
        completer!.complete();
      }
    };

    dc.onMessage = (rawMessage) {
      final bytes = rawMessage.binary;
      onMessage(bytes);
    };
  }

  Future<void> close() async {
    if (dc != null) {
      await dc!.close();
    }
    await pc.close();
    if (onClose != null) {
      await onClose!();
    }
  }
}