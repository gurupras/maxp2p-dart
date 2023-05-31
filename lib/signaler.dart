import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef RTCDescriptionCallback = void Function(
    String src, String connectionID, RTCSessionDescription sdp);
typedef RTCICECandidateCallback = void Function(
    String src, String connectionID, RTCIceCandidate candidate);

abstract class Signaler {
  void sendICECandidate(
      String dest, String connectionID, RTCIceCandidate candidate);
  void sendSDP(String dest, String connectionID, RTCSessionDescription sdp);

  RTCDescriptionCallback? onSDP;
  RTCICECandidateCallback? onICECandidate;
}

const String candidatePacketType = "candidate";
const String sdpPacketType = "sdp";
