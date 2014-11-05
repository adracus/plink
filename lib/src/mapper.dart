part of plink;

StrongSchema _schemaFor(SchemaIndex index, arg) {
  if (arg is! Identifyable) throw new ArgumentError();
  if (arg is Mapped) return index.schemaFor(arg.value.runtimeType);
  return index.schemaFor(arg.runtimeType);
}

_value(arg) {
  if (arg is! Identifyable) throw new ArgumentError();
  if (arg is Mapped) return arg.value;
  return arg;
}


abstract class Mapper<T> implements StrongSchema {
  SchemaIndex get index;
  
  Future<T> load(int id);
  Future<Mapped<T>> save(T element);
  
  static Type getMapperType(Mapper mapper) {
    var clazz = reflect(mapper).type;
    var typeArgs = clazz.typeVariables;
    return typeArgs.single.reflectedType;
  }
  
  bool matches(Type type);
  
  static List<Mapper> generateMappers(SchemaIndex index) {
    var classMap = $.rootLibrary.getClasses();
    var mapperClasses = classMap.values.where((clazz) =>
        !clazz.isAbstract && clazz.isSubtypeOf(reflectType(Mapper)));
    var mappers = mapperClasses.map((clazz) =>
        clazz.newInstance(const Symbol(''), [index]).reflectee).toList();
    return mappers;
  }
}

class Mapped<E> implements Identifyable {
  final E value;
  final int id;
  
  Mapped(this.id, this.value);
}


abstract class PrimitiveMapper<T> implements Mapper<T> {
  SchemaIndex get index;
  
  FieldCombination get fields => new FieldCombination(
        [new Field(#id, int, [KEY, AUTO_INCREMENT]),
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
      return res.single["value"];
    });
  });
  
  Future delete(int id) => index.getAdapter().then((adapter) {
    return adapter.delete(str(name), {"id": id});
  });
  
  Future drop() => index.getAdapter().then((adapter) =>
      adapter.dropTable(str(name)));
  
  bool get needsPersistance => true;
}


abstract class ConvertMapper<T, E> implements Mapper<T> {
  SchemaIndex get index;
  
  Type get coveredType;
  
  FieldCombination get fields => new FieldCombination._empty();
  StrongSchema get coveredSchema => index.schemaFor(coveredType);
  
  Future drop() => new Future.value();
  
  T decode(E element);
  E encode(T element);
  
  bool get needsPersistance => false;
  
  Future<Mapped<T>> save(T element) {
    return coveredSchema.save(encode(element)).then((mapped) =>
        new Mapped(mapped.id, decode(mapped.value)));
  }
  
  Future<T> load(int id) => coveredSchema.load(id)
    .then((loaded) => decode(loaded));
  
  Future delete(int id) => coveredSchema.delete(id);
}


class StringMapper extends Object with PrimitiveMapper<String> {
  static final Symbol className = reflectClass(StringMapper).qualifiedName;
  final SchemaIndex index;
  
  StringMapper(this.index);
  
  Type get valueType => String;
  Symbol get name => className;
  
  bool matches(Type type) => String == type;
}


class DoubleMapper extends Object with PrimitiveMapper<double> {
  static final Symbol className = reflectClass(DoubleMapper).qualifiedName;
  final SchemaIndex index;
  
  DoubleMapper(this.index);
  
  Type get valueType => double;
  Symbol get name => className;
  bool matches(Type type) => double == type;
}


class IntMapper extends PrimitiveMapper<int> {
  static final Symbol className = reflectClass(IntMapper).qualifiedName;
  final SchemaIndex index;
  
  IntMapper(this.index);
  
  Type get valueType => int;
  Symbol get name => className;
  bool matches(Type type) => int == type;
}


class DateTimeMapper extends PrimitiveMapper<DateTime> {
  static final Symbol className = reflectClass(DateTimeMapper).qualifiedName;
  final SchemaIndex index;
  
  DateTimeMapper(this.index);
  
  Type get valueType => DateTime;
  Symbol get name => className;
  bool matches(Type type) => DateTime == type;
}


class NullMapper implements Mapper<Null> {
  static final Symbol className = reflectClass(NullMapper).qualifiedName;
  final SchemaIndex index;
  
  NullMapper(this.index);
  
  FieldCombination get fields => new FieldCombination(
          [new Field(#id, int, [KEY])]);
  
  Future<Mapped<Null>> save(Null element) =>
      new Future.value(new Mapped<Null>(1, null));
  
  
  Future<Null> load(int id) => new Future.value(null);
  
  Future delete(int id) => new Future.value();
  
  Symbol get name => className;
  
  bool get needsPersistance => false;
  
  Future drop() => new Future.value();
  
  bool matches(Type type) => Null == type;
}

class SymbolMapper extends Object with ConvertMapper<Symbol, String> {
  static final Symbol className = reflectClass(SymbolMapper).qualifiedName;
  final Type coveredType = String;
  final SchemaIndex index;
  
  SymbolMapper(this.index);
  
  Symbol decode(String element) => new Symbol(element);
  String encode(Symbol element) => str(element);
  
  Symbol get name => className;
  
  bool matches(Type type) =>
      reflectType(type).isSubtypeOf(reflectType(Symbol));
}


class ListMapper implements Mapper<List> {
  static final Symbol className = reflectClass(ListMapper).qualifiedName;
  final SchemaIndex index;
  
  ListMapper(this.index);
  
  final FieldCombination fields = new FieldCombination(
      [new Field(#id, int, [KEY, AUTO_INCREMENT]),
       new Field(#index, int, [KEY]),
       new Field(#targetTable, String, [KEY]),
       new Field(#targetId, int, [KEY])]);
  
  Future<Mapped<List>> save(List element) => index.getAdapter().then((adapter) {
    var fs = [];
    for (int i = 0; i < element.length; i++) {
      var schema = index.schemaFor(element[i].runtimeType) as StrongSchema;
      fs.add(schema.save(element[i]));
    }
    return Future.wait(fs).then(_persistListLink).then((id) =>
        new Mapped<List>(id, element));
  });
  
  Future<int> _persistListLink(List<Identifyable> element) => index.getAdapter().then((adapter) {
    if (element.length == 0) return adapter.insert(str(name), {"index": 0,
      "targetTable": "", "targetId": 0}).then((row) => row["id"]);
    var first = element.first;
    return adapter.insert(str(name), {"index": 0, "targetTable":
        str(index.schemaFor(first.value.runtimeType).name),
        "targetId": first.id}).then((rec) {
      var id = rec["id"];
      var fs = [];
      for (int i = 1; i < element.length; i++) {
        fs.add(_saveSingleElement(adapter, element[i], id, i));
      }
      return Future.wait(fs).then((_) => id);
    });
  });
  
  Future _saveSingleElement(DatabaseAdapter adapter, Mapped element, int id, int i) {
    var targetTable = str(index.schemaFor(element.value.runtimeType).name);
    return adapter.insert(str(name), {"id": id, "index": i, "targetTable": targetTable,
      "targetId": element.id});
  }
  
  Future delete(int id) => index.getAdapter().then((adapter) { //TODO: Should all items
    return adapter.where(str(name), {"id": id}).then((rows) {  //Be deleted ??
      if (_isEmptyListResult(rows)) return adapter.delete(str(name), {"id": id});
      return Future.wait(rows.map((row) => _deleteRow(adapter, row))).then((_) {
        return adapter.delete(str(name), {"id": id});
      });
    });
  });
  
  Future<List> load(int id) => index.getAdapter().then((adapter) {
    return adapter.where(str(name), {"id": id}).then((rows) {
      if (_isEmptyListResult(rows)) return new Future.value([]);
      var fs = [];
      var result = new List.generate(rows.length, (_) => null, growable: true);
      Future.wait(rows.map((row) => _loadItemFromRow(row).then((loaded) {
        result[row["index"]] = loaded;
      }))).then((_) => result);
    });
  });
  
  
  Future _deleteRow(DatabaseAdapter adapter, Map<String, dynamic> row) {
    return index.schemaFor(row["targetTable"]).delete(row["targetId"]);
  }
  
  
  Future _loadItemFromRow(Map<String, dynamic> row) {
    var schema = index.schemaFor(row["targetTable"]);
    return schema.load(row["targetId"]);
  }
  
  
  bool _isEmptyListResult(List<Map<String, dynamic>> rows) {
    return 1 == rows.length && rows.single["targetTable"] == "";
  }
  
  Symbol get name => className;
  
  bool get needsPersistance => true;
  
  Future drop() =>
      index.getAdapter().then((adapter) => adapter.dropTable(str(name)));
  
  bool matches(Type type) => reflectType(type).isSubtypeOf(reflectType(List));
}


class SetMapper extends Object with ConvertMapper<Set, List> {
  static final Symbol className = reflectClass(SetMapper).qualifiedName;
  final SchemaIndex index;
  final Type coveredType = List;
  
  SetMapper(this.index);
  
  List encode(Set element) => element.toList();
  Set decode(List element) => element.toSet();
  
  Symbol get name => className;
  
  bool matches(Type type) => reflectType(type).isSubtypeOf(reflectType(Set));
}


class MapMapper implements Mapper<Map> {
  static final Symbol className = reflectClass(MapMapper).qualifiedName;
  final SchemaIndex index;
  final FieldCombination fields = new FieldCombination(
      [new Field(#id, int, [KEY, AUTO_INCREMENT]),
       new Field(#keyId, int, [KEY]),
       new Field(#keyTable, String, [KEY]),
       new Field(#valueId, int, [KEY]),
       new Field(#valueTable, String, [KEY])]);
  
  MapMapper(this.index);
 
  Symbol get name => className;
  
  bool matches(Type type) => reflectType(type).isSubtypeOf(reflectType(Map));
  
  Future<Map> load(int id) => index.getAdapter().then((adapter) {
    return adapter.where(str(name), {"id": id}).then((records) {
      if (_isEmptyMapResult(records)) return new Future.value({});
      return Future.wait(records.map((record) => _loadPair(adapter, record))).then((pairs) {
        return KeyValuePair.fromKeyValues(pairs);
      });
    });
  });
  
  Future<KeyValuePair> _loadPair(DatabaseAdapter adapter, Map<String, dynamic> row) {
    var key, value;
    var keySchema = index.schemaFor(row["keyTable"]);
    var valueSchema = index.schemaFor(row["valueTable"]);
    var fs = [];
    fs.add(keySchema.load(row["keyId"]).then((k) => key = k));
    fs.add(valueSchema.load(row["valueId"]).then((v) => value = v));
    return Future.wait(fs).then((_) => new KeyValuePair(key, value));
  }
  
  bool _isEmptyMapResult(List<Map<String, dynamic>> rows) {
    return rows.length == 1 && rows.single["keyTable"] == ""
                            && rows.single["valueTable"] == ""
                            && rows.single["keyId"] == 0
                            && rows.single["valueId"] == 0;
  }
  
  Future<Mapped<Map>> save(Map element) => index.getAdapter().then((adapter) {
    if (0 == element.length) return adapter.insert(str(name), {"keyId": 0,
      "keyTable": "", "valueId": 0, "valueTable": ""}).then((savedRow) {
      return new Mapped(savedRow["id"], {});
    });
    var pairs = KeyValuePair.flattenMap(element);
    return Future.wait(pairs.map((pair) => _savePair(adapter, pair))).then((savedPairs) {
      return _saveMapLink(adapter, savedPairs).then((id) => new Mapped(id, element));
    });
  });
  
  Future<int> _saveMapLink(DatabaseAdapter adapter,
      List<KeyValuePair<Identifyable, Identifyable>> pairs) {
    var first = pairs.first;
    var keyTableName = str(_schemaFor(index, first.key).name);
    var valueTableName = str(_schemaFor(index, first.value).name);
    return adapter.insert(str(name), {"keyId": first.key.id, "keyTable": keyTableName,
      "valueId": first.value.id, "valueTable": valueTableName}).then((rec) {
      if (pairs.length == 1) return new Future.value(rec["id"]);
      var fs = [];
      for (int i = 1; i < pairs.length; i++) {
        keyTableName = str(_schemaFor(index, pairs[i].key).name);
        valueTableName = str(_schemaFor(index, pairs[i].value).name);
        fs.add(adapter.insert(str(name), {"keyId": pairs[i].key.id,
          "keyTable": keyTableName, "valueId": pairs[i].value.id,
          "valueTable": valueTableName}));
      }
      return Future.wait(fs).then((_) => rec["id"]);
    });
  }
  
  
  Future<KeyValuePair<Identifyable, Identifyable>>
  _savePair(DatabaseAdapter adapter, KeyValuePair pair) {
    var key, value;
    var fs = [];
    var keySchema = index.schemaFor(pair.key.runtimeType) as StrongSchema;
    var valueSchema = index.schemaFor(pair.value.runtimeType) as StrongSchema;
    fs.add(keySchema.save(pair.key).then((saved) => key = saved));
    fs.add(valueSchema.save(pair.value).then((saved) => value = saved));
    return Future.wait(fs).then((_) => new KeyValuePair(key, value));
  }
  
  Future delete(int id) => index.getAdapter().then((adapter) {
    adapter.delete(str(name), {"id": id});
  });
  
  Future drop() =>
      index.getAdapter().then((adapter) => adapter.dropTable(str(name)));
  
  final bool needsPersistance = true;
}


class KeyValuePair<K, V> {
  final K key;
  final V value;
  
  KeyValuePair(this.key, this.value);
  
  static List<KeyValuePair> flattenMap(Map map) {
    return $(map).flatten((key, value) => new KeyValuePair(key, value));
  }
  
  static Map fromKeyValues(Iterable<KeyValuePair> keyValues) {
    var result = {};
    keyValues.forEach((kvp) => result[kvp.key] = kvp.value);
    return result;
  }
}