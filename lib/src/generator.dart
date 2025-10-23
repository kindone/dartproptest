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
      return nextGen.generate(rand);
    });
  }

  @override
  Generator<(T, U)> chain<U>(Generator<U> Function(T) genFactory) {
    return Arbitrary<(T, U)>((rand) {
      // Generate the initial value and keep it
      final initialShr = generate(rand);
      final nextGen = genFactory(initialShr.value);
      final nextShr = nextGen.generate(rand);

      // Return a shrinkable tuple
      return Shrinkable<(T, U)>((initialShr.value, nextShr.value));
    });
  }

  @override
  Generator<T> filter(bool Function(T) filterer) {
    return Arbitrary<T>((rand) {
      // Keep generating until a value satisfies the filter.
      // Note: This can potentially loop infinitely if the filter is too restrictive.
      while (true) {
        final shr = generate(rand);
        if (filterer(shr.value)) return shr;
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

      // Use standard array shrinking - this will shrink length (from end) and individual elements
      return shrinkableArray(shrinkableElements, minLength);
    });
  }

  @override
  Generator<List<T>> aggregate(Generator<List<T>> Function(List<T>) nextGen,
      int minLength, int maxLength) {
    return Arbitrary<List<T>>((rand) {
      // Generate the initial value
      final initialShr = generate(rand);
      var currentArray = <T>[initialShr.value];

      // Generate additional array states based on the current array
      final targetLength = rand.interval(minLength, maxLength);
      while (currentArray.length < targetLength) {
        final nextGenerator = nextGen(currentArray);
        final nextShr = nextGenerator.generate(rand);
        currentArray = nextShr.value;
      }

      // For aggregate, we can't easily shrink individual elements since they're generated
      // as complete array states. We'll use basic array shrinking by length.
      final shrinkableElements =
          currentArray.map((elem) => Shrinkable<T>(elem)).toList();
      return shrinkableArray(shrinkableElements, minLength);
    });
  }
}

/// Type alias for the core function within a Generator that produces a Shrinkable value.
///
/// [ARG] The type of value to generate.
/// [rand] The random number generator instance.
/// Returns a Shrinkable value.
typedef GenFunction<ARG> = Shrinkable<ARG> Function(Random rand);
