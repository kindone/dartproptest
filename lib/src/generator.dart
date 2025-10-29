import 'random.dart';
import 'shrinkable.dart';
import 'shrinker/array.dart';
import 'stream.dart';

/// Defines the core interface for generating random values along with their shrinkable counterparts.
/// Shrinkable values are essential for property-based testing, allowing the system to find the smallest failing example.
///
/// [T] The type of value to generate.
abstract class Generator<T> {
  /// Generates a random value wrapped in a Shrinkable container.
  ///
  /// [rand] The random number generator instance.
  /// Returns a Shrinkable containing the generated value and its potential smaller versions.
  Shrinkable<T> generate(Random rand);

  /// Transforms the generated values using a provided function.
  ///
  /// [U] The type of the transformed value.
  /// [transformer] A function to apply to the generated value.
  /// Returns a new Generator producing transformed values.
  Generator<U> map<U>(U Function(T) transformer);

  /// Chains the generation process by using the output of this generator to create a new generator.
  /// This is useful for creating dependent random values.
  ///
  /// [U] The type produced by the subsequent generator.
  /// [genFactory] A function that takes the generated value and returns a new Generator.
  /// Returns a new Generator producing values from the chained generator.
  Generator<U> flatMap<U>(Generator<U> Function(T) genFactory);

  /// Similar to flatMap, but preserves the original value, returning a tuple.
  ///
  /// [U] The type produced by the subsequent generator.
  /// [genFactory] A function that takes the generated value and returns a new Generator.
  /// Returns a new Generator producing tuples of [originalValue, newValue].
  Generator<(T, U)> chain<U>(Generator<U> Function(T) genFactory);

  /// Filters the generated values based on a predicate.
  /// It will keep generating values until one satisfies the predicate.
  ///
  /// [filterer] A function that returns true if the value should be kept.
  /// Returns a new Generator producing only values that satisfy the predicate.
  Generator<T> filter(bool Function(T) filterer);

  /// Builds an array incrementally using the last generated value.
  /// Starts with a value from this generator, then uses nextGen to produce the next element.
  ///
  /// [nextGen] A function that takes the last generated value and returns a generator for the next element.
  /// [minLength] Minimum length of the resulting array.
  /// [maxLength] Maximum length of the resulting array.
  /// Returns a new Generator producing arrays built incrementally.
  Generator<List<T>> accumulate(
      Generator<T> Function(T) nextGen, int minLength, int maxLength);

  /// Builds an array using the entire current array state.
  /// Similar to accumulate, but nextGen takes the entire array generated so far.
  ///
  /// [nextGen] A function that takes the current array and returns a generator for the next complete array state.
  /// [minLength] Minimum length of the resulting array.
  /// [maxLength] Maximum length of the resulting array.
  /// Returns a new Generator producing arrays built with full state awareness.
  Generator<List<T>> aggregate(Generator<List<T>> Function(List<T>) nextGen,
      int minLength, int maxLength);
}

/// A concrete implementation of the Generator interface.
///
/// [T] The type of value to generate.
class Arbitrary<T> implements Generator<T> {
  /// The core function used to generate Shrinkable values.
  final Shrinkable<T> Function(Random) genFunction;

  /// Creates an instance of Arbitrary.
  ///
  /// [genFunction] The core function used to generate Shrinkable values.
  Arbitrary(this.genFunction);

  @override
  Shrinkable<T> generate(Random rand) {
    return genFunction(rand);
  }

  @override
  Generator<U> map<U>(U Function(T) transformer) {
    // Creates a new Arbitrary that applies the transformer to the generated Shrinkable's value.
    return Arbitrary<U>((rand) => generate(rand).map(transformer));
  }

  @override
  Generator<U> flatMap<U>(Generator<U> Function(T) genFactory) {
    return Arbitrary<U>((rand) {
      // Generate the initial value and use it to create the next generator
      final initialShr = generate(rand);
      final nextGen = genFactory(initialShr.value);
      final nextShr = nextGen.generate(rand);

      // Helper function to create shrinks with proper type preservation
      LazyStream<Shrinkable<U>> createFlatMapShrinks() {
        // First, shrink the original value and regenerate new value for each
        final originalShrinks = initialShr
            .shrinks()
            .transform<Shrinkable<U>>((Shrinkable<T> origShr) {
          final newNextGen = genFactory(origShr.value);
          final newNextShr = newNextGen.generate(rand);
          return newNextShr; // Return the new shrinkable directly
        });

        // Then, shrink the new value directly
        final newValueShrinks = nextShr.shrinks() as LazyStream<Shrinkable<U>>;

        // Combine both shrink streams
        return originalShrinks.concat(newValueShrinks);
      }

      // Create shrinks that preserve the structure
      // 1. Shrink the original value and regenerate the new value for each shrunk original
      // 2. Shrink the new value directly
      // Combine both shrink streams
      return Shrinkable<U>(nextShr.value, createFlatMapShrinks);
    });
  }

  @override
  Generator<(T, U)> chain<U>(Generator<U> Function(T) genFactory) {
    return Arbitrary<(T, U)>((rand) {
      // Generate the initial value and keep it
      final initialShr = generate(rand);
      final nextGen = genFactory(initialShr.value);
      final nextShr = nextGen.generate(rand);

      // Create shrinks that preserve the structure
      // 1. Shrink the first value, regenerating the second for each shrunk first value
      //    (and preserving the second value's shrinking structure)
      // 2. Shrink the second value while keeping the first value fixed
      return Shrinkable<(T, U)>((initialShr.value, nextShr.value))
          .withShrinks(() {
        // First, shrink the first value and regenerate second for each
        final firstShrinks = initialShr.shrinks().transform((firstShr) {
          final newNextGen = genFactory(firstShr.value);
          final newNextShr = newNextGen.generate(rand);
          // Preserve the shrinking structure of the new second value
          return newNextShr.map((secondVal) => (firstShr.value, secondVal));
        });

        // Then, shrink the second value while keeping first fixed
        final secondShrinks = nextShr.shrinks().transform((secondShr) {
          return Shrinkable<(T, U)>((initialShr.value, secondShr.value));
        });

        // Combine both shrink streams
        return firstShrinks.concat(secondShrinks);
      });
    });
  }

  @override
  Generator<T> filter(bool Function(T) filterer) {
    return Arbitrary<T>((rand) {
      // Keep generating until a value satisfies the filter.
      // Note: This can potentially loop infinitely if the filter is too restrictive.
      while (true) {
        final shr = generate(rand);
        if (filterer(shr.value)) {
          // Apply the filter to the shrinks to ensure constraint preservation
          return shr.filter(filterer);
        }
      }
    });
  }

  @override
  Generator<List<T>> accumulate(
      Generator<T> Function(T) nextGen, int minLength, int maxLength) {
    return Arbitrary<List<T>>((rand) {
      // Generate the initial value
      final initialShr = generate(rand);
      final targetLength = rand.interval(minLength, maxLength);

      // Generate the full sequence and store Shrinkable elements
      final shrinkableElements = <Shrinkable<T>>[initialShr];
      var currentValue = initialShr.value;

      for (int i = 1; i < targetLength; i++) {
        final nextGenerator = nextGen(currentValue);
        final nextShr = nextGenerator.generate(rand);
        shrinkableElements.add(nextShr);
        currentValue = nextShr.value;
      }

      // Use a custom shrinking strategy that preserves constraints
      // First, create a shrinkable that can shrink by length
      final lengthShrinkable = shrinkArrayLength(shrinkableElements, minLength);

      // Helper function to apply element shrinking to a list of given length
      LazyStream<Shrinkable<List<T>>> applyElementShrinking(int length) {
        final shrunkElements = <Shrinkable<T>>[];
        bool hasShrinks = false;

        for (int i = 0; i < length; i++) {
          final elementShrinks = shrinkableElements[i].shrinks();
          if (!elementShrinks.isEmpty()) {
            final iterator = elementShrinks.iterator();
            if (iterator.hasNext()) {
              shrunkElements.add(iterator.next());
              hasShrinks = true;
            } else {
              shrunkElements.add(shrinkableElements[i]);
            }
          } else {
            shrunkElements.add(shrinkableElements[i]);
          }
        }

        if (hasShrinks) {
          return LazyStream<Shrinkable<List<T>>>(Shrinkable<List<T>>(
              shrunkElements.map((shr) => shr.value).toList()));
        } else {
          return LazyStream<Shrinkable<List<T>>>(null);
        }
      }

      // Create final shrinkable that combines:
      // 1. Length shrinking (with element shrinking applied to each length-shrunk version) - prioritized for efficiency
      // 2. Element shrinking for the root value
      return Shrinkable<List<T>>(lengthShrinkable.value).withShrinks(() {
        // Get length-based shrinks with element shrinking applied
        final lengthShrinks = lengthShrinkable.shrinks().transform((lengthShr) {
          return Shrinkable<List<T>>(lengthShr.value).withShrinks(() {
            return applyElementShrinking(lengthShr.value.length);
          });
        });

        // Get element-based shrinks for the root value
        final rootElementShrinks =
            applyElementShrinking(lengthShrinkable.value.length);

        // Combine both: length shrinks first (logarithmic), then element shrinks
        return lengthShrinks.concat(rootElementShrinks);
      });
    });
  }

  @override
  Generator<List<T>> aggregate(Generator<List<T>> Function(List<T>) nextGen,
      int minLength, int maxLength) {
    return Arbitrary<List<T>>((rand) {
      // Generate the initial value
      final initialShr = generate(rand);
      var currentArray = <T>[initialShr.value];

      // Store shrinkables for each array state (for potential state shrinking)
      final arrayStateShrinkables = <Shrinkable<List<T>>>[];
      final targetLength = rand.interval(minLength, maxLength);

      while (currentArray.length < targetLength) {
        final nextGenerator = nextGen(currentArray);
        final nextShr = nextGenerator.generate(rand);
        arrayStateShrinkables.add(nextShr);
        currentArray = nextShr.value;
      }

      // For aggregate, array states are generated as complete states that depend on previous states.
      // We can shrink:
      // 1. By length (remove trailing elements from final array) - logarithmic
      // 2. The initial element (if it has shrinks)
      // 3. Each array state (if the generator provides shrinks)

      // Create shrinkables for the final array elements
      // For aggregate, we can shrink:
      // 1. The initial element (if it has shrinks)
      // 2. Array states (if generators provide shrinks) - but this is complex due to dependencies
      // For simplicity, we'll allow shrinking the initial element and use simple shrinkables for others
      final shrinkableElements = <Shrinkable<T>>[];

      // First element comes from initialShr (can be shrunk)
      shrinkableElements.add(initialShr);

      // For remaining elements, create simple shrinkables without shrinking
      // (since they depend on previous states, shrinking them independently is complex)
      for (int i = 1; i < currentArray.length; i++) {
        shrinkableElements.add(Shrinkable<T>(currentArray[i]));
      }

      // Use length-based shrinking first (logarithmic)
      final lengthShrinkable = shrinkArrayLength(shrinkableElements, minLength);

      // Helper function to apply element/state shrinking to a list of given length
      LazyStream<Shrinkable<List<T>>> applyElementShrinking(int length) {
        final shrunkElements = <Shrinkable<T>>[];
        bool hasShrinks = false;

        for (int i = 0; i < length; i++) {
          final elementShrinks = shrinkableElements[i].shrinks();
          if (!elementShrinks.isEmpty()) {
            final iterator = elementShrinks.iterator();
            if (iterator.hasNext()) {
              shrunkElements.add(iterator.next());
              hasShrinks = true;
            } else {
              shrunkElements.add(shrinkableElements[i]);
            }
          } else {
            shrunkElements.add(shrinkableElements[i]);
          }
        }

        if (hasShrinks) {
          return LazyStream<Shrinkable<List<T>>>(Shrinkable<List<T>>(
              shrunkElements.map((shr) => shr.value).toList()));
        } else {
          return LazyStream<Shrinkable<List<T>>>(null);
        }
      }

      // Create final shrinkable that combines:
      // 1. Length shrinking (with element shrinking applied) - prioritized for efficiency
      // 2. Element shrinking for the root value
      return Shrinkable<List<T>>(lengthShrinkable.value).withShrinks(() {
        // Get length-based shrinks with element shrinking applied
        final lengthShrinks = lengthShrinkable.shrinks().transform((lengthShr) {
          return Shrinkable<List<T>>(lengthShr.value).withShrinks(() {
            return applyElementShrinking(lengthShr.value.length);
          });
        });

        // Get element-based shrinks for the root value
        final rootElementShrinks =
            applyElementShrinking(lengthShrinkable.value.length);

        // Combine both: length shrinks first (logarithmic), then element shrinks
        return lengthShrinks.concat(rootElementShrinks);
      });
    });
  }
}

/// Type alias for the core function within a Generator that produces a Shrinkable value.
///
/// [ARG] The type of value to generate.
/// [rand] The random number generator instance.
/// Returns a Shrinkable value.
typedef GenFunction<ARG> = Shrinkable<ARG> Function(Random rand);
