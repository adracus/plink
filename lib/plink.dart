library plink;

import 'dart:mirrors';
import 'dart:async' show Future;
import 'package:u_til/u_til.dart';
import 'package:logging/logging.dart';


part 'model_repository.dart';
part 'model_schema.dart';
part 'database_adapter.dart';
part 'exceptions.dart';


const Object ignore = const Object();
const Object defaultConstructor = const Object();
const Symbol _empty = const Symbol("");
const List<Type> PRIMITIVES = const [double, int, String, DateTime];

final Map<Type, Symbol> _defaultConstructorSymbols = {};


bool _isPrimitive(arg) => arg is Type ? PRIMITIVES.contains(arg) :
  arg is VariableMirror ? PRIMITIVES.contains(arg.type.reflectedType) :
    PRIMITIVES.contains(arg.runtimeType);
  
bool _isFieldCandidate(VariableMirror arg) =>
    !_shouldBeIgnored(arg) && !arg.isStatic;
  
bool _isPrimitiveField(VariableMirror arg) =>
    !_shouldBeIgnored(arg) && !arg.isStatic && _isPrimitive(arg);

Symbol _getDefaultConstructorSymbol(Type type) {
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
  return _defaultConstructorSymbols[type] = _empty;
}
  
InstanceMirror _defaultInstanceMirror(Type type) =>
      reflectClass(type).newInstance(_getDefaultConstructorSymbol(type), []);

bool _isPrimitiveList(VariableMirror mirr) {
  var typeArgs = mirr.type.typeArguments;
  return typeArgs.length == 1 && _isPrimitive(typeArgs.single.reflectedType);
}

bool _isModelSubtype(ClassMirror clazz) {
  return clazz.isSubtypeOf(reflectType(Model));
}

bool _shouldBeIgnored(mirror) =>
    mirror.metadata.any((elem) => elem.reflectee == ignore);

@ignore
class Model {
  @ignore
  static Map<Type, Map<Symbol, VariableMirror>> _fieldCache = {};
  
  @primaryKey @autoIncrement
  int id;
  DateTime created_at;
  DateTime updated_at;
  
  Future<Model> save() => REPO.save(this);
  
  
  Future delete({bool recursive: false}) {
    if (id == null)
      return new Future.error("Cannot delete non persistent model");
    beforeDelete();
    return REPO.delete(this, recursive: recursive);
  }
  
  
  void beforeCreate() => null;
  void beforeUpdate() => null;
  void beforeDelete() => null;
  
  
  Map<Symbol, VariableMirror> get _fields {
    if (Model._fieldCache[this.runtimeType] == null) {
      Model._fieldCache[this.runtimeType] =
          $($(reflect(this).type).fields).whereValue(_isFieldCandidate);
    }
    return Model._fieldCache[this.runtimeType];
  }
  
  
  Map<String, dynamic> _extractValues({bool acceptNullValues: false}) {
    var reflection = reflect(this);
    var result = {};
    _fields.keys.forEach((sym) {
      var value = reflection.getField(sym).reflectee;
      if (acceptNullValues || value != null) result[$(sym).name] = value;
    });
        
    return result;
  }
  
  
  void setField(String name, value) {
    reflect(this).setField(new Symbol(name), value);
  }
  
  
  getField(String name) {
    return reflect(this).getField(new Symbol(name)).reflectee;
  }
}