import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:maxp2p/chunk_manager.dart';
import 'package:maxp2p/peer_connection.dart';
import 'package:maxp2p/signaler.dart';
import 'package:maxp2p/typedefs.dart';
import 'package:maxp2p/web_socket_signaler.dart';
import 'package:mutex/mutex.dart';

class WebSocketBasedP2P {
  final String deviceID;
  final Signaler signaler;
  final Mutex mutex;
  late Map<String, Map<String, PeerConnection>> connectionsMap;
  final ChunkManager chunkManager;
  MessageCallback onMessage;

  WebSocketBasedP2P(
      {required this.deviceID,
      required this.signaler,
      required this.onMessage})
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
