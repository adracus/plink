part of plink;


const PrimaryKey primaryKey = const PrimaryKey();
const AutoIncrement autoIncrement = const AutoIncrement();
const Unique unique = const Unique();


abstract class Constraint {
  const Constraint();
}


class PrimaryKey extends Constraint {
  const PrimaryKey() : super();
}


class AutoIncrement extends Constraint {
  const AutoIncrement() : super();
}


class Unique extends Constraint {
  const Unique() : super();
}


abstract class DatabaseAdapter {
  Future<bool> hasTable(String tableName);
  Future createTable(String tableName, List<FieldSchema> columns);
  Future dropTable(String tableName);
  Future<Map<String, dynamic>> saveToTable(String tableName,
      Map<String, dynamic> values);
  Future<Map<String, dynamic>> updateToTable(String tableName,
      Map<String, dynamic> values, Map<String, dynamic> condition);
  Future<List<Map<String, dynamic>>> findWhere(String tableName,
        Map<String, dynamic> condition);
  Future<List<Map<String, dynamic>>> all(String tableName);
  Future delete(String tableName, Map<String, dynamic> condition);
  Logger get logger;
}


abstract class MemoryAdapter implements DatabaseAdapter {
  Map<String, Map<String, dynamic>> _tables = {};
  
  
  Future<bool> hasTable(String tableName) =>
      new Future.value(_tables[tableName] != null);
  
  
  Future createTable(String tableName, List<FieldSchema> columns);
}


abstract class Watcher<E> {
  void beforeChange(E old, E nu) => null;
  void afterChange(E old, E nu) => null;
}


class Observer<E> {
  E _observed;
  List<Watcher<E>> _watchers = [];
  
  Observer([this._observed, this._watchers]) {
    if (_watchers == null) _watchers = [];
  }
  
  E get observed => _observed;
  
  void addWatcher(Watcher<E> watcher) => _watchers.add(watcher);
  bool removeWatcher(Watcher<E> watcher) => _watchers.remove(watcher);
  
  set observed(E nu) {
    if (observed == nu) {
      this.observed = nu;
      return nu;
    }
    var old = _observed;
    _watchers.forEach((watcher) => watcher.beforeChange(old, nu));
    _observed = nu;
    _watchers.forEach((watcher) => watcher.afterChange(old, nu));
    return nu;
  }
}


final Observer<DatabaseAdapter> _surveillance =
  new Observer<DatabaseAdapter>();

DatabaseAdapter get adapter => _surveillance.observed;
set adapter(DatabaseAdapter adapter) => _surveillance.observed = adapter;