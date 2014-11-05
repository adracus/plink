import 'dart:mirrors';
import 'package:plink/plink.dart';
import 'package:plink/postgres_adapter.dart';
import 'package:plink/memory_adapter.dart';

class TestClass extends Model {
  String firstName;
  String lastName;
}

main() {
  var adapter = new PostgresAdapter(
      "postgres://dartman:password@localhost:5432/dartbase");
  adapter.logger.onRecord.listen((record) => print(record));
  var migrator = new Migrator(adapter);
  var index = new SchemaIndex([reflectClass(TestClass)], migrator);

  var model = new TestClass();

  var schema = index.getModelSchema(TestClass);
  schema.save(model).then((saved) {
    print(saved.id);
  });
}