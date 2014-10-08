part of plink;

final ModelRepository REPO = new ModelRepository();


class ModelRepository {
  Map<Schema, dynamic> _existingTables = {};
  final Map<Type, Schema> _schemes = _parseSchemes();
  DatabaseAdapter adapter = null; //new MemoryAdapter();
  
  
  ModelRepository();
  
  
  ModelSchema getModelSchema(arg) => arg is Model ?
      _schemes[arg.runtimeType] : _schemes[arg];
  
  
  static Map<Type, Schema> _parseSchemes() {
    var classes = $.rootLibrary.getClasses();
    var result = {};
    classes.forEach((_, mirr) {
      if (_isModelSubtype(mirr) && !_shouldBeIgnored(mirr))
        result[mirr.reflectedType] = new ModelSchema.fromMirror(mirr);
    });
    return result;
  }
  
  
  Future<Model> save(Model model) => getModelSchema(model).save(model);
  
  
  Future<List<Model>> saveMany(List<Model> models) =>
      Future.wait(models.map((model) => model.save()));
  
  
  Future delete(Model model, {bool recursive: false}) =>
      getModelSchema(model).delete(model, recursive: recursive);
  
  
  Future deleteMany(List<Model> models, {bool recursive: false}) =>
      Future.wait(models.map((model) => model.delete(recursive: recursive)));
  
  
  Future<Model> find(Type type, int id) => getModelSchema(type).find(id);
  
  
  Future where(Type type, Map<String, dynamic> condition,
               {bool populate: true}) =>
      getModelSchema(type).where(condition);
  
  
  Future _checkTable(Schema schema) {
    if (_existingTables[schema] == true) return new Future.value();
    if (_existingTables[schema] is Future) // Check for table could be running
      return _existingTables[schema].then((_) => _checkTable(schema));
    return _existingTables[schema] = adapter.hasTable(schema.name).then((res) {
      if (res) {
        _existingTables[schema] = true;
        return new Future.value();
      }
      var fs = [];
      fs..add(_createTableFromSchema(schema))
        ..addAll(schema.relations.map(_checkTable));
      return Future.wait(fs);
    });
  }
  
  
  Future _createTableFromSchema(Schema schema) =>
      adapter.createTable(schema.name, schema.fields)
        .then((_) => _existingTables[schema] = true);
  
  
  Future<List<Map<String, dynamic>>> fetchRelation(String link_tableName,
      int link_id, Schema schema) {
    return adapter.findWhere(schema.name, {"${link_tableName}_id": link_id});
  }
}