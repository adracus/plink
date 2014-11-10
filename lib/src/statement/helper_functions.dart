part of plink.statement;

const select = const SelectStatementGenerator();


List<String> from(arg) => arg is List ? arg : [arg];


InnerJoin innerJoin(String tableName, ColumnIdentifierPair pair) =>
    new InnerJoin(tableName, pair.first, pair.second);


WhereClause where(WhereStatement statement) => new WhereClause(statement);


Column c(arg) => new Column(arg);


ColumnIdentifier i(tableName, columnName) =>
    new ColumnIdentifier(tableName, columnName);


@proxy
class SelectStatementGenerator {
  const SelectStatementGenerator();
  
  noSuchMethod(Invocation invocation) {
    if (#call == invocation.memberName) return generateSelect(invocation);
    return super.noSuchMethod(invocation);
  }
  
  SelectStatement generateSelect(Invocation invocation) {
    var args = new List.from(invocation.positionalArguments, growable: true);
    var columns = args[0];
    List<String> tableIdentifier = args[1];
    var join;
    var where;
    if (args.length > 2 && args[2] is Join) {
      join = args[2];
      args.removeAt(2);
    }
    if (3 == args.length) {
      where = args[2];
    }
    var select;
    if (columns is List)
      return new SelectStatement(
          new SelectSome(columns, tableIdentifier, join), where);
    return new SelectStatement(
        new SelectAll(tableIdentifier, join), where);
  }
}

ColumnIdentifierPair on(ColumnIdentifier first, ColumnIdentifier second) =>
    new ColumnIdentifierPair(first, second);

class ColumnIdentifierPair {
  final ColumnIdentifier first;
  final ColumnIdentifier second;
  
  ColumnIdentifierPair(this.first, this.second);
}