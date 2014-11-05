part of plink;


class Model implements Identifyable {
  int id;
  DateTime createdAt;
  DateTime updatedAt;
  
  void beforeCreate() => null;
  void afterCreate() => null;
  void beforeUpdate() => null;
  void afterUpdate() => null;
  void beforeDelete() => null;
  void afterDelete() => null;
}


class ModelSchema implements StrongSchema<Model> {
  final Symbol name;
  final SchemaIndex index;
  final ClassMirror clazz;
  final FieldCombination fields =
      new FieldCombination([new Field(#id, int, [KEY, AUTO_INCREMENT])]);
  final List<Relation> relations;

  ModelSchema(ClassMirror clazz, SchemaIndex index)
      : clazz = clazz,
        index = index,
        name = clazz.qualifiedName,
        relations = $(clazz).fields.values
          .where((field) => field.simpleName != #id)
          .map((field) =>
              new Relation.fromField(field, clazz, index)).toList();

  Future<Model> load(int id) => index.getAdapter().then((adapter) {
    return exists(adapter, id).then((result) {
      if (!result) throw "Not found";
      var values = {};
      return Future.wait(relations.map((rel) => rel.load(id).then((loaded) =>
          values[rel.simpleName] = loaded))).then((_) {
        var inst = clazz.newInstance(new Symbol(""), []);
        print(values);
        values.forEach((key, value) =>
            inst.setField(key, value));
        return inst.reflectee;
      });
    });
  });
  

  Future<Model> save(Model model) => index.getAdapter().then((adapter) {
    if (null == model.id) return insert(model);
    return update(model);
  });
  
  
  Future<Model> insert(Model model) {
    model.beforeCreate();
    return index.getAdapter().then((adapter) {
      model.updatedAt = new DateTime.now();
      model.createdAt = new DateTime.now();
      return adapter.insert(str(name), {}).then((saved) {
        model.id = saved["id"];
        return saveRelations(model).then((savedRelations) =>
            updateModelWithRelations(model, savedRelations))
            .then((updated) => updated..afterCreate());
      });
    });
  }
  
  
  Future<Model> update(Model model) {
    model.beforeUpdate();
    model.updatedAt = new DateTime.now();
    return saveRelations(model).then((savedRelations) =>
        updateModelWithRelations(model, savedRelations))
        .then((updated) => updated..afterUpdate());
  }
  
  
  Future<Map<Symbol, dynamic>> saveRelations(Model model) =>
      index.getAdapter().then((adapter) {
    var result = {};
    return Future.wait(relations.map((relation) =>
        relation.save(model.id, getRelationField(relation, model))
                .then((savedItem) => result[relation.simpleName] = savedItem)))
          .then((_) => result);
  });
  
  
  getRelationField(Relation relation, Model model) {
    var reflection = reflect(model);
    var instanceMirror = reflection.getField(relation.simpleName);
    return instanceMirror.reflectee;
  }
  
  
  Model updateModelWithRelations(Model model, Map<Symbol, dynamic> savedRelations) {
    var reflection = reflect(model);
    savedRelations.forEach((name, value) => reflection.setField(name, value));
    return reflection.reflectee;
  }
  
  
  Future deleteModel(Model model) {
    if (null == model.id) throw new ArgumentError("Model has to be persisted");
    model.beforeDelete();
    return delete(model.id).then((_) => model.afterDelete());
  }
  
  
  Future delete(int id) => index.getAdapter().then((adapter) {
    if (null == id) throw new ArgumentError("id cannot be null");
    return Future.wait(relations.map((rel) => rel.delete(id))).then((_) {
      return adapter.delete(str(name), {"id": id});
    });
  });
  
  
  Future<bool> exists(DatabaseAdapter adapter, int id) =>
      adapter.where(str(name), {"id": id}).then((rows) => rows.length == 1);
  
  
  Future drop() => index.getAdapter().then((adapter) {
    return adapter.dropTable(str(name)).then((_) =>
        Future.wait(relations.map((rel) => rel.drop())));
  });
  

  Type get type => clazz.reflectedType;
  
  bool get needsPersistance => true;
}