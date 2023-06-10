import 'dart:async';
import 'dart:collection';

import 'package:mutex/mutex.dart';

class BlockingQueue<T> {
  final Mutex _mutex;
  final Queue<T> _queue;
  final Queue<Function> _notifyList;

  BlockingQueue()
      : _mutex = Mutex(),
        _queue = Queue<T>(),
        _notifyList = Queue();

  Future<void> put(T element) async {
    Function? cb;
    await _mutex.protect(() async {
      _queue.addLast(element);
      if (_notifyList.isNotEmpty) {
        cb = _notifyList.removeFirst();
      }
    });
    if (cb != null) {
      cb!();
    }
  }

  Future<T> get() async {
    while (true) {
      await _mutex.acquire();
      if (_queue.isEmpty) {
        final c = Completer<void>();
        _notifyList.add(c.complete);
        _mutex.release();
        await c.future;
        continue;
      }
      final result = _queue.removeFirst();
      _mutex.release();
      return result;
    }
  }
}
