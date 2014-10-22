part of plink;

bool autoMigrate = false;


class Migrator {
  int levenshteinThreshold;
  DatabaseAdapter _adapter;
  Map<Schema, dynamic> _existingTables;
  final SchemaIndex schemaIndex;
  
  Migrator(this.levenshteinThreshold, this.schemaIndex, this._adapter) {
    if (this._adapter != null) migrate();
  }
  
  Migrator._byConfig(Configuration config, SchemaIndex index)
      : this(config.levenshteinThreshold, index, config.adapter);
  
  
  Future migrate() {
    var tablesInMemory = schemaIndex.schemes.map((s) => new Table.fromSchema(s));
    _existingTables = {};
    REPO.saveMany(tablesInMemory.toList());
    var tableSchema = schemaIndex.getSchema(Table);
    tableSchema.all().then((tables) {
      var databaseTables = new Set()..addAll(tables);
      for (var table in tablesInMemory) {
        if (databaseTables.any((dbTable) => dbTable == table)) continue;
        var match = getTableMatch(table, databaseTables);
        if (match == null) {
          ensureExistence(schemaIndex.getSchema(table.name));
          tableSchema.save(table);
          continue;
        }
      }
    });
  }
  
  
  Table getTableMatch(Table inMemoryTable, Set<Table> databaseTables) {
    var matches = databaseTables.map((databaseTable) =>
        new TableMatchResult(inMemoryTable, databaseTable));
    if (matches.length == 0) return null;
    return (matches.toList()..sort()).last.matched;
  }
  
  
  Future ensureExistence(Schema schema) {
    if (_existingTables[schema] == true) return new Future.value(true);
    if (_existingTables[schema] is Future) // Check for table could be running
      return _existingTables[schema].then((_) => ensureExistence(schema));
    var f = _adapter.hasTable(schema.name).then((res) {
      if (res) {
        _existingTables[schema] = true;
        return new Future.value();
      }
      var fs = [];
      fs..add(_createTableFromSchema(schema))
        ..addAll(schema.relations.map(ensureExistence));
      return Future.wait(fs);
    });
    _existingTables[schema] = f;
    return f;
  }
  
  
  Future _createTableFromSchema(Schema schema) =>
      _existingTables[schema] =
        _adapter.createTable(schema.name, schema.fields)
          .then((_) => _existingTables[schema] = true);
  
  
  void set adapter(DatabaseAdapter adapter) {
    _adapter = adapter;
    if (_adapter != null) migrate();
  }
}


class Table extends Model {
  String name;
  
  Table(this.name, this.columns);
  
  @defaultConstructor
  Table.def();
  
  Table.fromSchema(Schema schema)
      : name = schema.name,
        columns = _extractSchemaColumns(schema);
        
  static List<Column> _extractSchemaColumns(Schema schema) {
    var result = [];
    result.addAll(schema.fields.map((field) =>
        new Column.fromFieldSchema(field)));
    result.addAll(schema.relations.map((rel) =>
        new Column.fromRelation(rel)));
    return result;
  }
  
  List<Column> columns;
  
  operator==(other) {
    if (other is! Table) return false;
    if (other.name != name) return false;
    if (other.columns.length != columns.length) return false;
    _sortColumns();
    other._sortColumns();
    for (int i = 0; i < columns.length; i++) {
      if (columns[i] != other.columns[i]) return false;
    }
    return true;
  }
  
  int differenceTo(Table other) {
    return levenshtein(name, other.name);
  }
  
  void _sortColumns() {
    columns.sort((c1, c2) => c1.name.compareTo(c2.name));
  }
  
  int get hashCode {
    int result = 17 * 37 + name.hashCode;
    _sortColumns();
    for (int i = 0; i < columns.length; i++) {
      result = result * 37 + columns[i].hashCode;
    }
    return result;
  }
  
  
  toString() => "Table '$name'";
}


class Column extends Model {
  String name;
  String type;
  
  Column(this.name, this.type);
  
  @defaultConstructor
  Column.def();
  
  operator==(other) {
    if (other is! Column) return false;
    return name == other.name && type == other.type;
  }
  
  int get hashCode {
    int result = 17;
    result = 37 * result + name.hashCode;
    result = 37 * result + type.hashCode;
    return result;
  }
  
  Column.fromFieldSchema(FieldSchema schema)
      : name = schema.name,
        type = schema.type;
  
  Column.fromRelation(Relation relation)
      : name = relation.fieldName,
        type = $(reflectType(relation.type).simpleName).name;
  
  
  toString() => "Column $type '$name'";
}


class TableMatchResult implements Comparable {
  final int distance;
  final Table from;
  final Table matched;
  
  TableMatchResult(Table from, Table matched)
      : from = from,
        matched = matched,
        distance = from.differenceTo(matched);
  
  int compareTo(TableMatchResult other) => distance.compareTo(other.distance);
}