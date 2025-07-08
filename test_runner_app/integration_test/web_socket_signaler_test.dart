import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'package:maxp2p/web_socket_signaler.dart';

const String serverURL = "ws://127.0.0.1:3330/ws";

void main() {
  test('Able to connect to remote server', () async {
    final conn = await WebSocketSignaler.createWebSocketSignaler(
        deviceID: "test", url: serverURL);
  });

  test('Able to create PeerConnection', () async {
    WidgetsFlutterBinding.ensureInitialized();

    final pc1 = await createPeerConnection({'iceServers': []});
  });

  test('Able to set up P2P connections', () async {
    WidgetsFlutterBinding.ensureInitialized();
    if (WebRTC.platformIsDesktop) {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    }
    const d1 = "pc1";
    const d2 = "pc2";
    RTCPeerConnection? pc1, pc2;
    WebSocketSignaler? sig1, sig2;
    pc1 = await createPeerConnection({'iceServers': []});
    pc2 = await createPeerConnection({'iceServers': []});

    sig1 = await WebSocketSignaler.createWebSocketSignaler(
        deviceID: d1, url: serverURL);
    sig2 = await WebSocketSignaler.createWebSocketSignaler(
        deviceID: d2, url: serverURL);

    sig1.onICECandidate =
        (src, connectionID, candidate) => pc1!.addCandidate(candidate);
    sig2.onICECandidate =
        (src, connectionID, candidate) => pc2!.addCandidate(candidate);

    sig1.onSDP = (src, connectionID, sdp) async {
      await pc1!.setRemoteDescription(sdp);
    };
    sig2.onSDP = (src, connectionID, sdp) async {
      await pc2!.setRemoteDescription(sdp);
      if (sdp.type == 'offer') {
        final answer = await pc2.createAnswer();
        await pc2.setLocalDescription(answer);
        sig2!.sendSDP(src, connectionID, answer);
      }
    };

    pc1.onIceCandidate = (candidate) {
      sig1!.sendICECandidate(d2, "1", candidate);
    };
    pc2.onIceCandidate = (candidate) {
      sig2!.sendICECandidate(d1, "1", candidate);
    };

    final dc1 = await pc1.createDataChannel("dc", RTCDataChannelInit()..id = 1);

    final offer = await pc1.createOffer({});
    pc1.setLocalDescription(offer);
    sig1.sendSDP(d2, "1", offer);

    final c1 = Completer();
    pc1.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        c1.complete();
      }
    };

    final c2 = Completer();
    pc2.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        c2.complete();
      }
    };

    await Future.wait(<Future>{c1.future, c2.future});
  });
}