import 'package:plink/plink.dart';
import 'package:plink/postgres_adapter.dart';

class TestClass extends Model {
  String firstName;
  String lastName;
  List<String> otherStrings;
  Symbol test;
  Map aMap;
  
  TestClass(this.firstName, this.lastName);
  
  @defaultConstructor
  TestClass.def();
}

main() {
  var adapter = new PostgresAdapter(
      "postgres://dartman:password@localhost:5432/dartbase");
  adapter.logger.onRecord.listen((record) => print(record));
  var repo = new ModelRepository.global(adapter);

  var model = new TestClass("Watanga", "no");
  model.otherStrings = ["wahhhhahhh", "wuuuh"];
  model.test = #wahhaa;
  model.aMap = {1: "one", 2: "two"};

  
  repo.save(model).then((model) {
    repo.find(TestClass, model.id).then((loaded) {
      print(loaded.firstName);
    });
  });
}