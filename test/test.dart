import 'package:plink/plink.dart';
import 'package:plink/postgres_adapter.dart';
import 'package:unittest/unittest.dart';

class TestModel extends Model {
  @unique
  String name;
  
  List<double> test;
}

main() {
  ModelRepository.adapter =
      new PostgresAdapter("postgres://dartman:password@localhost:5432/dartbase");
  var inst = new TestModel();
  
  inst.save();
}