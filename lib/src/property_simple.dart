import 'generator_simple.dart';
import 'random.dart';

/// Simple property test function
bool simpleForAll(dynamic func, List<SimpleGenerator<dynamic>> gens) {
  final random = Random();

  for (int i = 0; i < 100; i++) {
    final args = gens.map((gen) => gen.generate(random).value).toList();

    try {
      final dynamic result = Function.apply(func as Function, args);
      if (result == false) {
        throw Exception('Property failed with args: $args');
      }
    } catch (e) {
      throw Exception('Property failed with args: $args, error: $e');
    }
  }

  return true;
}
