part of plink;


const Key KEY = const Key();
const AutoIncrement AUTO_INCREMENT = const AutoIncrement();


abstract class Schema<E> {
  Symbol get name;
  SchemaIndex get index;

  FieldCombination get fields;

  Future<E> load(int id);
  Future delete(int id);
}


abstract class WeakSchema<E> implements Schema<E> {
  Future<E> save(int sourceId, E element);
  Future delete(int sourceId);
}


abstract class StrongSchema<E> implements Schema<E>{
  Future<E> save(E element);
  Future delete(int id);
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
  final Migrator migrator;
  MapperFramework _mappers;
  Set<Schema> _schemes;

  SchemaIndex(Iterable<ClassMirror> classes, this.migrator) {
    _schemes = classes.toSet().map((clazz) =>
        new ModelSchema(clazz, this)).toSet();
    _mappers = new MapperFramework(this);
    migrator.migrate(this);
  }

  ModelSchema getModelSchema(Type type) {
    return _schemes.firstWhere((schema) =>
        schema is ModelSchema && schema.type == type);
  }

  Future<DatabaseAdapter> getAdapter() => migrator.getAdapter();
  
  MapperFramework get mappers => _mappers;
  
  Schema schemaFor(arg) {
    if (arg is! Type && arg is! String && arg is! Symbol)
      throw new ArgumentError();
    if (arg is Type) {
      var mapper = mappers.mapperFor(arg);
      if (mapper != null) return mapper;
      return getModelSchema(arg);
    }
    var name = arg;
    if (name is String) name = new Symbol(name);
    return _schemes.firstWhere((scheme) => scheme.name == name);
  }
  
  List<Schema> get allSchemes {
    var result = [];
    result..addAll(_schemes)
          ..addAll(_mappers.mappers)
          ..addAll(_schemes.where((schema) =>
        schema is ModelSchema).map((ModelSchema schema) =>
            schema.relations).fold([], (l1, l2) => l1..addAll(l2)));
    return result;
  }
}


class MapperFramework {
  final IntMapper intMapper;
  final StringMapper stringMapper;
  final DoubleMapper doubleMapper;
  final DateTimeMapper dateTimeMapper;
  final NullMapper nullMapper;
  
  MapperFramework(SchemaIndex index)
      : intMapper = new IntMapper(index),
        stringMapper = new StringMapper(index),
        doubleMapper = new DoubleMapper(index),
        dateTimeMapper = new DateTimeMapper(index),
        nullMapper = new NullMapper(index);
  
  Mapper mapperFor(Type type) {
    if (type == int) return intMapper;
    if (type == String) return stringMapper;
    if (type == double) return doubleMapper;
    if (type == DateTime) return dateTimeMapper;
    if (type == Null) return nullMapper;
    return null;
  }
  
  List<Mapper> get mappers => [intMapper, stringMapper, doubleMapper,
                               dateTimeMapper, nullMapper];
}