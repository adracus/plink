part of plink;

final SchemaIndex SCHEMA_INDEX = new SchemaIndex._global();


class SchemaIndex {
  final Map<String, Schema> _schemaCache;
  
  SchemaIndex(this._schemaCache);
  
  factory SchemaIndex.from(library) {
    if (library is! LibraryMirror && library is! $libraryMirror)
      throw new ArgumentError(library);
    var classes = $(library).getClasses();
    var result = {};
    classes.forEach((_, mirr) {
      if (_isModelSubtype(mirr) && !_shouldBeIgnored(mirr)) {
        var schema = new ModelSchema.fromMirror(mirr);
        result[schema.name] = schema;
        schema.relations.forEach((relation) =>
            result[relation.name] = relation);
      }
    });
    return new SchemaIndex(result);
  }
  
  factory SchemaIndex._global() {
    return new SchemaIndex.from($.rootLibrary);
  }
  
  Schema getSchema(arg) {
    if (arg is Type) return _schemaCache[$(reflectType(arg).simpleName).name];
    if (arg is String) return _schemaCache[arg];
    throw new ArgumentError("Unsupported argument " +
        "type ${arg.runtimeType.toString()})");
  }
  
  ModelSchema getModelSchema(arg) {
    if (arg is Model) return getSchema(arg.runtimeType);
    return getSchema(arg);
  }
  
  List<Schema> get schemes => _schemaCache.values.toList();
}



abstract class Schema<E> extends Object with Watcher<DatabaseAdapter> {
  final Type type;
  final String name;
  final List<FieldSchema> fields;
  final List<Relation> relations;
  var _exists = false;
  
  
  FieldSchema getField(String name) =>
      fields.firstWhere((field) => field.name == name);
  
  
  Schema(this.type, this.name, [this.fields = const [],
      this.relations = const[]]) {
    _surveillance.addWatcher(this);
  }
  
  
  String toString() => "Schema '$name' (${fields.map((f) =>
      f.toString()).join(", ")})";
      
  
  InstanceMirror newInstanceMirror() =>
      _defaultInstanceMirror(type);
      
      
  newInstance() => newInstanceMirror().reflectee;
  
  
  Future ensureExistence({bool recursive: true}) {
    if (_exists == true) return new Future.value(true);
    if (_exists == false) {
      return _exists = adapter.hasTable(name).then((res) {
        if (res == true) {
          _exists = true;
          return new Future.value(true);
        };
        return adapter.createTable(name, fields).then((_) {
          return Future.wait(relations.map((rel) =>
              rel.ensureExistence(recursive: recursive)));
        }).then((_) {
          _exists = true;
          return new Future.value(true);
        });
      });
    }
    return (_exists as Future).then((_) {
      if (_exists == true) return new Future.value();
      return ensureExistence(recursive: recursive);
    });
  }
  
  
  Future<bool> exists() {
    if (_exists == true) return new Future.value(true);
    return null;
  }
  
  
  void afterChange(DatabaseAdapter old, DatabaseAdapter nu) {
    _exists = false;
  }
}


abstract class StrongSchema<E> extends Schema<E> {
  StrongSchema(Type type, String name, [List<FieldSchema> fields,
                                        List<Relation> relations])
      : super(type, name, fields, relations);
  
  
  Future<E> save(E data, {bool recursive: true}) =>
      ensureExistence().then((_) => _save(data, recursive: recursive));
  
  
  Future<List<E>> saveMany(Iterable<E> data, {bool recursive: true}) =>
      Future.wait(data.map((element) => save(element, recursive: recursive)));
  
  
  Future<E> _save(E data, {bool recursive: true});
  
  
  Future<List<E>> where(Map<String, dynamic> criteria, {bool populate: true}) {
    return ensureExistence().then((_) =>
        _where(criteria, populate: populate));
  }
  
  
  Future<List<E>> _where(Map<String, dynamic> criteria, {bool populate: true});
  
  
  Future delete(E data, {bool recursive: true}) {
    return ensureExistence().then((_) => _delete(data, recursive: recursive));
  }
  
  
  Future deleteMany(Iterable<E> data, {bool recursive: true}) =>
      Future.wait(data.map((element) => delete(element, recursive: recursive)));
  
  
  Future _delete(E data, {bool recursive: true});
  
  
  Future<List<E>> all({bool populate: true}) {
    return ensureExistence().then((_) => _all(populate: populate));
  }
  
  
  Future _all({bool populate: true});
}



abstract class WeakSchema<E, D> extends Schema<E> {
  WeakSchema(Type type, String name, [List<FieldSchema> fields,
                                         List<Relation> relations])
       : super(type, name, fields, relations);
  
  Future<E> save(E data, D dependency) {
    return ensureExistence().then((_) => _save(data, dependency));
  }
  
  
  Future<E> _save(E data, D dependency);
  
  
  Future<E> where(D dependency) =>
      ensureExistence().then((_) => _where(dependency));
  
  
  Future<E> _where(D dependency);
  
  
  Future delete(D dependency) =>
      ensureExistence().then((_) => _delete(dependency));
  
  
  Future _delete(D dependency);
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
  
  
  Future<Model> _save(Model model, {bool recursive: true}) {
    return _store(model).then((saved) {
      if (!recursive) return saved;
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
  
  
  Future<Model> find(int id, {bool populate: true}) =>
      where({"id": id}, populate: populate).then((ms) => ms.single);
  
  
  Future<List<Model>> _where(Map<String, dynamic> criteria, {bool populate: true}) {
    return adapter.findWhere(this.name, criteria).then((rows) {
      var models = rows.map(instantiateByRow).toList(growable: true);
      if (!populate) return models;
      return Future.wait(models.map(_populate));
    });
  }
  
  
  Future<List<Model>> _all({bool populate: true}) {
    return adapter.all(this.name).then((rows) {
      var models = rows.map(instantiateByRow).toList(growable: true);
      if (!populate) return models;
      return Future.wait(models.map(_populate));
    });
  }
  
  
  Future<Model> _populate(Model model) {
    return Future.wait(relations.map((rel) => rel.where(model).then((value) =>
        model._setField(rel.fieldName, value)))).then((_) => model);
  }
  
  
  Future<Model> _create(Model model) {
    model.beforeCreate();
    return adapter.saveToTable(name,
        extractFieldValues(model)).then(instantiateByRow);
  }
  
  
  Future<Model> _update(Model model) {
    model.beforeUpdate();
    var values = extractFieldValues(model);
    var id = values.remove("id");
    return adapter.updateToTable(this.name,
        values, {"id": id}).then(instantiateByRow);
  }
  
  
  Future _delete(Model model, {bool recursive: true}) {
    return adapter.delete(name, {"id": model.id}).then((_) {
      if (!recursive) return new Future.value();
      return Future.wait(relations.map((rel) =>
          rel.delete(model)));
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
      adapter.delete(name, {idName: m.id});
  
  
  Future<List<Map<String, dynamic>>> fetchRows(Model dependency) =>
      adapter.findWhere(name, {idName: dependency.id});
  
  
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
      return data._schema.save(data).then((saved) {
        return adapter.saveToTable(name,
            {idName: dependency.id, fieldName: saved.id}).then((_) => saved);
      });
    });
  }
  
  
  Future<Model> _where(Model dependency) {
    return fetchRows(dependency).then((rows) {
      if (rows.length == 0) return null;
      var id = rows.single[fieldName];
      return SCHEMA_INDEX.getModelSchema(type).find(id, populate: true);
    });
  }
  
  
  Future _delete(Model dependency) {
    return _where(dependency).then((model) {
      if (model == null) return null;
      model.delete(recursive: true);
    }).then((_) {
      return deleteRelationLink(dependency);
    });
  }
  
  
  Future ensureExistence({bool recursive: true}) {
    var f = super.ensureExistence();
    if (!recursive) return f;
    return f.then((_) =>
        SCHEMA_INDEX.getSchema(type).ensureExistence(recursive: true));
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
        adapter.saveToTable(name, values))).then((_) => data);
    });
  }
  
  
  Future _delete(Model dependency) {
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
      return Future.wait(models.map((m) => m._schema.save(m))).then((savedModels) {
        return Future.wait(listToMap(savedModels, model).map((map) =>
            adapter.saveToTable(name, map))).then((_) {
          return savedModels.toList(growable: true);
        });
      });
    });
  }
  
  
  Future _delete(Model dependency) {
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
          SCHEMA_INDEX.getModelSchema(listType).find(id, populate: true)))
            .then((models) => models.toList(growable: true));
    });
  }
  
  
  List<Map<String, dynamic>> listToMap(List<Model> list, Model model) {
    var result = [];
    for(int i = 0; i < list.length; i++) {
      result.add({indexName: i, idName: model.id, fieldName: list[i].id});
    }
    return result;
  }
  
  
  Future ensureExistence({bool recursive: true}) {
    var f = super.ensureExistence();
    if (!recursive) return f;
    return f.then((_) => SCHEMA_INDEX.getSchema(listType)
                          .ensureExistence(recursive: true));
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