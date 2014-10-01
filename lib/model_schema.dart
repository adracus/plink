part of plink;

class ModelSchema {
  final String name;
  final List<FieldSchema> fields;
  final List<Relation> relations;
  
  
  factory ModelSchema.fromMirror(ClassMirror mirror) {
    var name = $(mirror.simpleName).name;
    var fields = $(mirror).fields.values.where((VariableMirror mir) =>
        _isPrimitiveField(mir)).map((mir) =>
            new FieldSchema.fromMirror(mir));
    var relations = $(mirror).fields.values.where((VariableMirror mir) =>
        _isFieldCandidate(mir) && !_isPrimitive(mir)).map((mir) =>
            new Relation.fromMirror(mir));
    return new ModelSchema(name, fields.toList(), relations.toList());
  }
  
  
  FieldSchema getField(String name) =>
      fields.firstWhere((field) => field.name == name);
  
  
  ModelSchema(this.name, [this.fields = const [], this.relations = const[]]);
  
  
  String toString() => "ModelSchema '$name' (${fields.map((f) =>
      f.toString()).join(", ")})";
      
  
  Future<Model> save(Model model) {
    
  }
}



abstract class Relation extends ModelSchema {
  final String fieldName;
  
  
  Relation(String name, this.fieldName, [List<FieldSchema> fields,
           List<Relation> relations]) : super(name, fields, relations);
  
  
  factory Relation.fromMirror(VariableMirror mirror) {
    var type = mirror.type.originalDeclaration;
    if (type.originalDeclaration == reflectClass(List))
      return new ListRelation.fromMirror(mirror);
  }
}



abstract class ListRelation extends Relation {
  final Type listType;
  
  
  factory ListRelation.fromMirror(VariableMirror mirror) {
    if (PRIMITIVES.contains(mirror.type.typeArguments.single.reflectedType))
      return new PrimitiveListRelation.fromMirror(mirror);
  }
  
  
  ListRelation(String name, String fieldName, this.listType, [
               List<FieldSchema> fields, List<Relation> relations])
      : super(name, fieldName, fields, relations);
}



class PrimitiveListRelation implements ListRelation {
  final List<FieldSchema> fields;
  final Type listType;
  final String name;
  final String fieldName;
  
  
  factory PrimitiveListRelation.fromMirror(VariableMirror mirror) {
    var name = $(mirror.owner.simpleName).name + "_" + $(mirror.simpleName).name;
    var type = mirror.type.typeArguments.single.reflectedType;
    var fields = [new FieldSchema($(mirror.owner.simpleName).name + "_id",
                                  type: int),
                  new FieldSchema($(mirror.simpleName).name, type: type)];
    return new PrimitiveListRelation(name, $(mirror.simpleName).name, type, fields);
  }
  
  
  PrimitiveListRelation(this.name, this.fieldName, this.listType, 
                        [this.fields = const[]]);
  
  
  FieldSchema getField(String name) =>
        fields.firstWhere((field) => field.name == name);
  
  
  List<ModelSchema> get relations => [];
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