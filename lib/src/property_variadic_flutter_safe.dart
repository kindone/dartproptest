import 'generator.dart';
import 'random.dart';
import 'util/error.dart';
import 'util/json.dart';

/// Flutter-compatible main entry point for property-based testing.
///
/// This function works across all Dart platforms including Flutter.
/// It provides the same API as the mirrors-based version but uses
/// Function.apply for compatibility.
///
/// Example:
/// ```dart
/// forAll(
///   (int a, int b) => a + b == b + a,
///   [Gen.interval(0, 100), Gen.interval(0, 100)],
/// );
/// ```
bool forAll<T>(
  Function func,
  List<Generator<dynamic>> generators, {
  int numRuns = 200,
  String seed = '',
}) {
  final random = seed.isEmpty ? Random() : Random(seed);
  int numPrecondFailures = 0;
  dynamic result = true;

  for (int i = 0; i < numRuns; i++) {
    final savedRandom = random.clone();

    try {
      final args = generators.map((gen) => gen.generate(random).value).toList();

      // Use Function.apply to call the function with the generated arguments
      result = Function.apply(func, args);

      if (result == false) {
        throw Exception('Property failed with args: $args');
      }
    } on PreconditionError {
      numPrecondFailures++;
      if (numPrecondFailures >= numRuns) {
        throw Exception(
            'Property failed: Too many precondition failures ($numPrecondFailures)');
      }
      continue;
    } on NoSuchMethodError catch (e) {
      // Handle argument count/type mismatches
      if (e.toString().contains('Closure call with mismatched arguments')) {
        throw ArgumentError(
            'Function signature does not match provided generators. '
            'Expected ${_extractExpectedArgs(e.toString())} arguments, '
            'but got ${generators.length} generators.');
      }
      rethrow;
    } catch (e) {
      // Attempt to shrink the failing arguments
      final shrinkResult =
          _shrinkFailingArgs<dynamic>(func, generators, savedRandom, e);
      throw _processFailureAsError(e, shrinkResult);
    }
  }

  return true;
}

/// Alias for the main forAll function (for backward compatibility)
bool forAllVariadic<T>(
  Function func,
  List<Generator<dynamic>> generators, {
  int numRuns = 200,
  String seed = '',
}) {
  return forAll<T>(func, generators, numRuns: numRuns, seed: seed);
}

/// Alternative implementation using a simpler approach without mirrors
/// This version uses a more direct method that works across all Dart platforms
bool forAllSimple<T>(
  Function func,
  List<Generator<dynamic>> generators, {
  int numRuns = 200,
  String seed = '',
}) {
  return forAll<T>(func, generators, numRuns: numRuns, seed: seed);
}

/// Internal class to hold the results of a shrinking operation.
class _ShrinkResult {
  /// Flag indicating if shrinking found a simpler failing case.
  final bool isSuccessful;

  /// The simplest arguments found that still cause the property to fail.
  final List<dynamic> args;

  /// The error object thrown by the property function for the simplest failing case.
  final Object? error;

  /// History of shrinking steps taken (argument index, stringified args).
  final List<(int, String)>? failedArgs;

  _ShrinkResult(this.args, [this.error, this.failedArgs])
      : isSuccessful = error != null;
}

/// Attempts to shrink failing arguments to find a minimal failing case
_ShrinkResult _shrinkFailingArgs<T>(
  Function func,
  List<Generator<dynamic>> gens,
  Random random,
  Object originalError,
) {
  // Regenerate the initial failing shrinkables using the saved random state
  final shrinkables = gens.map((gen) => gen.generate(random)).toList();

  final List<(int, String)> failedArgs =
      []; // History of successful shrink steps (for reporting)

  // Start with the original failing arguments as the current best candidate
  final args = shrinkables.map((shr) => shr.value).toList();
  bool shrunk = false; // Flag: Did we find any simpler failing case?
  dynamic result =
      originalError; // Stores the failure result (Error or false) of the simplest case found

  // Iterate through each argument position (index n)
  for (int n = 0; n < shrinkables.length; n++) {
    var shrinks = shrinkables[n]
        .shrinks(); // Get the shrink candidates for the nth argument

    // Repeatedly try to shrink argument n as long as we find simpler failing values
    while (!shrinks.isEmpty()) {
      final iter = shrinks.iterator();
      bool shrinkFound =
          false; // Found a smaller failing value for arg n in this pass?

      // Test each shrink candidate for the current argument n
      while (iter.hasNext()) {
        final nextShrinkable = iter.next();
        // Test the property with arg n replaced by the shrink candidate value
        final testResult =
            _testWithReplace(func, args, n, nextShrinkable.value);

        // Check if this smaller value *also* causes a failure (ignoring PreconditionError)
        if (testResult is PreconditionError) {
          // Skip precondition failures during shrinking
          continue;
        }
        if ((testResult is Exception) || testResult == false) {
          // Yes, this shrink is a new, simpler failing case
          result = testResult;
          shrinks = nextShrinkable
              .shrinks(); // Get shrinks for this *new*, smaller value
          args[n] = nextShrinkable.value;
          shrinkFound = true;
          break; // Stop testing other shrinks at this level, focus on the new smaller value
        }
      }

      if (shrinkFound) {
        // Record the successful shrink step for reporting
        failedArgs.add((n, JSONStringify.call(args)));
        shrunk = true;
        // Continue shrinking the *same* argument (n) further
      } else {
        // No shrink candidate for arg n at this level caused a failure
        break; // Stop shrinking arg n, move to the next argument (n+1)
      }
    }
  }

  if (shrunk) {
    // If shrinking was successful
    if (result is Object) {
      return _ShrinkResult(args, result, failedArgs);
    } else {
      // If the failure was returning false, create a placeholder error
      final error = Exception('  property returned false\n');
      return _ShrinkResult(args, error, failedArgs);
    }
  } else {
    // If no shrinking was possible
    return _ShrinkResult(args, originalError, null);
  }
}

/// Helper to test the property with one argument replaced.
/// Used during the shrinking process.
dynamic _testWithReplace(
    Function func, List<dynamic> args, int n, dynamic replace) {
  final newArgs = [...args.sublist(0, n), replace, ...args.sublist(n + 1)];
  return _test(func, newArgs);
}

/// Executes the core property function once with the given arguments.
/// Handles exceptions and captures results.
///
/// Returns `true` on success, `false` if the function returns false, or the Exception if it throws.
dynamic _test(Function func, List<dynamic> args) {
  try {
    final result = Function.apply(func, args);
    if (result == false) {
      return false; // Explicit false return means failure
    }
    return true;
  } catch (e) {
    // Catch exceptions
    return e;
  }
}

/// Constructs the final Exception object to be thrown when a property fails.
/// Includes information about the original failure and the shrinking process.
Exception _processFailureAsError(dynamic result, _ShrinkResult shrinkResult) {
  // shrink
  if (shrinkResult.isSuccessful) {
    // Case 1: Shrinking was successful
    final shrinkLines = shrinkResult.failedArgs?.map(((int, String) step) {
          return '  shrinking found simpler failing arg ${step.$1}: ${step.$2}';
        }).toList() ??
        <String>[];

    // Construct message with simplest args
    final newError = Exception(
        'property failed (simplest args found by shrinking): ${JSONStringify.call(shrinkResult.args)}\n' +
            shrinkLines.join('\n'));
    if (shrinkResult.error != null) {
      return Exception(
          '${newError.toString()}\n  ${shrinkResult.error.toString()}');
    }
    return newError;
  }
  // not shrunk
  else {
    // Case 2: Shrinking did not find a simpler failing case
    // Construct message with original failing args
    final newError = Exception(
        'property failed (args found): ${JSONStringify.call(shrinkResult.args)}');

    if (result is Object) {
      // Subcase 2a: The original failure was an Exception
      return Exception('${newError.toString()}\n  ${result.toString()}');
    } else {
      // Subcase 2b: The original failure was returning false
      return Exception('${newError.toString()}\nproperty returned false\n');
    }
  }
}

/// Extracts expected argument count from NoSuchMethodError message
int _extractExpectedArgs(String errorMessage) {
  // Parse error message like: "Tried calling: function(3, 0) Found: function(int, int, int) => bool"
  final foundMatch = RegExp(r'Found: .*\(([^)]*)\)').firstMatch(errorMessage);
  if (foundMatch != null) {
    final params = foundMatch.group(1)?.trim();
    if (params == null || params.isEmpty) return 0;
    return params.split(',').length;
  }
  return 0;
}
