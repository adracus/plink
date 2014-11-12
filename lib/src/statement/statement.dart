library plink.statement;


part 'helper_functions.dart';
part 'generator.dart';


abstract class SQLStatement {
}

class SelectStatement implements SQLStatement {
  final Select select;
  final WhereClause where;
  
  const SelectStatement(this.select, [this.where]);
}


abstract class Select {
  final List<String> tableIdentifier;
  final Join join;
  
  const Select(this.tableIdentifier, [this.join]);
}


class SelectAll extends Select {
  SelectAll(tableIdentifier, [Join join]) : super(tableIdentifier, join);
}

class SelectSome extends Select {
  final List<ColumnIdentifier> columns;
  
  SelectSome(this.columns, tableIdentifier, [Join join])
      : super(tableIdentifier, join);
}


abstract class Join {
  final String table;
  final ColumnIdentifier first;
  final ColumnIdentifier second;
  
  Join(this.table, this.first, this.second);
}


class ColumnIdentifier {
  final String table;
  final String name;
  
  ColumnIdentifier(this.table, this.name);
}


class InnerJoin extends Join {
  InnerJoin(String tableName, ColumnIdentifier first, ColumnIdentifier second)
      : super(tableName, first, second);
  
  String toSQL() {
    var sql = "INNER JOIN $table ON $first=$second";
    return sql;
  }
}

class WhereClause implements SQLStatement {
  final WhereStatement statement;
  
  const WhereClause(this.statement);
}

abstract class WhereStatement implements SQLStatement {
}

abstract class Combinator implements WhereStatement {
  final WhereStatement first;
  final WhereStatement second;
  
  const Combinator(this.first, this.second);
  
  AndCombinator and(Operator operator) => new AndCombinator(this, operator);
  OrCombinator or(Operator operator) => new OrCombinator(this, operator);
}

class AndCombinator extends Combinator {
  const AndCombinator(first, second) : super(first, second);
}


class OrCombinator extends Combinator {
  const OrCombinator(first, second) : super(first, second);
}


class Column {
  final String name;
  
  Column(this.name);
  
  Equals eq(other) => new Equals(this, other);
  
  GreaterThan gt(other) => new GreaterThan(this, other);
  
  LessThan lt(other) => new LessThan(this, other);
  
  GreaterThanOrEquals gtoe(other) => new GreaterThanOrEquals(this, other);
  
  LessThanOrEquals ltoe(other) => new LessThanOrEquals(this, other);
  
  String toString() => name;
}

abstract class Operator implements WhereStatement {
  Column identifier;
  var value;
  
  Operator(this.identifier, this.value);
  
  AndCombinator and(Operator other) => new AndCombinator(this, other);
  OrCombinator or(Operator other) => new OrCombinator(this, other);
}

class Equals extends Operator {
  Equals(Column identifier, value)
      : super(identifier, value);
}

class NotEquals extends Operator {
  NotEquals(Column identifier, value)
      : super(identifier, value);
}

class GreaterThan extends Operator {
  GreaterThan(Column identifier, value)
      : super(identifier, value);
}

class LessThan extends Operator {
  LessThan(Column identifier, value)
      : super(identifier, value);
}

class GreaterThanOrEquals extends Operator {
  GreaterThanOrEquals(Column identifier, value)
      : super(identifier, value);
}

class LessThanOrEquals extends Operator {
  LessThanOrEquals(Column identifier, value)
      : super(identifier, value);
}