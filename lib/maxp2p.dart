library maxp2p;

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:maxp2p/blocking_queue.dart';
import 'package:maxp2p/chunk.dart';
import 'package:maxp2p/chunk_manager.dart';
import 'package:maxp2p/serialize.dart';
import 'package:maxp2p/web_socket_signaler.dart';
import 'package:mutex/mutex.dart';

typedef MessageCallback = Future<void> Function(Uint8List bytes);
typedef Callback<T> = FutureOr<T> Function();

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

class WebSocketBasedP2P {
  final String deviceID;
  final WebSocketSignaler signaler;
  final Mutex mutex;
  late Map<String, Map<String, PeerConnection>> connectionsMap;
  final ChunkManager chunkManager;
  MessageCallback onMessage;

  WebSocketBasedP2P(
      {required this.deviceID, required this.signaler, required this.onMessage})
      : mutex = Mutex(),
        chunkManager = ChunkManager(onPacket: onMessage) {
    connectionsMap = <String, Map<String, PeerConnection>>{};

    signaler.onICECandidate = (src, connectionID, candidate) {
      final conn = getPC(src, connectionID);
      conn.pc.addCandidate(candidate);
    };

    signaler.onSDP = (src, connectionID, sdp) async {
      if (sdp.type == "offer") {
        final pc = await createPeerConnection({'iceServers': []});
        final conn = PeerConnection(pc: pc);
        pc.onDataChannel = (channel) {
          conn.addDC(channel, chunkManager.onMessage);
        };
        addPC(src, connectionID, conn);
        pc.setRemoteDescription(sdp);
        final answer = await pc.createAnswer();
        pc.setLocalDescription(answer);
        signaler.sendSDP(src, connectionID, answer);
      } else {
        final conn = getPC(src, connectionID);
        conn.pc.setRemoteDescription(sdp);
      }
    };

    signaler.onICECandidate = (src, connectionID, candidate) {
      final conn = getPC(src, connectionID);
      conn.pc.addCandidate(candidate);
    };
  }

  PeerConnection getPC(String peer, String connectionID) {
    if (!this.connectionsMap.containsKey(peer)) {
      throw 'No connection from peer $peer';
    }
    final connections = this.connectionsMap[peer]!;
    if (!connections.containsKey(connectionID)) {
      throw 'No connection with id $connectionID';
    }
    final pc = connections[connectionID]!;
    return pc;
  }

  void addPC(String peer, String connectionID, PeerConnection conn) {
    conn.pc.onIceCandidate = (candidate) {
      signaler.sendICECandidate(peer, connectionID, candidate);
    };

    if (!connectionsMap.containsKey(peer)) {
      connectionsMap[peer] = <String, PeerConnection>{};
    }
    final peerConnections = connectionsMap[peer]!;
    peerConnections[connectionID] = conn;
  }

  static Future<WebSocketBasedP2P> createWebSocketBasedP2P(
      {required String deviceID,
      required String signalServerURL,
      required onMessage}) async {
    final signaler = await WebSocketSignaler.createWebSocketSignaler(
        deviceID: deviceID, url: signalServerURL);
    return WebSocketBasedP2P(
        deviceID: deviceID, signaler: signaler, onMessage: onMessage);
  }

  Future<PeerConnection> connect(String peer, String connectionID) async {
    final pc = await createPeerConnection({'iceServers': []});

    final dcProps = RTCDataChannelInit()..binaryType = 'binary';

    final dc = await pc.createDataChannel("dc", dcProps);
    final conn = PeerConnection(pc: pc);
    conn.onClose = () {
      connectionsMap[peer]!.remove(connectionID);
      if (connectionsMap[peer]!.length == 0) {
        connectionsMap.remove(peer);
      }
    };
    conn.addDC(dc, chunkManager.onMessage);
    addPC(peer, connectionID, conn);
    final offer = await pc.createOffer({});
    pc.setLocalDescription(offer);
    signaler.sendSDP(peer, connectionID, offer);
    final c = Completer<PeerConnection>();
    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        c.complete(conn);
      }
    };
    return c.future;
  }
}

class OutgoingMessage {
  final Uint8List bytes;
  final Future<void> Function(String error) callback;

  OutgoingMessage(this.bytes, this.callback);
}

class MaxP2P extends WebSocketBasedP2P {
  final String peer;
  final Mutex mutex;
  BlockingQueue<PeerConnection>? _readyConnections;

  MaxP2P(
      {required super.deviceID,
      required this.peer,
      required super.signaler,
      required super.onMessage})
      : mutex = Mutex();

  Future<void> Start(int numConnections) async {
    _readyConnections = await BlockingQueue<PeerConnection>();
    final promises = <Future<PeerConnection>>[];
    for (var idx = 0; idx < numConnections; idx++) {
      promises.add(super
          .connect(peer, idx.toString().padLeft(4, '0'))
          .then((connection) {
        _readyConnections!.put(connection);
        return connection;
      }));
    }
    await Future.wait(promises);
  }

  Future<void> send(final Serialize s) async {
    final conn = await mutex.protect(() async {
      return _readyConnections!.get();
    });
    await conn.send(s);
    await mutex.protect(() async {
      return _readyConnections!.put(conn);
    });
    // final conn = connectionsMap.values.first.values.first;
    // await conn.send(s);
  }

  Future<void> close() async {
    await Future.wait(super.connectionsMap[peer]!.values.map((e) => e.close()));
  }
}
