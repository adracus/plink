part of plink;

const ID = "id";
const TARGET_ID = "targetId";
const TARGET_TABLE = "targetTable";


class Relation implements WeakSchema {
  final SchemaIndex index;
  final Symbol sourceName;
  final Symbol qualifiedName;
  final Symbol simpleName;
  final FieldCombination fields = new FieldCombination(
      [new Field(const Symbol(ID), int, [KEY]),
       new Field(const Symbol(TARGET_ID), int, [KEY]),
       new Field(const Symbol(TARGET_TABLE), String, [KEY])]);

  Relation.fromField(VariableMirror field, ClassMirror source, this.index)
      : sourceName = source.qualifiedName,
        simpleName = field.simpleName,
        qualifiedName = field.qualifiedName;

  Future load(int sourceId) => index.getAdapter().then((adapter) {
    return fetchRecord(adapter, sourceId).then((record) {
      return index.schemaFor(record[TARGET_TABLE])
                  .load(record[TARGET_ID]);
    });
  });
  
  Symbol get name => combineSymbols(sourceName, simpleName);
  
  Future save(int sourceId, element) => index.getAdapter().then((adapter) {
    var schema = index.schemaFor(element.runtimeType) as StrongSchema;
    return (null == sourceId ? new Future.value() : delete(sourceId)).then((_) =>
        schema.save(element).then((saved) {
      return adapter.insert(str(name), {ID: sourceId, TARGET_ID: saved.id,
                                        TARGET_TABLE: str(schema.name)})
                    .then((_) => element);
    }));
  });
  
  
  Future delete(int sourceId) => index.getAdapter().then((adapter) {
    return fetchRecord(adapter, sourceId).then((record) {
      if (record == null) return new Future.value();
      return index.schemaFor(record[TARGET_TABLE]).delete(record[TARGET_ID]).then((_) {
        return adapter.delete(str(name), {ID: sourceId});
      });
    });
  });
  
  Future<Map<String, dynamic>> fetchRecord(DatabaseAdapter adapter, int sourceId) =>
      adapter.where(str(name), {ID: sourceId}).then((results) => 1 == results.length ?
          results.single : null);

  toString() => "Relation '${str(name)}'";
  
  
  Future drop() => index.getAdapter().then((adapter) {
    return adapter.dropTable(str(name));
  });
  
  
  bool get needsPersistance => true;
}