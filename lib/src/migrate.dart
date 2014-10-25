part of plink;


abstract class Migrator {
  final int levenshteinThreshold;
  
  const Migrator(this.levenshteinThreshold);
  
  Future migrate() {
    var inMemoryTables = SCHEMA_INDEX.schemes.map((schema) =>
        new Table.fromSchema(schema)).toList();
    var tableSchema = Table.schema;
    return tableSchema.ensureExistence(recursive: true).then((_) {
      return tableSchema.all(populate: true).then((tables) {
        return Future.wait(inMemoryTables.map((t) =>
            evaluateMatches(t, tables)));
      });
    });
  }
  
  
  Future evaluateMatches(Table table, List<Table> databaseTables) {
    var matches = LevenshteinMatch.getMatches(table, databaseTables)
                       .where((match) => match.distance <= levenshteinThreshold)
                       .toList();
    return migrateTable(table, matches);
  }
  
  
  Future migrateTable(Table table, List<LevenshteinMatch> matches);
}


class AutoMigrator extends Migrator {
  const AutoMigrator(int levenshteinThreshold) : super(levenshteinThreshold);
  
  Future migrateTable(Table table, List<LevenshteinMatch> matches) {
    if (matches.length == 0) {
      var fs = [];
      fs.add(SCHEMA_INDEX.getSchema(table.name)
                .ensureExistence(recursive: false));
      fs.add(Table.schema.save(table, recursive: true));
      return Future.wait(fs);
    }
    var best = LevenshteinMatch.getBestMatch(matches);
    if (table == best.matched) return new Future.value();
    log.shout("TRYING TO MIGRATE $table");
    return convertTable(best.matched, table);
  }
  
  Future convertTable(Table old, Table nu) {
    if (nu.name != old.name) {
      return convertTableName(old, nu);
    }
    return new Future.value();
  }
  
  
  Future convertTableName(Table old, Table nu) {
    var fs = [];
    fs.add(adapter.renameTable(old.name, nu.name));
    old.name = nu.name;
    fs.add(Table.schema.save(old, recursive: true));
    return Future.wait(fs);
  }
}


abstract class Named {
  String get name;
  
  int differenceTo(Named other) {
    return levenshtein(name, other.name);
  }
  
  static List<Named> toNamedList(List elems) =>
      elems.map((elem) => elem as Named).toList();
}


class Table extends Model with Named {
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
  
  List<Column> columns = [];
  
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
  
  
  static ModelSchema get schema => SCHEMA_INDEX.getModelSchema(Table);
  
  
  toString() => "Table '$name'";
}


class Column extends Model with Named {
  String name;
  String type;
  bool isRelation;
  List<ColumnConstraint> constraints = [];
  
  Column(this.name, this.type, this.constraints, this.isRelation);
  
  @defaultConstructor
  Column.def();
  
  operator==(other) {
    if (constraints == null) constraints = [];
    if (other is! Column) return false;
    if (other.name != name || other.type != type) return false;
    if (other.constraints.length != constraints.length) return false;
    _sortConstraints();
    other._sortConstraints();
    for (int i = 0; i < constraints.length; i++) {
      if (constraints[i] != other.constraints[i]) return false;
    }
    return true;
  }
  
  
  void _sortConstraints() {
    constraints.sort((c1, c2) => c1.name.compareTo(c2.name));
  }
  
  int get hashCode {
    if (constraints == null) constraints = [];
    int result = 17;
    result = 37 * result + name.hashCode;
    result = 37 * result + type.hashCode;
    _sortConstraints();
    for (int i = 0; i < constraints.length; i++) {
      result = result * 37 + constraints[i].hashCode;
    }
    return result;
  }
  
  Column.fromFieldSchema(FieldSchema schema)
      : name = schema.name,
        type = schema.type,
        constraints = schema.constraints.map((c) =>
            new ColumnConstraint.fromConstraint(c)).toList(),
        isRelation = false;
  
  Column.fromRelation(Relation relation)
      : name = relation.fieldName,
        type = $(reflectType(relation.type).simpleName).name,
        constraints = [],
        isRelation = true;
  
  
  toString() => "Column $type '$name'";
}


class ColumnConstraint extends Model with Named {
  String type;
  
  ColumnConstraint(this.type);
  ColumnConstraint.fromType(Type c)
      : type = $(reflectType(c).simpleName).name;
  
  
  @defaultConstructor
  ColumnConstraint.def();
  
  
  factory ColumnConstraint.fromConstraint(Constraint c) {
    if (c is Unique)
      return new ColumnConstraint.fromType(Unique);
    if (c is AutoIncrement)
      return new ColumnConstraint.fromType(AutoIncrement);
    if (c is PrimaryKey)
      return new ColumnConstraint.fromType(PrimaryKey);
    throw new ArgumentError("Unsupported constraint $c");
  }
  
  String get name => type;
  
  operator==(other) {
    if (other is! ColumnConstraint) return false;
    return other.type == this.type;
  }
  
  
  int get hashCode => type.hashCode;
}


class LevenshteinMatch implements Comparable {
  final int distance;
  final Named from;
  final Named matched;
  
  LevenshteinMatch(Named from, Named matched)
      : from = from,
        matched = matched,
        distance = from.differenceTo(matched);
  
  static LevenshteinMatch getBestMatch(List<LevenshteinMatch> matches) {
    if (matches.length == 0) return null;
    matches.sort();
    return matches.first;
  }
  
  static List<LevenshteinMatch> getMatches(Named named, List<Named> possibilities) {
    return possibilities.map((p) =>
        new LevenshteinMatch(named, p)).toList(growable: true);
  }
  
  int compareTo(LevenshteinMatch other) => distance.compareTo(other.distance);
}