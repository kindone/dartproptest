import 'package:test/test.dart';
import 'package:dartproptest/dartproptest.dart';

// Database-like system with complex state management
class Database {
  final Map<String, dynamic> _data = {};
  final List<String> _transactionLog = [];
  bool _inTransaction = false;

  void insert(String key, dynamic value) {
    if (_inTransaction) {
      _transactionLog.add('INSERT $key = $value');
    }
    _data[key] = value;
  }

  void update(String key, dynamic value) {
    if (_inTransaction) {
      _transactionLog.add('UPDATE $key = $value');
    }
    if (_data.containsKey(key)) {
      _data[key] = value;
    }
  }

  void delete(String key) {
    if (_inTransaction) {
      _transactionLog.add('DELETE $key');
    }
    _data.remove(key);
  }

  void beginTransaction() {
    _inTransaction = true;
    _transactionLog.clear();
  }

  void commitTransaction() {
    _inTransaction = false;
    _transactionLog.clear();
  }

  void rollbackTransaction() {
    _inTransaction = false;
    _transactionLog.clear();
  }

  Map<String, dynamic> get data => Map.from(_data);
  List<String> get transactionLog => List.from(_transactionLog);
  bool get inTransaction => _inTransaction;
}

// File system-like structure with complex nested state
class FileSystem {
  final Map<String, dynamic> _files = {};
  final Map<String, List<String>> _directories = {};
  String _currentPath = '/';

  void createFile(String path, String content) {
    _files[path] = content;
    final dir = _getDirectory(path);
    if (!_directories.containsKey(dir)) {
      _directories[dir] = [];
    }
    _directories[dir]!.add(_getFileName(path));
  }

  void createDirectory(String path) {
    _directories[path] = [];
  }

  void deleteFile(String path) {
    _files.remove(path);
    final dir = _getDirectory(path);
    _directories[dir]?.remove(_getFileName(path));
  }

  void deleteDirectory(String path) {
    _directories.remove(path);
    // Remove all files in this directory
    _files.removeWhere((filePath, _) => filePath.startsWith(path));
  }

  void changeDirectory(String path) {
    if (_directories.containsKey(path)) {
      _currentPath = path;
    }
  }

  String _getDirectory(String path) {
    final parts = path.split('/');
    parts.removeLast();
    return parts.join('/').isEmpty ? '/' : parts.join('/');
  }

  String _getFileName(String path) {
    return path.split('/').last;
  }

  Map<String, dynamic> get files => Map.from(_files);
  Map<String, List<String>> get directories => Map.from(_directories);
  String get currentPath => _currentPath;
}

// Cache system with complex eviction and state management
class Cache {
  final Map<String, dynamic> _cache = {};
  final List<String> _accessOrder = [];
  final int _maxSize;
  int _hits = 0;
  int _misses = 0;

  Cache(this._maxSize);

  void put(String key, dynamic value) {
    if (_cache.containsKey(key)) {
      _accessOrder.remove(key);
    } else if (_cache.length >= _maxSize) {
      // Evict least recently used
      final lru = _accessOrder.removeAt(0);
      _cache.remove(lru);
    }
    _cache[key] = value;
    _accessOrder.add(key);
  }

  dynamic get(String key) {
    if (_cache.containsKey(key)) {
      _accessOrder.remove(key);
      _accessOrder.add(key); // Move to end (most recently used)
      _hits++;
      return _cache[key];
    } else {
      _misses++;
      return null;
    }
  }

  void remove(String key) {
    _cache.remove(key);
    _accessOrder.remove(key);
  }

  void clear() {
    _cache.clear();
    _accessOrder.clear();
  }

  Map<String, dynamic> get data => Map.from(_cache);
  List<String> get accessOrder => List.from(_accessOrder);
  int get hits => _hits;
  int get misses => _misses;
  int get size => _cache.length;
  bool get isFull => _cache.length >= _maxSize;
}

// Connection pool with complex state management
class Connection {
  final String id;
  bool _isConnected = false;
  bool _isBusy = false;
  DateTime? _lastUsed;

  Connection(this.id);

  void connect() {
    _isConnected = true;
    _lastUsed = DateTime.now();
  }

  void disconnect() {
    _isConnected = false;
    _isBusy = false;
  }

  void acquire() {
    if (_isConnected && !_isBusy) {
      _isBusy = true;
      _lastUsed = DateTime.now();
    }
  }

  void release() {
    _isBusy = false;
    _lastUsed = DateTime.now();
  }

  bool get isConnected => _isConnected;
  bool get isBusy => _isBusy;
  bool get isAvailable => _isConnected && !_isBusy;
  DateTime? get lastUsed => _lastUsed;
}

class ConnectionPool {
  final List<Connection> _connections = [];
  final int _maxConnections;
  int _connectionCounter = 0;

  ConnectionPool(this._maxConnections);

  void addConnection() {
    if (_connections.length < _maxConnections) {
      final conn = Connection('conn_${_connectionCounter++}');
      _connections.add(conn);
    }
  }

  void removeConnection() {
    if (_connections.isNotEmpty) {
      final conn = _connections.removeLast();
      conn.disconnect();
    }
  }

  void connectAll() {
    for (final conn in _connections) {
      conn.connect();
    }
  }

  void disconnectAll() {
    for (final conn in _connections) {
      conn.disconnect();
    }
  }

  void acquireConnection() {
    final available = _connections.where((c) => c.isAvailable).toList();
    if (available.isNotEmpty) {
      available.first.acquire();
    }
  }

  void releaseConnection() {
    final busy = _connections.where((c) => c.isBusy).toList();
    if (busy.isNotEmpty) {
      busy.first.release();
    }
  }

  List<Connection> get connections => List.from(_connections);
  int get availableCount => _connections.where((c) => c.isAvailable).length;
  int get busyCount => _connections.where((c) => c.isBusy).length;
  int get connectedCount => _connections.where((c) => c.isConnected).length;
  bool get isFull => _connections.length >= _maxConnections;
}

void main() {
  group('Complex Stateful Testing Scenarios', () {
    test('Database-like operations with complex state', () {
      final insertAction = Action<Database, Map<String, dynamic>>((db, model) {
        final key = 'key_${model['counter'] ?? 0}';
        final value = model['counter'] ?? 0;
        db.insert(key, value);
        model['counter'] = (model['counter'] ?? 0) + 1;
        model['operations'] = (model['operations'] ?? 0) + 1;
      }, 'insert');

      final updateAction = Action<Database, Map<String, dynamic>>((db, model) {
        final keys = db.data.keys.toList();
        if (keys.isNotEmpty) {
          final key = keys.first;
          final newValue = (model['counter'] ?? 0) + 1000;
          db.update(key, newValue);
          model['counter'] = (model['counter'] ?? 0) + 1;
          model['operations'] = (model['operations'] ?? 0) + 1;
        }
      }, 'update');

      final deleteAction = Action<Database, Map<String, dynamic>>((db, model) {
        final keys = db.data.keys.toList();
        if (keys.isNotEmpty) {
          final key = keys.first;
          db.delete(key);
          model['operations'] = (model['operations'] ?? 0) + 1;
        }
      }, 'delete');

      final beginTransactionAction =
          Action<Database, Map<String, dynamic>>((db, model) {
        if (!db.inTransaction) {
          db.beginTransaction();
          model['transactions'] = (model['transactions'] ?? 0) + 1;
        }
      }, 'begin_transaction');

      final commitTransactionAction =
          Action<Database, Map<String, dynamic>>((db, model) {
        if (db.inTransaction) {
          db.commitTransaction();
        }
      }, 'commit_transaction');

      final actionFactory = (Database db, Map<String, dynamic> model) {
        final operations = model['operations'] ?? 0;
        final transactions = model['transactions'] ?? 0;

        if (operations < 5) {
          // Early operations: mostly inserts
          return oneOf([just(insertAction), just(beginTransactionAction)]);
        } else if (db.data.isEmpty) {
          // No data: only insert or begin transaction
          return oneOf([just(insertAction), just(beginTransactionAction)]);
        } else if (db.inTransaction) {
          // In transaction: can do any operation or commit
          return oneOf([
            just(insertAction),
            just(updateAction),
            just(deleteAction),
            just(commitTransactionAction)
          ]);
        } else {
          // Not in transaction: can do any operation or begin transaction
          return oneOf([
            just(insertAction),
            just(updateAction),
            just(deleteAction),
            just(beginTransactionAction)
          ]);
        }
      };

      final prop = statefulProperty(
        just(Database()),
        (db) => {'counter': 0, 'operations': 0, 'transactions': 0},
        actionFactory,
      );

      expect(() => prop.setNumRuns(1).setMaxActions(10).go(), returnsNormally);
    });

    test('File system operations with nested state', () {
      final createFileAction =
          Action<FileSystem, Map<String, dynamic>>((fs, model) {
        final fileName = 'file_${model['fileCounter'] ?? 0}.txt';
        final content = 'content_${model['fileCounter'] ?? 0}';
        final path = '${fs.currentPath}/$fileName';
        fs.createFile(path, content);
        model['fileCounter'] = (model['fileCounter'] ?? 0) + 1;
        model['operations'] = (model['operations'] ?? 0) + 1;
      }, 'create_file');

      final createDirectoryAction =
          Action<FileSystem, Map<String, dynamic>>((fs, model) {
        final dirName = 'dir_${model['dirCounter'] ?? 0}';
        final path = '${fs.currentPath}/$dirName';
        fs.createDirectory(path);
        model['dirCounter'] = (model['dirCounter'] ?? 0) + 1;
        model['operations'] = (model['operations'] ?? 0) + 1;
      }, 'create_directory');

      final deleteFileAction =
          Action<FileSystem, Map<String, dynamic>>((fs, model) {
        final files = fs.files.keys.toList();
        if (files.isNotEmpty) {
          fs.deleteFile(files.first);
          model['operations'] = (model['operations'] ?? 0) + 1;
        }
      }, 'delete_file');

      final changeDirectoryAction =
          Action<FileSystem, Map<String, dynamic>>((fs, model) {
        final dirs = fs.directories.keys.toList();
        if (dirs.isNotEmpty) {
          fs.changeDirectory(dirs.first);
          model['operations'] = (model['operations'] ?? 0) + 1;
        }
      }, 'change_directory');

      final actionFactory = (FileSystem fs, Map<String, dynamic> model) {
        final operations = model['operations'] ?? 0;

        if (operations < 3) {
          // Early operations: create root directory and some files
          return oneOf([just(createDirectoryAction), just(createFileAction)]);
        } else if (fs.directories.isEmpty) {
          // No directories: create directory first
          return just(createDirectoryAction);
        } else if (fs.files.isEmpty) {
          // No files: create file or change directory
          return oneOf([just(createFileAction), just(changeDirectoryAction)]);
        } else {
          // Can do any operation
          return oneOf([
            just(createFileAction),
            just(createDirectoryAction),
            just(deleteFileAction),
            just(changeDirectoryAction)
          ]);
        }
      };

      final prop = statefulProperty(
        just(FileSystem()),
        (fs) => {'fileCounter': 0, 'dirCounter': 0, 'operations': 0},
        actionFactory,
      );

      expect(() => prop.setNumRuns(1).setMaxActions(8).go(), returnsNormally);
    });

    test('Cache system with eviction policies', () {
      final putAction = Action<Cache, Map<String, dynamic>>((cache, model) {
        final key = 'key_${model['keyCounter'] ?? 0}';
        final value = 'value_${model['keyCounter'] ?? 0}';
        cache.put(key, value);
        model['keyCounter'] = (model['keyCounter'] ?? 0) + 1;
        model['operations'] = (model['operations'] ?? 0) + 1;
      }, 'put');

      final getAction = Action<Cache, Map<String, dynamic>>((cache, model) {
        final keys = cache.data.keys.toList();
        if (keys.isNotEmpty) {
          final key = keys.first;
          cache.get(key);
          model['operations'] = (model['operations'] ?? 0) + 1;
        }
      }, 'get');

      final removeAction = Action<Cache, Map<String, dynamic>>((cache, model) {
        final keys = cache.data.keys.toList();
        if (keys.isNotEmpty) {
          final key = keys.first;
          cache.remove(key);
          model['operations'] = (model['operations'] ?? 0) + 1;
        }
      }, 'remove');

      final clearAction = Action<Cache, Map<String, dynamic>>((cache, model) {
        cache.clear();
        model['operations'] = (model['operations'] ?? 0) + 1;
      }, 'clear');

      final actionFactory = (Cache cache, Map<String, dynamic> model) {
        final operations = model['operations'] ?? 0;

        if (operations < 2) {
          // Early operations: put some items
          return just(putAction);
        } else if (cache.data.isEmpty) {
          // Empty cache: only put
          return just(putAction);
        } else if (cache.isFull) {
          // Full cache: can do any operation (put will evict)
          return oneOf([
            just(putAction),
            just(getAction),
            just(removeAction),
            just(clearAction)
          ]);
        } else {
          // Not full: can do any operation
          return oneOf([
            just(putAction),
            just(getAction),
            just(removeAction),
            just(clearAction)
          ]);
        }
      };

      final prop = statefulProperty(
        just(Cache(3)), // Small cache to test eviction
        (cache) => {'keyCounter': 0, 'operations': 0},
        actionFactory,
      );

      expect(() => prop.setNumRuns(1).setMaxActions(10).go(), returnsNormally);
    });

    test('Network connection pool with complex state transitions', () {
      final addConnectionAction =
          Action<ConnectionPool, Map<String, dynamic>>((pool, model) {
        pool.addConnection();
        model['operations'] = (model['operations'] ?? 0) + 1;
      }, 'add_connection');

      final connectAllAction =
          Action<ConnectionPool, Map<String, dynamic>>((pool, model) {
        pool.connectAll();
        model['operations'] = (model['operations'] ?? 0) + 1;
      }, 'connect_all');

      final acquireConnectionAction =
          Action<ConnectionPool, Map<String, dynamic>>((pool, model) {
        pool.acquireConnection();
        model['operations'] = (model['operations'] ?? 0) + 1;
      }, 'acquire_connection');

      final releaseConnectionAction =
          Action<ConnectionPool, Map<String, dynamic>>((pool, model) {
        pool.releaseConnection();
        model['operations'] = (model['operations'] ?? 0) + 1;
      }, 'release_connection');

      final disconnectAllAction =
          Action<ConnectionPool, Map<String, dynamic>>((pool, model) {
        pool.disconnectAll();
        model['operations'] = (model['operations'] ?? 0) + 1;
      }, 'disconnect_all');

      final actionFactory = (ConnectionPool pool, Map<String, dynamic> model) {
        final operations = model['operations'] ?? 0;

        if (operations < 2) {
          // Early operations: add connections
          return just(addConnectionAction);
        } else if (pool.connections.isEmpty) {
          // No connections: add connection
          return just(addConnectionAction);
        } else if (pool.connectedCount == 0) {
          // No connected connections: connect all
          return just(connectAllAction);
        } else if (pool.availableCount == 0) {
          // No available connections: release or disconnect
          return oneOf(
              [just(releaseConnectionAction), just(disconnectAllAction)]);
        } else {
          // Can do any operation
          return oneOf([
            just(addConnectionAction),
            just(connectAllAction),
            just(acquireConnectionAction),
            just(releaseConnectionAction),
            just(disconnectAllAction)
          ]);
        }
      };

      final prop = statefulProperty(
        just(ConnectionPool(3)), // Small pool to test state transitions
        (pool) => {'operations': 0},
        actionFactory,
      );

      expect(() => prop.setNumRuns(1).setMaxActions(12).go(), returnsNormally);
    });
  });
}
