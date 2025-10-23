# dartproptest

`dartproptest` is a property-based testing (PBT) framework for Dart, drawing inspiration from libraries such as Haskell's QuickCheck and Python's Hypothesis. This is a port of the TypeScript [jsproptest](https://github.com/kindone/jsproptest) library to Dart. Property-based testing shifts the focus from example-based verification to defining universal *properties* or *invariants* that must hold true for an input domain.

Instead of manually crafting test cases for specific inputs, PBT allows you to describe the *domain* of inputs your function expects and the *general characteristics* of the output. `dartproptest` then generates hundreds or thousands of varied inputs, searching for edge cases or unexpected behaviors that violate your defined properties.

## Getting Started

### Installation

To add `dartproptest` to your project, add it to your `pubspec.yaml`:

```yaml
dev_dependencies:
  dartproptest: ^0.1.0
```

Then run:

```bash
dart pub get
```

## Key Features

`dartproptest` offers a rich set of features to empower your property-based testing efforts:

*   **Built-in Generators:** A comprehensive suite of generators for common data types (integers, strings, arrays, objects, etc.) and the ability to create custom generators.
*   **Powerful Combinators:** Flexible combinators to compose, transform, and filter generators, enabling the creation of complex and highly specific data structures.
*   **Automatic Shrinking:** When a test fails, `dartproptest` automatically tries to find the smallest possible input that still causes the failure, making debugging much easier.
*   **Stateful Testing:** Support for testing stateful systems by generating sequences of actions or commands and verifying invariants across these sequences.
*   **Flutter Compatible:** Works seamlessly across all Dart platforms including Flutter web, mobile, and desktop applications.

## Quick Example

```dart
import 'package:dartproptest/dartproptest.dart';

void main() {
  forAll(
    (int a, int b) => a + b == b + a,
    [Gen.interval(0, 100), Gen.interval(0, 100)],
  );

  // Works with any number of arguments
  forAll(
    (int a, int b, int c) => (a + b) + c == a + (b + c),
    [Gen.interval(0, 50), Gen.interval(0, 50), Gen.interval(0, 50)],
  );
}
```

## Flutter Compatibility

`dartproptest` is fully compatible with Flutter and works across all Dart platforms:

## Documentation

For comprehensive documentation, including core concepts, API reference, and advanced features, please visit the **[Documentation](doc/index.md)**.

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.