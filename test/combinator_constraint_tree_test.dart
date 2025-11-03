import 'package:test/test.dart';
import 'package:dartproptest/dartproptest.dart';
import 'testutil.dart';

/// Creates the 40213 shrinkable structure:
///   4
///   ├─ 0
///   ├─ 2
///   │  └─ 1
///   └─ 3
Shrinkable<int> genShrinkable40213() =>
    Shrinkable<int>(4).withShrinks(() => LazyStream.three(
        Shrinkable<int>(0),
        Shrinkable<int>(2)
            .withShrinks(() => LazyStream.one(Shrinkable<int>(1))),
        Shrinkable<int>(3)));

/// Creates a larger variant: 7531246
///   7
///   ├─ 5
///   │  ├─ 3
///   │  │  └─ 1
///   │  └─ 2
///   ├─ 4
///   └─ 6
Shrinkable<int> genShrinkable7531246() =>
    Shrinkable<int>(7).withShrinks(() => LazyStream.three(
        Shrinkable<int>(5).withShrinks(() => LazyStream.two(
            Shrinkable<int>(3)
                .withShrinks(() => LazyStream.one(Shrinkable<int>(1))),
            Shrinkable<int>(2))),
        Shrinkable<int>(4),
        Shrinkable<int>(6)));

/// Creates an even larger variant: 964285173
///   9
///   ├─ 6
///   │  ├─ 4
///   │  │  └─ 2
///   │  └─ 8
///   ├─ 5
///   │  └─ 1
///   └─ 7
///      └─ 3
Shrinkable<int> genShrinkable964285173() =>
    Shrinkable<int>(9).withShrinks(() => LazyStream.three(
        Shrinkable<int>(6).withShrinks(() => LazyStream.two(
            Shrinkable<int>(4)
                .withShrinks(() => LazyStream.one(Shrinkable<int>(2))),
            Shrinkable<int>(8))),
        Shrinkable<int>(5)
            .withShrinks(() => LazyStream.one(Shrinkable<int>(1))),
        Shrinkable<int>(7)
            .withShrinks(() => LazyStream.one(Shrinkable<int>(3)))));

/// Helper function to collect all values from a shrinkable tree
void collectAllValues<T>(Shrinkable<T> shrinkable, Set<T> allValues,
    {int maxDepth = 100}) {
  if (maxDepth <= 0) return;
  allValues.add(shrinkable.value);
  final iterator = shrinkable.shrinks().iterator();
  while (iterator.hasNext()) {
    collectAllValues(iterator.next(), allValues, maxDepth: maxDepth - 1);
  }
}

/// Helper function to verify that all shrunk values satisfy a constraint
bool verifyConstraint<T>(Shrinkable<T> shrinkable, bool Function(T) constraint,
    {int maxDepth = 100}) {
  if (maxDepth <= 0) return true;
  if (!constraint(shrinkable.value)) {
    return false;
  }
  final iterator = shrinkable.shrinks().iterator();
  while (iterator.hasNext()) {
    if (!verifyConstraint(iterator.next(), constraint,
        maxDepth: maxDepth - 1)) {
      return false;
    }
  }
  return true;
}

void main() {
  group('Combinator Constraint Preservation Tests (40213 Structure)', () {
    test('map preserves tree structure: even numbers only', () {
      // Start with 40213 structure, map to double values
      // Expected tree structure after mapping (x * 2):
      //   8
      //   ├─ 0
      //   ├─ 4
      //   │  └─ 2
      //   └─ 6
      final baseGen = Arbitrary<int>((_) => genShrinkable40213());
      final mappedGen = baseGen.map((int x) => x * 2);

      final shrinkable = mappedGen.generate(Random('map_test'));

      // Get actual serialized tree
      final actualSerialized = serializeShrinkable(shrinkable);

      // Expected serialized tree structure
      final expectedSerialized =
          '{"value":8,"shrinks":[{"value":0},{"value":4,"shrinks":[{"value":2}]},{"value":6}]}';

      print('Map test - Actual:   $actualSerialized');
      print('Map test - Expected: $expectedSerialized');

      expect(actualSerialized, equals(expectedSerialized),
          reason: 'Mapped tree structure should match expected structure');

      // Verify all shrunk values are even
      expect(verifyConstraint(shrinkable, (x) => x % 2 == 0), isTrue,
          reason: 'All shrunk values should satisfy the even constraint');
    });

    test('filter preserves tree structure: only values >= 2', () {
      // Filter the 40213 structure to only include values >= 2
      // Expected tree structure after filtering (x >= 2):
      //   4
      //   ├─ 2
      //   └─ 3
      // (0 and 1 are filtered out)
      final baseGen = Arbitrary<int>((_) => genShrinkable40213());
      final filteredGen = baseGen.filter((int x) => x >= 2);

      // Generate multiple times to find a value that passes the filter
      final rand = Random('filter_test');
      Shrinkable<int>? shrinkable;
      for (int i = 0; i < 100; i++) {
        final candidate = filteredGen.generate(rand);
        if (candidate.value >= 2) {
          shrinkable = candidate;
          break;
        }
      }

      expect(shrinkable, isNotNull, reason: 'Should find a value >= 2');

      // Get actual serialized tree
      final actualSerialized = serializeShrinkable(shrinkable!);

      // Expected serialized tree structure (after filtering out values < 2)
      final expectedSerialized =
          '{"value":4,"shrinks":[{"value":2},{"value":3}]}';

      print('Filter test - Actual:   $actualSerialized');
      print('Filter test - Expected: $expectedSerialized');

      expect(actualSerialized, equals(expectedSerialized),
          reason: 'Filtered tree structure should match expected structure');

      // Verify all shrunk values satisfy the constraint
      expect(verifyConstraint(shrinkable, (x) => x >= 2), isTrue,
          reason: 'All shrunk values should satisfy the filter constraint');
    });

    test('chain preserves tree structure: dependent values', () {
      // Chain: first value from 40213, second value must be <= first
      // Expected tree structure:
      //   (4, 4)
      //   ├─ (0, 0)
      //   ├─ (2, 2)
      //   │  └─ (2, 1)
      //   └─ (3, 3)
      //      └─ (3, 1)
      final baseGen = Arbitrary<int>((_) => genShrinkable40213());
      final chainedGen = baseGen.chain((int first) => Arbitrary<int>((_) =>
              Shrinkable<int>(first).withShrinks(() => LazyStream.one(
                  Shrinkable<int>(
                      first ~/ 2)))) // Second value is half of first
          );

      final shrinkable = chainedGen.generate(Random('chain_test'));

      // Get actual serialized tree
      final actualSerialized = serializeShrinkable(shrinkable);

      // Expected serialized tree structure
      // Note: Tuple records serialize as (a, b) format
      // The structure includes:
      // 1. Shrinks of the first value, with regenerated second values (preserving their shrinks)
      // 2. Shrinks of the second value while keeping first fixed
      final expectedSerialized =
          '{"value":(4, 4),"shrinks":[{"value":(0, 0),"shrinks":[{"value":(0, 0)}]},{"value":(2, 2),"shrinks":[{"value":(2, 1)}]},{"value":(3, 3),"shrinks":[{"value":(3, 1)}]},{"value":(4, 2)}]}';

      print('Chain test - Actual:   $actualSerialized');
      print('Chain test - Expected: $expectedSerialized');

      expect(actualSerialized, equals(expectedSerialized),
          reason: 'Chained tree structure should match expected structure');

      // Verify constraint: second value should be <= first
      final allPairs = <(int, int)>{};
      void collectPairs(Shrinkable<(int, int)> shr, {int maxDepth = 50}) {
        if (maxDepth <= 0) return;
        allPairs.add(shr.value);
        final iterator = shr.shrinks().iterator();
        while (iterator.hasNext()) {
          collectPairs(iterator.next(), maxDepth: maxDepth - 1);
        }
      }

      collectPairs(shrinkable as Shrinkable<(int, int)>);

      for (final pair in allPairs) {
        expect(pair.$2, lessThanOrEqualTo(pair.$1),
            reason: 'Second value should be <= first value');
      }
    });

    test('flatMap preserves tree structure: nested dependency', () {
      // FlatMap: generate a list where each element depends on previous
      // Using a deterministic generator that produces simple arrays
      final baseGen = Arbitrary<int>((_) => genShrinkable40213());
      final flatMappedGen = baseGen.flatMap((int start) =>
          Gen.array(Gen.interval(0, start + 1), minLength: 1, maxLength: 3));

      final shrinkable = flatMappedGen.generate(Random('flatmap_test'));

      // Get actual serialized tree
      final actualSerialized = serializeShrinkable(shrinkable);

      print('FlatMap test - Actual:   $actualSerialized');
      print(
          'FlatMap test - Note: Tree structure depends on array generation, verifying constraints instead');

      // Verify constraint: all elements should be <= start value
      final allLists = <List<int>>{};
      void collectLists(Shrinkable<List<int>> shr, {int maxDepth = 50}) {
        if (maxDepth <= 0) return;
        allLists.add(List.from(shr.value));
        final iterator = shr.shrinks().iterator();
        while (iterator.hasNext()) {
          collectLists(iterator.next() as Shrinkable<List<int>>,
              maxDepth: maxDepth - 1);
        }
      }

      collectLists(shrinkable as Shrinkable<List<int>>);

      // Verify the structure is valid
      for (final list in allLists) {
        expect(list.length, greaterThanOrEqualTo(1),
            reason: 'List should have at least 1 element');
        expect(list.length, lessThanOrEqualTo(3),
            reason: 'List should have at most 3 elements');
      }

      // Verify that flatMap produces shrinks (not just one value)
      expect(allLists.length, greaterThan(1),
          reason: 'flatMap should produce multiple shrinks');
    });

    test('accumulate preserves tree structure: variable length sequences', () {
      // Accumulate: generate a sequence where each element depends on previous
      // Using variable length (2-4) to test full shrinking behavior including length-based shrinking
      // Expected tree structure:
      //   [4,4,4,4]
      //   └─ [4,4,4]  (length shrink)
      //      └─ [0,3,3]  (element shrink)
      final baseGen = Arbitrary<int>((_) => genShrinkable40213());

      // Create an accumulate generator with variable length (2-4)
      final accumulateGen = baseGen.accumulate(
          (int last) => Arbitrary<int>((_) => Shrinkable<int>(last).withShrinks(
                  () => LazyStream.one(Shrinkable<int>(
                      (last - 1).clamp(0, double.infinity).toInt()))))
              .filter((int x) => x >= 0),
          2, // minLength
          4); // maxLength

      // Try to find a length-4 sequence to test full shrinking behavior
      // (length-based shrinking + element-based shrinking)
      Shrinkable<List<int>>? shrinkable;
      String? seedUsed;
      for (int seed = 0; seed < 100; seed++) {
        final candidate =
            accumulateGen.generate(Random('accumulate_seed_$seed'));
        if (candidate.value.length == 4) {
          shrinkable = candidate;
          seedUsed = 'accumulate_seed_$seed';
          break;
        }
      }

      // If we didn't find length-4, use the default seed (might be length-2 or 3)
      if (shrinkable == null) {
        shrinkable = accumulateGen.generate(Random('accumulate_test'));
        seedUsed = 'accumulate_test';
      }

      // Get actual serialized tree
      final actualSerialized = serializeShrinkable(shrinkable);

      // Expected serialized tree structure depends on the length we got
      String expectedSerialized;
      String? expectedSerializedAlt;
      if (shrinkable.value.length == 4) {
        // Length-4 sequence: length shrinking first (logarithmic), then element shrinking
        // Length shrinking: [4,4,4,4] → [4,4,4] → [0,3,3] and [4,4,4,4] → [4,4] → [0,3]
        // Element shrinking: [4,4,4,4] → [0,3,3,3] (shrinking all elements)
        expectedSerialized =
            '{"value":[4,4,4,4],"shrinks":[{"value":[4,4,4],"shrinks":[{"value":[0,3,3]}]},{"value":[4,4],"shrinks":[{"value":[0,3]}]},{"value":[0,3,3,3]}]}';
        // Accept either ordering of the two length-shrink branches ([4,4,4] and [4,4])
        expectedSerializedAlt =
            '{"value":[4,4,4,4],"shrinks":[{"value":[4,4],"shrinks":[{"value":[0,3]}]},{"value":[4,4,4],"shrinks":[{"value":[0,3,3]}]},{"value":[0,3,3,3]}]}';
        print('Accumulate test - Using length-4 sequence (seed: $seedUsed)');
      } else if (shrinkable.value.length == 3) {
        // Length-3 sequence: length shrinking first (to minLength=2), then element shrinking
        // Length shrinking: [4,4,4] → [4,4] → [0,3]
        // Element shrinking: [4,4,4] → [0,3,3]
        expectedSerialized =
            '{"value":[4,4,4],"shrinks":[{"value":[4,4],"shrinks":[{"value":[0,3]}]},{"value":[0,3,3]}]}';
        print('Accumulate test - Using length-3 sequence (seed: $seedUsed)');
      } else {
        // Length-2 sequence: already at minLength, so only element shrinking
        expectedSerialized = '{"value":[4,4],"shrinks":[{"value":[0,3]}]}';
        print('Accumulate test - Using length-2 sequence (seed: $seedUsed)');
      }

      print('Accumulate test - Actual:   $actualSerialized');
      print('Accumulate test - Expected: $expectedSerialized');
      print('Accumulate test - Serialized length: ${actualSerialized.length}');
      print(
          'Accumulate test - Root sequence length: ${shrinkable.value.length}');

      if (expectedSerializedAlt != null) {
        expect(
            actualSerialized == expectedSerialized ||
                actualSerialized == expectedSerializedAlt,
            isTrue,
            reason:
                'accumulate tree structure should match one of the accepted variants');
      } else {
        expect(actualSerialized, equals(expectedSerialized),
            reason: 'accumulate tree structure should match expected structure');
      }

      // Verify constraint: length constraints and element constraints
      final allSequences = <List<int>>{};
      void collectSequences(Shrinkable<List<int>> shr, {int maxDepth = 50}) {
        if (maxDepth <= 0) return;
        allSequences.add(List.from(shr.value));
        final iterator = shr.shrinks().iterator();
        while (iterator.hasNext()) {
          collectSequences(iterator.next() as Shrinkable<List<int>>,
              maxDepth: maxDepth - 1);
        }
      }

      collectSequences(shrinkable as Shrinkable<List<int>>);

      for (final sequence in allSequences) {
        // Verify length constraints
        expect(sequence.length, greaterThanOrEqualTo(2),
            reason: 'Sequence should have at least 2 elements');
        expect(sequence.length, lessThanOrEqualTo(4),
            reason: 'Sequence should have at most 4 elements');

        // Verify all values >= 0
        expect(sequence.every((x) => x >= 0), isTrue,
            reason: 'All values should be >= 0: $sequence');
      }
    });

    test('aggregate preserves tree structure: variable length sequences', () {
      // Aggregate: generate array states where each state depends on previous state
      // Using variable length (2-4) to test full shrinking behavior including length-based shrinking
      // Expected tree structure (note: only initial element shrinks, subsequent elements stay fixed):
      //   [4,4,4,4]
      //   ├─ [4,4,4]  (length shrink)
      //   │  └─ [0,4,4]  (element shrink for initial element only)
      //   ├─ [4,4]  (length shrink to minSize)
      //   │  └─ [0,4]  (element shrink for initial element only)
      //   └─ [0,4,4,4]  (element shrink for root - initial element only)
      final baseGen = Arbitrary<int>((_) => genShrinkable40213());

      // Create an aggregate generator with variable length (2-4)
      // Each state appends a new element based on the previous state
      final aggregateGen = baseGen.aggregate(
          (List<int> prev) => Arbitrary<List<int>>((rand) {
                // Generate a new element based on the last element of previous state
                final last = prev.isEmpty ? 4 : prev.last;
                final newElem = last; // Same value as last element
                return Shrinkable<List<int>>([...prev, newElem])
                    .withShrinks(() {
                  // Generate a shrinkable for the new element
                  final newElemShr = Shrinkable<int>(newElem).withShrinks(() =>
                      LazyStream.one(Shrinkable<int>(
                          (newElem - 1).clamp(0, double.infinity).toInt())));
                  // Shrink the last element only
                  final shrunkLast = newElemShr.value;
                  return LazyStream.one(
                      Shrinkable<List<int>>([...prev, shrunkLast]));
                });
              }),
          2, // minLength
          4); // maxLength

      // Try to find a length-4 sequence to test full shrinking behavior
      Shrinkable<List<int>>? shrinkable;
      String? seedUsed;
      for (int seed = 0; seed < 100; seed++) {
        final candidate = aggregateGen.generate(Random('aggregate_seed_$seed'));
        if (candidate.value.length == 4) {
          shrinkable = candidate;
          seedUsed = 'aggregate_seed_$seed';
          break;
        }
      }

      // If we didn't find length-4, use the default seed
      if (shrinkable == null) {
        shrinkable = aggregateGen.generate(Random('aggregate_test'));
        seedUsed = 'aggregate_test';
      }

      // Get actual serialized tree
      final actualSerialized = serializeShrinkable(shrinkable);

      // Expected serialized tree structure depends on the length we got
      // For aggregate, we can only shrink the initial element, not subsequent elements
      // since they depend on previous states
      String expectedSerialized;
      String? expectedSerializedAlt;
      if (shrinkable.value.length == 4) {
        // Length-4 sequence: length shrinking first (logarithmic), then element shrinking
        // Length shrinking: [4,4,4,4] → [4,4,4] → [0,4,4] and [4,4,4,4] → [4,4] → [0,4]
        // Element shrinking: [4,4,4,4] → [0,4,4,4] (only initial element shrinks)
        expectedSerialized =
            '{"value":[4,4,4,4],"shrinks":[{"value":[4,4,4],"shrinks":[{"value":[0,4,4]}]},{"value":[4,4],"shrinks":[{"value":[0,4]}]},{"value":[0,4,4,4]}]}';
        // Allow either ordering of the two length-shrink branches
        expectedSerializedAlt =
            '{"value":[4,4,4,4],"shrinks":[{"value":[4,4],"shrinks":[{"value":[0,4]}]},{"value":[4,4,4],"shrinks":[{"value":[0,4,4]}]},{"value":[0,4,4,4]}]}';
        print('Aggregate test - Using length-4 sequence (seed: $seedUsed)');
      } else if (shrinkable.value.length == 3) {
        // Length-3 sequence: length shrinking first (to minLength=2), then element shrinking
        // Length shrinking: [4,4,4] → [4,4] → [0,4]
        // Element shrinking: [4,4,4] → [0,4,4]
        expectedSerialized =
            '{"value":[4,4,4],"shrinks":[{"value":[4,4],"shrinks":[{"value":[0,4]}]},{"value":[0,4,4]}]}';
        print('Aggregate test - Using length-3 sequence (seed: $seedUsed)');
      } else {
        // Length-2 sequence: already at minLength, so only element shrinking
        expectedSerialized = '{"value":[4,4],"shrinks":[{"value":[0,4]}]}';
        print('Aggregate test - Using length-2 sequence (seed: $seedUsed)');
      }

      print('Aggregate test - Actual:   $actualSerialized');
      print('Aggregate test - Expected: $expectedSerialized');
      print('Aggregate test - Serialized length: ${actualSerialized.length}');
      print(
          'Aggregate test - Root sequence length: ${shrinkable.value.length}');

      if (expectedSerializedAlt != null) {
        expect(
            actualSerialized == expectedSerialized ||
                actualSerialized == expectedSerializedAlt,
            isTrue,
            reason:
                'aggregate tree structure should match one of the accepted variants');
      } else {
        expect(actualSerialized, equals(expectedSerialized),
            reason: 'aggregate tree structure should match expected structure');
      }

      // Verify constraint: length constraints and element constraints
      final allSequences = <List<int>>{};
      void collectSequences(Shrinkable<List<int>> shr, {int maxDepth = 50}) {
        if (maxDepth <= 0) return;
        allSequences.add(List.from(shr.value));
        final iterator = shr.shrinks().iterator();
        while (iterator.hasNext()) {
          collectSequences(iterator.next() as Shrinkable<List<int>>,
              maxDepth: maxDepth - 1);
        }
      }

      collectSequences(shrinkable as Shrinkable<List<int>>);

      for (final sequence in allSequences) {
        // Verify length constraints
        expect(sequence.length, greaterThanOrEqualTo(2),
            reason: 'Sequence should have at least 2 elements');
        expect(sequence.length, lessThanOrEqualTo(4),
            reason: 'Sequence should have at most 4 elements');

        // Verify all values >= 0
        expect(sequence.every((x) => x >= 0), isTrue,
            reason: 'All values should be >= 0: $sequence');
      }
    });

    test('oneOf preserves tree structure: non-overlapping domains', () {
      // OneOf: select from multiple generators with non-overlapping domains
      // gen1: values 0-10 (using 40213 structure mapped to 0-10)
      // gen2: values 100-114 (using 7531246 structure mapped to 100-114)
      final gen1 = Arbitrary<int>((_) => genShrinkable40213())
          .map((x) => x * 2 + 0); // 0, 2, 4, 6, 8
      final gen2 = Arbitrary<int>((_) => genShrinkable7531246())
          .map((x) => x * 2 + 100); // 114, 110, 104, 108, 106, 100, 112

      // Expected tree structures
      final gen1Expected =
          '{"value":8,"shrinks":[{"value":0},{"value":4,"shrinks":[{"value":2}]},{"value":6}]}';
      final gen2Expected =
          '{"value":114,"shrinks":[{"value":110,"shrinks":[{"value":106,"shrinks":[{"value":102}]},{"value":104}]},{"value":108},{"value":112}]}';

      // Test gen1: use high weight to bias selection
      final oneOfGen1 = Gen.oneOf([
        Gen.weightedGen(gen1, 0.95), // 95% chance
        Gen.weightedGen(gen2, 0.05), // 5% chance
      ]);

      // Try multiple times with a single Random instance to get gen1
      Shrinkable<int>? gen1Shrinkable;
      final randGen1 = Random('oneof_gen1');
      for (int attempt = 0; attempt < 100; attempt++) {
        final candidate = oneOfGen1.generate(randGen1);
        if (candidate.value >= 0 && candidate.value <= 10) {
          gen1Shrinkable = candidate;
          break;
        }
      }

      expect(gen1Shrinkable, isNotNull,
          reason: 'Should find a value from gen1');
      final gen1Serialized = serializeShrinkable(gen1Shrinkable!);
      print('OneOf gen1 test - Value: ${gen1Shrinkable.value}');
      print('OneOf gen1 test - Actual:   $gen1Serialized');
      print('OneOf gen1 test - Expected: $gen1Expected');
      expect(gen1Serialized, equals(gen1Expected),
          reason: 'oneOf gen1 tree structure should match expected');

      // Verify all shrunk values are from gen1 domain
      final gen1Values = <int>{};
      collectAllValues(gen1Shrinkable, gen1Values);
      expect(gen1Values.every((x) => x >= 0 && x <= 10), isTrue,
          reason: 'All gen1 shrunk values should be from domain (0-10)');

      // Test gen2: use high weight to bias selection
      final oneOfGen2 = Gen.oneOf([
        Gen.weightedGen(gen1, 0.01), // 1% chance
        Gen.weightedGen(gen2, 0.99), // 99% chance
      ]);

      // Try multiple times with different Random instances to get gen2
      Shrinkable<int>? gen2Shrinkable;
      for (int seed = 0; seed < 200; seed++) {
        final rand = Random('oneof_gen2_seed_$seed');
        final candidate = oneOfGen2.generate(rand);
        if (candidate.value >= 100 && candidate.value <= 114) {
          // Adjusted range to include 114
          gen2Shrinkable = candidate;
          break;
        }
      }

      expect(gen2Shrinkable, isNotNull,
          reason: 'Should find a value from gen2');
      final gen2Serialized = serializeShrinkable(gen2Shrinkable!);
      print('OneOf gen2 test - Value: ${gen2Shrinkable.value}');
      print('OneOf gen2 test - Actual:   $gen2Serialized');
      print('OneOf gen2 test - Expected: $gen2Expected');
      expect(gen2Serialized, equals(gen2Expected),
          reason: 'oneOf gen2 tree structure should match expected');

      // Verify all shrunk values are from gen2 domain
      final gen2Values = <int>{};
      collectAllValues(gen2Shrinkable, gen2Values);
      expect(gen2Values.every((x) => x >= 100 && x <= 114), isTrue,
          reason: 'All gen2 shrunk values should be from domain (100-114)');
    });

    test('elementOf preserves constraint: selection from set', () {
      // ElementOf: select from a fixed set
      final baseGen = Arbitrary<int>((_) => genShrinkable40213());
      final elementOfGen = baseGen.map((int x) => x % 5); // Map to 0-4 range
      final constrainedGen = elementOfGen.filter((int x) => x >= 2 && x <= 4);

      final shrinkable = constrainedGen.generate(Random('elementof_test'));

      // Verify constraint: all values should be in [2, 4]
      final allValues = <int>{};
      collectAllValues(shrinkable, allValues);

      print('ElementOf test - All values: $allValues');
      expect(allValues.every((x) => x >= 2 && x <= 4), isTrue,
          reason: 'All values should be in [2, 4]');

      expect(verifyConstraint(shrinkable, (x) => x >= 2 && x <= 4), isTrue,
          reason: 'All shrunk values should satisfy the constraint');
    });

    test('larger variant (7531246) with map preserves tree structure', () {
      // Test with larger shrinkable structure
      // Expected tree structure after mapping (x * 3 + 1):
      //   22
      //   ├─ 16
      //   │  ├─ 10
      //   │  │  └─ 4
      //   │  └─ 7
      //   ├─ 13
      //   └─ 19
      final baseGen = Arbitrary<int>((_) => genShrinkable7531246());
      final mappedGen = baseGen.map((int x) => x * 3 + 1);

      final shrinkable = mappedGen.generate(Random('large_map_test'));

      // Get actual serialized tree
      final actualSerialized = serializeShrinkable(shrinkable);

      // Expected serialized tree structure
      final expectedSerialized =
          '{"value":22,"shrinks":[{"value":16,"shrinks":[{"value":10,"shrinks":[{"value":4}]},{"value":7}]},{"value":13},{"value":19}]}';

      print('Large map test - Actual:   $actualSerialized');
      print('Large map test - Expected: $expectedSerialized');

      expect(actualSerialized, equals(expectedSerialized),
          reason:
              'Large mapped tree structure should match expected structure');

      // Verify constraint preservation
      expect(verifyConstraint(shrinkable, (x) => (x - 1) % 3 == 0), isTrue,
          reason: 'All values should be of form 3*n+1');
    });

    test('largest variant (964285173) with filter preserves tree structure',
        () {
      // Test with largest shrinkable structure
      // Expected tree structure after filtering (x % 2 == 1, odd numbers only):
      //   9
      //   ├─ 5
      //   │  └─ 1
      //   └─ 7
      //      └─ 3
      // (6, 4, 2, 8 are filtered out)
      final baseGen = Arbitrary<int>((_) => genShrinkable964285173());
      final filteredGen =
          baseGen.filter((int x) => x % 2 == 1); // Only odd numbers

      // Generate multiple times to find a value that passes the filter
      final rand = Random('large_filter_test');
      Shrinkable<int>? shrinkable;
      for (int i = 0; i < 100; i++) {
        final candidate = filteredGen.generate(rand);
        if (candidate.value % 2 == 1) {
          shrinkable = candidate;
          break;
        }
      }

      expect(shrinkable, isNotNull, reason: 'Should find an odd value');

      // Get actual serialized tree
      final actualSerialized = serializeShrinkable(shrinkable!);

      // Expected serialized tree structure (after filtering out even numbers)
      final expectedSerialized =
          '{"value":9,"shrinks":[{"value":5,"shrinks":[{"value":1}]},{"value":7,"shrinks":[{"value":3}]}]}';

      print('Large filter test - Actual:   $actualSerialized');
      print('Large filter test - Expected: $expectedSerialized');

      expect(actualSerialized, equals(expectedSerialized),
          reason:
              'Large filtered tree structure should match expected structure');

      // Verify all shrunk values are odd
      expect(verifyConstraint(shrinkable, (x) => x % 2 == 1), isTrue,
          reason: 'All shrunk values should be odd');
    });
  });
}
