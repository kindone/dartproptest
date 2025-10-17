import 'package:test/test.dart';
import 'package:dartproptest/dartproptest.dart';

void main() {
  group('Stateful Property Failure Testing', () {
    test('Action execution failure - assertion error', () {
      // Test that assertion failures in actions are properly caught
      final failingAction = Action<List<int>, Map<String, int>>((obj, model) {
        obj.add(42);
        // This assertion will fail when the list length doesn't match expectation
        expect(
            obj.length, equals(1)); // Will fail if list was not empty initially
        model['count'] = (model['count'] ?? 0) + 1;
      }, 'failing_assertion');

      final actionFactory = (List<int> obj, Map<String, int> model) {
        return just(failingAction);
      };

      final prop = statefulProperty(
        just(<int>[1, 2, 3]), // Start with non-empty list
        (obj) => {'count': 0},
        actionFactory,
      );

      expect(() => prop.setNumRuns(1).setMaxActions(1).go(),
          throwsA(isA<TestFailure>()));
    });

    test('Action execution failure - runtime exception', () {
      // Test that runtime exceptions in actions are properly caught
      final failingAction = Action<List<int>, Map<String, int>>((obj, model) {
        if (obj.length > 2) {
          throw StateError('List too long: ${obj.length}');
        }
        obj.add(42);
        model['count'] = (model['count'] ?? 0) + 1;
      }, 'runtime_exception');

      final actionFactory = (List<int> obj, Map<String, int> model) {
        return just(failingAction);
      };

      final prop = statefulProperty(
        just(<int>[1, 2, 3, 4]), // Start with long list
        (obj) => {'count': 0},
        actionFactory,
      );

      expect(() => prop.setNumRuns(1).setMaxActions(1).go(),
          throwsA(isA<StateError>()));
    });

    test('Post-check failure - assertion error', () {
      // Test that assertion failures in post-check are properly caught
      final action = Action<List<int>, Map<String, int>>((obj, model) {
        obj.add(42);
        model['count'] = (model['count'] ?? 0) + 1;
      }, 'add');

      final actionFactory = (List<int> obj, Map<String, int> model) {
        return just(action);
      };

      final prop = statefulProperty(
        just(<int>[]),
        (obj) => {'count': 0},
        actionFactory,
      );

      // Set a post-check that will fail
      prop.setPostCheck((obj, model) {
        expect(
            obj.length, equals(0)); // Will fail because action added an element
      });

      expect(() => prop.setNumRuns(1).setMaxActions(1).go(),
          throwsA(isA<TestFailure>()));
    });

    test('Post-check failure - custom exception', () {
      // Test that custom exceptions in post-check are properly caught
      final action = Action<List<int>, Map<String, int>>((obj, model) {
        obj.add(42);
        model['count'] = (model['count'] ?? 0) + 1;
      }, 'add');

      final actionFactory = (List<int> obj, Map<String, int> model) {
        return just(action);
      };

      final prop = statefulProperty(
        just(<int>[]),
        (obj) => {'count': 0},
        actionFactory,
      );

      // Set a post-check that will throw a custom exception
      prop.setPostCheck((obj, model) {
        if (obj.length > 0) {
          throw ArgumentError('Post-check failed: list should be empty');
        }
      });

      expect(() => prop.setNumRuns(1).setMaxActions(1).go(),
          throwsA(isA<ArgumentError>()));
    });

    test('Model inconsistency failure', () {
      // Test that model inconsistencies are detected
      final inconsistentAction =
          Action<List<int>, Map<String, int>>((obj, model) {
        obj.add(42);
        // Intentionally make model inconsistent with object
        model['count'] = (model['count'] ?? 0) + 2; // Should be +1, not +2
      }, 'inconsistent_model');

      final actionFactory = (List<int> obj, Map<String, int> model) {
        return just(inconsistentAction);
      };

      final prop = statefulProperty(
        just(<int>[]),
        (obj) => {'count': 0},
        actionFactory,
      );

      // Post-check that verifies model consistency
      prop.setPostCheck((obj, model) {
        expect(model['count'], equals(obj.length));
      });

      expect(() => prop.setNumRuns(1).setMaxActions(1).go(),
          throwsA(isA<TestFailure>()));
    });

    test('State-dependent action failure', () {
      // Test failure when action is executed in invalid state
      final invalidAction = Action<List<int>, Map<String, int>>((obj, model) {
        // This action assumes the list is not empty, but it might be
        final lastElement = obj.removeLast(); // Will throw if list is empty
        model['count'] = (model['count'] ?? 0) - 1;
      }, 'remove_last');

      final actionFactory = (List<int> obj, Map<String, int> model) {
        // Always return the invalid action, even when list is empty
        return just(invalidAction);
      };

      final prop = statefulProperty(
        just(<int>[]), // Start with empty list
        (obj) => {'count': 0},
        actionFactory,
      );

      expect(() => prop.setNumRuns(1).setMaxActions(1).go(),
          throwsA(isA<RangeError>()));
    });

    test('Complex state failure - counter overflow', () {
      // Test failure in complex state management with simple types
      final incrementAction = Action<List<int>, Map<String, int>>((obj, model) {
        obj.add(1);
        model['count'] = (model['count'] ?? 0) + 1;
        // Bug: don't check for overflow
        model['total'] = (model['total'] ?? 0) + 1;
      }, 'increment');

      final decrementAction = Action<List<int>, Map<String, int>>((obj, model) {
        if (obj.isNotEmpty) {
          obj.removeLast();
          model['count'] = (model['count'] ?? 0) - 1;
          model['total'] = (model['total'] ?? 0) - 1;
        }
      }, 'decrement');

      final actionFactory = (List<int> obj, Map<String, int> model) {
        final operations = model['operations'] ?? 0;

        if (operations < 3) {
          return just(incrementAction);
        } else {
          return just(decrementAction);
        }
      };

      final prop = statefulProperty(
        just(<int>[]),
        (obj) => {'count': 0, 'total': 0, 'operations': 0},
        actionFactory,
      );

      // Post-check that verifies count consistency
      prop.setPostCheck((obj, model) {
        expect(model['count'], equals(obj.length));
        expect(model['total'], greaterThanOrEqualTo(0));
      });

      expect(() => prop.setNumRuns(1).setMaxActions(5).go(),
          returnsNormally); // This should pass
    });

    test('State invariant failure - negative count', () {
      // Test failure when state invariants are violated
      final popAction = Action<List<int>, Map<String, int>>((obj, model) {
        if (obj.isNotEmpty) {
          obj.removeLast();
          model['count'] = (model['count'] ?? 0) - 1;
        } else {
          // Bug: decrement count even when list is empty
          model['count'] = (model['count'] ?? 0) - 1;
        }
      }, 'pop');

      final actionFactory = (List<int> obj, Map<String, int> model) {
        return just(popAction);
      };

      final prop = statefulProperty(
        just(<int>[]), // Start with empty list
        (obj) => {'count': 0},
        actionFactory,
      );

      // Post-check that verifies count is never negative
      prop.setPostCheck((obj, model) {
        expect(model['count'], greaterThanOrEqualTo(0));
      });

      expect(() => prop.setNumRuns(1).setMaxActions(2).go(),
          throwsA(isA<TestFailure>()));
    });

    test('Shrinking with stateful failures', () {
      // Test that stateful failures can be shrunk to minimal cases
      final conditionalFailingAction =
          Action<List<int>, Map<String, int>>((obj, model) {
        obj.add(42);
        // Only fail if the list has more than 2 elements
        if (obj.length > 2) {
          expect(obj.length, equals(1)); // This will fail
        }
        model['count'] = (model['count'] ?? 0) + 1;
      }, 'conditional_failure');

      final actionFactory = (List<int> obj, Map<String, int> model) {
        return just(conditionalFailingAction);
      };

      final prop = statefulProperty(
        just(<int>[1, 2, 3, 4, 5]), // Start with long list
        (obj) => {'count': 0},
        actionFactory,
      );

      // This should fail and be shrunk to a minimal case
      expect(() => prop.setNumRuns(1).setMaxActions(1).go(),
          throwsA(isA<TestFailure>()));
    });

    test('Multiple action sequence failure', () {
      // Test failure that only occurs with specific action sequences
      final pushAction = Action<List<int>, Map<String, int>>((obj, model) {
        obj.add(42);
        model['count'] = (model['count'] ?? 0) + 1;
        model['operations'] = (model['operations'] ?? 0) + 1;
      }, 'push');

      final popAction = Action<List<int>, Map<String, int>>((obj, model) {
        // Bug: always decrement count, even when list is empty
        model['count'] = (model['count'] ?? 0) - 1;
        if (obj.isNotEmpty) {
          obj.removeLast();
        }
        model['operations'] = (model['operations'] ?? 0) + 1;
      }, 'pop');

      final actionFactory = (List<int> obj, Map<String, int> model) {
        final operations = model['operations'] ?? 0;

        if (operations < 1) {
          return just(pushAction);
        } else {
          return just(popAction);
        }
      };

      final prop = statefulProperty(
        just(<int>[]),
        (obj) => {'count': 0, 'operations': 0},
        actionFactory,
      );

      // Post-check that fails when count becomes negative
      prop.setPostCheck((obj, model) {
        expect(model['count'], greaterThanOrEqualTo(0));
      });

      // This should fail: 1 push (count = 1) then multiple pops that decrement count
      // even when list is empty, making count negative
      expect(() => prop.setNumRuns(20).setMaxActions(5).setSeed('test').go(),
          throwsA(isA<TestFailure>()));
    });
  });
}
