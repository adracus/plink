import 'package:plink/plink.dart';
import 'package:plink/postgres_adapter.dart';
import 'package:unittest/unittest.dart';

class TestClass extends Model {
  String name;
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
  model.name = "Test";
  model.aMap = {1: "one", 2: "two"};
  var model2 = new TestClass();
  model2.name = "Not Test";
  model2.aMap = {2: "two", "three": 3};
  
  repo.saveMany([model, model2], deep: true).then((models) {
    repo.find(TestClass, models.first.id).then((loaded) {
      print(loaded.aMap);
      
      repo.where(TestClass, c("name").eq("Test").or(c("name").eq("Not Test"))).then((models) {
        models.forEach((model) => print(model.name));
        repo.index.dropAll();
      });
    });
  });
}