import 'package:test/test.dart';
import 'package:dartproptest/dartproptest.dart';

void main() {
  group('Shrinker Tests', () {
    test('shrinkableBoolean shrinks true to false', () {
      final trueShrinkable = shrinkableBoolean(true);
      expect(trueShrinkable.value, equals(true));

      final shrinks = trueShrinkable.shrinks();
      expect(shrinks.isEmpty(), equals(false));

      final iterator = shrinks.iterator();
      expect(iterator.hasNext(), equals(true));
      final firstShrink = iterator.next();
      expect(firstShrink.value, equals(false));
    });

    test('shrinkableBoolean does not shrink false', () {
      final falseShrinkable = shrinkableBoolean(false);
      expect(falseShrinkable.value, equals(false));

      final shrinks = falseShrinkable.shrinks();
      expect(shrinks.isEmpty(), equals(true));
    });

    test('binarySearchShrinkable shrinks ranges correctly', () {
      final rangeShrinkable = binarySearchShrinkable(8);
      expect(rangeShrinkable.value, equals(8));

      final shrinks = rangeShrinkable.shrinks();
      expect(shrinks.isEmpty(), equals(false));

      final iterator = shrinks.iterator();
      expect(iterator.hasNext(), equals(true));
      final firstShrink = iterator.next();
      expect(firstShrink.value, equals(0)); // Prepend 0 first, then binary search
      
      expect(iterator.hasNext(), equals(true));
      final secondShrink = iterator.next();
      expect(secondShrink.value, equals(4)); // 8 / 2
    });

    test('shrinkArrayLength shrinks array lengths', () {
      final elements = [
        Shrinkable<int>(1),
        Shrinkable<int>(2),
        Shrinkable<int>(3),
        Shrinkable<int>(4),
        Shrinkable<int>(5),
      ];

      final arrayShrinkable = shrinkArrayLength(elements, 2);
      expect(arrayShrinkable.value, hasLength(5));

      final shrinks = arrayShrinkable.shrinks();
      expect(shrinks.isEmpty(), equals(false));

      final iterator = shrinks.iterator();
      expect(iterator.hasNext(), equals(true));
      final firstShrink = iterator.next();
      // range = 5 - 2 = 3, binarySearchShrinkable(3) first gives 0, so size = 0 + 2 = 2
      expect(firstShrink.value, hasLength(2));
    });

    test('shrinkableArray creates shrinkable arrays', () {
      final elements = [
        Shrinkable<int>(10),
        Shrinkable<int>(20),
        Shrinkable<int>(30),
      ];

      final arrayShrinkable = shrinkableArray(elements, 1);
      expect(arrayShrinkable.value, equals([10, 20, 30]));

      final shrinks = arrayShrinkable.shrinks();
      expect(shrinks.isEmpty(), equals(false));
    });

    test('shrinkableSet creates shrinkable sets', () {
      final elements = [
        Shrinkable<int>(1),
        Shrinkable<int>(2),
        Shrinkable<int>(3),
      ];

      final setShrinkable = shrinkableSet(elements, 1);
      expect(setShrinkable.value, equals({1, 2, 3}));

      final shrinks = setShrinkable.shrinks();
      expect(shrinks.isEmpty(), equals(false));
    });

    test('shrinkableString shrinks string lengths', () {
      final codepoints = [
        Shrinkable<int>(65), // 'A'
        Shrinkable<int>(66), // 'B'
        Shrinkable<int>(67), // 'C'
        Shrinkable<int>(68), // 'D'
      ];

      final stringShrinkable = shrinkableString(codepoints, 2);
      expect(stringShrinkable.value, equals('ABCD'));

      final shrinks = stringShrinkable.shrinks();
      expect(shrinks.isEmpty(), equals(false));
    });

    test('shrinkableFloat shrinks floating point numbers', () {
      final floatShrinkable = shrinkableFloat(8.0);
      expect(floatShrinkable.value, equals(8.0));

      final shrinks = floatShrinkable.shrinks();
      expect(shrinks.isEmpty(), equals(false));
    });

    test('shrinkableFloat handles special values', () {
      // Test NaN
      final nanShrinkable = shrinkableFloat(double.nan);
      expect(nanShrinkable.value.isNaN, equals(true));

      final nanShrinks = nanShrinkable.shrinks();
      expect(nanShrinks.isEmpty(), equals(false));

      final iterator = nanShrinks.iterator();
      expect(iterator.hasNext(), equals(true));
      final firstNanShrink = iterator.next();
      expect(firstNanShrink.value, equals(0.0));

      // Test zero
      final zeroShrinkable = shrinkableFloat(0.0);
      expect(zeroShrinkable.value, equals(0.0));

      final zeroShrinks = zeroShrinkable.shrinks();
      expect(zeroShrinks.isEmpty(), equals(true));
    });

    test('shrinkableFloat shrinks large values correctly', () {
      final shrinkable = shrinkableFloat(100.0);
      final shrinks = shrinkable.shrinks();

      expect(shrinks.isEmpty(), isFalse);
      final iterator = shrinks.iterator();
      expect(iterator.next().value, equals(0.0)); // Prepended zero

      // Should shrink to a smaller value (exponent-based shrinking)
      expect(iterator.hasNext(), isTrue);
      final secondShrink = iterator.next();
      expect(secondShrink.value, lessThan(100.0));
      expect(secondShrink.value, greaterThan(0.0));
    });

    test('shrinkableFloat shrinks values with exponent 0 correctly', () {
      final testCases = [8.0, 3.14, 0.5];

      for (final value in testCases) {
        final shrinkable = shrinkableFloat(value);
        final shrinks = shrinkable.shrinks();

        expect(shrinks.isEmpty(), isFalse, reason: '$value should have shrinks');
        final iterator = shrinks.iterator();
        expect(iterator.next().value, equals(0.0)); // Prepended zero

        // Should shrink to smaller values, not 0.0
        if (iterator.hasNext()) {
          final secondShrink = iterator.next();
          expect(secondShrink.value, lessThan(value),
              reason: '$value should shrink to a smaller value');
          expect(secondShrink.value, greaterThanOrEqualTo(0.0));
        }
      }
    });

    test('shrinkableFloat tree terminates without infinite recursion', () {
      // Verify that shrinking doesn't create infinite loops
      final shrinkable = shrinkableFloat(100.0);
      final shrinks = shrinkable.shrinks();
      final iterator = shrinks.iterator();

      iterator.next(); // Skip prepended 0.0
      final secondShrink = iterator.next(); // Get first non-zero shrink

      // The shrink should itself have shrinks, but they should be different values
      final secondShrinks = secondShrink.shrinks();
      if (!secondShrinks.isEmpty()) {
        final secondIterator = secondShrinks.iterator();
        secondIterator.next(); // Skip prepended 0.0

        if (secondIterator.hasNext()) {
          final thirdShrink = secondIterator.next();
          // Should be different from the parent (no self-reference)
          expect(thirdShrink.value, isNot(equals(secondShrink.value)),
              reason: 'Shrink should not reference itself');
        }
      }
    });

    test('shrinkableTuple creates shrinkable tuples', () {
      final elements = [
        Shrinkable<int>(1),
        Shrinkable<int>(2),
        Shrinkable<int>(3),
      ];

      final tupleShrinkable = shrinkableTuple(elements);
      expect(tupleShrinkable.value, equals([1, 2, 3]));

      // For now, the tuple shrinker is simplified and doesn't have complex shrinking
      final shrinks = tupleShrinkable.shrinks();
      expect(shrinks.isEmpty(), equals(true));
    });
  });
}
