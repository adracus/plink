library plink.postgres_adapter;

import 'dart:async' show Future;
import 'package:u_til/u_til.dart';
import 'package:plink/plink.dart';
import 'package:postgresql/postgresql.dart';

class PostgresAdapter implements DatabaseAdapter {
  final Uri _uri;
  
  PostgresAdapter(uri)
      : _uri = uri is Uri ? uri : Uri.parse(uri);
  
  Future<Connection> obtainConnection() => connect(_uri.toString());
  
  Future<bool> hasTable(String tableName) {
    return obtainConnection().then((conn) {
      return conn.query("SELECT EXISTS (" +
                   "SELECT table_name " +
                   "FROM information_schema.tables " +
                   "WHERE table_schema = 'public' " +
                   "AND table_name = '${tableName.toLowerCase()}' "
                 ")")
          .toList().then((rows) {
        return rows.first[0];})
          .whenComplete(() => conn.close());
    });
  }
  
  Future createTable(TableSchema schema) {
    var variables = schema.structure.values.map(variableForCreate).join(", ");
    return obtainConnection().then((conn) {
      return conn.execute("CREATE TABLE ${schema.tableName} ($variables)")
                 .then((val) => new Future.value())
                 .whenComplete(() => conn.close());
    });
  }
  
  String getType(VariableSchema variable) {
    if (variable.constraints.any((elem) =>
        elem is AutoIncrement)) return "serial";
    if (variable.type == "string") return "text";
    if (variable.type == "int") return "integer";
    if (variable.type == "double") return "double precision";
    if (variable.type == "datetime") return "timestamp";
    return "";
  }
  
  String variableForCreate(VariableSchema variable) {
    var type = getType(variable);
    return ("${variable.name} $type " +
        variable.constraints.map(constraintsForCreate).join(" ")).trim();
  }
  
  static String constraintsForCreate(constraint) {
    if (constraint is PrimaryKey) return "primary key";
    if (constraint is Unique) return "unique";
    return "";
  }
  
  Future<Map<String, dynamic>> findById(String tableName, int id) {
    return obtainConnection().then((conn) {
      return conn.query("SELECT * FROM $tableName WHERE id=@id", {"id": id})
                 .toList().then((rows) => transformRows(rows).first)
                 .whenComplete(() => conn.close());
    });
  }
  
  Future<List<Map<String, dynamic>>> all(String tableName) {
    return obtainConnection().then((conn) {
      return conn.query("SELECT * FROM $tableName")
          .toList().then((rows) => transformRows(rows))
          .whenComplete(() => conn.close());
    });
  }
  
  Future delete(String tableName, int id) {
    return obtainConnection().then((conn) {
      return conn.execute("DELETE FROM $tableName WHERE id=@id", {"id": id})
                 .then((res) => new Future.value())
                 .whenComplete(() => conn.close());
    });
  }
  
  Future dropTable(String tableName) {
    return obtainConnection().then((conn) {
      return conn.execute("DROP TABLE $tableName")
                 .then((res) => new Future.value())
                 .whenComplete(() => conn.close());
    });
  }
  
  Future<List<Map<String, dynamic>>> findWhere(String tableName,
      Map<String, dynamic> condition) {
    List conditions = $(condition).flatten((k, v) => "$k = @$k");
    return obtainConnection().then((conn) {
      conn.query("SELECT * FROM $tableName WHERE ${conditions.join(" AND ")}",
          condition).toList().then(transformRows)
          .whenComplete(() => conn.close());
    });
  }
  
  List<Map<String, dynamic>> transformRows(List<Row> rows) {
    var result = [];
    rows.forEach((row) {
      var transformed = {};
      row.forEach((name, value) => transformed[name] = value);
      result.add(transformed);
    });
    return result;
  }
  
  Future<Map<String, dynamic>> saveToTable(String tableName,
      Map<String, dynamic> values) {
    var keyNames = values.keys.join(", ");
    var keySubs = values.keys.map((name) => "@$name").join(", ");
    return obtainConnection().then((conn) {
      return conn.query("INSERT INTO $tableName ($keyNames) VALUES " + 
                          "($keySubs) RETURNING *", values).toList()
                 .then((rows) => transformRows(rows).first)
                 .whenComplete(() => conn.close());
    });
  }
  
  Future<Map<String, dynamic>> updateToTable(String tableName,
      Map<String, dynamic> values) {
    var id = values.remove("id");
    var keyNames = values.keys.join(", ");
    var keySubs = values.keys.map((name) => "@$name").join(", ");
    return obtainConnection().then((conn) {
      return conn.query("UPDATE $tableName SET ($keyNames) = ($keySubs)" +
                          " WHERE id=$id RETURNING *", values).toList()
                 .then((rows) => transformRows(rows).first)
                 .whenComplete(() => conn.close());
    });
  }
  
  Future<TableSchema> describeTable(String tableName) =>
      obtainConnection().then((conn) =>
          conn.query("SELECT column_name, data_type "+
                     "FROM information_schema.columns " +
                     "WHERE table_name = '${tableName.toLowerCase()}'").toList()
              .then(transformRows)
              .then((rows) {
      }).whenComplete(() => conn.close()));
}