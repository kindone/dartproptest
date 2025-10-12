# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

## [0.1.0] - 2024-01-XX

### Added
- Initial release
- Core property-based testing functionality
- All generators and combinators
- Shrinking algorithms
- Stateful testing support
- Flutter compatibility
- Complete documentation
