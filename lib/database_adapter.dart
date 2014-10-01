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
}


abstract class MemoryAdapter implements DatabaseAdapter {
  Map<String, Map<String, dynamic>> _tables = {};
  
  
  Future<bool> hasTable(String tableName) =>
      new Future.value(_tables[tableName] != null);
  
  
  Future createTable(String tableName, List<FieldSchema> columns);
}