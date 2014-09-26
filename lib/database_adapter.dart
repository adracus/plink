part of plink;


const PrimaryKey PRIMARY_KEY = const PrimaryKey();
const AutoIncrement AUTO_INCREMENT = const AutoIncrement();
const Unique unique = const Unique();


class TableSchema {
  String tableName;
  Map<String, VariableSchema> structure;
  Map<String, TableSchema> relations;
  
  TableSchema(this.tableName, this.structure, [this.relations = const{}]);
}


class VariableSchema {
  final String name;
  final String type;
  final List<Constraint> constraints;
  final List<Validation> validations;
  
  VariableSchema(this.name, this.type, this.constraints, this.validations);
  VariableSchema.fromMirror(VariableMirror mirror)
      : name = $(mirror.simpleName).name,
        type = $(mirror.type.simpleName).name,
        constraints = _constraintsFromMirror(mirror),
        validations = _validationsFromMirror(mirror);
  
  static List<Constraint> _constraintsFromMirror(VariableMirror mirror) =>
      mirror.metadata.map((m) => m.reflectee).where((meta) =>
          meta is Constraint).toList();
  
  static List<Validation> _validationsFromMirror(VariableMirror mirror) =>
      mirror.metadata.map((m) => m.reflectee).where((meta) =>
          meta is Validation).toList();
}


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


abstract class Validation {
  final String name;
  bool call(value);
  
  const Validation(this.name);
}


class EmailValidation extends Validation {
  static final EMAIL_REGEX =
      new RegExp("""[a-z0-9!#\$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#\$%&'*+/=?^_`
                    {|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-
                    9](?:[a-z0-9-]*[a-z0-9])?""");
  
  const EmailValidation() : super("Email");
  
  bool isFullMatch(String value) {
    var match = EMAIL_REGEX.firstMatch(value);
    return match != null && match.end == value.length; 
  }
  
  bool call(value) => value is String && isFullMatch(value);
}


abstract class Condition {
  bool call(value);
  const Condition();
}


class EqualsCondition {
  final comparator;
  bool call(value) => value == comparator;
  const EqualsCondition(this.comparator) : super();
}


abstract class DatabaseAdapter {
  Future<bool> hasTable(String tableName);
  Future createTable(TableSchema schema);
  Future dropTable(String tableName);
  Future<Map<String, dynamic>> saveToTable(String tableName,
      Map<String, dynamic> values);
  Future<Map<String, dynamic>> updateToTable(String tableName,
      Map<String, dynamic> values);
  Future<Map<String, dynamic>> findById(String tableName, int id);
  Future<List<Map<String, dynamic>>> findWhere(String tableName,
        Map<String, dynamic> condition);
  Future<List<Map<String, dynamic>>> all(String tableName);
  Future delete(String tableName, int id);
  Future<TableSchema> describeTable(String tableName);
}


class MemoryAdapter implements DatabaseAdapter {
  Map<String, Map<int, Map<String, dynamic>>> _tables = {};
  Map<String, int> _tableIdCount = {};
  Map<String, TableSchema> _schemes = {};
  
  Future delete(String tableName, int id) {
    _tables[tableName][id] = null;
    return new Future.value();
  }
  
  Future<bool> hasTable(String tableName) =>
      new Future.value(_tables[tableName] != null);
  
  Future createTable(TableSchema schema) {
    _schemes[schema.tableName] = schema;
    _tables[schema.tableName] = {};
    _tableIdCount[schema.tableName] = 1;
    return new Future.value();
  }
  
  Future<TableSchema> describeTable(String tableName) =>
      new Future.value(_schemes[tableName]);
  
  Future dropTable(String tableName) {
    _tables[tableName] = null;
    _tableIdCount[tableName] = null;
    return new Future.value();
  }
  
  Future<List<Map<String, dynamic>>> findWhere(String tableName,
      Map<String, dynamic> condition) {
    return new Future.value(_tables[tableName].values.where((map) {
      for (var key in condition.keys) {
        if (map[key] != condition[key]) return false;
      }
      return true;
    }).toList());
  }
  
  Future<Map<String, dynamic>> findById(String tableName, int id) {
    return new Future.value(_tables[tableName][id]);
  }
  
  Future<Map<String, dynamic>> saveToTable(String tableName,
      Map<String, dynamic> values) {
    if (values["id"] == null) values["id"] = _tableIdCount[tableName]++;
    _tables[tableName][values["id"]] = values;
    return new Future.value(values);
  }
  
  Future<Map<String, dynamic>> updateToTable(String tableName,
      Map<String, dynamic> values) {
    return saveToTable(tableName, values);
  }
  
  Future<List<Map<String, dynamic>>> all(String tableName) {
    return new Future.value(_tables[tableName].values.toList());
  }
}