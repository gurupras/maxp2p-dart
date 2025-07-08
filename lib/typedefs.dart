import 'dart:async';
import 'dart:typed_data';

typedef MessageCallback = Future<void> Function(Uint8List bytes);
typedef Callback<T> = FutureOr<T> Function();
