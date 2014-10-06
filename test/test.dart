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
  
  test("Model persisting", () {
    var model = new TestModel();
    model.name = "Test Name";
    model.accountNrs = [1, 2, 3];
    model.save().then(expectAsync((TestModel saved) {
      expect(saved.name, equals("Test Name"));
      expect(saved.id, isNotNull);
      print(saved.accountNrs);
      saved.delete();
    }));
  });
  
  test("Model finding", () {
    var model = new TestModel();
    model.name = "Find me";
    model.accountNrs = [99, 199];
    model.save().then(expectAsync((TestModel saved) {
      expect(saved.name, equals("Find me"));
      expect(saved.id, isNotNull);
      expect(saved.accountNrs, equals([99, 199]));
      REPO.where(TestModel, {"id": saved.id}).then(expectAsync((List models) {
        expect(models.length, equals(1));
        expect(models.single.name, equals("Find me"));
        expect(models.single.accountNrs, equals([99, 199]));
        models.single.delete();
      }));
    }));
  });
  
  test("List persisting and changing", () {
    var model = new TestModel();
    model.accountNrs = [1, 3];
    model.save().then(expectAsync((TestModel saved) {
      expect(saved.accountNrs, equals([1, 3]));
      saved.accountNrs.add(4);
      saved.save().then(expectAsync((savedAgain) {
        expect(savedAgain.accountNrs, equals([1, 3, 4]));
      }));
    }));
  });
}