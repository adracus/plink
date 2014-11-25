part of plink;


const Key KEY = const Key();
const AutoIncrement AUTO_INCREMENT = const AutoIncrement();


abstract class Schema<E> {
  Symbol get name;
  SchemaIndex get index;
  
  bool get needsPersistance;

  FieldCombination get fields;

  Future<E> find(int id);
  Future<List<E>> all();
  Future delete(int id, {bool deep: false});
  Future drop();
}


abstract class WeakSchema<E> implements Schema<E> {
  Future<E> save(int sourceId, E element, {bool deep: false});
}


abstract class Identifyable {
  int get id;
}


abstract class StrongSchema<E extends Identifyable> implements Schema<E>{
  Future<E> save(E element, {bool deep: false});
}


class FieldCombination {
  final Set<Field> content;

  factory FieldCombination(Iterable<Field> fields) {
    if (fields == null || fields.every((field) => !field.isKeyField))
      throw new ArgumentError("Fields has to contain a key");
    return new FieldCombination._(fields);
  }

  FieldCombination._(Iterable<Field> fields)
      : content = new Set.from(fields);
  
  FieldCombination._empty()
      : content = new Set();
}


class Field {
  final Symbol name;
  final Type type;
  final ConstraintSet constraints;
  Field(this.name, this.type, [Iterable<Constraint> constraints = const []])
      : constraints = new ConstraintSet(constraints);

  bool get isKeyField => constraints.hasKeyConstraint;
}


abstract class Constraint {
}


class Key implements Constraint {
  const Key();
}


class AutoIncrement implements Constraint {
  const AutoIncrement();
}


class ConstraintSet {
  final Set<Constraint> _content;

  ConstraintSet([Iterable<Constraint> constraints = const []])
      : _content = new Set.from(constraints);

  bool get hasKeyConstraint => _content.any((c) => c is Key);
}


class SchemaIndex {
  final AdapterEndpoint endpoint;
  MapperFramework _mappers;
  Set<ModelSchema> _schemes;

  SchemaIndex(Iterable<ClassMirror> classes, this.endpoint) {
    _schemes = classes.toSet().map((clazz) =>
        new ModelSchema(clazz, this)).toSet();
    _mappers = new MapperFramework(this);
  }

  Future<DatabaseAdapter> getAdapter() => endpoint.getAdapter();
  
  MapperFramework get mappers => _mappers;
  
  List<Schema> schemesFor(Type type) {
    return _schemes.where((schema) =>
        reflectType(schema.type).isAssignableTo(reflectType(type))).toList();
  }
  
  Schema schemaFor(arg) {
    var mapper = mappers.mapperFor(arg, orElse: () => null);
    if (mapper != null) return mapper;
    var name = _toSym(arg);
    return _schemes.firstWhere((schema) => schema.name == name,
        orElse: () => throw "No Schema found for $arg");
  }
  
  ModelSchema modelSchemaFor(arg){
    var name = _toSym(arg);
    return _schemes.firstWhere((schema) => schema.name == name,
        orElse: () =>
            throw "No Schema found for $arg");
  }
  
  static Symbol _toSym(arg) {
    if (arg is String) return new Symbol(arg);
    if (arg is Symbol) return arg;
    if (arg is Model) return reflectType(arg.runtimeType).qualifiedName;
    if (arg is Type) return reflectType(arg).qualifiedName;
    throw "Unsupported argument $arg";
  }
  
  Set<Schema> get schemes => _schemes;
  
  Future dropAll() {
    var f1 = Future.wait(schemes.map((schema) => schema.drop()));
    var f2 = Future.wait(mappers.mappers.map((mapper) => mapper.drop()));
    return Future.wait([f1, f2]);
  }
}


class MapperFramework {
  final List<Mapper> mappers;
  
  MapperFramework(SchemaIndex index)
      : mappers = Mapper.generateMappers(index);
  
  Mapper mapperFor(arg, {Mapper orElse ()}) {
    if (arg is Type)
      return mappers.firstWhere((mapper) =>
          mapper.matches(arg), orElse: orElse);
    if (arg is String)
      return mappers.firstWhere((mapper) =>
          mapper.name == new Symbol(arg), orElse: orElse);
    throw "Unsupported argument $arg";
  }
  
  Future dropMappers() => Future.wait(mappers.map((mapper) => mapper.drop()));
}