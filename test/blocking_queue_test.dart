import 'package:flutter_test/flutter_test.dart';
import 'package:maxp2p/blocking_queue.dart';

void main() {
  group('BlockingQueue', () {
    BlockingQueue<int>? queue;
    setUp(() async {
      queue = BlockingQueue<int>();
    });
    test('Can add multiple before removing', () async {
      for (int idx = 0; idx < 20; idx++) {
        queue!.put(4);
      }
      expect(await queue!.get(), 4);
    });

    test('Can remove multiple', () async {
      queue!.put(4);
      queue!.put(5);
      expect(await queue!.get(), 4);
      expect(await queue!.get(), 5);
    });

    test('Can get multiple in parallel', () async {
      for (int idx = 0; idx < 20; idx++) {
        queue!.put(idx);
      }
      final promises = <Future<void>>[];
      for (int idx = 0; idx < 20; idx++) {
        promises.add(queue!.get().then((value) => expect(value, idx)));
      }
      await Future.wait(promises);
    });
  });
}
