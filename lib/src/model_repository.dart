part of plink;


class ModelRepository {
  DatabaseAdapter _adapter;
  Migrator _migrator;
  final SchemaIndex schemaIndex;
  
  
  ModelRepository(this._adapter, this._migrator, this.schemaIndex);
  
  
  ModelRepository._byConfig(Configuration config)
      : schemaIndex = new SchemaParser().parse($.rootLibrary) {
    this._adapter = config.adapter;
    this._migrator = new Migrator._byConfig(config, this.schemaIndex);
  }
  
  
  Future<Model> save(Model model, {bool recursive: true}) =>
      schemaIndex.getModelSchema(model).save(model, recursive: recursive);
  
  
  Future<List<Model>> saveMany(List<Model> models, {bool recursive: true}) =>
      Future.wait(models.map((model) => model.save(recursive: recursive)));
  
  
  Future delete(Model model, {bool recursive: true}) =>
      schemaIndex.getModelSchema(model).delete(model, recursive: recursive);
  
  
  Future deleteMany(List<Model> models, {bool recursive: true}) =>
      Future.wait(models.map((model) => model.delete(recursive: recursive)));
  
  
  Future<Model> find(Type type, int id, {bool populate: true}) =>
      schemaIndex.getModelSchema(type).find(id, populate: populate);
  
  
  Future where(Type type, Map<String, dynamic> condition,
               {bool populate: true}) =>
      schemaIndex.getModelSchema(type).where(condition);
  
  
  Future ensureExistence(Schema schema) => _migrator.ensureExistence(schema);
  
  
  Future all(Type type, {bool populate: true}) {
    return schemaIndex.getModelSchema(type).all(populate: populate);
  }
  
  
  Future<List<Map<String, dynamic>>> fetchRelation(String link_tableName,
      int link_id, Schema schema) {
    return adapter.findWhere(schema.name, {"${link_tableName}_id": link_id});
  }
  
  DatabaseAdapter get adapter => _adapter;
  
  void set adapter(DatabaseAdapter adapter) {
    _adapter = adapter;
    _migrator.adapter = adapter;
  }
}