import 'package:plink/plink.dart';
import 'package:plink/postgres_adapter.dart';
import 'package:unittest/unittest.dart';

class TestModel extends Model {
  String name;
  
  List<int> accountNrs;
}

main() {
  REPO.adapter =
      new PostgresAdapter("postgres://dartman:password@localhost:5432/dartbase");
  
  REPO.find(TestModel, 2).then((model) {
    print(model.accountNrs);
  });
  
  
  test("Model persisting", () {
    var model = new TestModel();
    model.name = "Test Name";
    model.save().then(expectAsync((TestModel saved) {
      expect(saved.name, equals("Test Name"));
      expect(saved.id, isNotNull);
      saved.delete();
    }));
  });
  
  test("Model finding", () {
    var model = new TestModel();
    model.name = "Find me";
    model.save().then(expectAsync((TestModel saved) {
      expect(saved.name, equals("Find me"));
      expect(saved.id, isNotNull);
      REPO.where(TestModel, {"id": saved.id}).then(expectAsync((List models) {
        expect(models.length, equals(1));
        expect(models.single.name, equals("Find me"));
        models.single.delete();
      }));
    }));
  });
}