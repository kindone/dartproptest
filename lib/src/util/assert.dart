import 'error.dart';

/// Utility function to create a precondition that can be used in property tests.
///
/// When a precondition fails, it throws a [PreconditionError] which causes
/// the property test to skip the current input and try another one.
///
/// Example:
/// ```dart
/// forAll((int x) {
///   precond(x > 0); // Skip negative numbers
///   return x * x >= 0;
/// }, Gen.integers());
/// ```
// ignore: avoid_positional_boolean_parameters
void precond(bool condition, [String? message]) {
  if (!condition) {
    throw PreconditionError(message ?? 'Precondition failed');
  }
}
