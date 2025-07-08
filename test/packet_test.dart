import 'package:flutter_test/flutter_test.dart';
import 'package:maxp2p/packet.dart';

void main() {
  group('Packet', () {
    test('toJSON creates correct map', () {
      final packet = Packet(connectionID: "conn1", packetType: "offer", data: "sdp_data");
      final json = packet.toJSON();
      expect(json["connectionID"], "conn1");
      expect(json["type"], "offer");
      expect(json["data"], "sdp_data");
    });

    test('fromJSON creates correct Packet object', () {
      final map = {"connectionID": "conn2", "type": "answer", "data": "sdp_answer"};
      final packet = Packet.fromJSON(map);
      expect(packet.connectionID, "conn2");
      expect(packet.packetType, "answer");
      expect(packet.data, "sdp_answer");
    });
  });

  group('SignalPacket', () {
    test('toJSON creates correct map', () {
      final packet = Packet(connectionID: "conn3", packetType: "candidate", data: "ice_candidate");
      final signalPacket = SignalPacket(packet: packet, src: "deviceA", dest: "deviceB");
      final json = signalPacket.toJSON();
      expect(json["connectionID"], "conn3");
      expect(json["type"], "candidate");
      expect(json["data"], "ice_candidate");
      expect(json["src"], "deviceA");
      expect(json["dest"], "deviceB");
    });

    test('fromJSON creates correct SignalPacket object', () {
      final map = {
        "connectionID": "conn4",
        "type": "offer",
        "data": "sdp_offer",
        "src": "deviceC",
        "dest": "deviceD"
      };
      final signalPacket = SignalPacket.fromJSON(map);
      expect(signalPacket.packet.connectionID, "conn4");
      expect(signalPacket.packet.packetType, "offer");
      expect(signalPacket.packet.data, "sdp_offer");
      expect(signalPacket.src, "deviceC");
      expect(signalPacket.dest, "deviceD");
    });
  });
}