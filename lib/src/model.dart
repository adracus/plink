part of plink;


class Model {
  int id;
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
      Future.wait(relations.map((rel) => rel.load(id).then((loaded) =>
          values[rel.name] = loaded))).then((_) {
        var inst = clazz.newInstance(new Symbol(""), []);
        values.forEach((key, value) => inst.setField(key, value));
        return inst.reflectee;
      });
    });
  });
  

  Future<Model> save(Model model) => index.getAdapter().then((adapter) {
    if (null == model.id) return insert(model);
    return update(model);
  });
  
  
  Future<Model> insert(Model model) => index.getAdapter().then((adapter) {
    return adapter.insert(str(name), {}).then((saved) {
      model.id = saved["id"];
      return saveRelations(model).then((savedRelations) =>
          updateModelWithRelations(model, savedRelations));
    });
  });
  
  
  Future<Model> update(Model model) {
    return saveRelations(model).then((savedRelations) =>
        updateModelWithRelations(model, savedRelations));
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
  
  
  Future delete(int id, {bool notify: false}) => index.getAdapter().then((adapter) {
    if (null == id) return new Future.value();
    return exists(adapter, id).then((res) {
      if (!res && notify) throw "Not found";
      return Future.wait(relations.map((rel) => rel.delete(id))).then((_) {
        return adapter.delete(str(name), {"id": id});
      });
    });
  });
  
  
  Future<bool> exists(DatabaseAdapter adapter, int id) =>
      adapter.where(str(name), {"id": id}).then((rows) => rows.length == 1);

  Type get type => clazz.reflectedType;
}