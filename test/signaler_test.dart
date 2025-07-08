import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:maxp2p/signaler.dart';

class MockSignaler extends Signaler {
  @override
  void sendICECandidate(
      String dest, String connectionID, RTCIceCandidate candidate) {
    onICECandidate?.call(dest, connectionID, candidate);
  }

  @override
  void sendSDP(String dest, String connectionID, RTCSessionDescription sdp) {
    onSDP?.call(dest, connectionID, sdp);
  }
}

void main() {
  group('Signaler', () {
    test('onICECandidate callback is invoked', () {
      final signaler = MockSignaler();
      RTCIceCandidate? receivedCandidate;
      String? receivedSrc;
      String? receivedConnectionID;

      signaler.onICECandidate = (src, connectionID, candidate) {
        receivedSrc = src;
        receivedConnectionID = connectionID;
        receivedCandidate = candidate;
      };

      final candidate = RTCIceCandidate("candidate", "sdpMid", 0);
      signaler.sendICECandidate("dest1", "conn1", candidate);

      expect(receivedSrc, "dest1");
      expect(receivedConnectionID, "conn1");
      expect(receivedCandidate, candidate);
    });

    test('onSDP callback is invoked', () {
      final signaler = MockSignaler();
      RTCSessionDescription? receivedSdp;
      String? receivedSrc;
      String? receivedConnectionID;

      signaler.onSDP = (src, connectionID, sdp) {
        receivedSrc = src;
        receivedConnectionID = connectionID;
        receivedSdp = sdp;
      };

      final sdp = RTCSessionDescription("sdp_data", "offer");
      signaler.sendSDP("dest2", "conn2", sdp);

      expect(receivedSrc, "dest2");
      expect(receivedConnectionID, "conn2");
      expect(receivedSdp, sdp);
    });
  });
}