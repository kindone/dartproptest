import 'package:test/test.dart';
import 'package:dartproptest/dartproptest.dart';

void main() {
  group('Async Stateful Testing', () {
    test('AsyncSimpleAction can be created and called', () async {
      final action = AsyncSimpleAction<List<int>>((obj) async {
        await Future.delayed(Duration(milliseconds: 1));
        obj.add(42);
      }, 'add');

      final list = <int>[];
      await action(list);

      expect(list, equals([42]));
      expect(action.name, equals('add'));
      expect(action.toString(), equals('add'));
    });

    test('AsyncAction can be created and called', () async {
      final action = AsyncAction<List<int>, int>((obj, model) async {
        await Future.delayed(Duration(milliseconds: 1));
        obj.add(model);
      }, 'addFromModel');

      final list = <int>[];
      await action(list, 99);

      expect(list, equals([99]));
      expect(action.name, equals('addFromModel'));
      expect(action.toString(), equals('addFromModel'));
    });

    test('AsyncAction can be created from AsyncSimpleAction', () async {
      final simpleAction = AsyncSimpleAction<List<int>>((obj) async {
        await Future.delayed(Duration(milliseconds: 1));
        obj.add(42);
      }, 'add');

      final action = AsyncAction.fromSimpleAction<List<int>, int>(simpleAction);

      final list = <int>[];
      await action(list, 0);

      expect(list, equals([42]));
      expect(action.name, equals('add'));
    });

    test('Multiple async actions can be executed sequentially', () async {
      final addAction = AsyncAction<List<int>, int>((obj, model) async {
        await Future.delayed(Duration(milliseconds: 1));
        obj.add(model);
      }, 'add');

      final removeAction = AsyncAction<List<int>, int>((obj, model) async {
        await Future.delayed(Duration(milliseconds: 1));
        if (obj.isNotEmpty) {
          obj.removeLast();
        }
      }, 'remove');

      final list = <int>[];
      await addAction(list, 10);
      await addAction(list, 20);
      await addAction(list, 30);
      expect(list, equals([10, 20, 30]));

      await removeAction(list, 0);
      expect(list, equals([10, 20]));
    });

    test('Async actions work with generators', () async {
      final addActionGen = Gen.interval(1, 100)
          .map((val) => AsyncAction<List<int>, int>((obj, model) async {
                await Future.delayed(Duration(milliseconds: 1));
                obj.add(val);
              }, 'add_$val'));

      final rand = Random();
      final action = addActionGen.generate(rand).value;

      final list = <int>[];
      await action(list, 0);

      expect(list.length, equals(1));
      expect(list[0], greaterThanOrEqualTo(1));
      expect(list[0], lessThanOrEqualTo(100));
    });

    test('AsyncSimpleAction with complex async operations', () async {
      var counter = 0;

      final action = AsyncSimpleAction<Map<String, int>>((obj) async {
        // Simulate complex async work
        await Future.delayed(Duration(milliseconds: 1));
        counter++;
        await Future.delayed(Duration(milliseconds: 1));
        obj['counter'] = counter;
        await Future.delayed(Duration(milliseconds: 1));
      }, 'updateCounter');

      final map = <String, int>{};
      await action(map);

      expect(map['counter'], equals(1));
      expect(counter, equals(1));

      await action(map);
      expect(map['counter'], equals(2));
      expect(counter, equals(2));
    });
  });
}
