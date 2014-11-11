library memory_adapter;

import 'dart:async';
import 'package:plink/plink.dart';


class MemoryAdapter implements DatabaseAdapter {
  Map<String, Table> _tableStore = {};
  
  Future<List<Map<String, dynamic>>>select(SelectStatement select) =>
      throw new UnimplementedError();

  Future createTable(String tableName, List<DatabaseField> fields) {
    _tableStore[tableName] = new Table(tableName, fields);
    return new Future.value();
  }

  Future insert(String tableName, Map<String, dynamic> values) {
    return new Future.value(_tableStore[tableName].insert(values));
  }

  Future dropTable(String tableName) {
    _tableStore.remove(tableName);
    return new Future.value();
  }

  Future where(String tableName, Map<String, dynamic> condition) {
    return new Future.value(_tableStore[tableName].where(condition));
  }
  
  Future delete(String tableName, Map<String, dynamic> condition) {
    _tableStore[tableName].delete(condition);
    return new Future.value();
  }
  
  Future hasTable(String tableName) {
    return new Future.value(null == _tableStore[tableName]);
  }
}


class Table {
  final String name;
  final TableRowGenerator rowGenerator;
  List<Map<String, dynamic>> rows = [];

  Table(this.name, List<DatabaseField> fields)
      : rowGenerator = new TableRowGenerator(fields);

  Map<String, dynamic> insert(Map<String, dynamic> values) {
    var newRow = rowGenerator.generate(values);
    if (rowGenerator.hasAutoIncrementId) {
      newRow["id"] = _getNextId();
    }
    return newRow;
  }

  List<Map<String, dynamic>> where(Map<String, dynamic> condition) {
    return rows.where((row) => meetsCondition(row, condition)).toList();
  }
  
  
  bool meetsCondition(Map<String, dynamic> row, Map<String, dynamic> condition) {
    for (var key in condition.keys) {
      if (row[key] != condition[key]) return false;
    }
    return true;
  }
  
  
  void delete(Map<String, dynamic> condition) {
    rows.removeWhere((row) => meetsCondition(row, condition));
  }
  

  int _getNextId() {
    var biggest = 1;
    rows.forEach((row) {
      if (row["id"] > biggest) biggest = row["id"] + 1;
    });
    return biggest;
  }
}


class TableRowGenerator {
  final List<DatabaseField> structure;
  TableRowGenerator(this.structure);

  Map<String, dynamic> generate(Map<String, dynamic> values) {
    var proto = {};
    structure.forEach((field) => proto[field.name] = null);
    values.forEach((key, value) {
      if (!proto.containsKey(key)) throw "Illegal operation";
      proto[key] = value;
    });
    return proto;
  }

  bool _isIdField(DatabaseField field) {
    return field.name == "id" &&
           field.type == "int" &&
           field.constraints.contains(KEY) &&
           field.constraints.contains(AUTO_INCREMENT);
  }

  bool get hasAutoIncrementId => structure.any(_isIdField);
}