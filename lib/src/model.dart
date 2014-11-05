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
    return delete(model.id).then((_) {
      var mirr = reflect(model);
      return Future.wait(relations.map((rel) =>
          rel.save(model.id, mirr.getField(rel.simpleName).reflectee).then((saved) =>
              saved is Mapped ? mirr.setField(rel.simpleName, saved.value) :
                mirr.setField(rel.simpleName, saved)))).then((_) {
        return adapter.insert(str(name), {"id": model.id}).then((saved) {
          mirr.setField(#id, saved["id"]);
          return mirr.reflectee;
        });
      });
    });
  });
  
  
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