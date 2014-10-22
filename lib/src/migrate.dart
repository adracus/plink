part of plink;


abstract class Migrator {
  final int levenshteinThreshold;
  
  const Migrator(this.levenshteinThreshold);
  
  Future migrate();
}


class AutoMigrator extends Migrator {
  const AutoMigrator(int levenshteinThreshold) : super(levenshteinThreshold);
  
  Future migrate() => new Future.value();
}


class Table extends Model {
  String name;
  
  Table(this.name, this.columns);
  
  @defaultConstructor
  Table.def();
  
  Table.fromSchema(Schema schema)
      : name = schema.name,
        columns = _extractSchemaColumns(schema);
        
  static List<Column> _extractSchemaColumns(Schema schema) {
    var result = [];
    result.addAll(schema.fields.map((field) =>
        new Column.fromFieldSchema(field)));
    result.addAll(schema.relations.map((rel) =>
        new Column.fromRelation(rel)));
    return result;
  }
  
  List<Column> columns;
  
  operator==(other) {
    if (other is! Table) return false;
    if (other.name != name) return false;
    if (other.columns.length != columns.length) return false;
    _sortColumns();
    other._sortColumns();
    for (int i = 0; i < columns.length; i++) {
      if (columns[i] != other.columns[i]) return false;
    }
    return true;
  }
  
  int differenceTo(Table other) {
    return levenshtein(name, other.name);
  }
  
  void _sortColumns() {
    columns.sort((c1, c2) => c1.name.compareTo(c2.name));
  }
  
  int get hashCode {
    int result = 17 * 37 + name.hashCode;
    _sortColumns();
    for (int i = 0; i < columns.length; i++) {
      result = result * 37 + columns[i].hashCode;
    }
    return result;
  }
  
  
  toString() => "Table '$name'";
}


class Column extends Model {
  String name;
  String type;
  
  Column(this.name, this.type);
  
  @defaultConstructor
  Column.def();
  
  operator==(other) {
    if (other is! Column) return false;
    return name == other.name && type == other.type;
  }
  
  int get hashCode {
    int result = 17;
    result = 37 * result + name.hashCode;
    result = 37 * result + type.hashCode;
    return result;
  }
  
  Column.fromFieldSchema(FieldSchema schema)
      : name = schema.name,
        type = schema.type;
  
  Column.fromRelation(Relation relation)
      : name = relation.fieldName,
        type = $(reflectType(relation.type).simpleName).name;
  
  
  toString() => "Column $type '$name'";
}


class TableMatchResult implements Comparable {
  final int distance;
  final Table from;
  final Table matched;
  
  TableMatchResult(Table from, Table matched)
      : from = from,
        matched = matched,
        distance = from.differenceTo(matched);
  
  int compareTo(TableMatchResult other) => distance.compareTo(other.distance);
}