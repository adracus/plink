part of plink;

final REPO = new ModelRepository();


class ModelRepository {
  Map<ModelSchema, bool> _existingTables = {};
  final Map<Type, ModelSchema> _schemes = _parseSchemes();
  DatabaseAdapter adapter = null; //new MemoryAdapter();
  
  
  ModelRepository();
  
  
  ModelSchema getSchemaByModel(Model model) => _schemes[model.runtimeType];
  
  
  static Map<Type, ModelSchema> _parseSchemes() {
    var classes = $.rootLibrary.getClasses();
    var result = {};
    classes.forEach((_, mirr) {
      if (_isModelSubtype(mirr) && !_shouldBeIgnored(mirr))
        result[mirr.reflectedType] = new ModelSchema.fromMirror(mirr);
    });
    return result;
  }
  
  
  Future<Model> find(Type type, int id) =>
      where(type, {"id": id}).then((models) => models.first);
  
  
  Future<Model> save(Model model) {
    if (model.created_at == null) model.created_at = new DateTime.now();
    model.updated_at = new DateTime.now();
    if (model.id == null) return executeSave(model);
    return executeUpdate(model);
  }
  
  
  Future<Model> executeSave(Model model) {
    return _checkTable(getSchemaByModel(model)).then((_) {
      model.beforeCreate();
      return adapter.saveToTable(_schemes[model.runtimeType].name,
          model._extractValues()).then((row) =>
              instantiateByRow(model.runtimeType, row));
    });
  }
  
  
  Future<Model> executeUpdate(Model model) {
    model.beforeUpdate();
    var values = model._extractValues();
    var id = values.remove("id");
    return adapter.updateToTable(_schemes[model.runtimeType].name,
        values, {"id": id}).then((row) =>
            instantiateByRow(model.runtimeType, row));
  }
  
  
  Future<Model> executeRelationSave(Model model) {
    var schema = getSchemaByModel(model);
    if (schema.relations.length == 0) return new Future.value(model);
  }
  
  
  Future delete(Model model) {
    return adapter.delete(_schemes[model.runtimeType].name, {"id": model.id});
  }
  
  
  Future _checkTable(ModelSchema schema) {
    if (_existingTables[schema] == true) return new Future.value();
    return adapter.hasTable(schema.name).then((res) {
      if (res) return new Future.value();
      var fs = [];
      fs..add(_createTableFromSchema(schema))
        ..addAll(schema.relations.map(_checkTable));
      return Future.wait(fs);
    });
  }
  
  
  Future _createTableFromSchema(ModelSchema schema) =>
      adapter.createTable(schema.name, schema.fields)
        .then((_) => _existingTables[schema] = true);
  
  
  Future<List<Model>> where(Type type, Map<String, dynamic> criteria,
      {bool populate: true}) {
    return adapter.findWhere(_schemes[type].name, criteria).then((rows) {
      var models = rows.map((row) => instantiateByRow(type, row)).toList();
      if (!populate) return models;
      return Future.wait(models.map(this.populate));
    });
  }
  
  
  Future<Model> populate(Model model) {
    var schema = getSchemaByModel(model);
    if (schema.relations.length == 0) return new Future.value(model);
    return Future.wait(schema.relations.map((rel) =>
        fetchRelation(schema.name, model.id, rel).then((values) {
      updateWithRelationData(model, rel, values);
    }))).then((_) {
      return new Future.value(model);
    });
  }
  
  
  void updateWithRelationData(target, Relation relation,
                                   List<Map<String, dynamic>> data) {
    if (relation is PrimitiveListRelation) {
      var result = data.map((row) =>
          row[relation.fieldName.toLowerCase()]).toList();
      if (target is Map) {
        target[relation.fieldName] = result;
        return;
      }
      reflect(target).setField(new Symbol(relation.fieldName), result);
      return;
    }
  }
  
  
  Future<List<Map<String, dynamic>>> fetchRelation(String link_tableName,
      int link_id, ModelSchema schema) {
    return adapter.findWhere(schema.name, {"${link_tableName}_id": link_id});
  }
  
  
  Model instantiateByRow(Type type, Map<String, dynamic> values) {
    var inst = _defaultInstanceMirror(type);
    values.forEach((name, value) => inst.setField(new Symbol(name), value));
    return inst.reflectee;
  }
}