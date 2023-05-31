import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:maxp2p/packet.dart';
import 'package:maxp2p/signaler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketSignaler implements Signaler {
  final String deviceID;
  final WebSocketChannel channel;
  @override
  RTCDescriptionCallback? onSDP;
  @override
  RTCICECandidateCallback? onICECandidate;

  WebSocketSignaler({required this.deviceID, required this.channel});

  Future<void> start() async {
    final c = Completer<void>();
    channel.stream.listen((message) {
      final json = jsonDecode(message) as Map<String, dynamic>;
      if (json.containsKey('action')) {
        final action = json['action'] as String;
        switch (action) {
          case "ready":
            c.complete();
            break;
          default:
            throw 'Unexpected message. Did not receive ready signal';
        }
      } else {
        onMessage(json);
      }
    });

    return c.future;
  }

  void onMessage(dynamic json) {
    final src = json['src'] as String;
    final pkt = Packet.fromJSON(json);
    final connID = pkt.connectionID;
    switch (pkt.packetType) {
      case candidatePacketType:
        {
          final candidateInitStr = pkt.data;
          final candidateInitJSON =
              jsonDecode(candidateInitStr) as Map<String, dynamic>;
          final candidate = candidateInitJSON["candidate"] as String;
          String? sdpMid;
          int? sdpMLineIndex;
          if (candidateInitJSON.containsKey("sdpMid")) {
            sdpMid = candidateInitJSON["sdpMid"] as String;
          }
          if (candidateInitJSON.containsKey("sdpMLineIndex")) {
            sdpMLineIndex = candidateInitJSON["sdpMLineIndex"] as int;
          }
          RTCIceCandidate iceCandidate =
              RTCIceCandidate(candidate, sdpMid, sdpMLineIndex);
          onICECandidate!(src, connID, iceCandidate);
          break;
        }
      case sdpPacketType:
        {
          final sdpJSONStr = pkt.data;
          final sdpJSON = jsonDecode(sdpJSONStr);
          final sdpStr = sdpJSON["sdp"] as String;
          final type = sdpJSON["type"] as String;
          final sdp = RTCSessionDescription(sdpStr, type);
          onSDP!(src, connID, sdp);
          break;
        }
    }
  }

  @override
  void sendSDP(String peer, String connectionID, RTCSessionDescription sdp) {
    final map = <String, dynamic>{"sdp": sdp.sdp, "type": sdp.type};
    final sdpStr = jsonEncode(map);
    final pkt = SignalPacket(
        packet: Packet(
            connectionID: connectionID,
            packetType: sdpPacketType,
            data: sdpStr),
        src: deviceID,
        dest: peer);
    channel.sink.add(jsonEncode(pkt.toJSON()));
  }

  @override
  void sendICECandidate(
      String peer, String connectionID, RTCIceCandidate candidate) {
    final map = <String, dynamic>{
      "candidate": candidate.candidate,
      "sdpMid": candidate.sdpMid,
      "sdpMLineIndex": candidate.sdpMLineIndex
    };
    final candidateStr = jsonEncode(map);
    final pkt = SignalPacket(
        packet: Packet(
            connectionID: connectionID,
            packetType: candidatePacketType,
            data: candidateStr),
        src: deviceID,
        dest: peer);
    channel.sink.add(jsonEncode(pkt.toJSON()));
  }

  static Future<WebSocketSignaler> createWebSocketSignaler(
      {required String deviceID, required String url}) async {
    String finalURL = url;
    final uri = Uri.parse(url);
    if (uri.query != "") {
      // Already has some query parameters
      finalURL = '$finalURL&deviceID=$deviceID';
    } else {
      finalURL = '$finalURL?deviceID=$deviceID';
    }
    final channel = WebSocketChannel.connect(Uri.parse(finalURL));
    final ret = WebSocketSignaler(deviceID: deviceID, channel: channel);
    await ret.start();
    return ret;
  }
}
