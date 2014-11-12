import "dart:mirrors" show reflectClass;
import "package:mock/mock.dart";
import "package:unittest/unittest.dart";
import "package:plink/plink.dart";

@proxy
class MockMigrator extends Mock implements Migrator {
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

@proxy
class MockMapperFramework extends Mock implements MapperFramework {
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}


class MyModel extends Model {
  String name;
}


main() {
  group("FieldCombination", () {
    test("No key field error", () {
      expect(() => new FieldCombination([]), throwsArgumentError);
    });
  });
  
  group("ConstraintSet", () {
    test("hasKeyConstraint", () {
      var withoutKeyConstraint = new ConstraintSet([AUTO_INCREMENT]);
      var withKeyConstraint = new ConstraintSet([KEY, AUTO_INCREMENT]);
      
      expect(withoutKeyConstraint.hasKeyConstraint, equals(false));
      expect(withKeyConstraint.hasKeyConstraint, equals(true));
    });
  });
  
  group("SchemaIndex", () {
    
    test("Index schema for", () {
      var migrator = new MockMigrator()
                          ..when(callsTo("migrate")).thenReturn(null);
      var schemaIndex = new SchemaIndex([reflectClass(MyModel)], migrator);
      var modelSchema = schemaIndex.schemaFor(MyModel);
      var mapperSchema = schemaIndex.schemaFor(String);
      
      expect(modelSchema, new isInstanceOf<ModelSchema>());
      expect(modelSchema.name, equals(reflectClass(MyModel).qualifiedName));
      expect(mapperSchema, new isInstanceOf<StringMapper>());
    });
    
    test("All schemes", () {
      var migrator = new MockMigrator()
                          ..when(callsTo("migrate")).thenReturn(null);
      var schemaIndex = new SchemaIndex([reflectClass(MyModel)], migrator);
      
      // 4 because of name, created_at, updated_at, MyModel
      expect(schemaIndex.schemes.length, equals(1));
    });
  });
}

