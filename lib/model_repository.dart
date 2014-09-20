part of plink;

const ModelRepository REPO = const ModelRepository();


class ModelRepository {
  static Map<Symbol, ModelSchema> MODELS = parseModels();
  static DatabaseAdapter adapter = new MemoryAdapter();
  static Map<Symbol, bool> _existingTables = {};
  
  const ModelRepository();
  
  static Map<Symbol, ModelSchema> parseModels() =>
        $($($.rootLibrary.getClasses()).retainWhereValue((mirr) =>
            mirr.isSubtypeOf(reflectType(Model)) && !_shouldBeIgnored(mirr)))
              .transformValue((mirr) => new ModelSchema(mirr));
  
  Future delete(Type type, int id) {
    var sym = reflectType(type).simpleName;
    return MODELS[sym].delete(id);
  }
  
  Future<Model> find(Type type, int id) =>
      MODELS[reflectType(type).simpleName].find(id);
  
  static Future ensureTableExistence(Symbol sym) {
    if (_existingTables[sym] == true) return new Future.value();
    return adapter.hasTable($(sym).name).then((res) {
      if (res) return new Future.value();
      return adapter.createTable(MODELS[sym].tableSchema).then((_) {
        _existingTables[sym] = true;
        return new Future.value();
      });
    });
  }
  
  static Model updateModelWithValues(model, Map<String, dynamic> values) {
    var mirror = model is InstanceMirror ? model : reflect(model);
    values.forEach((name, value) => mirror.setField(new Symbol(name), value));
    return mirror.reflectee;
  }
  
  Future<Model> save(Model model) {
    if (model.created_at == null) model.created_at = new DateTime.now();
    model.updated_at = new DateTime.now();
    var sym = reflect(model).type.simpleName;
    var values = MODELS[sym].extractValues(model);
    return ensureTableExistence(sym).then((_) {
      return adapter.saveToTable(MODELS[sym].tableName,
        $(values).transformKey((key) => $(key.simpleName).name))
          .then((resValues) => updateModelWithValues(model, resValues));
    });
  }
  
  Future<List<Model>> findWhere(Type type, Map<String, dynamic> condition) {
    var sym = reflectType(type).simpleName;
    return MODELS[sym].findWhere(condition);
  }
  
  Future<List<Model>> all(Type type) {
    var sym = reflectType(type).simpleName;
    return MODELS[sym].all();
  }
  
  Future<List<Model>> saveModels(List<Model> models) =>
      Future.wait(models.map((model) => save(model)));
}


class ModelSchema {
  static const List PRIMITIVES = const [double, int, String, DateTime];
  
  final ClassMirror mirror;
  final Map<Symbol, VariableMirror> fields;
  
  ModelSchema(ClassMirror mirror)
      : fields = $($(mirror).fields).retainWhereValue((VariableMirror val) =>
          _isPrimitive(val.type.reflectedType)),
        this.mirror = mirror;
  
  Symbol get name => mirror.simpleName;
  String get tableName => $(name).name;
  
  Future<Model> find(int id) {
    return ModelRepository.adapter.findById($(name).name, id)
        .then(instantiateModelFromSet);
  }
  
  Future delete(int id) {
    return ModelRepository.adapter.delete(tableName, id);
  }
  
  Future<List<Model>> findWhere(Map<String, dynamic> condition) {
    return ModelRepository.adapter.findWhere(tableName, condition).then((set) {
      return set.map(instantiateModelFromSet).toList();
    });
  }
  
  Future<List<Model>> all() {
    return ModelRepository.adapter.all(tableName).then((set) {
      return set.map(instantiateModelFromSet).toList();
    });
  }
  
  Model instantiateModelFromSet(Map<String, dynamic> set) {
    var instMirror = mirror.newInstance(new Symbol(""), []);
    return ModelRepository.updateModelWithValues(instMirror, set);
  }
  
  Map<VariableMirror, dynamic> extractValues(Model instance) {
    var instanceMirror = reflect(instance);
    var result = {};
    fields.forEach((sym, mirr) =>
        result[mirr] = instanceMirror.getField(sym).reflectee);
    return result;
  }
  
  static bool _isPrimitive(Type t) => PRIMITIVES.contains(t);
  
  TableSchema get tableSchema =>
      new TableSchema(tableName, $(fields).transform((key) => $(key).name,
        getVariableSchema));
  
  VariableSchema getVariableSchema(VariableMirror mirror) =>
      new VariableSchema($(mirror.simpleName).name, [], []);
  
  String toString() => "Schema of " + $(name).name;
}