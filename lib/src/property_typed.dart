import 'generator.dart';
import 'random.dart';
import 'util/error.dart';
import 'util/json.dart';
import 'typed_function.dart';

/// Enhanced property-based testing with type-safe function support
///
/// This module provides type-safe alternatives to the standard forAll function,
/// allowing you to write cleaner, more type-safe property tests.

/// Type-safe version of forAll that accepts a TypedFunction
///
/// [typedFunc] A TypedFunction that provides runtime type checking
/// [gens] Generators for each argument of the test function
/// [numRuns] Number of test runs (default: 200)
/// [seed] Optional seed for reproducible tests
/// Returns `true` if the property holds for all runs
/// Throws An error describing the failure and the smallest failing arguments found
bool forAllTyped<T>(
  TypedFunction<T> typedFunc,
  List<Generator<dynamic>> gens, {
  int numRuns = 200,
  String seed = '',
}) {
  if (gens.length != typedFunc.argTypes.length) {
    throw ArgumentError(
        'Number of generators (${gens.length}) must match number of argument types (${typedFunc.argTypes.length})');
  }

  final random = seed.isEmpty ? Random() : Random(seed);
  int numPrecondFailures = 0;
  dynamic result = true;

  for (int i = 0; i < numRuns; i++) {
    final savedRandom = random.clone();

    try {
      final args = gens.map((gen) => gen.generate(random).value).toList();

      // Use the typed function with runtime type checking
      result = typedFunc(args);

      if (result == false) {
        throw Exception('Property failed with args: $args');
      }
    } on PreconditionError {
      numPrecondFailures++;
      if (numPrecondFailures > numRuns * 0.5) {
        throw Exception('Too many precondition failures: $numPrecondFailures');
      }
      continue;
    } catch (e) {
      // Attempt to shrink the failing arguments
      final shrinkResult = _shrinkFailingArgs(typedFunc, gens, savedRandom, e);
      final errorMsg = _formatFailureMessage(
        typedFunc.argTypes,
        shrinkResult.args,
        shrinkResult.error,
        shrinkResult.failedArgs,
        shrinkResult.isSuccessful,
      );
      throw Exception(errorMsg);
    }
  }

  return true;
}

/// Convenience function for type-safe property testing with 1 argument
bool forAll1<A>(
  bool Function(A) func,
  Generator<A> genA, {
  int numRuns = 200,
  String seed = '',
}) {
  final typedFunc = TypedFunction.oneArg(func);
  return forAllTyped(typedFunc, [genA], numRuns: numRuns, seed: seed);
}

/// Convenience function for type-safe property testing with 2 arguments
bool forAll2<A, B>(
  bool Function(A, B) func,
  Generator<A> genA,
  Generator<B> genB, {
  int numRuns = 200,
  String seed = '',
}) {
  final typedFunc = TypedFunction.twoArgs(func);
  return forAllTyped(typedFunc, [genA, genB], numRuns: numRuns, seed: seed);
}

/// Convenience function for type-safe property testing with 3 arguments
bool forAll3<A, B, C>(
  bool Function(A, B, C) func,
  Generator<A> genA,
  Generator<B> genB,
  Generator<C> genC, {
  int numRuns = 200,
  String seed = '',
}) {
  final typedFunc = TypedFunction.threeArgs(func);
  return forAllTyped(typedFunc, [genA, genB, genC],
      numRuns: numRuns, seed: seed);
}

/// Convenience function for type-safe property testing with 4 arguments
bool forAll4<A, B, C, D>(
  bool Function(A, B, C, D) func,
  Generator<A> genA,
  Generator<B> genB,
  Generator<C> genC,
  Generator<D> genD, {
  int numRuns = 200,
  String seed = '',
}) {
  final typedFunc = TypedFunction.fourArgs(func);
  return forAllTyped(typedFunc, [genA, genB, genC, genD],
      numRuns: numRuns, seed: seed);
}

/// Convenience function for type-safe property testing with 5 arguments
bool forAll5<A, B, C, D, E>(
  bool Function(A, B, C, D, E) func,
  Generator<A> genA,
  Generator<B> genB,
  Generator<C> genC,
  Generator<D> genD,
  Generator<E> genE, {
  int numRuns = 200,
  String seed = '',
}) {
  final typedFunc = TypedFunction.fiveArgs(func);
  return forAllTyped(typedFunc, [genA, genB, genC, genD, genE],
      numRuns: numRuns, seed: seed);
}

/// Internal class to hold the results of a shrinking operation
class _ShrinkResult {
  final bool isSuccessful;
  final List<dynamic> args;
  final Object? error;
  final List<(int, String)>? failedArgs;

  _ShrinkResult(this.args, [this.error, this.failedArgs])
      : isSuccessful = error != null;
}

/// Attempts to shrink failing arguments to find a minimal failing case
_ShrinkResult _shrinkFailingArgs<T>(
  TypedFunction<T> typedFunc,
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
            _testWithReplace(typedFunc, args, n, nextShrinkable.value);

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
dynamic _testWithReplace(TypedFunction<dynamic> typedFunc, List<dynamic> args,
    int n, dynamic replace) {
  final newArgs = [...args.sublist(0, n), replace, ...args.sublist(n + 1)];
  return _test(typedFunc, newArgs);
}

/// Executes the core property function once with the given arguments.
/// Handles exceptions and captures results.
///
/// Returns `true` on success, `false` if the function returns false, or the Exception if it throws.
dynamic _test(TypedFunction<dynamic> typedFunc, List<dynamic> args) {
  try {
    final result = typedFunc(args);
    if (result == false) {
      return false; // Explicit false return means failure
    }
    return true;
  } catch (e) {
    // Catch exceptions
    return e;
  }
}

/// Formats a failure message with type information
String _formatFailureMessage(
  List<Type> argTypes,
  List<dynamic> args,
  Object? error,
  List<(int, String)>? failedArgs,
  bool shrunk,
) {
  final buffer = StringBuffer();

  if (shrunk) {
    buffer.writeln(
        'property failed (simplest args found by shrinking): ${JSONStringify.call(args)}');
    if (failedArgs != null && failedArgs.isNotEmpty) {
      for (final (index, argStr) in failedArgs) {
        buffer.writeln('  shrinking found simpler failing arg $index: $argStr');
      }
    }
  } else {
    buffer.writeln('property failed (args found): ${JSONStringify.call(args)}');
  }

  buffer.writeln('Typed arguments:');
  for (int i = 0; i < args.length; i++) {
    buffer.writeln(
        '  ${argTypes[i].toString()} arg$i: ${JSONStringify.call(args[i])}');
  }

  if (error != null) {
    buffer.writeln('Error: $error');
  }

  return buffer.toString();
}
