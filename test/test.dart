import 'dart:mirrors';
import 'package:plink/plink.dart';
import 'package:plink/postgres_adapter.dart';
import 'package:plink/memory_adapter.dart';

class TestClass extends Model {
  String firstName;
  String lastName;
  List<String> otherStrings;
  Symbol test;
  Map aMap;
}

main() {
  var adapter = new PostgresAdapter(
      "postgres://dartman:password@localhost:5432/dartbase");
  adapter.logger.onRecord.listen((record) => print(record));
  var migrator = new Migrator(adapter);
  var index = new SchemaIndex([reflectClass(TestClass)], migrator);

  var model = new TestClass();
  model.firstName = "Watanga";
  model.lastName = "No";
  model.otherStrings = ["wahhhhahhh", "wuuuh"];
  model.test = #wahhaa;
  model.aMap = {1: "one", 2: "two"};

  var schema = index.getModelSchema(TestClass);
  schema.load(1).then((model) {
    print(model.aMap);
  });
}