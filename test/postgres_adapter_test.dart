import 'dart:mirrors';
import 'package:plink/postgres_adapter.dart';
import 'package:plink/plink.dart';

class TestTable extends Model {
  String name;
}

const one = 1;
const two = 2;

@one @two
class Test {
}

main() {
  //ModelRepository.adapter = new PostgresAdapter("postgres://dartman:password@localhost:5432/dartbase");
  var cm = reflectClass(Test);
  print(cm.metadata.map((m) => m.reflectee).toList());
}