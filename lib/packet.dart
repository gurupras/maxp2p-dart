

class Packet {
  final String connectionID;
  final String packetType;
  final String data;

  Packet(
      {required this.connectionID,
      required this.packetType,
      required this.data});

  Map<String, dynamic> toJSON() {
    final map = <String, dynamic>{
      "connectionID": connectionID,
      "type": packetType,
      "data": data
    };
    return map;
  }

  static Packet fromJSON(Map<String, dynamic> map) {
    final connectionID = map["connectionID"] as String;
    final packetType = map["type"] as String;
    final data = map["data"] as String;
    return Packet(
        connectionID: connectionID, packetType: packetType, data: data);
  }
}

class SignalPacket {
  final Packet packet;
  final String src;
  final String dest;

  SignalPacket({required this.packet, required this.src, required this.dest});

  Map<String, dynamic> toJSON() {
    final map = packet.toJSON();
    map['src'] = src;
    map['dest'] = dest;
    return map;
  }

  static SignalPacket fromJSON(Map<String, dynamic> map) {
    final packet = Packet.fromJSON(map);
    final src = map["src"] as String;
    final dest = map["dest"] as String;
    return SignalPacket(packet: packet, src: src, dest: dest);
  }
}
