import 'generator.dart';
import 'random.dart';
import 'util/error.dart';
import 'util/json.dart';

/// Async entry point for property-based testing.
///
/// This function works across all Dart platforms including Flutter.
/// It uses Function.apply to call async functions with generated arguments.
///
/// Example:
/// ```dart
/// await forAllAsync(
///   (int a, int b) async {
///     final result = await someAsyncOperation(a, b);
///     return result == expectedValue;
///   },
///   [Gen.interval(0, 100), Gen.interval(0, 100)],
/// );
/// ```
Future<bool> forAllAsync<T>(
  Function func,
  List<Generator<dynamic>> generators, {
  int numRuns = 200,
  String seed = '',
}) async {
  final random = seed.isEmpty ? Random() : Random(seed);
  int numPrecondFailures = 0;
  dynamic result = true;

  for (int i = 0; i < numRuns; i++) {
    final savedRandom = random.clone();

    try {
      final args = generators.map((gen) => gen.generate(random).value).toList();

      // Use Function.apply to call the function with the generated arguments
      result = Function.apply(func, args);

      // Await the result if it's a Future
      if (result is Future) {
        result = await result;
      }

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
    } catch (e) {
      // Attempt to shrink the failing arguments
      final shrinkResult =
          await _shrinkFailingArgsAsync<dynamic>(func, generators, savedRandom, e);
      throw Exception(
          'Property failed with args: ${shrinkResult.args}\nError: $e');
    }
  }

  return true;
}

/// Async alternative implementation using a simpler approach without mirrors
/// This version uses a more direct method that works across all Dart platforms
Future<bool> forAllAsyncSimple<T>(
  Function func,
  List<Generator<dynamic>> generators, {
  int numRuns = 200,
  String seed = '',
}) async {
  final random = seed.isEmpty ? Random() : Random(seed);
  int numPrecondFailures = 0;
  dynamic result = true;

  for (int i = 0; i < numRuns; i++) {
    final savedRandom = random.clone();

    try {
      final args = generators.map((gen) => gen.generate(random).value).toList();

      // Use Function.apply to call the function with the generated arguments
      result = Function.apply(func, args);

      // Await the result if it's a Future
      if (result is Future) {
        result = await result;
      }

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
      // For now, just throw the error with the failing arguments
      final args =
          generators.map((gen) => gen.generate(savedRandom).value).toList();
      final errorMsg = _formatSimpleFailureMessage(args, e);
      throw Exception(errorMsg);
    }
  }

  return true;
}

/// Formats a failure message for the simple approach
String _formatSimpleFailureMessage(List<dynamic> args, Object error) {
  final buffer = StringBuffer();
  buffer.writeln('Property failed with arguments:');

  for (int i = 0; i < args.length; i++) {
    buffer.writeln('  arg$i: ${JSONStringify.call(args[i])}');
  }

  buffer.writeln('Error: $error');

  return buffer.toString();
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

/// Attempts to shrink failing arguments to find a minimal failing case (async version)
Future<_ShrinkResult> _shrinkFailingArgsAsync<T>(
  Function func,
  List<Generator<dynamic>> gens,
  Random random,
  Object originalError,
) async {
  // For now, return the original failing case
  // In a full implementation, this would attempt to shrink the arguments
  final args = gens.map((gen) => gen.generate(random).value).toList();
  return _ShrinkResult(args, originalError, null);
}
