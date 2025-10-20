import '../generator.dart';

/// Represents a simple async action that can be performed on an object.
/// It doesn't involve a model.
/// [ObjectType] The type of the object the action acts upon.
class AsyncSimpleAction<ObjectType> {
  /// [func] The async function to execute when the action is called.
  /// [name] An optional name for the action, used for reporting.
  AsyncSimpleAction(this.func, [this.name = 'unnamed']);

  final Future<void> Function(ObjectType) func;
  final String name;

  /// Calls the underlying function with the given object.
  Future<void> call(ObjectType obj) {
    return func(obj);
  }

  /// Returns the name of the action.
  @override
  String toString() {
    return name;
  }
}

/// Represents an async action that involves both a real object and a model.
/// Used for stateful property-based testing to compare system-under-test and model states.
/// [ObjectType] The type of the real object.
/// [ModelType] The type of the model object.
class AsyncAction<ObjectType, ModelType> {
  /// Creates an `AsyncAction` from an `AsyncSimpleAction`, ignoring the model.
  /// [simpleAction] The simple action to convert.
  /// Returns a new `AsyncAction` instance.
  static AsyncAction<ObjectType, ModelType>
      fromSimpleAction<ObjectType, ModelType>(
          AsyncSimpleAction<ObjectType> simpleAction) {
    return AsyncAction<ObjectType, ModelType>(
        (object, _) => simpleAction.call(object), simpleAction.name);
  }

  /// [func] The async function to execute, taking both the object and the model.
  /// [name] An optional name for the action.
  AsyncAction(this.func, [this.name = 'unnamed']);

  final Future<void> Function(ObjectType obj, ModelType mdl) func;
  final String name;

  /// Calls the underlying function with the object and model.
  Future<void> call(ObjectType obj, ModelType mdl) {
    return func(obj, mdl);
  }

  /// Returns the name of the action.
  @override
  String toString() {
    return name;
  }
}

/// A generator for `AsyncSimpleAction` instances.
typedef AsyncSimpleActionGen<ObjectType>
    = Generator<AsyncSimpleAction<ObjectType>>;

/// A generator for `AsyncAction` instances involving an object and a model.
typedef AsyncActionGen<ObjectType, ModelType>
    = Generator<AsyncAction<ObjectType, ModelType>>;
