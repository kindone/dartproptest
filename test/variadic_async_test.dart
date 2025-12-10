import 'package:dartproptest/dartproptest.dart';
import 'package:test/test.dart';

void main() {
  group('Async forAll Tests', () {
    test('forAllAsync with single argument', () async {
      await expectLater(() async {
        await forAllAsync(
          (int a) async => a * a >= 0,
          [Gen.interval(-100, 100)],
          numRuns: 10,
        );
      }(), completes);
    });

    test('forAllAsync with two arguments', () async {
      await expectLater(() async {
        await forAllAsync(
          (int a, int b) async {
            // Simulate async work
            await Future.delayed(Duration.zero);
            return a + b == b + a;
          },
          [Gen.interval(0, 100), Gen.interval(0, 100)],
          numRuns: 10,
        );
      }(), completes);
    });

    test('forAllAsync with three arguments', () async {
      await expectLater(() async {
        await forAllAsync(
          (int a, int b, int c) async {
            await Future.delayed(Duration.zero);
            return (a + b) + c == a + (b + c);
          },
          [Gen.interval(0, 50), Gen.interval(0, 50), Gen.interval(0, 50)],
          numRuns: 10,
        );
      }(), completes);
    });

    test('forAllAsync with mixed types', () async {
      await expectLater(() async {
        await forAllAsync(
          (int a, String s, bool flag) async {
            await Future.delayed(Duration.zero);
            if (flag) {
              return a.toString().length >= 1;
            } else {
              return a >= 0;
            }
          },
          [
            Gen.interval(0, 100),
            Gen.asciiString(minLength: 1, maxLength: 5),
            Gen.boolean()
          ],
          numRuns: 10,
        );
      }(), completes);
    });

    test('forAllAsync should fail on false result', () async {
      await expectLater(() async {
        await forAllAsync(
          (int a) async => a > 1000, // Will fail for most inputs
          [Gen.interval(0, 100)],
          numRuns: 10,
        );
      }(), throwsException);
    });

    test('forAllAsync with synchronous function', () async {
      // Should also work with non-async functions
      await expectLater(() async {
        await forAllAsync(
          (int a, int b) => a + b == b + a,
          [Gen.interval(0, 100), Gen.interval(0, 100)],
          numRuns: 10,
        );
      }(), completes);
    });

    test('forAllAsyncSimple with single argument', () async {
      await expectLater(() async {
        await forAllAsyncSimple(
          (int a) async => a * a >= 0,
          [Gen.interval(-100, 100)],
          numRuns: 10,
        );
      }(), completes);
    });

    test('forAllAsyncSimple with two arguments', () async {
      await expectLater(() async {
        await forAllAsyncSimple(
          (int a, int b) async {
            await Future.delayed(Duration.zero);
            return a + b == b + a;
          },
          [Gen.interval(0, 100), Gen.interval(0, 100)],
          numRuns: 10,
        );
      }(), completes);
    });

    test('forAllAsync with custom numRuns', () async {
      int count = 0;
      await expectLater(() async {
        await forAllAsync(
          (int a) async {
            count++;
            return a >= -100;
          },
          [Gen.interval(-100, 100)],
          numRuns: 5,
        );
      }(), completes);
      expect(count, equals(5));
    });

    test('forAllAsync with seed for reproducibility', () async {
      final results1 = <int>[];
      final results2 = <int>[];

      await forAllAsync(
        (int a) async {
          results1.add(a);
          return true;
        },
        [Gen.interval(0, 1000)],
        numRuns: 5,
        seed: 'test-seed',
      );

      await forAllAsync(
        (int a) async {
          results2.add(a);
          return true;
        },
        [Gen.interval(0, 1000)],
        numRuns: 5,
        seed: 'test-seed',
      );

      expect(results1, equals(results2));
    });
  });
}
