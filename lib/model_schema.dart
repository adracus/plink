part of plink;


abstract class Schema<E> {
  final Type type;
  final String name;
  final List<FieldSchema> fields;
  final List<Relation> relations;
  
  
  FieldSchema getField(String name) =>
      fields.firstWhere((field) => field.name == name);
  
  
  Schema(this.type, this.name, [this.fields = const [],
      this.relations = const[]]);
  
  
  String toString() => "ModelSchema '$name' (${fields.map((f) =>
      f.toString()).join(", ")})";
      
  
  InstanceMirror newInstanceMirror() =>
      reflectClass(type).newInstance(_empty, []);
      
      
  newInstance() => newInstanceMirror().reflectee;
  
  
  Future _ensureExistence() => REPO._checkTable(this);
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
  
  
  Future delete(E data) {
    return _ensureExistence().then((_) => _delete(data));
  }
  
  
  Future _delete(E data);
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
  
  
  Future delete(D dependency) => _ensureExistence().then((_) => _delete(dependency));
  
  
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
  
  
  Future<Model> _save(Model model) {
    return _store(model).then((saved) {
      return Future.wait(relations.map((rel) =>
          rel.save(model.getField(rel.fieldName), saved)
            .then((savedRelation) =>
                saved.setField(rel.fieldName, savedRelation))))
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
  
  
  Future<Model> _populate(Model model) {
    return Future.wait(relations.map((rel) => rel.where(model).then((value) =>
        model.setField(rel.fieldName, value)))).then((_) => model);
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
  
  
  Future _delete(Model model) {
    return REPO.adapter.delete(name, {"id": model.id}).then((_) {
      return Future.wait(relations.map((rel) => rel.delete(model)));
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
  
  
  Relation(Type type, String name, this.fieldName, [List<FieldSchema> fields,
           List<Relation> relations]) : super(type, name, fields, relations);
  
  
  factory Relation.fromMirror(VariableMirror mirror) {
    var type = mirror.type.originalDeclaration;
    if (type.originalDeclaration == reflectClass(List))
      return new ListRelation.fromMirror(mirror);
  }
}



abstract class ListRelation<E extends List> extends Relation<E> {
  final Type listType;
  
  
  factory ListRelation.fromMirror(VariableMirror mirror) {
    if (PRIMITIVES.contains(mirror.type.typeArguments.single.reflectedType))
      return new PrimitiveListRelation.fromMirror(mirror);
  }
  
  
  ListRelation(Type type, String name, String fieldName, this.listType, [
               List<FieldSchema> fields, List<Relation> relations = const[]])
      : super(type, name, fieldName, fields,
          [new FieldSchema("index", type: int)]..addAll(relations));
}



class PrimitiveListRelation extends ListRelation<dynamic> {
  factory PrimitiveListRelation.fromMirror(VariableMirror mirror) {
    var name = $(mirror.owner.simpleName).name + "_" + $(mirror.simpleName).name;
    var type = mirror.type.typeArguments.single.reflectedType;
    var fields = [new FieldSchema("${name}_id",
                                  type: int),
                  new FieldSchema("${name}_index",
                                  type: int),
                  new FieldSchema($(mirror.simpleName).name, type: type)];
    return new PrimitiveListRelation(mirror.type.reflectedType,
        name, $(mirror.simpleName).name, type, fields);
  }
  
  
  PrimitiveListRelation(Type type, String name, String fieldName, Type listType,
                        [List<FieldSchema> fields])
      : super(type, name, fieldName, listType, fields);
  
  
  FieldSchema getField(String name) =>
        fields.firstWhere((field) => field.name == name);
  
  
  Future<List> _where(Model dependency) {
    return REPO.adapter.findWhere(name, {idName: dependency.id}).then((rows) {
      if (rows.length == 0) return null;
      return listFromRows(rows);
    });
  }
  
  
  Future<List> _save(List data, Model model) {
    if (data == null) {
      return _delete(model).then((_) => null);
    }
    return _delete(model).then((_) { // TODO: Intelligent diff instead of delete
      return Future.wait(listToMap(data, model.id).map((values) =>
        REPO.adapter.saveToTable(name, values))).then((_) => data);
    });
  }
  
  
  List<Map<String, dynamic>> listToMap(List list, int id) {
    var result = [];
    for(int i = 0; i < list.length; i++) {
      result.add({indexName: i, idName: id, fieldName: list[i]});
    }
    return result;
  }
  
  
  Future _delete(Model dependency) {
    return REPO.adapter.delete(name, {idName: dependency.id});
  }
  
  
  List listFromRows(Iterable<Map<String, dynamic>> rows) {
    if (rows.length == 0) return [];
    var maxIndex = $(rows.map((row) => row[indexName]).toList()).max() + 1;
    var result = new List.generate(maxIndex, (_) => null, growable: true);
    rows.forEach((row) => result[row[indexName]] = row[fieldName]);
    return result;
  }
  
  
  String get idName => "${name}_id";
  String get indexName => "${name}_index";
  
  
  List<Schema> get relations => [];
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