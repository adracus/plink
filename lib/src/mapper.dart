part of plink;


abstract class Mapper<T> implements StrongSchema {
  final SchemaIndex index;
  
  Mapper(this.index);
  
  Future<T> load(int id);
  Future<Mapped<T>> save(T element);
}

class Mapped<E> {
  final E value;
  final int id;
  
  Mapped(this.id, this.value);
}


abstract class PrimitiveMapper<T> extends Mapper<T> {
  PrimitiveMapper(SchemaIndex index) : super(index);
  
  FieldCombination get fields => new FieldCombination(
        [new Field(#id, int, [KEY]),
         new Field(#value, valueType)]);
  
  Type get valueType;
  
  Future<Mapped<T>> save(T element) => index.getAdapter().then((adapter) {
    return adapter.insert(str(name), {"value": element}).then((res) {
      var id = res["id"];
      var value = res["value"];
      return new Mapped<T>(id, value);
    });
  });
  
  Future<T> load(int id) => index.getAdapter().then((adapter) {
    return adapter.where(str(name), {"id": id}).then((res) {
      return res["value"];
    });
  });
  
  Future delete(int id) => index.getAdapter().then((adapter) {
    return adapter.delete(str(name), {"id": id});
  });
}


class StringMapper extends PrimitiveMapper<String> {
  final Symbol name = #StringMapper;
  
  StringMapper(SchemaIndex index) : super(index);
  
  Type get valueType => String;
}


class DoubleMapper extends PrimitiveMapper<double> {
  final Symbol name = #DoubleMapper;
  
  DoubleMapper(SchemaIndex index) : super(index);
  
  Type get valueType => double;
}


class IntMapper extends PrimitiveMapper<int> {
  final Symbol name = #IntMapper;
  
  IntMapper(SchemaIndex index) : super(index);
  
  Type get valueType => int;
}


class DateTimeMapper extends PrimitiveMapper<DateTime> {
  final Symbol name = #DateTimeMapper;
  
  DateTimeMapper(SchemaIndex index) : super(index);
  
  Type get valueType => DateTime;
}


class NullMapper implements Mapper<Null> {
  final Symbol name = #NullMapper;
  final SchemaIndex index;
  
  NullMapper(this.index);
  
  FieldCombination get fields => new FieldCombination(
          [new Field(#id, int, [KEY])]);
  
  Future<Mapped<Null>> save(Null element) =>
      new Future.value(new Mapped<Null>(1, null));
  
  
  Future<Null> load(int id) => new Future.value(null);
  
  Future delete(int id) => new Future.value();
}