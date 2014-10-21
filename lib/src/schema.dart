part of plink;



class SchemaParser {
  SchemaIndex parse(library) {
    if (library is! LibraryMirror && library is! $libraryMirror)
      throw new ArgumentError(library);
    var classes = $(library).getClasses();
    var result = {};
    classes.forEach((_, mirr) {
      if (_isModelSubtype(mirr) && !_shouldBeIgnored(mirr))
        result[mirr.reflectedType] = new ModelSchema.fromMirror(mirr);
    });
    return new SchemaIndex(result);
  }
}



class SchemaIndex {
  final Map<Type, Schema> _schemaCache;
  
  SchemaIndex(this._schemaCache);
  
  Schema getSchema(arg) {
    if (arg is Type) return _schemaCache[arg];
    if (arg is String) return _schemaCache.values.firstWhere((key) =>
        key.name == arg, orElse: () => null);
    throw new ArgumentError("Unsupported argument " +
        "type ${arg.runtimeType.toString()})");
  }
  
  ModelSchema getModelSchema(arg) {
    if (arg is Model) return _schemaCache[arg.runtimeType];
    return getSchema(arg);
  }
  
  List<Schema> get schemes => _schemaCache.values.toList();
}



abstract class Schema<E> {
  final Type type;
  final String name;
  final List<FieldSchema> fields;
  final List<Relation> relations;
  
  
  FieldSchema getField(String name) =>
      fields.firstWhere((field) => field.name == name);
  
  
  Schema(this.type, this.name, [this.fields = const [],
      this.relations = const[]]);
  
  
  String toString() => "Schema '$name' (${fields.map((f) =>
      f.toString()).join(", ")})";
      
  
  InstanceMirror newInstanceMirror() =>
      _defaultInstanceMirror(type);
      
      
  newInstance() => newInstanceMirror().reflectee;
  
  
  Future _ensureExistence() => REPO.ensureExistence(this);
}


abstract class StrongSchema<E> extends Schema<E> {
  StrongSchema(Type type, String name, [List<FieldSchema> fields,
                                        List<Relation> relations])
      : super(type, name, fields, relations);
  
  
  Future<E> save(E data) => _ensureExistence().then((_) => _save(data));
  
  
  Future<E> _save(E data);
  
  
  Future<List<E>> where(Map<String, dynamic> criteria) {
    return _ensureExistence().then((_) =>
        _where(criteria));
  }
  
  
  Future<List<E>> _where(Map<String, dynamic> criteria);
  
  
  Future delete(E data, {bool recursive: false}) {
    return _ensureExistence().then((_) => _delete(data, recursive: recursive));
  }
  
  
  Future _delete(E data, {bool recursive: false});
  
  
  Future<List<E>> all() {
    return _ensureExistence().then((_) => _all());
  }
  
  Future _all();
}



abstract class WeakSchema<E, D> extends Schema<E> {
  WeakSchema(Type type, String name, [List<FieldSchema> fields,
                                         List<Relation> relations])
       : super(type, name, fields, relations);
  
  Future<E> save(E data, D dependency) {
    return _ensureExistence().then((_) => _save(data, dependency));
  }
  
  
  Future<E> _save(E data, D dependency);
  
  
  Future<E> where(D dependency) =>
      _ensureExistence().then((_) => _where(dependency));
  
  
  Future<E> _where(D dependency);
  
  
  Future delete(D dependency, {bool recursive: false}) =>
      _ensureExistence().then((_) => _delete(dependency, recursive: recursive));
  
  
  Future _delete(D dependency, {bool recursive: false});
}



class ModelSchema extends StrongSchema<Model> {
  ModelSchema(Type type, String name, [List<FieldSchema> fields,
                                       List<Relation> relations])
      : super(type, name, fields, relations);
  
  
  factory ModelSchema.fromMirror(ClassMirror mirror) {
    var name = $(mirror.simpleName).name;
    var fields = $(mirror).fields.values.where((VariableMirror mir) =>
        _isPrimitiveField(mir)).map((mir) =>
            new FieldSchema.fromMirror(mir));
    var relations = $(mirror).fields.values.where((VariableMirror mir) =>
        _isFieldCandidate(mir) && !_isPrimitive(mir)).map((mir) =>
            new Relation.fromMirror(mir));
    return new ModelSchema(mirror.reflectedType,
        name, fields.toList(), relations.toList());
  }
  
  
  Future<Model> _save(Model model) {
    return _store(model).then((saved) {
      return Future.wait(relations.map((rel) =>
          rel.save(model._getField(rel.fieldName), saved)
            .then((savedRelation) =>
                saved._setField(rel.fieldName, savedRelation))))
            .then((_) => saved);
    });
  }
  
  
  Future<Model> _store(Model model) {
    if (model.created_at == null) model.created_at = new DateTime.now();
    model.updated_at = new DateTime.now();
    if (model.id == null) return _create(model);
    return _update(model);
  }
  
  
  Future<Model> find(int id) => where({"id": id}).then((ms) => ms.single);
  
  
  Future<List<Model>> _where(Map<String, dynamic> criteria) {
    return REPO.adapter.findWhere(this.name, criteria).then((rows) {
      var models = rows.map(instantiateByRow).toList();
      return Future.wait(models.map(_populate));
    });
  }
  
  
  Future<List<Model>> _all() {
    return REPO.adapter.all(this.name).then((rows) {
      var models = rows.map(instantiateByRow).toList();
      return Future.wait(models.map(_populate));
    });
  }
  
  
  Future<Model> _populate(Model model) {
    return Future.wait(relations.map((rel) => rel.where(model).then((value) =>
        model._setField(rel.fieldName, value)))).then((_) => model);
  }
  
  
  Future<Model> _create(Model model) {
    model.beforeCreate();
    return REPO.adapter.saveToTable(name,
        extractFieldValues(model)).then(instantiateByRow);
  }
  
  
  Future<Model> _update(Model model) {
    model.beforeUpdate();
    var values = extractFieldValues(model);
    var id = values.remove("id");
    return REPO.adapter.updateToTable(this.name,
        values, {"id": id}).then(instantiateByRow);
  }
  
  
  Future _delete(Model model, {bool recursive: false}) {
    return REPO.adapter.delete(name, {"id": model.id}).then((_) {
      return Future.wait(relations.map((rel) =>
          rel.delete(model, recursive: recursive)));
    });
  }
  
  
  Model instantiateByRow(Map<String, dynamic> values) {
    var inst = newInstanceMirror();
    values.forEach((name, value) => inst.setField(new Symbol(name), value));
    return inst.reflectee;
  }
  
  
  Map<String, dynamic> extractFieldValues(Model model,
      {bool acceptNullValues: false}) {
    var reflection = reflect(model);
    var result = {};
    fields.forEach((field) {
      var value = reflection.getField(new Symbol(field.name)).reflectee;
      if (acceptNullValues || value != null) result[field.name] = value;
    });
    return result;
  }
}


abstract class Relation<E> extends WeakSchema<E, Model> {
  final String fieldName;
  
  
  Relation(Type type, String name, this.fieldName,
      [List<FieldSchema> fields = const[], List<Relation> relations = const[]])
      : super(type, name, [new FieldSchema("${name}_id",
          type: int)]..addAll(fields), relations);
  
  
  factory Relation.fromMirror(VariableMirror mirror) {
    var type = mirror.type.originalDeclaration;
    if (type.originalDeclaration == reflectClass(List))
      return new ListRelation.fromMirror(mirror);
    if (mirror.type.isSubtypeOf(reflectType(Model)))
      return (new ModelRelation.fromMirror(mirror) as dynamic);
    throw new UnsupportedTypeError(mirror.type.reflectedType);
  }
  
  
  String get idName => "${name}_id";
  
  
  Future deleteRelationLink(Model m) =>
      REPO.adapter.delete(name, {idName: m.id});
  
  
  Future<List<Map<String, dynamic>>> fetchRows(Model dependency) =>
          REPO.adapter.findWhere(name, {idName: dependency.id});
  
  
  static String getRelationName(VariableMirror mirror) =>
      $(mirror.owner.simpleName).name + "_" + $(mirror.simpleName).name;
}



class ModelRelation extends Relation<Model> {
  factory ModelRelation.fromMirror(VariableMirror mirror) {
    var name = Relation.getRelationName(mirror);
    var type = mirror.type.reflectedType;
    return new ModelRelation(type, name, $(mirror.simpleName).name);
  }
  
  
  ModelRelation(Type type, String name, String fieldName,
                [List<FieldSchema> fields = const[],
                 List<Relation> relations = const[]])
      : super(type, name, fieldName,
          [new FieldSchema(fieldName, type: int)]..addAll(fields), relations);
  
  
  Future<Model> _save(Model data, Model dependency) {
    if (data == null) return _delete(dependency).then((_) => null);
    return _delete(dependency).then((_) {
      return data.save().then((saved) {
        return REPO.adapter.saveToTable(name,
            {idName: dependency.id, fieldName: saved.id}).then((_) => saved);
      });
    });
  }
  
  
  Future<Model> _where(Model dependency) {
    return fetchRows(dependency).then((rows) {
      if (rows.length == 0) return null;
      return REPO.find(type, rows.single[fieldName]);
    });
  }
  
  
  Future _delete(Model dependency, {bool recursive: false}) {
    if (!recursive) return deleteRelationLink(dependency);
    return _where(dependency).then((model) {
      if (model == null) return null;
      model.delete(recursive: recursive);
    }).then((_) {
      return deleteRelationLink(dependency);
    });
  }
}



abstract class ListRelation<E extends List> extends Relation<E> {
  final Type listType;
  
  
  factory ListRelation.fromMirror(VariableMirror mirror) {
    if (PRIMITIVES.contains(mirror.type.typeArguments.single.reflectedType))
      return new PrimitiveListRelation.fromMirror(mirror);
    if (mirror.type.typeArguments.single.isSubtypeOf(reflectType(Model)))
      return (new ModelListRelation.fromMirror(mirror) as dynamic);
  }
  
  
  ListRelation(Type type, String name, String fieldName, Type listType, [
               List<FieldSchema> fields, List<Relation> relations = const[]])
      : listType = listType,
        super(type, name, fieldName, [new FieldSchema("${name}_index",
                                                type: int)]
                                      ..addAll(fields), 
                                      relations);
  
  
  static TypeMirror getListTypeMirror(VariableMirror mirror) =>
      mirror.type.typeArguments.single;
  
  
  static Type getListType(VariableMirror mirror) =>
      getListTypeMirror(mirror).reflectedType;
  
  
  String get indexName => "${name}_index";
  
  
  List<Map<String, dynamic>> listToMap(E list, Model model);
}



class PrimitiveListRelation extends ListRelation<dynamic> {
  factory PrimitiveListRelation.fromMirror(VariableMirror mirror) {
    var name = Relation.getRelationName(mirror);
    var type = ListRelation.getListType(mirror);
    return new PrimitiveListRelation(mirror.type.reflectedType,
        name, $(mirror.simpleName).name, type);
  }
  
  
  PrimitiveListRelation(Type type, String name, String fieldName, Type listType,
                        [List<FieldSchema> fields = const[]])
      : super(type, name, fieldName, listType,
          [new FieldSchema(fieldName, type: listType)]..addAll(fields));
  
  
  FieldSchema getField(String name) =>
        fields.firstWhere((field) => field.name == name);
  
  
  Future<List> _where(Model dependency) {
    return fetchRows(dependency).then((rows) {
      if (rows.length == 0) return null;
      return listFromRows(rows);
    });
  }
  
  
  Future<List> _save(List data, Model model) {
    if (data == null) {
      return _delete(model).then((_) => null);
    }
    return _delete(model).then((_) { // TODO: Intelligent diff instead of delete
      return Future.wait(listToMap(data, model).map((values) =>
        REPO.adapter.saveToTable(name, values))).then((_) => data);
    });
  }
  
  
  Future _delete(Model dependency, {bool recursive: false}) {
    return deleteRelationLink(dependency);
  }
  
  
  List<Map<String, dynamic>> listToMap(List list, Model model) {
    var result = [];
    for(int i = 0; i < list.length; i++) {
      result.add({indexName: i, idName: model.id, fieldName: list[i]});
    }
    return result;
  }
  
  
  List listFromRows(Iterable<Map<String, dynamic>> rows) {
    if (rows.length == 0) return [];
    var maxIndex = $(rows.map((row) => row[indexName]).toList()).max() + 1;
    var result = new List.generate(maxIndex, (_) => null, growable: true);
    rows.forEach((row) => result[row[indexName]] = row[fieldName]);
    return result;
  }
  
  
  List<Schema> get relations => [];
}



class ModelListRelation extends ListRelation<List<Model>>{
  factory ModelListRelation.fromMirror(VariableMirror mirror) {
    var name = Relation.getRelationName(mirror);
    var type = ListRelation.getListType(mirror);
    return new ModelListRelation(mirror.type.reflectedType,
        name, $(mirror.simpleName).name, type, []);
  }
  
  
  ModelListRelation(Type type, String name, String fieldName, Type listType,
            [List<FieldSchema> fields])
      : super(type, name, fieldName, listType,
          [new FieldSchema(fieldName, type: int)]..addAll(fields));
  
  
  Future<List<Model>> _save(List<Model> models, Model model) {
    if (models == null) {
      return _delete(model).then((_) => null);
    }
    return _delete(model).then((_) {
      return Future.wait(models.map((m) => m.save())).then((savedModels) {
        return Future.wait(listToMap(savedModels, model).map((map) =>
            REPO.adapter.saveToTable(name, map))).then((_) {
          return savedModels;
        });
      });
    });
  }
  
  
  Future _delete(Model dependency, {bool recursive: false}) {
    if (!recursive) return deleteRelationLink(dependency);
    return _where(dependency).then((models) {
      return Future.wait(models.map((model) => model.delete(recursive: true)))
          .then((_) {
        return deleteRelationLink(dependency);
      });
    });
  }
  
  
  Future<List<Model>> _where(Model model) {
    return fetchRows(model).then((rows) {
      return Future.wait(rows.map((row) => row[fieldName]).map((id) =>
          REPO.find(listType, id)));
    });
  }
  
  
  List<Map<String, dynamic>> listToMap(List<Model> list, Model model) {
    var result = [];
    for(int i = 0; i < list.length; i++) {
      result.add({indexName: i, idName: model.id, fieldName: list[i].id});
    }
    return result;
  }
}



class FieldSchema {
  final String name;
  final String type;
  final List<Constraint> constraints;
  
  
  factory FieldSchema.fromMirror(VariableMirror mirror) {
    var name = $(mirror.simpleName).name;
    var type = $(mirror.type.simpleName).name;
    var constraints = mirror.metadata.map((meta) => meta.reflectee)
        .where((meta) => meta is Constraint).toList();
    return new FieldSchema(name, type: type, constraints: constraints);
  }
  
  
  FieldSchema(this.name, {type, this.constraints: const[]})
      : type = type == null ? "string" : 
          type is String ? type.toLowerCase() :
            $(reflectType(type).simpleName).name;
  
  
  String toString() => "FieldSchema $name [$type]";
}