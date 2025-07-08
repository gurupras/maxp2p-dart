import 'dart:async';
import 'dart:typed_data';

import 'package:maxp2p/blocking_queue.dart';
import 'package:maxp2p/peer_connection.dart';
import 'package:maxp2p/serialize.dart';
import 'package:maxp2p/typedefs.dart';
import 'package:maxp2p/websocket_based_p2p.dart';
import 'package:mutex/mutex.dart';

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

  Future<int> send(final Serialize s) async {
    final conn = await _readyConnections!.get();
    final ret = await conn.send(s);
    await _readyConnections!.put(conn);
    // final conn = connectionsMap.values.first.values.first;
    // final ret = await conn.send(s);
    return ret;
  }

  Future<void> close() async {
    await Future.wait(super.connectionsMap[peer]!.values.map((e) => e.close()));
  }
}
