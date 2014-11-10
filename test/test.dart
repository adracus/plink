import 'package:plink/plink.dart';
import 'package:plink/postgres_adapter.dart';
import 'package:plink/src/statement/statement.dart';

class TestClass extends Model {
  Map aMap;
  
  TestClass();
  
  @defaultConstructor
  TestClass.def();
}

main() {
  var adapter = new PostgresAdapter(
      "postgres://dartman:password@localhost:5432/dartbase");
  adapter.logger.onRecord.listen((record) => print(record));
  var repo = new ModelRepository.global(adapter);

  var model = new TestClass();
  model.aMap = {1: "one", 2: "two"};
  
  var test = select("*", from(["myTable", "yourTable"]), where(c("name").eq("Threaderic")));
  var st = test.toPreparedStatement();

  
  repo.save(model).then((model) {
    repo.find(TestClass, model.id).then((loaded) {
      print(loaded.aMap);
      repo.index.dropAll();
    });
  });
}