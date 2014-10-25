part of plink;

ModelRepository _repo;

ModelRepository get REPO {
  if (_repo == null) {
    _initialize();
  }
  return _repo;
}

void _initialize() {
  _repo = new ModelRepository._byConfig(defaultConfiguration);
}


class ModelRepository extends Object with Watcher<DatabaseAdapter>{
  final AutoMigrator _migrator;
  Future _runningMigration;
  
  
  ModelRepository(this._migrator) {
    _surveillance.addWatcher(this);
    _migrate();
  }
  
  
  void _migrate() {
    if (adapter != null && _migrator != null) {
      _runningMigration = _migrator.migrate().then((_) =>
          _runningMigration = null);
    }
  }
  
  
  ModelRepository._byConfig(Configuration config)
      : this(config.migrator);
  
  
  Future _checkMigration() {
    if (_runningMigration == null) return new Future.value();
    return _runningMigration;
  }
  
  
  Future<Model> save(Model model, {bool recursive: true}) =>
      _checkMigration().then((_) =>
          SCHEMA_INDEX.getModelSchema(model).save(model, recursive: recursive));
  
  
  Future<List<Model>> saveMany(Iterable<Model> models, {bool recursive: true}) =>
      _checkMigration().then((_) =>
          Future.wait(models.map((model) => model.save(recursive: recursive))));
  
  
  Future delete(Model model, {bool recursive: true}) =>
      _checkMigration().then((_) =>
          SCHEMA_INDEX.getModelSchema(model).delete(model, recursive: recursive));
  
  
  Future deleteMany(Iterable<Model> models, {bool recursive: true}) =>
      _checkMigration().then((_) =>
          Future.wait(models.map((model) => model.delete(recursive: recursive))));
  
  
  Future<Model> find(Type type, int id, {bool populate: true}) =>
      _checkMigration().then((_) =>
        SCHEMA_INDEX.getModelSchema(type).find(id, populate: populate));
  
  
  Future where(Type type, Map<String, dynamic> condition,
               {bool populate: true}) =>
                   _checkMigration().then((_) =>
                      SCHEMA_INDEX.getModelSchema(type).where(condition));
  
  
  Future all(Type type, {bool populate: true}) =>
      _checkMigration().then((_) =>
          SCHEMA_INDEX.getModelSchema(type).all(populate: populate));
  
  void afterChange(DatabaseAdapter old, DatabaseAdapter nu) {
    _migrate();
  }
}