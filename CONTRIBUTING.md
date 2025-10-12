# Contributing to dartproptest

Thank you for your interest in contributing to dartproptest! This document provides guidelines and information for contributors.

## Getting Started

### Prerequisites
- Dart SDK >= 3.0.0
- Git
- A code editor (VS Code, IntelliJ IDEA, etc.)

### Setting Up Development Environment

1. **Fork and clone the repository**
   ```bash
   git clone https://github.com/kindone/dartproptest.git
   cd dartproptest
   ```

2. **Install dependencies**
   ```bash
   dart pub get
   ```

3. **Run tests to ensure everything works**
   ```bash
   dart test
   ```

4. **Run analysis to check code quality**
   ```bash
   dart analyze
   ```

## Development Workflow

### Branch Strategy
- `main`: Stable, production-ready code
- `develop`: Integration branch for features
- `feature/*`: Feature development branches
- `bugfix/*`: Bug fix branches
- `hotfix/*`: Critical bug fixes

### Making Changes

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Follow the coding standards (see below)
   - Add tests for new functionality
   - Update documentation as needed

3. **Run tests and analysis**
   ```bash
   dart test
   dart analyze
   dart format --set-exit-if-changed .
   ```

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: add new generator for custom types"
   ```

5. **Push and create a pull request**
   ```bash
   git push origin feature/your-feature-name
   ```

## Coding Standards

### Code Style
- Follow Dart's official style guide
- Use `dart format` to format code
- Follow the linter rules defined in `analysis_options.yaml`
- Use meaningful variable and function names
- Add documentation for public APIs

### Documentation
- Use Dart's documentation comments (`///`)
- Include examples in documentation
- Update README.md for user-facing changes
- Update CHANGELOG.md for significant changes

### Testing
- Write tests for all new functionality
- Maintain or improve test coverage
- Use descriptive test names
- Test edge cases and error conditions

### Commit Messages
Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
type(scope): description

[optional body]

[optional footer(s)]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Test changes
- `chore`: Maintenance tasks

Examples:
```
feat(generators): add custom type generator
fix(shrinking): handle edge case in array shrinking
docs(readme): update installation instructions
```

## Areas for Contribution

### High Priority
- **Performance improvements**: Optimize generator and shrinking algorithms
- **New generators**: Add generators for more data types
- **Better error messages**: Improve debugging experience
- **Documentation**: Improve examples and guides

### Medium Priority
- **IDE support**: Better integration with development tools
- **Advanced shrinking**: More sophisticated shrinking strategies
- **Stateful testing**: Enhanced stateful testing capabilities
- **Platform support**: Better Flutter integration

### Low Priority
- **Tooling**: Additional development tools
- **Examples**: More comprehensive examples
- **Benchmarks**: Performance benchmarking tools

## Testing Guidelines

### Running Tests
```bash
# Run all tests
dart test

# Run specific test file
dart test test/generator_test.dart

# Run tests with coverage
dart test --coverage=coverage
```

### Writing Tests
- Test both success and failure cases
- Use property-based testing to test the testing framework itself
- Include edge cases and boundary conditions
- Test error handling and validation

### Test Structure
```dart
import 'package:test/test.dart';
import 'package:dartproptest/dartproptest.dart';

void main() {
  group('Generator Tests', () {
    test('should generate valid integers', () {
      // Test implementation
    });

    test('should handle edge cases', () {
      // Edge case testing
    });
  });
}
```

## Pull Request Process

### Before Submitting
- [ ] Code follows style guidelines
- [ ] All tests pass
- [ ] Code analysis passes
- [ ] Documentation updated
- [ ] CHANGELOG.md updated (if applicable)

### Pull Request Template
When creating a pull request, please include:

1. **Description**: What changes are being made and why
2. **Type**: Feature, bug fix, documentation, etc.
3. **Testing**: How the changes were tested
4. **Breaking Changes**: Any breaking changes and migration path
5. **Related Issues**: Link to related issues

### Review Process
- All pull requests require review
- Address feedback promptly
- Keep pull requests focused and small
- Update documentation as needed

## Issue Reporting

### Bug Reports
When reporting bugs, please include:
- Dart SDK version
- Operating system
- Steps to reproduce
- Expected behavior
- Actual behavior
- Code example (if applicable)

### Feature Requests
For feature requests, please include:
- Use case description
- Proposed API design
- Benefits and drawbacks
- Alternative solutions considered

## Release Process

### Versioning
We follow [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Schedule
- **Patch releases**: As needed for bug fixes
- **Minor releases**: Monthly for new features
- **Major releases**: As needed for breaking changes

## Community Guidelines

### Code of Conduct
- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow
- Follow the golden rule

### Getting Help
- Check existing issues and discussions
- Ask questions in GitHub Discussions
- Join community conversations
- Help others when you can

## Recognition

Contributors will be recognized in:
- CONTRIBUTORS.md file
- Release notes
- Project documentation
- Community acknowledgments

## License

By contributing to dartproptest, you agree that your contributions will be licensed under the BSD 3-Clause License.

## Questions?

If you have questions about contributing, please:
1. Check existing documentation
2. Search existing issues
3. Create a new issue with the "question" label
4. Start a discussion in GitHub Discussions

Thank you for contributing to dartproptest! 🎉
