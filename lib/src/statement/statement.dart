library plink.statement;


part 'helper_functions.dart';

class PreparedStatement {
  final String sql;
  final Map<String, dynamic> values;
  
  PreparedStatement(this.sql, [this.values = const{}]);
  
  PreparedStatement operator+(other) => append(other);
  
  PreparedStatement append(other) {
    if (other is String) other = new PreparedStatement(other);
    var newValues = {}..addAll(values)..addAll(other.values);
    return new PreparedStatement(this.sql + other.sql, newValues);
  }
  
  PreparedStatement prepend(other) {
    if (other is String) other = new PreparedStatement(other);
    var newValues = {}..addAll(values)..addAll(other.values);
    return new PreparedStatement(other.sql + this.sql, newValues);
  }
  
  String toString() => sql;
}


abstract class SQLConvertable {
  String toSQL();
}


abstract class SQLStatement {
  PreparedStatement toPreparedStatement();
}

class SelectStatement implements SQLStatement {
  final Select select;
  final WhereClause where;
  
  const SelectStatement(this.select, [this.where]);
  
  PreparedStatement toPreparedStatement() {
    var sql = select.toSQL();
    if (null == where) return new PreparedStatement(sql);
    
    return where.toPreparedStatement().prepend(sql + " ");
  }
}


abstract class Select implements SQLConvertable {
  final List<String> tableIdentifier;
  final Join join;
  
  const Select(this.tableIdentifier, [this.join]);
  
  String toSQL();
}


class SelectAll extends Select {
  SelectAll(tableIdentifier, [Join join]) : super(tableIdentifier, join);
  
  String toSQL() {
    var sql = "SELECT * FROM ${tableIdentifier.join(", ")}";
    if (null == join) return sql;
    return "$sql ${join.toSQL()}";
  }
}

class SelectSome extends Select {
  final List<ColumnIdentifier> columns;
  
  SelectSome(this.columns, tableIdentifier, [Join join])
      : super(tableIdentifier, join);
  
  String toSQL() => throw new UnimplementedError();
}


abstract class Join implements SQLConvertable {
  final String tableName;
  final ColumnIdentifier first;
  final ColumnIdentifier second;
  
  Join(this.tableName, this.first, this.second);
}


class ColumnIdentifier implements SQLConvertable {
  final String tableName;
  final String columnName;
  
  ColumnIdentifier(this.tableName, this.columnName);
  
  String toSQL() {
    var sql = "$tableName.$columnName";
    return sql;
  }
}


class InnerJoin extends Join {
  InnerJoin(String tableName, ColumnIdentifier first, ColumnIdentifier second)
      : super(tableName, first, second);
  
  String toSQL() {
    var sql = "INNER JOIN $tableName ON $first=$second";
    return sql;
  }
}

class WhereClause implements SQLStatement {
  final WhereStatement statement;
  
  const WhereClause(this.statement);
  
  PreparedStatement toPreparedStatement() {
    return statement.toPreparedStatement().prepend("WHERE ");
  }
}

abstract class WhereStatement implements SQLStatement {
}

abstract class WhereStatementCombinator implements WhereStatement {
  final WhereStatement first;
  final WhereStatement second;
  final String combinatorSymbol;
  
  const WhereStatementCombinator(this.first, this.combinatorSymbol, this.second);
  
  AndCombinator and(Operator operator) => new AndCombinator(this, operator);
  OrCombinator or(Operator operator) => new OrCombinator(this, operator);
  
  PreparedStatement toPreparedStatement() {
    return first.toPreparedStatement() + " $combinatorSymbol " +
        second.toPreparedStatement();
  }
}

class AndCombinator extends WhereStatementCombinator {
  const AndCombinator(first, second) : super(first, "AND", second);
}


class OrCombinator extends WhereStatementCombinator {
  const OrCombinator(first, second) : super(first, "OR", second);
}


class Column {
  final String name;
  
  Column(this.name);
  
  Equals eq(other) => new Equals(this, other);
  
  GreaterThan gt(other) => new GreaterThan(this, other);
  
  LessThan lt(other) => new LessThan(this, other);
  
  GreaterThanOrEqual gtoe(other) => new GreaterThanOrEqual(this, other);
  
  LessThanOrEqual ltoe(other) => new LessThanOrEqual(this, other);
  
  String toString() => name;
}

abstract class Operator implements WhereStatement {
  final Column identifier;
  final value;
  final String operatorSymbol;
  
  const Operator(this.identifier, this.operatorSymbol, this.value);
  
  AndCombinator and(Operator other) => new AndCombinator(this, other);
  OrCombinator or(Operator other) => new OrCombinator(this, other);
  
  PreparedStatement toPreparedStatement() {
    return new PreparedStatement("$identifier$operatorSymbol@$identifier",
        {identifier: value});
  }
}

class Equals extends Operator {
  const Equals(Column identifier, value)
      : super(identifier, "=", value);
}

class NotEquals extends Operator {
  const NotEquals(Column identifier, value)
      : super(identifier, "<>", value);
}

class GreaterThan extends Operator {
  const GreaterThan(Column identifier, value)
      : super(identifier, ">", value);
}

class LessThan extends Operator {
  const LessThan(Column identifier, value)
      : super(identifier, "<", value);
}

class GreaterThanOrEqual extends Operator {
  const GreaterThanOrEqual(Column identifier, value)
      : super(identifier, ">=", value);
}

class LessThanOrEqual extends Operator {
  const LessThanOrEqual(Column identifier, value)
      : super(identifier, "<=", value);
}