part of plink;


abstract class AdapterEndpoint {
  Future<DatabaseAdapter> getAdapter();
}


abstract class DatabaseAdapter {
  Future<List<Map<String, dynamic>>> where(String tableName,
      Map<String, dynamic> condition);
  
  Future createTable(String tableName, List<DatabaseField> fields);
  
  Future dropTable(String tableName);
  
  Future<Map<String, dynamic>> insert(String tableName,
      Map<String, dynamic> values);
  
  Future delete(String tableName, Map<String, dynamic> condition);
  
  Future hasTable(String tableName);
}

class DatabaseField {
  final String name;
  final String type;
  final List<Constraint> constraints;

  DatabaseField(this.name, this.type, [this.constraints = const[]]);
  DatabaseField.fromField(Field field)
      : name = str(field.name),
        type = str(field.type).toLowerCase(),
        constraints = field.constraints._content.toList();
  
  static List<DatabaseField> fromFieldCombination(FieldCombination combination) {
    return combination.content.map((field) => new DatabaseField.fromField(field))
                              .toList();
  }
}