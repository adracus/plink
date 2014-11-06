part of plink;


class Migrator {
  final DatabaseAdapter _adapter;
  var currentMigration = null;

  Migrator(this._adapter);

  void migrate(SchemaIndex index) {
    var f1 = Future.wait(index.mappers.mappers.map(migrateSchema));
    var f2 = Future.wait(index.schemes.map(migrateModelSchema));
    currentMigration = Future.wait([f1, f2]);
  }
  
  Future migrateModelSchema(ModelSchema schema) {
    return migrateSchema(schema).then((_) =>
        Future.wait(schema.relations.map(migrateSchema)));
  }

  Future<DatabaseAdapter> getAdapter() {
    var f = null == currentMigration ? new Future.value() : currentMigration;
    return f.then((_) => _adapter);
  }
  
  Future migrateSchema(Schema schema) {
    if (!schema.needsPersistance) return new Future.value();
    var name = str(schema.name);
    return _adapter.hasTable(name).then((res) {
      if (res) return new Future.value();
      return _adapter.createTable(name,
          DatabaseField.fromFieldCombination(schema.fields));
    });
  }
}


Symbol combineSymbols(Symbol first, Symbol second) {
  return new Symbol($(first).name + $(second).name);
}