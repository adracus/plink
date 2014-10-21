part of plink;

bool autoMigrate = false;


class Migrator {
  int levenshteinThreshold;
  DatabaseAdapter _adapter;
  Map<Schema, dynamic> _existingTables;
  final SchemaIndex schemaIndex;
  
  Migrator(this.levenshteinThreshold, this.schemaIndex);
  
  Migrator._byConfig(Configuration config, SchemaIndex index)
      : levenshteinThreshold = config.levenshteinThreshold,
        _adapter = config.adapter,
        schemaIndex = index;
  
  
  Future migrate() {
    _existingTables = {};
    return Future.wait(schemaIndex.schemes.map(ensureExistence));
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