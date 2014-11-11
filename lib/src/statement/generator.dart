part of plink.statement;

class PreparedStatement {
  final String sql;
  final Map<String, dynamic> values;
  
  PreparedStatement(this.sql, [this.values = const{}]);
  
  PreparedStatement operator+(other) => append(other);
  
  PreparedStatement append(other) {
    if (other is String) return new PreparedStatement(sql + other, values);
    var newValues = {}..addAll(values)..addAll(other.values);
    return new PreparedStatement(this.sql + other.sql, newValues);
  }
  
  PreparedStatement prepend(other) {
    if (other is String) return new PreparedStatement(other + sql, values);
    var newValues = {}..addAll(values)..addAll(other.values);
    return new PreparedStatement(other.sql + this.sql, newValues);
  }
  
  String toString() => sql;
}

class StatementConverter {
  static const OPERATOR_MAPPING = const {
    Equals: "=",                NotEquals: "<>",
    GreaterThan: ">",           LessThan: "<",
    GreaterThanOrEquals: ">=",  LessThanOrEquals: "<="
  };
  
  static const COMBINATOR_MAPPING = const {
    AndCombinator: "AND",       OrCombinator: "OR"
  };
  
  PreparedStatement convertSelectStatement(SelectStatement statement) {
    var select = convertSelect(statement.select);
    if (null == statement.where) return select;
    var where = convertWhereClause(statement.where);
    return select + " " + where;
  }
  
  PreparedStatement convertJoin(Join join) {
    if (join is InnerJoin) return convertInnerJoin(join);
    throw new ArgumentError("Unknown object $join");
  }
  
  PreparedStatement convertInnerJoin(InnerJoin innerJoin) {
    var statement =  new PreparedStatement('INNER JOIN "${innerJoin.table}" ON ');
    var firstIdentifier = convertColumnIdentifier(innerJoin.first);
    var secondIdentifier = convertColumnIdentifier(innerJoin.second);
    return statement + firstIdentifier + "=" + secondIdentifier;
  }
  
  PreparedStatement convertSelect(Select select) {
    if (select is SelectAll) return convertSelectAll(select);
    if (select is SelectSome) return convertSelectSome(select);
    throw new ArgumentError("Unknown object $select");
  }
  
  PreparedStatement convertSelectAll(SelectAll selectAll) {
    var statement = new PreparedStatement("SELECT * FROM " +
        "${selectAll.tableIdentifier.join(", ")}");
    if (null == selectAll.join) return statement;
    var join = convertJoin(selectAll.join);
    return statement + " " + join;
  }
  
  PreparedStatement convertSelectSome(SelectSome selectSome) {
    var identifierString = selectSome.columns.map(convertColumnIdentifier)
                                             .join(", ");
    var statement = new PreparedStatement("SELECT $identifierString FROM " +
        "${selectSome.tableIdentifier.join(", ")}");
    if (null == selectSome.join) return statement;
    var join = convertJoin(selectSome.join);
    return statement + " " + join;
  }
  
  PreparedStatement convertWhereClause(WhereClause clause) {
    return convertWhereStatement(clause.statement).prepend("WHERE ");
  }
  
  PreparedStatement convertColumnIdentifier(ColumnIdentifier identifier) {
    return new PreparedStatement('"${identifier.table}"."${identifier.name}"');
  }
  
  PreparedStatement convertWhereStatement(WhereStatement statement) {
    if (statement is Operator) return convertOperator(statement);
    if (statement is Combinator) return convertCombinator(statement);
    throw new ArgumentError("Unknown object $statement");
  }
  
  PreparedStatement _convertOperator(Operator operator) {
    var sign = OPERATOR_MAPPING[operator.runtimeType];
    return new PreparedStatement('"${operator.identifier}"$sign@${operator.identifier}',
      {operator.identifier.name: operator.value});
  }
  
  PreparedStatement _convertCombinator(Combinator combinator) {
    var sign = COMBINATOR_MAPPING[combinator.runtimeType];
    var firstStatement = convertWhereStatement(combinator.first);
    var secondStatement = convertWhereStatement(combinator.second);
    return firstStatement + " $sign " + secondStatement;
  }
  
  PreparedStatement convertCombinator(Combinator combinator) {
    if (combinator is AndCombinator) return convertAndCombinator(combinator);
    if (combinator is OrCombinator) return convertOrCombinator(combinator);
    throw new ArgumentError("Unknown object $combinator");
  }
  
  PreparedStatement convertAndCombinator(AndCombinator and) {
    return _convertCombinator(and);
  }
  
  PreparedStatement convertOrCombinator(OrCombinator or) {
    return _convertCombinator(or);
  }
  
  PreparedStatement convertOperator(Operator operator) {
    if (operator is Equals) return convertEqualsOperator(operator);
    if (operator is NotEquals) return convertNotEqualsOperator(operator);
    if (operator is GreaterThan) return convertGreaterThanOperator(operator);
    if (operator is LessThan) return convertLessThanOperator(operator);
    if (operator is GreaterThanOrEquals)
      return convertGreaterThanOrEqualsOperator(operator);
    if (operator is LessThanOrEquals)
      return convertLessThanOrEqualsOperator(operator);
    throw new ArgumentError("Unknown object $operator");
  }
  
  PreparedStatement convertEqualsOperator(Equals equals) {
    return _convertOperator(equals);
  }
  
  PreparedStatement convertNotEqualsOperator(NotEquals notEquals) {
    return _convertOperator(notEquals);
  }
  
  PreparedStatement convertGreaterThanOperator(GreaterThan greaterThan) {
    return _convertOperator(greaterThan);
  }
  
  PreparedStatement convertLessThanOperator(LessThan lessThan) {
    return _convertOperator(lessThan);
  }
  
  PreparedStatement convertGreaterThanOrEqualsOperator
    (GreaterThanOrEquals greaterThanOrEquals) {
    return _convertOperator(greaterThanOrEquals);
  }
  
  PreparedStatement convertLessThanOrEqualsOperator
    (LessThanOrEquals lessThanOrEquals) {
    return _convertOperator(lessThanOrEquals);
  }
}