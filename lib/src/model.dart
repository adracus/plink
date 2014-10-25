part of plink;

@ignore
class Model {
  static const _MODEL_FIELDS = const ["id", "created_at", "updated_at"];
  static Map<Type, Map<Symbol, VariableMirror>> _fieldCache = {};
  
  @primaryKey @autoIncrement
  int id;
  DateTime created_at;
  DateTime updated_at;
  
  Future<Model> save({bool recursive: true}) =>
      REPO.save(this, recursive: recursive);
  
  
  Future delete({bool recursive: true}) {
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
  
  
  void updateWithOther(Model other) {
    if (other.runtimeType != this.runtimeType)
      throw new ArgumentError("$other has wrong type");
    var values = other._extractValues(acceptNullValues: true);
    _MODEL_FIELDS.forEach((field) => values.remove(field));
    values.forEach((key, value) => _setField(key, value));
  }
  
  
  _setField(String name, value) {
    reflect(this).setField(new Symbol(name), value).reflectee;
  }
  
  
  _getField(String name) {
    return reflect(this).getField(new Symbol(name)).reflectee;
  }
  
  
  ModelSchema get _schema => SCHEMA_INDEX.getModelSchema(this);
}