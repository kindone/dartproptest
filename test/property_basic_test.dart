import 'package:test/test.dart';
import 'package:dartproptest/dartproptest.dart';

void main() {
  group('Property Basic Tests', () {
    test('property with always true condition', () {
      final prop = Property((List<dynamic> args) {
        return true; // Always true
      });

      // Should not throw
      expect(
          () => prop
              .setNumRuns(10)
              .forAllLegacy([interval(0, 100), interval(0, 100)]),
          returnsNormally);
    });

    test('property with void function that never throws', () {
      final prop = Property((List<dynamic> args) {
        // Do nothing - never throws
      });

      // Should not throw
      expect(
          () => prop
              .setNumRuns(10)
              .forAllLegacy([interval(0, 100), interval(0, 100)]),
          returnsNormally);
    });

    test('property with single argument always true', () {
      final prop = Property((List<dynamic> args) => true);

      expect(() => prop.setNumRuns(10).forAllLegacy([interval(0, 100)]),
          returnsNormally);
    });

    test('property with three arguments always true', () {
      final prop = Property((List<dynamic> args) => true);

      expect(
          () => prop.setNumRuns(10).forAllLegacy(
              [interval(0, 100), interval(0, 100), interval(0, 100)]),
          returnsNormally);
    });

    test('property with array argument always true', () {
      final prop = Property((List<dynamic> args) => true);

      expect(
          () => prop
              .setNumRuns(10)
              .forAllLegacy([arrayGen(interval(0, 100), 0, 10)]),
          returnsNormally);
    });

    test('property with string argument always true', () {
      final prop = Property((List<dynamic> args) => true);

      expect(() => prop.setNumRuns(10).forAllLegacy([asciiStringGen(0, 20)]),
          returnsNormally);
    });

    test('property with boolean argument always true', () {
      final prop = Property((List<dynamic> args) => true);

      expect(() => prop.setNumRuns(10).forAllLegacy([booleanGen()]),
          returnsNormally);
    });

    test('property with floating point argument always true', () {
      final prop = Property((List<dynamic> args) => true);

      expect(() => prop.setNumRuns(10).forAllLegacy([floatingGen()]),
          returnsNormally);
    });

    test('property with setup and teardown', () {
      int setupCount = 0;
      int teardownCount = 0;

      final prop = Property((List<dynamic> args) {
        return true;
      }).setOnStartup(() => setupCount++).setOnCleanup(() => teardownCount++);

      prop.setNumRuns(10).forAllLegacy([interval(0, 100)]);

      // Setup should be called for each run
      expect(setupCount, equals(10));
      // Teardown should be called for each successful run
      expect(teardownCount, equals(10));
    });

    test('property with seeded random', () {
      // final prop1 = Property((List<dynamic> args) => true).setSeed('42');
      // final prop2 = Property((List<dynamic> args) => true).setSeed('42');

      // Both should generate the same sequence
      final results1 = <int>[];
      final results2 = <int>[];

      // Capture generated values (this is a bit hacky but works for testing)
      final gen1 = interval(0, 100);
      final gen2 = interval(0, 100);

      final rand1 = Random('42');
      final rand2 = Random('42');

      for (int i = 0; i < 10; i++) {
        results1.add(gen1.generate(rand1).value);
        results2.add(gen2.generate(rand2).value);
      }

      expect(results1, equals(results2));
    });

    test('property example method', () {
      final prop = Property((List<dynamic> args) {
        final a = args[0] as int;
        final b = args[1] as int;
        return a + b > 0;
      });

      // Test with valid example
      expect(prop.example([5, 3]), equals(true));

      // Test with invalid example
      expect(prop.example([-5, -3]), equals(false));
    });

    test('property shrinking with multiple arguments', () {
      final prop = Property((List<dynamic> args) {
        final a = args[0] as int;
        final b = args[1] as int;
        return a < 10 || b < 10;
      });

      // This should fail and shrink
      expect(
          () => prop
              .setNumRuns(100)
              .forAllLegacy([interval(0, 100), interval(0, 100)]),
          throwsException);
    });

    test('property with precondition error', () {
      final prop = Property((List<dynamic> args) {
        final a = args[0] as int;
        final b = args[1] as int;
        if (a == 0 || b == 0) {
          throw PreconditionError('Zero values not allowed');
        }
        return true;
      });

      // Should not throw because precondition errors are skipped
      expect(
          () => prop
              .setNumRuns(100)
              .forAllLegacy([interval(0, 10), interval(0, 10)]),
          returnsNormally);
    });

    test('property with exception throwing function', () {
      final prop = Property((List<dynamic> args) {
        final a = args[0] as int;
        final b = args[1] as int;
        if (a > 50 || b > 50) {
          throw Exception('Value too large: a=$a, b=$b');
        }
      });

      // Should throw for inputs that can be > 50
      expect(
          () => prop
              .setNumRuns(100)
              .forAllLegacy([interval(0, 100), interval(0, 100)]),
          throwsException);
    });

    test('property with failing boolean function', () {
      final prop = Property((List<dynamic> args) {
        final a = args[0] as int;
        final b = args[1] as int;
        return a < 50 && b < 50;
      });

      // Should throw for inputs that can be > 50
      expect(
          () => prop
              .setNumRuns(100)
              .forAllLegacy([interval(0, 100), interval(0, 100)]),
          throwsException);
    });
  });

  group('Property Matrix Tests', () {
    test('matrix: basic 2-argument test with all passing', () {
      final prop = Property((List<dynamic> args) {
        final a = args[0] as int;
        final b = args[1] as int;
        return a + b >= 0;
      });

      // Tests all combinations: (1,2), (1,3), (2,2), (2,3), (3,2), (3,3)
      expect(
          () => prop.matrix([
                [1, 2, 3],
                [2, 3]
              ]),
          returnsNormally);
    });

    test('matrix: 3-argument test', () {
      final prop = Property((List<dynamic> args) {
        final a = args[0] as int;
        final b = args[1] as int;
        final c = args[2] as int;
        return a + b + c >= 0;
      });

      // Tests all 2*2*2 = 8 combinations
      expect(
          () => prop.matrix([
                [1, 2],
                [3, 4],
                [5, 6]
              ]),
          returnsNormally);
    });

    test('matrix: single argument test', () {
      final prop = Property((List<dynamic> args) {
        final a = args[0] as int;
        return a >= 0;
      });

      // Tests all values in the list
      expect(
          () => prop.matrix([
                [0, 1, 2, 3]
              ]),
          returnsNormally);
    });

    test('matrix: failure case - throws with combination details', () {
      final prop = Property((List<dynamic> args) {
        final a = args[0] as int;
        final b = args[1] as int;
        return a < 2 || b < 2; // Fails for (2,2), (2,3), (3,2), (3,3)
      });

      expect(
          () => prop.matrix([
                [1, 2, 3],
                [2, 3]
              ]),
          throwsA(predicate((e) =>
              e is Exception &&
              e.toString().contains('Property failed in matrix test'))));
    });

    test('matrix: failure with exception', () {
      final prop = Property((List<dynamic> args) {
        final a = args[0] as int;
        final b = args[1] as int;
        if (a == 2 && b == 2) {
          throw Exception('Specific failure at (2,2)');
        }
        return true;
      });

      expect(
          () => prop.matrix([
                [1, 2, 3],
                [2, 3]
              ]),
          throwsA(predicate((e) =>
              e is Exception &&
              e.toString().contains('Property failed in matrix test'))));
    });

    test('matrix: precondition handling', () {
      final prop = Property((List<dynamic> args) {
        final a = args[0] as int;
        final b = args[1] as int;
        if (a == 0 || b == 0) {
          throw PreconditionError('Zero values not allowed');
        }
        return true;
      });

      // Should pass - preconditions are skipped
      expect(
          () => prop.matrix([
                [0, 1, 2],
                [1, 2, 3]
              ]),
          returnsNormally);
    });

    test('matrix: all preconditions fail', () {
      final prop = Property((List<dynamic> args) {
        final a = args[0] as int;
        final b = args[1] as int;
        if (a == 0 || b == 0) {
          throw PreconditionError('Zero values not allowed');
        }
        return true;
      });

      // All combinations trigger preconditions
      expect(
          () => prop.matrix([
                [0],
                [0]
              ]),
          throwsA(predicate((e) =>
              e is Exception &&
              e.toString().contains(
                  'All combinations in matrix test triggered preconditions'))));
    });

    test('matrix: empty input lists throws', () {
      final prop = Property((List<dynamic> args) => true);

      expect(
          () => prop.matrix([]),
          throwsA(predicate((e) =>
              e is ArgumentError &&
              e
                  .toString()
                  .contains('matrix() requires at least one input list'))));
    });

    test('matrix: with setup and teardown hooks', () {
      int setupCount = 0;
      int teardownCount = 0;

      final prop = Property((List<dynamic> args) {
        return true;
      }).setOnStartup(() => setupCount++).setOnCleanup(() => teardownCount++);

      // 2*2 = 4 combinations
      prop.matrix([
        [1, 2],
        [3, 4]
      ]);

      // Setup should be called for each combination
      expect(setupCount, equals(4));
      // Teardown should be called for each successful combination
      expect(teardownCount, equals(4));
    });

    test('matrix: void function', () {
      final prop = Property((List<dynamic> args) {
        final a = args[0] as int;
        final b = args[1] as int;
        expect(a + b, greaterThanOrEqualTo(0));
      });

      expect(
          () => prop.matrix([
                [1, 2],
                [3, 4]
              ]),
          returnsNormally);
    });

    test('matrix: mixed types', () {
      final prop = Property((List<dynamic> args) {
        final s = args[0] as String;
        final n = args[1] as int;
        return s.length >= 0 && n >= 0;
      });

      expect(
          () => prop.matrix([
                ['a', 'ab'],
                [1, 2]
              ]),
          returnsNormally);
    });
  });
}
