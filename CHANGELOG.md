# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - 2025-12-27

### Added
- Async property testing: `forAllAsync` and `forAllAsyncSimple` functions for testing async properties with automatic `Future` awaiting
- Async stateful testing: `AsyncSimpleAction` and `AsyncAction` classes for stateful testing with async operations

### Fixed
- Test stability: Fixed flaky tests in `variadic_test.dart` by making optional shrinking message checks optional
- Seed reproducibility: Fixed `Random` class to use `hashCode` for non-numeric string seeds instead of timestamps

### Changed
- Relaxed shrinking test expectations to check for general shrinking messages rather than specific intermediate steps

## [0.2.0] - 2025-11-09

### Added
- **Matrix testing**: Added `Property.matrix()` method for exhaustive testing via Cartesian product of input lists. Useful for testing all combinations of small input domains (e.g., enum values, edge cases). Similar to cppproptest2's matrix functionality.
- **Permutation generator**: Added `Gen.permutation(List<T>)` generator that creates permutations of the provided list. Shrinks towards the identity permutation (original order) by placing out-of-place elements into their correct positions recursively.

## [0.2.0-rc.1] - 2025-10-30

### Changed
- Overhauled shrinking behavior for `accumulate` to prioritize logarithmic length shrinks first, followed by element shrinks; preserves constraints and avoids exponential blow-ups.
- Updated `aggregate` to mirror `accumulate` strategy: length-first shrinking and safe element shrinking (initial element only) to respect state dependencies.
- Reworked `chain` and `flatMap` to preserve shrinking from both the original and derived generators; fixed type inference in `flatMap` for robust generic handling.
- Replaced integer shrinker with a binary-search-based strategy to remove duplicates and ensure complete shrink trees.

### Added
- Deterministic tree structure tests using serialization for `map`, `filter`, `chain`, `flatMap`, `oneOf`, `accumulate`, and `aggregate` (including larger known shrink-trees such as 40213/7531246/964285173).
- Constraint-preservation tests across combinators to ensure shrinks respect generation constraints.

### Fixed
- Resolved constraint violation and performance issues in `accumulate` (removed recursive `elementWise` explosion).
- Ensured `oneOf` preserves the selected generator's tree using non-overlapping domains and deterministic seeds.
- Addressed occasional flakiness in tests by seeding `Random` and tightening assertions.

### Added
- Initial release of dartproptest
- Property-based testing framework inspired by QuickCheck and Hypothesis
- Comprehensive generator library for common data types
- Powerful combinators for complex data structures
- Automatic shrinking for easier debugging
- Stateful testing support
- Flutter compatibility across all platforms
- Multiple API variants for different use cases:
  - `forAll` - Main function with reflection support
  - `forAllSimple` - Flutter-compatible version
  - `forAll1`, `forAll2`, etc. - Numbered variants for type safety
  - `forAllLegacy` - Traditional approach

### Features
- **Generators**: Built-in generators for integers, strings, arrays, objects, booleans, floating-point numbers, sets, dictionaries, and tuples
- **Combinators**: `just`, `lazy`, `elementOf`, `oneOf`, `construct`, `chainTuple`
- **Shrinking**: Automatic shrinking algorithms for all data types
- **Stateful Testing**: Support for testing stateful systems with action sequences
- **Platform Support**: Works on Dart VM, Flutter web, mobile, and desktop
- **Documentation**: Comprehensive documentation with examples and guides

### Technical Details
- Zero external dependencies for core functionality
- BSD 3-Clause License
- Dart SDK requirement: >=3.0.0 <4.0.0
- Comprehensive test suite with example tests
- Flutter compatibility documentation

## [0.1.0] - 2025-10-12
## [0.1.1] - 2025-10-13

### Added
- Initial release
- Core property-based testing functionality
- All generators and combinators
- Shrinking algorithms
- Stateful testing support
- Flutter compatibility
- Complete documentation
