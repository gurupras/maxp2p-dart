import 'dart:typed_data';

import 'package:maxp2p/packer.dart';

abstract class Serialize {
  Uint8List serialize();
  void serializeWithPacker(final Packer p);
}
