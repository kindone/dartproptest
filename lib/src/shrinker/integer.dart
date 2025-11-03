import '../random.dart';
import '../shrinkable.dart';
import '../stream.dart';

/// Generates a shrinkable integer within the specified range [min, max].
///
/// [random] The random number generator.
/// [min] The minimum value (inclusive).
/// [max] The maximum value (inclusive).
/// Returns a Shrinkable containing the generated integer and its shrinks.
Shrinkable<int> generateInteger(Random random, int min, int max) {
  final value = random.interval(min, max);
  return Shrinkable<int>(value, () => _shrinkInteger(value, min, max));
}

/// Generates shrinks for an integer value using binary search approach.
/// This avoids duplicate values by using a single, consistent shrinking strategy.
///
/// [value] The integer value to shrink.
/// [min] The minimum allowed value.
/// [max] The maximum allowed value.
/// Returns a stream of smaller integer values.
LazyStream<Shrinkable<int>> _shrinkInteger(int value, int min, int max) {
  if (value == min) {
    return LazyStream<Shrinkable<int>>(null);
  }

  // Use binary search approach like jsproptest
  if (min >= 0) {
    // Range is entirely non-negative: shrink towards min
    return _binarySearchTowardsZero(value - min)
        .transform((shr) => shr.map((n) => n + min));
  } else if (max <= 0) {
    // Range is entirely non-positive: shrink towards max
    return _binarySearchTowardsZero(value - max)
        .transform((shr) => shr.map((n) => n + max));
  } else {
    // Range crosses zero: shrink towards 0
    return _binarySearchTowardsZero(value);
  }
}

/// Generates shrinks for a positive integer using binary search towards 0.
/// This is the core binary search logic from jsproptest.
LazyStream<Shrinkable<int>> _binarySearchTowardsZero(int value) {
  if (value == 0) {
    return LazyStream<Shrinkable<int>>(null);
  }

  if (value > 0) {
    // For positive numbers, prioritize 0, then use binary search for (0, value)
    return LazyStream<Shrinkable<int>>(
        Shrinkable<int>(0), () => _genPos(0, value));
  } else {
    // For negative numbers, prioritize 0, then use binary search for (value, 0)
    return LazyStream<Shrinkable<int>>(
        Shrinkable<int>(0), () => _genNeg(value, 0));
  }
}

/// Generates shrinks for a positive integer range using binary search.
/// Splits the range [min, max) in half, shrinking towards min.
LazyStream<Shrinkable<int>> _genPos(int min, int max) {
  if (min + 1 >= max) {
    return LazyStream<Shrinkable<int>>(null); // No more shrinking possible
  }

  // Calculate midpoint, ensuring it rounds towards min correctly (like Math.floor)
  final mid = (min < 0 ? (min - 1) ~/ 2 : min ~/ 2) +
      (max < 0 ? (max - 1) ~/ 2 : max ~/ 2) +
      ((min % 2 != 0 && max % 2 != 0) ? 1 : 0);

  if (min + 2 >= max) {
    return LazyStream<Shrinkable<int>>(
        Shrinkable<int>(mid)); // Only midpoint left
  }

  // Recursively generate shrinks: prioritize midpoint, then lower half, then upper half
  return LazyStream<Shrinkable<int>>(
      Shrinkable<int>(mid, () => _genPos(min, mid))).concat(_genPos(mid, max));
}

/// Generates shrinks for a negative integer range using binary search.
/// Splits the range (min, max] in half, shrinking towards max.
LazyStream<Shrinkable<int>> _genNeg(int min, int max) {
  if (min + 1 >= max) {
    return LazyStream<Shrinkable<int>>(null); // No more shrinking possible
  }

  // Calculate midpoint, ensuring it rounds towards max correctly (like Math.floor)
  final mid = (min < 0 ? (min - 1) ~/ 2 : min ~/ 2) +
      (max < 0 ? (max - 1) ~/ 2 : max ~/ 2) +
      ((min % 2 != 0 && max % 2 != 0) ? -1 : 0);

  if (min + 2 >= max) {
    return LazyStream<Shrinkable<int>>(
        Shrinkable<int>(mid)); // Only midpoint left
  }

  // Recursively generate shrinks: prioritize midpoint, then lower half, then upper half
  return LazyStream<Shrinkable<int>>(
      Shrinkable<int>(mid, () => _genPos(min, mid))).concat(_genPos(mid, max));
}

/// Creates a shrinkable that uses binary search to shrink a range.
/// This is useful for shrinking array lengths and other range-based values.
/// Matches jsproptest behavior: shrinks towards 0 using genpos for all intermediate values.
///
/// [range] The range to shrink (e.g., array length - minSize).
/// Returns a Shrinkable that shrinks the range using binary search.
Shrinkable<int> binarySearchShrinkable(int range) {
  if (range <= 0) {
    return Shrinkable<int>(0);
  }

  return Shrinkable<int>(range, () {
    if (range == 0) {
      return LazyStream<Shrinkable<int>>(null);
    }
    // For positive numbers, shrink towards 0: prioritize 0, then use genpos for the range (0, value)
    if (range > 0) {
      return LazyStream<Shrinkable<int>>(Shrinkable<int>(0))
          .concat(_genPos(0, range));
    } else {
      // For negative numbers, shrink towards 0: prioritize 0, then use genneg for the range (value, 0)
      return LazyStream<Shrinkable<int>>(Shrinkable<int>(0))
          .concat(_genNeg(range, 0));
    }
  });
}
