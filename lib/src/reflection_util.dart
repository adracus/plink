part of plink;

final Map<Type, Symbol> _defaultConstructorSymbols = {};
const Object ignore = const Object();
const Object defaultConstructor = const Object();
const Symbol _empty = const Symbol("");
const List<Type> PRIMITIVES = const [double, int, String, DateTime];


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