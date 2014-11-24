import 'package:plink/plink.dart';
import 'package:plink/postgres_adapter.dart';


class TestClass extends Model {
  String name;
  Map aMap;
  
  TestClass();
  
  @defaultConstructor
  TestClass.def();
}

main() {
  var adapter = new PostgresAdapter(
      Uri.parse("postgres://dartman:password@0.0.0.0:5432/dartbase?sslmode=require"));
  adapter.logger.onRecord.listen((record) => print(record));
  var repo = new ModelRepository.global(adapter);

  var model = new TestClass();
  model.name = "Test";
  model.aMap = {1: "one", 2: "two"};
  
  repo.saveMany([model], deep: true).then((models) {
    repo.find(TestClass, models.first.id).then((loaded) {
      print(loaded.aMap);
      
      repo.where(TestClass, c("name").eq("Test").or(c("name").eq("Not Test"))).then((models) {
        models.forEach((model) => print(model.name));
        models.forEach((model) => print(model.aMap));
        repo.index.dropAll();
      });
    });
  });
}