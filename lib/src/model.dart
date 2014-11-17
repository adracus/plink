part of plink;

const defaultConstructor = const Object();


abstract class Model implements Identifyable {
  static Map<Type, Symbol> _defaultConstructorSymbols = {};
  
  int id;
  DateTime createdAt;
  DateTime updatedAt;
  
  void beforeCreate() => null;
  void afterCreate() => null;
  void beforeUpdate() => null;
  void afterUpdate() => null;
  void beforeDelete() => null;
  void afterDelete() => null;
  
  static Symbol _getDefaultConstructorSymbol(Type type) {
    if (_defaultConstructorSymbols[type] != null)
      return _defaultConstructorSymbols[type];
    var dec = ($(reflectClass(type).declarations.values.toList())
        .extract(MethodMirror) as List<DeclarationMirror>);
    var candidates = dec.where((method) => method.isConstructor &&
        method.metadata.map((meta) => meta.reflectee)
          .contains(defaultConstructor));
    if (candidates.length == 1)
      return _defaultConstructorSymbols[type] =
        new Symbol(($(candidates.single.simpleName).name as String).split(".").last);
    if (candidates.length > 1)
      throw new UnsupportedError("Multiple default constructors are not allowed!");
    return _defaultConstructorSymbols[type] = const Symbol("");
  }
  
  static InstanceMirror defaultInstanceMirror(ClassMirror clazz) {
    var constructorName = _getDefaultConstructorSymbol(clazz.reflectedType);
    return clazz.newInstance(constructorName, []);
  }
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
          .where((field) => field.simpleName != #id && !field.isStatic)
          .map((field) =>
              new Relation.fromField(field, clazz, index)).toList();
  

  Future<Model> find(int id) => index.getAdapter().then((adapter) {
    return exists(adapter, id).then((result) {
      if (!result) throw "Not found";
      return modelFromId(id);
    });
  });
  
  
  Future<List<Model>> all() => index.getAdapter().then((adapter) {
    return adapter.where(str(name), {}).then((idRecords) {
      var ids = idRecords.map((record) => record["id"]);
      return Future.wait(ids.map(modelFromId));
    });
  });
  
  
  Future<Model> modelFromId(int id) {
    var values = {};
    return Future.wait(relations.map((rel) => rel.find(id).then((loaded) =>
        values[rel.simpleName] = loaded))).then((_) {
      var inst = Model.defaultInstanceMirror(clazz);
      values.forEach((key, value) =>
          inst.setField(key, value));
      inst.setField(#id, id);
      return inst.reflectee;
    });
  }
  

  Future<Model> save(Model model, {bool deep: false}) =>
      index.getAdapter().then((adapter) {
    if (null == model.id) return insert(model, deep: deep);
    return update(model, deep: deep);
  });
  
  
  Future<Model> insert(Model model, {bool deep: false}) {
    model.beforeCreate();
    return index.getAdapter().then((adapter) {
      model.updatedAt = new DateTime.now();
      model.createdAt = new DateTime.now();
      return adapter.insert(str(name), {}).then((saved) {
        model.id = saved["id"];
        return saveRelations(model, deep: deep).then((savedRelations) =>
            updateModelWithRelations(model, savedRelations))
            .then((updated) => updated..afterCreate());
      });
    });
  }
  
  
  Future<Model> update(Model model, {bool deep: false}) {
    model.beforeUpdate();
    model.updatedAt = new DateTime.now();
    return saveRelations(model, deep: deep).then((savedRelations) =>
        updateModelWithRelations(model, savedRelations))
        .then((updated) => updated..afterUpdate());
  }
  
  
  Future<Map<Symbol, dynamic>> saveRelations(Model model, {bool deep: false}) =>
      index.getAdapter().then((adapter) {
    var result = {};
    return Future.wait(relations.map((relation) =>
        relation.save(model.id, getRelationField(relation, model), deep: deep)
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
  
  
  Future deleteModel(Model model, {bool deep: false}) {
    if (null == model.id) throw new ArgumentError("Model has to be persisted");
    model.beforeDelete();
    return delete(model.id, deep: deep).then((_) => model.afterDelete());
  }
  
  
  Future delete(int id, {bool deep: false}) =>
      index.getAdapter().then((adapter) {
    if (null == id) throw new ArgumentError("id cannot be null");
    return Future.wait(relations.map((rel) => rel.delete(id, deep: deep))).then((_) {
      return adapter.delete(str(name), {"id": id});
    });
  });
  
  
  Future where(s.WhereStatement statement) {
    return _evaluateWhereStatement(statement).then((ids) =>
        Future.wait((ids.map(find))));
  }
  
  
  Future<Set<int>> _evaluateWhereStatement(s.WhereStatement statement) {
    if (statement is s.Operator) {
      var relation = _relationWithName(statement.identifier.name);
      return relation.where(statement);
    }
    if (statement is s.Combinator) {
      return Future.wait([_evaluateWhereStatement(statement.first),
                          _evaluateWhereStatement(statement.second)]).then((sets) {
        if (statement is s.AndCombinator) {
          return sets.reduce((Set s1, Set s2) => s1.intersection(s2));
        }
        return sets.fold(new Set(), (s1, s2) => s1..addAll(s2));
      });
    }
    throw "Unknown statement $statement";
  }
  
  
  Relation _relationWithName(String name) {
    return relations.firstWhere((relation) => str(relation.simpleName) == name);
  }
  
  
  Future<bool> exists(DatabaseAdapter adapter, int id) =>
      adapter.where(str(name), {"id": id}).then((rows) => rows.length == 1);
  
  
  Future drop() => index.getAdapter().then((adapter) {
    return adapter.dropTable(str(name)).then((_) =>
        Future.wait(relations.map((rel) => rel.drop())));
  });
  

  Type get type => clazz.reflectedType;
  
  bool get needsPersistance => true;
}