import '../shrinkable.dart';
import '../stream.dart';
import 'integer.dart';

/// Shrinks an array by reducing its length from the rear.
/// It attempts to produce arrays with lengths ranging from the original size down to `minSize`.
/// Uses binary search internally for efficiency, but ensures we eventually reach `minSize`.
///
/// [shrinkableElems] The array of Shrinkable elements.
/// [minSize] The minimum allowed size for the shrunken array.
/// Returns a Shrinkable representing arrays of potentially smaller lengths.
Shrinkable<List<T>> shrinkArrayLength<T>(
    List<Shrinkable<T>> shrinkableElems, int minSize) {
  final size = shrinkableElems.length;
  if (size <= minSize) {
    // Already at minimum size, no shrinking possible
    return Shrinkable<List<T>>(
        shrinkableElems.sublist(0, size).map((shr) => shr.value).toList());
  }

  final range = size - minSize;
  final rangeShrinkableOriginal = binarySearchShrinkable(range);

  // Check if 0 (which maps to minSize) is already in the shrink tree
  bool hasZero = false;
  void checkForZero(Shrinkable<int> shr) {
    if (shr.value == 0) {
      hasZero = true;
      return;
    }
    final iterator = shr.shrinks().iterator();
    while (iterator.hasNext()) {
      checkForZero(iterator.next());
    }
  }

  checkForZero(rangeShrinkableOriginal);

  // Map range values to actual sizes
  final rangeShrinkable = rangeShrinkableOriginal.map((s) => s + minSize);

  // If 0 is not in the tree, add it as a final shrink (which maps to minSize)
  if (!hasZero) {
    return rangeShrinkable.withShrinks(() {
      final originalShrinks = rangeShrinkable.shrinks();
      final minSizeShrink = Shrinkable<int>(minSize);
      return originalShrinks.concat(LazyStream.one(minSizeShrink));
    }).map((newSize) {
      if (newSize == 0) return <T>[];
      return shrinkableElems
          .sublist(0, newSize)
          .map((shr) => shr.value)
          .toList();
    });
  } else {
    return rangeShrinkable.map((newSize) {
      if (newSize == 0) return <T>[];
      return shrinkableElems
          .sublist(0, newSize)
          .map((shr) => shr.value)
          .toList();
    });
  }
}

/// Creates a Shrinkable for an array, allowing shrinking by removing elements.
/// This is a simplified version that focuses on length-based shrinking.
///
/// [shrinkableElems] The initial array of Shrinkable elements.
/// [minSize] The minimum allowed length of the array after shrinking.
/// Returns a Shrinkable<Array<T>> that represents the original array and its potential shrunken versions.
Shrinkable<List<T>> shrinkableArray<T>(
    List<Shrinkable<T>> shrinkableElems, int minSize) {
  // For now, just use the length-based shrinking directly
  return shrinkArrayLength(shrinkableElems, minSize);
}
