import 'package:plink/plink.dart';
import 'package:plink/postgres_adapter.dart';
import 'package:unittest/unittest.dart';

class TestModel extends Model {
  String name;
  
  TestModel(this.name);
  
  @defaultConstructor
  TestModel.def();
  
  TestName testName;
  List<int> accountNrs;
  List<TestName> names;
}

class TestName extends Model {
  TestName([this.firstName, this.lastName]);
  
  String firstName;
  String lastName;
}

onRecord(record) => print(record);

main() {
  autoMigrate = true;
  REPO.adapter =
      new PostgresAdapter("postgres://dartman:password@localhost:5432/dartbase");
  REPO.adapter.logger.onRecord.listen(onRecord);
  
  test("Model persisting", () {
    var model = new TestModel("Test Name");
    model.accountNrs = [1, 2, 3];
    model.names = [new TestName("That is", "A name")];
    model.testName = new TestName("My Name", "Not known");
    model.save().then(expectAsync((TestModel saved) {
      expect(saved.name, equals("Test Name"));
      expect(saved.id, isNotNull);
      expect(saved.names.single.firstName, equals("That is"));
      expect(saved.names.single.lastName, equals("A name"));
      saved.delete(recursive: true);
    }));
  });
  
  test("Model finding", () {
    var model = new TestModel("Find me");
    model.accountNrs = [99, 199];
    model.save().then(expectAsync((TestModel saved) {
      expect(saved.name, equals("Find me"));
      expect(saved.id, isNotNull);
      expect(saved.accountNrs, equals([99, 199]));
      REPO.where(TestModel, {"id": saved.id}).then(expectAsync((List models) {
        expect(models.length, equals(1));
        expect(models.single.name, equals("Find me"));
        expect(models.single.accountNrs, equals([99, 199]));
        models.single.delete(recursive: true);
      }));
    }));
  });
  
  test("List persisting and changing", () {
    var model = new TestModel("No name");
    model.accountNrs = [1, 3];
    model.save().then(expectAsync((TestModel saved) {
      expect(saved.accountNrs, equals([1, 3]));
      saved.accountNrs.add(4);
      saved.save().then(expectAsync((savedAgain) {
        expect(savedAgain.accountNrs, equals([1, 3, 4]));
        savedAgain.delete();
      }));
    }));
  });
}