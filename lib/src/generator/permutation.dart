import '../generator.dart';
import '../random.dart';
import '../shrinkable.dart';
import '../stream.dart';

/// Low-level: Generates a permutation of [0, 1, ..., length-1].
///
/// Shrinking strategy:
/// - Only order shrinking towards the identity permutation by placing the first
///   out-of-place element into its correct position (recursively through child shrinkables)
Generator<List<int>> permutationIndicesGen(int length) {
  return Arbitrary<List<int>>((Random rand) {
    final int n = length;

    // Start from identity [0, 1, ..., n-1]
    final values = List<int>.generate(n, (i) => i);

    // Shuffle in-place using Fisher-Yates
    for (int i = n - 1; i > 0; i--) {
      final j = rand.inRange(0, i + 1);
      final tmp = values[i];
      values[i] = values[j];
      values[j] = tmp;
    }

    LazyStream<Shrinkable<List<int>>> orderShrinksFor(List<int> current) {
      // Find the first index where the element is out of place
      int idx = -1;
      for (int i = 0; i < current.length; i++) {
        if (current[i] != i) {
          idx = i;
          break;
        }
      }
      if (idx == -1) {
        // Already identity; no order shrinks
        return LazyStream<Shrinkable<List<int>>>(null);
      }
      // Find the position where value 'idx' currently resides
      int pos = idx;
      for (int j = idx + 1; j < current.length; j++) {
        if (current[j] == idx) {
          pos = j;
          break;
        }
      }
      // Swap current[idx] with current[pos] to place 'idx' correctly
      final swapped = List<int>.from(current);
      final tmp = swapped[idx];
      swapped[idx] = swapped[pos];
      swapped[pos] = tmp;

      // Provide one-step order shrink, and allow it to continue shrinking recursively
      return LazyStream.one(
        Shrinkable<List<int>>(swapped)
            .withShrinks(() => orderShrinksFor(swapped)),
      );
    }

    return Shrinkable<List<int>>(values)
        .withShrinks(() => orderShrinksFor(values));
  });
}

/// High-level: Permutes the provided items, preserving shrinking towards original order.
Generator<List<T>> permutationOf<T>(List<T> items) {
  final indicesGen = permutationIndicesGen(items.length);
  return indicesGen.map((List<int> idxs) => idxs.map((i) => items[i]).toList());
}
