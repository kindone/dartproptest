import 'package:test/test.dart';
import 'package:dartproptest/dartproptest.dart';
import 'testutil.dart';

/// Limited-depth serialization to avoid infinite trees
Map<String, dynamic> outShrinkableLimited<T>(Shrinkable<T> shrinkable,
    {int maxDepth = 5, int maxChildren = 3}) {
  final obj = <String, dynamic>{};
  obj['value'] = shrinkable.value;

  if (maxDepth <= 0) {
    obj['_truncated'] = true;
    return obj;
  }

  final shrinks = shrinkable.shrinks();
  if (!shrinks.isEmpty()) {
    final shrinksObj = <Map<String, dynamic>>[];
    final iterator = shrinks.iterator();
    int count = 0;
    while (iterator.hasNext() && count < maxChildren) {
      shrinksObj.add(outShrinkableLimited(iterator.next(),
          maxDepth: maxDepth - 1, maxChildren: maxChildren));
      count++;
    }
    if (iterator.hasNext()) {
      shrinksObj.add({'value': '... (more)', '_truncated': true});
    }
    obj['shrinks'] = shrinksObj;
  }
  return obj;
}

String serializeLimited<T>(Shrinkable<T> shrinkable) {
  return _compactJson(outShrinkableLimited(shrinkable));
}

String _compactJson(dynamic obj) {
  if (obj == null) return 'null';
  if (obj is String) return '"$obj"';
  if (obj is num || obj is bool) return obj.toString();
  if (obj is List) {
    final items = obj.map((item) => _compactJson(item)).join(',');
    return '[$items]';
  }
  if (obj is Map<String, dynamic>) {
    final pairs = obj.entries
        .map((entry) => '"${entry.key}":${_compactJson(entry.value)}')
        .join(',');
    return '{$pairs}';
  }
  return obj.toString();
}

void main() {
  test('Show shrink tree for 100.0 (limited)', () {
    print(
        '\n=== Shrink Tree for 100.0 (First 5 levels, max 3 children per node) ===\n');

    final shrinkable = shrinkableFloat(100.0);

    // Show first few shrinks directly
    print('Direct shrinks:');
    final iterator = shrinkable.shrinks().iterator();
    int count = 0;
    while (iterator.hasNext() && count < 10) {
      final shrink = iterator.next();
      print('  ${++count}. ${shrink.value}');
    }

    // Show limited serialization
    print('\n=== Limited Serialization (depth 5, max 3 children) ===');
    final limitedSerialized = serializeLimited(shrinkable);
    print(limitedSerialized);

    // Try to see the structure pattern
    print('\n=== Tree Pattern (visualized, depth 3) ===');
    void printTree(
        Shrinkable<double> shr, int depth, int maxDepth, int maxSiblings) {
      if (depth > maxDepth) return;
      final indent = '  ' * depth;
      print('$indent${shr.value}');

      final it = shr.shrinks().iterator();
      int siblingCount = 0;
      while (it.hasNext() && siblingCount < maxSiblings) {
        printTree(it.next(), depth + 1, maxDepth, maxSiblings);
        siblingCount++;
      }
      if (it.hasNext()) {
        print('$indent  ...');
      }
    }

    printTree(shrinkable, 0, 3, 2);

    expect(true, isTrue);
  });
}
